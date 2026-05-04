# HTTP Cache Policy

StackLight reads from the local `Cache.sqlite` first and only spends a network request when there's something fresh to deliver. This document records what's currently cached for each provider, why, and what would change if a provider added/removed conditional-request support.

## Cache backend

Two layers, defined in `StackLightCore/Support/`:

- `HTTPResponseCache` — SQLite (GRDB), `~/Library/Application Support/StackLight/Cache.sqlite`. Stores body + ETag + status + headers JSON + rate-limit metadata, keyed by URL.
- `ETagCache` — actor with an in-memory LRU (512 entries) over the SQLite store. Reads check RAM first, fall back to disk.

Both are owned by `RequestRunner`. The `cached / saved / hit` counters are surfaced in the menu footer and the future `Cache & Limits` settings view.

## Per-provider matrix

| Provider | Path | ETag support | Currently cached | Notes |
|---|---|---|---|---|
| GitHub Actions | `RequestRunner.execute` | ✅ Yes (REST) | ❌ No (uses `execute` for custom error decode) | Migration target — switch to `get(...)` once the Vercel-style error decode pattern is generalized. |
| GitHub PRs | `RequestRunner.execute` | ✅ Yes (REST) | ❌ No | Same as above. |
| Vercel | `RequestRunner.execute` | ❌ No (v6 `/deployments` doesn't issue ETags) | ❌ No | Could cache `body + Last-Modified` instead, but Vercel's `created` field already lets the client diff cheaply. |
| Cloudflare Pages | `RequestRunner.get` | ⚠️ Inconsistent (some endpoints set `etag`, others don't) | ✅ Opportunistic — saved when `ETag` header present; ignored otherwise. | Safe default. |
| Netlify | `RequestRunner.get` | ❌ No (`/deploys` is uncached) | ✅ Opportunistic | Same as Cloudflare; never receives a 304. |
| Railway | `RequestRunner.execute` (POST GraphQL) | ❌ No (POST + body) | ❌ No | GraphQL bodies are not cacheable by URL alone. Would need a body-hashed cache table. |
| Fly.io | `RequestRunner.get` | ❌ No | ✅ Opportunistic | Same. |
| TestFlight | AppStoreConnect SDK | n/a | ❌ No | SDK does its own networking — outside `RequestRunner`. |
| Xcode Cloud | AppStoreConnect SDK | n/a | ❌ No | Same. |

## Decisions

1. **`useETag` defaults to `true`.** The behavior is safe: when the server doesn't issue an `ETag`, nothing gets cached and nothing changes. When it does, we get a 304 for free.
2. **Providers that need to read service-specific error bodies use `execute(request:)`** and lose the automatic ETag wiring. Acceptable trade-off — those endpoints either don't issue ETags or the latency saved isn't worth losing the structured error message. Worth revisiting if those providers add ETag support upstream.
3. **GraphQL responses (Railway) are not cached.** Caching requires hashing the request body — feasible (RepoBar does it) but a bigger lift than necessary right now.
4. **The cache is shared across providers in a single SQLite file.** Per-provider tables would simplify partial clears but split the rate-limit table into pieces; the unified table mirrors RepoBar.

## When to revisit

- A provider starts issuing `ETag` / `Last-Modified` → flip its call site from `execute` to `get`.
- API costs become a problem (repeated 200 with same body) → introduce a content-hash fallback.
- Polling interval drops below 30 s → cache becomes load-bearing rather than nice-to-have; review eviction LRU size.
