# stacklightcli

A small CLI that exercises the same provider, cache, and settings code paths the menu-bar app uses. Useful for:

- Verifying credentials before opening the GUI (`stacklight test vercel`).
- Diagnosing "why doesn't X show up?" — point the CLI at a provider and inspect the raw fetch.
- Scripting / Raycast / Alfred integrations (`stacklight deployments --json`).
- Inspecting and clearing the persistent HTTP cache.

## Build

```bash
swift build --product stacklightcli
.build/debug/stacklightcli --help
```

For a release build:

```bash
swift build -c release --product stacklightcli
cp .build/release/stacklightcli /usr/local/bin/stacklight
```

## Commands

```
stacklight deployments [--provider <id>] [--json | --plain]
stacklight test <provider-id>            # one-shot fetch, prints details
stacklight providers status              # which providers are configured
stacklight providers list                # all providers, configured or not
stacklight cache status [--limit N]      # SQLite cache summary
stacklight cache clear                   # wipe persistent + in-memory caches
stacklight rate-limits                   # active cooldowns + cache hits
stacklight settings show
stacklight settings pin    <provider:item>
stacklight settings hide   <provider:item>
stacklight settings reset  <provider:item>
```

Every command supports `--json` for machine-readable output.

## Sharing state with the GUI

The CLI links `StackLightCore` directly, so it reads the same:

- Keychain entries (`KeychainManager`)
- UserDefaults (`AppConfig.defaults`, `SettingsStore`)
- Persistent cache (`~/Library/Application Support/StackLight/Cache.sqlite`)

That means `stacklight settings hide vercel:abc` is equivalent to right-clicking that row in the menu and choosing Hide — the GUI picks it up via `SettingsStore.didChange` next time the menu rebuilds.
