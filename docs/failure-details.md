# Deployment Failure Details (hover card + agent handoff)

Hovering a **failed** row in the menu bar panel opens a floating card with
the failure reason pulled on demand from the provider's API, plus actions to
copy the error — either as plain text or as a ready-to-paste **AI agent
prompt** — or to launch `claude` / `codex` in Terminal with that prompt.
The same actions live in the row's right-click menu as a hover-free
fallback.

## Data flow

```
MenuBarContentView row (status == .failed)
  └─ ErrorHoverAnchor (tracking area, hit-test transparent)
       └─ ErrorHoverPanelController (non-activating NSPanel, child of the menu window)
            └─ ErrorDetailCard (SwiftUI)
                 └─ FailureDetailsStore (@MainActor UI state)
                      └─ FailureDetailsService (actor: TTL cache + in-flight de-dupe)
                           └─ provider.fetchFailureDetails(for:)   // FailureDetailsProviding
```

- `FailureDetailsProviding` (StackLightCore) is an opt-in capability
  protocol next to `DeploymentProvider`. Providers without a usable
  upstream API simply don't adopt it; the card then renders metadata plus
  copy actions ("metadata only").
- Details are fetched **only on demand** (hover / copy), never during the
  regular poll — log endpoints are the most expensive calls providers
  offer. Results are cached ~10 minutes per deployment (failed builds are
  immutable) and capped at 50 entries.
- `AIErrorHandoff.deploymentPrompt(for:)` builds the agent prompt:
  deployment metadata, failure summary, structured issues, a sanitized log
  tail (ANSI stripped, `\r` progress collapsed, last 60 lines / 6 KB), and
  instructions for the agent.

## Window-activation rules (why the hover card is hand-rolled)

The menu panel is a `MenuBarExtra(.window)` — it dismisses itself when it
stops being the key window, and the app is an `LSUIElement` accessory that
must not activate on hover. Consequences baked into
`ErrorHoverPanelController`:

- The card lives in a borderless `NSPanel` with
  `.nonactivatingPanel`, and `canBecomeKey`/`canBecomeMain` overridden to
  `false`. It can never take key status, so the menu panel never resigns
  key and stays open while the user interacts with the card.
- It is attached as a **child window** of the menu panel (same window
  level, same collection behavior + `.fullScreenAuxiliary`) so it stacks
  above it, follows it, and dies with it (`willCloseNotification` +
  `onDisappear` both tear it down).
- Copying uses `NSPasteboard` only — no activation needed. The card has no
  text fields, so it never needs keyboard focus.
- "Open Logs" / "Open in Claude/Codex" intentionally activate another app
  (browser/Terminal); the menu then closes itself and the card follows.
- Show is delayed (~320 ms) so scanning the list doesn't flash cards; hide
  has a ~200 ms grace window so the pointer can travel from the row into
  the card.

## Per-provider support matrix

| Provider | Failure details | Upstream API used | What you get |
|---|---|---|---|
| Vercel | ✅ | `GET /v3/deployments/{id}/events?direction=backward&limit=200` | Build log tail (command/stdout/stderr/fatal events), last error line as summary |
| GitHub Actions | ✅ | `GET …/actions/runs/{id}/jobs` + `GET …/check-runs/{jobID}/annotations` | Failed job + step names, log annotations (`::error::`, compiler diagnostics) with file:line |
| Cloudflare Pages | ✅ | `GET …/deployments/{id}` + `GET …/deployments/{id}/history/logs` | Failing stage, build log tail, `Failed: …` line as summary |
| Netlify | ✅ | `GET /api/v1/deploys/{id}` | `error_message` summary + deep link to the deploy log page (raw logs aren't in the public REST API) |
| GitLab CI | ✅ | `GET …/pipelines/{id}/jobs` + `GET …/jobs/{id}/trace` | Failed jobs (name, stage, `failure_reason`, `allow_failure` respected), trace tail |
| Railway | ✅ | GraphQL `buildLogs(deploymentId:limit:)`, falls back to `deploymentLogs` | Build (or crash) log tail, last `err`-severity line as summary |
| Xcode Cloud | ✅ | ASC `GET /v1/ciBuildRuns/{id}/actions` + `GET /v1/ciBuildActions/{id}/issues` | Compile errors / test failures with file:line, per-action summary |
| TestFlight | ➖ metadata only | — | App Store Connect's public API doesn't expose review rejection reasons or processing diagnostics |
| GitHub PRs | ➖ metadata only | — | A PR row isn't a build; failure context = checks on the head SHA (possible follow-up via check-runs API) |
| GitLab MRs | ➖ metadata only | — | Same as GitHub PRs (head pipeline jobs would be the follow-up) |
| Fly.io | ➖ metadata only | — | Machines API has state/events but no log endpoint in plain REST (logs need NATS/log-shipper) |
| Supabase | ➖ metadata only | — | Management API exposes health/action state, not failure logs |
| Zeabur | ➖ metadata only | — | Log queries exist but are undocumented/unstable GraphQL |

"Metadata only" rows still get the hover card and both copy actions — the
agent prompt just carries deployment metadata plus a note that no detailed
output was available.

## Testing

- `Tests/StackLightCoreTests/DeploymentFailureDetailsTests.swift` — log
  tail trimming/sanitizing, prompt content, service caching.
- `Tests/StackLightCoreTests/ProviderFailureDetailsTests.swift` — wire
  format decoding fixtures + mapping for each supported provider,
  including ID → native-coordinate recovery (GitHub run URL, GitLab
  `gl-pipeline-<path>-<id>`).
