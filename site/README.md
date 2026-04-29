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
