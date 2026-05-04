---
name: stacklight-setup
description: Guide the user through configuring StackLight providers (Vercel, Cloudflare Pages, GitHub Actions/PR, Netlify, Railway, Fly.io, Xcode Cloud, TestFlight). Use when the user says things like "set up StackLight", "configure StackLight", "help me add a new provider", "fill in StackLight settings", or asks how to wire up credentials for any supported service. The skill reads providers.schema.json, collects missing credentials, validates them, and writes a local config JSON the user can reference while entering values in the Settings window.
---

# StackLight Setup

This skill turns a configuration conversation into structured work: the agent reads a schema, probes the environment for existing credentials, asks the user only for what's missing, validates each credential, and emits a JSON file summarizing the result.

## Inputs

- **Schema**: `.Codex/skills/stacklight-setup/providers.schema.json` — the single source of truth for which fields each provider needs. Never hard-code field names; always read this file.
- **Validator**: `.Codex/skills/stacklight-setup/scripts/validate.sh <provider> <json-config>` — returns exit 0 on success, non-zero with a short error on failure.
- **Output**: `./.stacklight-config.json` in the repo root (gitignored). This is a reference the user will manually paste into Settings → StackLight, because secrets must land in macOS Keychain via the UI.

## Workflow

Execute these steps in order. Do not skip steps.

### 1. Load the schema

Read `.Codex/skills/stacklight-setup/providers.schema.json`. The `providers` object is authoritative — every field, secret flag, required flag, and test endpoint comes from here.

### 2. Pick providers

Ask the user which providers they want to enable using `AskUserQuestion`. Offer all keys from `providers.schema.json` plus a free-form "other" option. If the user previously mentioned specific services in the conversation, pre-check those.

### 3. Probe the environment for each enabled provider

Before asking the user for a value, check (in order) whether it already exists:

| Field pattern              | Check these sources                                                                 |
|----------------------------|--------------------------------------------------------------------------------------|
| `github.token`             | `gh auth token` (if `gh` installed), then `$GITHUB_TOKEN`, then `~/.netrc`           |
| `vercel.token`             | `$VERCEL_TOKEN`, then `~/.local/share/com.vercel.cli/auth.json`                      |
| `cloudflare.token`         | `$CLOUDFLARE_API_TOKEN`, then `$CF_API_TOKEN`                                        |
| `cloudflare.accountId`     | `$CLOUDFLARE_ACCOUNT_ID`, then `wrangler whoami` output                              |
| `netlify.token`            | `$NETLIFY_AUTH_TOKEN`, then `~/.netlify/config.json`                                 |
| `railway.token`            | `$RAILWAY_TOKEN`, then `~/.railway/config.json`                                      |
| `flyio.token`              | `$FLY_API_TOKEN`, then `fly auth token`                                              |
| `github.repos`             | `git remote -v` of the current repo; offer that `owner/repo` first                   |
| `asc.*` (Apple)            | Never auto-detect — always ask the user; `.p8` paths are user-specific               |

Run the detection commands with Bash. Do not print secret values back to the user; confirm presence as `(detected ✓)`.

### 4. Ask for the rest — one round only

Use a single `AskUserQuestion` call with one question per still-missing field. Set `multiSelect: false` on all of them and keep the `question` text short. For fields marked `secret: true`, add the suffix `(will be stored in macOS Keychain)` to the question so the user knows the final destination.

### 5. Validate each provider

For every provider the user enabled, call:

```bash
.Codex/skills/stacklight-setup/scripts/validate.sh <provider> <path-to-partial-json>
```

The validator uses only `curl` and `jq`. On non-zero exit, report the error message back to the user and re-ask just the failing fields. Do not continue until every selected provider validates, unless the user explicitly says "skip validation for <provider>".

### 6. Write `./.stacklight-config.json`

Emit a file with this shape (example):

```json
{
  "generatedAt": "2026-04-15T12:00:00Z",
  "providers": {
    "vercel":      { "vercel.token": "***", "vercel.teamId": "" },
    "githubPR":    { "github.token": "***", "github.pr.repos": ["owner/repo"] }
  }
}
```

Redact secrets as `***` when *printing to chat*, but write the real values to the file. Also append `.stacklight-config.json` to `.gitignore` if not already present.

### 7. Tell the user what to do in the UI

Output a short bullet list:

1. Launch StackLight (▲ in menu bar → Settings).
2. For each provider in the config JSON, open that tab, paste the fields listed under its key, click **Save**, then **Test**.
3. Note that credentials listed as `credentialSharedWith` in the schema (e.g. Xcode Cloud ↔ TestFlight, GitHub Actions ↔ GitHub PR) only need to be entered once.

## Rules

- **Never invent field keys.** If the schema does not define a key, do not ask for it.
- **Never commit `.stacklight-config.json`.** Always verify/update `.gitignore`.
- **Never echo secrets** back to the user in plain text after collection — use `***` or the last 4 characters only.
- **Prefer one batch of questions.** Users dislike being drip-fed prompts. Gather everything you know first, then ask once.
- **Shared credentials.** When two providers share a key (see `credentialSharedWith`), collect it once and reuse.
- **`asc.privateKey` (Xcode Cloud).** Ask the user for a file path, then read the `.p8` file contents and strip PEM headers before writing to the config (mirror the provider's own `strippedKey` logic in `XcodeCloudProvider.swift`).

## When to update this skill

If a new provider is added to `Sources/StackLight/Providers/`, update `providers.schema.json` to add its entry. The fields must mirror the Swift `settingsFields()` method exactly — that is the contract.
