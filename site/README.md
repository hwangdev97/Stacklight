# StackLight Site

Marketing site for StackLight, the macOS menu-bar deploy monitor.
Built with Astro + Tailwind, deployed on Cloudflare Pages.

## Develop

```bash
cd site
npm install
npm run dev      # http://localhost:4321
```

## Build

```bash
npm run build    # outputs to site/dist
npm run preview  # local preview of the production build
```

## Deploy

Connected to Cloudflare Pages with these settings:

- **Root directory:** `site`
- **Build command:** `npm run build`
- **Build output directory:** `dist`
- **Node version:** `20`

Pushing to `main` deploys to production. Every PR gets a preview URL automatically.

## Editing copy

Each of the eight landing sections is a single file under `src/sections/`. The
canonical wording lives in `../docs/landing-copy.md` — keep both in sync when
copy changes.

## Calendar (`/calendar`)

Fantastical-style release calendar. Aggregates releases, deploys, and CI runs
from configured providers and serves them via `GET /api/events?from=…&to=…`.

Visit `/calendar?demo=1` to preview the UI with mock data (no credentials needed).

### Configuration

Set environment variables (in `site/.dev.vars` for local dev, in the Cloudflare
Pages dashboard for production). All keys are optional — only the configured
ones contribute events:

| Variable | Purpose |
|---|---|
| `GITHUB_REPOS` | Comma-separated `owner/repo` list. Drives both Releases and Actions. |
| `GITHUB_TOKEN` | Personal access token. Optional for public-repo Releases; required for Actions and to avoid rate limits. |
| `VERCEL_TOKEN` | Vercel API token. |
| `VERCEL_TEAM_ID` | Optional team ID. |
| `VERCEL_PROJECTS` | Optional comma-separated project name filter. |
| `NETLIFY_TOKEN` | Netlify personal access token. |
| `NETLIFY_SITES` | Comma-separated Netlify site IDs. |
| `DEMO` | Set to `1` to always serve mock data alongside real data. |

Adding a new provider: create a module in `src/lib/providers/` implementing
`ProviderModule` and register it in `src/lib/providers/index.ts`.
