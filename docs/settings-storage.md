# Settings Storage

Single source of truth for every persisted user setting in StackLight.

## Layers

```
┌──────────────────────────────────────────────────────────────────┐
│ SwiftUI views          @SettingsValue(\.fieldName)               │
│ (macOS + iOS)          @SettingsString("key") / @SettingsBool    │
└──────────────────────────────────────────────────────────────────┘
                                │
┌──────────────────────────────────────────────────────────────────┐
│ Provider code          AppConfig.string(forKey: "vercel.teamId") │
│ + non-SwiftUI          AppConfig.bool(forKey: …)                 │
│ (PollingManager,       AppConfig.setValue(…, forKey: …)          │
│  CLI, BG refresh)                                                │
└──────────────────────────────────────────────────────────────────┘
                                │
┌──────────────────────────────────────────────────────────────────┐
│ SettingsStore.shared    ObservableObject + lock-protected envelope│
│                         settings: UserSettings                    │
│                         mutate { … }, string(for:), setBool(…)    │
└──────────────────────────────────────────────────────────────────┘
                                │
┌──────────────────────────────────────────────────────────────────┐
│ UserDefaults             one key: app.yellowplus.stacklight.settings│
│ (App Group on iOS,       JSON-encoded SettingsEnvelope            │
│  .standard on macOS)     { version, settings: UserSettings }      │
└──────────────────────────────────────────────────────────────────┘
```

## What lives where

| Bucket | Field | Why |
|---|---|---|
| Application | pollIntervalSeconds, notificationsEnabled, diagnosticsEnabled, fileLoggingEnabled, loggingVerbosity | Typed properties on UserSettings — autocomplete + compile-time safety. |
| Visibility | pinnedItems, hiddenItems, hiddenProviders | Sets of `DeploymentKey.rawValue` strings. |
| Provider config | providerStrings / providerBools / providerStringArrays | Free-form `[String: T]` dictionaries so adding a new SettingsField doesn't change the schema. |
| Tokens | KeychainManager (separate) | Secrets never go in UserDefaults. |
| OS-managed | SMAppService (Launch at login) | macOS owns the truth — UserSettings doesn't shadow it. |

## Migration

`SettingsEnvelope.version` is bumped on schema changes. `applyMigrations` in `SettingsStore` copies values from older schemas (or, on first launch, from the historical scattered UserDefaults keys) into the new envelope. Idempotent — safe to re-run.

Currently `currentVersion = 2`:
- v0 → v2: copy known keys (`pollInterval`, `notificationsEnabled`, all provider keys) from `.standard` and the App Group suite. Both sources are checked because `@AppStorage` historically wrote to `.standard` while providers wrote to App Group.
- v1 → v2: v1 only had pinned/hidden, so the app-level fields fall back to defaults; provider keys are migrated the same way as v0.

## Adding a new setting

**Application-level (typed):**
1. Add a stored property to `UserSettings`.
2. Add an accessor on `SettingsStore` (mirrors the property).
3. Bind in views via `@SettingsValue(\.newField)`.
4. Bump `currentVersion` and add a default-fill in `applyMigrations` if you removed/renamed a field. New fields are no-ops because `decodeIfPresent` already handles them.

**Provider-level (key-value):**
1. Pick a key like `"foo.bar"`.
2. Read with `AppConfig.string(forKey: "foo.bar")` etc.
3. Optionally add the key to `legacyProviderStringKeys` in `SettingsStore.applyMigrations` if existing users have it stored under the old `.standard` UserDefaults regime.

## Cross-process notes

- iOS host + widget extension share the App Group suite so the envelope is one file. Widget reads pull the same JSON.
- `SettingsStore.didChange` notification only fires within a single process. The widget rebuilds its timeline on a polling cadence anyway, so it picks up changes naturally.
- `objectWillChange` is published on the main thread via `DispatchQueue.main.async` so background callers (CLI, BG refresh) don't trip SwiftUI's main-actor invariants.
