# StackLight Landing Page — Development Plan

## Context

The landing copy lives at `docs/landing-copy.md`. This plan describes how to ship the actual website that renders it. Decisions already made:

- **Repo layout:** new `/site` subdirectory in this repo (copy + code stay in sync; one PR updates both).
- **Stack:** Astro 4 + Tailwind CSS. Static-first, near-zero JS, MDX-friendly.
- **Hosting:** Cloudflare Pages. Free, fast, on-brand (StackLight monitors it), auto-deploy from GitHub.
- **Visual direction:** Apple-minimal. System font stack (SF Pro), generous whitespace, subtle gradients, high contrast type.

The marketing copy is already final — this plan does **not** revise wording. It scaffolds the site that displays it.

---

## File structure

```
site/
├── astro.config.mjs
├── tailwind.config.mjs
├── tsconfig.json
├── package.json
├── public/
│   ├── favicon.svg
│   ├── og.png                       # 1200×630 social card
│   └── logos/                       # Service logos (see Assets section)
│       ├── vercel.svg
│       ├── cloudflare.svg
│       ├── netlify.svg
│       ├── railway.svg
│       ├── flyio.svg
│       ├── github.svg
│       ├── xcode-cloud.svg
│       └── testflight.svg
├── src/
│   ├── layouts/
│   │   └── Base.astro               # <html>, meta, OG, fonts, footer slot
│   ├── components/
│   │   ├── Button.astro             # primary / secondary variants
│   │   ├── SectionHeading.astro     # H2 + optional eyebrow
│   │   ├── ServiceLogo.astro        # logo + caption tile
│   │   ├── FeatureCard.astro        # icon + title + body
│   │   └── DialogueBlock.astro      # the agent-conversation pull-quote
│   ├── sections/
│   │   ├── Hero.astro
│   │   ├── TabFatigue.astro
│   │   ├── ServiceGrid.astro
│   │   ├── AISetup.astro
│   │   ├── Features.astro
│   │   ├── HowItWorks.astro
│   │   ├── Security.astro
│   │   └── FinalCTA.astro
│   ├── pages/
│   │   └── index.astro              # composes all eight sections
│   └── styles/
│       └── global.css               # Tailwind directives + base type
└── README.md                        # how to run/deploy locally
```

The eight `sections/*.astro` files map 1:1 to the eight sections in `docs/landing-copy.md`. Keeps copy traceable.

---

## Styling system

**Font stack** (no webfont download):
```css
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text",
             "Segoe UI", Roboto, sans-serif;
```

**Tailwind theme additions** (in `tailwind.config.mjs`):
- `colors.ink`: `#0a0a0a` (body text)
- `colors.muted`: `#6b6b6b` (subhead / microcopy)
- `colors.accent`: `#0066ff` (primary CTA, links)
- `colors.surface`: `#fafafa` (alt section background)
- `fontSize`: enlarge display sizes — `display-xl: clamp(3rem, 7vw, 5.5rem)`, `display-lg: clamp(2rem, 4vw, 3rem)`
- `maxWidth.container`: `1120px`

**Spacing rhythm**: every section uses `py-24 md:py-32`. Inside sections, content uses `space-y-6` for prose, `gap-6 md:gap-8` for grids.

**Hero gradient**: subtle conic / radial gradient behind the H1 — not loud. e.g. `bg-[radial-gradient(ellipse_at_top,_rgba(0,102,255,0.06),_transparent_70%)]`.

**Dark mode**: skip in v1. Apple landing pages are light-first; revisit after launch if requested.

---

## Component contracts

| Component | Props | Notes |
|---|---|---|
| `Button` | `href`, `variant: "primary" \| "secondary"`, slot for label | Primary = filled accent, secondary = link with arrow |
| `SectionHeading` | `eyebrow?`, slot for H2 | Eyebrow is small uppercase label above H2 |
| `ServiceLogo` | `src`, `name`, `caption` | Renders inside the 9-up grid in section 3 |
| `FeatureCard` | `title`, slot for body, optional `icon` | Used 6× in section 5 |
| `DialogueBlock` | slot for `<p class="speaker">` lines | Renders the You/Agent conversation in section 4. Light surface bg, monospace optional |

All components ship as plain Astro `.astro` files — no client-side framework, no hydration directives.

---

## Assets to source

### Already in the repo
- Provider logos: `Sources/StackLight/Resources/ProviderLogos/` already has Cloudflare, Fly.io, GitHub, Netlify, Railway, Vercel as SVGs. Copy these into `site/public/logos/`.

### To source
- **TestFlight + Xcode Cloud logos.** Apple SF Symbols equivalents (`testtube.2`, `cloud`) or use Apple's official press logos. Pick one approach and stay consistent.
- **App icon.** Re-use `Sources/StackLight/AppIcon.icon/` rendered at 256×256 for the hero.
- **Hero screenshot.** Capture the menu bar with the StackLight ▲ icon clicked open, showing two or three deploys in mixed states (one green, one red). Crop to ~880×560.
- **AI setup screencast.** Optional v1; if shipped, ≤8 sec MP4 loop showing a Claude Code / Codex agent running through the setup. If skipped, fall back to the `DialogueBlock` text block alone — copy is already strong enough to stand without media.
- **OG image.** 1200×630 with H1 + ▲ icon, Apple-minimal styling. Generate once with Figma or Canva.
- **Favicon.** Triangle ▲ on white, exported SVG.

---

## Build & deploy

**Local dev**
```bash
cd site
npm install
npm run dev          # http://localhost:4321
```

**Production build**
```bash
npm run build        # outputs to site/dist
npm run preview      # local preview of the production build
```

**Cloudflare Pages setup**
1. Create a new Pages project in Cloudflare dashboard, point it at this GitHub repo.
2. Build settings:
   - **Root directory:** `site`
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`
   - **Node version:** `20`
3. Enable preview deployments on PRs (default on).
4. Connect a custom domain once we own one (e.g. `stacklight.app`). Add it in Pages → Custom domains; Cloudflare handles DNS + cert automatically when the apex is on Cloudflare DNS.

**No CI changes needed.** Cloudflare Pages handles the build itself; the existing GitHub Actions in `.github/workflows/` are macOS build pipelines and stay untouched.

---

## Milestones

### M1 — Skeleton (1 short session)
- `npm create astro@latest site -- --template minimal --typescript strict --tailwind`
- Wire up `Base.astro`, `Button.astro`, `SectionHeading.astro`.
- Stub all eight sections with raw copy from `docs/landing-copy.md` — no styling beyond defaults.
- Verify `npm run dev` renders end-to-end on localhost.

### M2 — Apple-minimal pass
- Apply font stack, color tokens, spacing rhythm.
- Build out `Hero` with gradient and CTA buttons.
- Build out `ServiceGrid` (responsive 3-up → 5-up).
- Build out `AISetup` including `DialogueBlock`.
- Build out `Features` grid (2×3 on desktop, 1-column on mobile).
- Build out `HowItWorks`, `Security`, `FinalCTA`.

### M3 — Assets
- Drop all logos into `public/logos/`.
- Add hero screenshot, OG image, favicon.
- (Optional) record + embed AI-setup screencast.

### M4 — Polish
- OG meta + Twitter card meta in `Base.astro`.
- 404 page (`src/pages/404.astro`) with a tiny "lost a deploy?" joke.
- Accessibility pass: every CTA has discernible text, contrast ratios ≥ AA, focus rings preserved.
- Lighthouse audit — target ≥ 95 on Performance, Accessibility, Best Practices, SEO.
- Cross-browser smoke test: Safari (incl. iOS Safari), Chrome, Firefox.

### M5 — Deploy
- Push to a feature branch → Cloudflare Pages preview deploys automatically → review preview URL.
- Merge to `main` → production deploy.
- Add the live URL to `README.md` under a "Website" badge.

Each milestone is a separate PR. Don't try to ship M1–M5 in one branch.

---

## Files to create / modify

**New** (all under `site/`):
- Everything in the file-structure tree above.

**Modified**:
- `README.md` — add a top-of-file link to the live site once M5 lands.
- `.gitignore` — add `site/node_modules` and `site/dist`.

**Untouched**:
- All Swift sources, `Package.swift`, `.github/workflows/*`, the existing `.claude/skills/stacklight-setup/`. The site is purely additive.

---

## Verification

End-to-end checklist before merging M5:

- [ ] `npm run build` exits 0 with no Astro warnings.
- [ ] Lighthouse ≥ 95 on all four categories on the deployed preview.
- [ ] Page renders correctly on iOS Safari (often the harshest reviewer of a "Mac app" landing page).
- [ ] Every CTA in the copy resolves to a real URL — no `href="#"` leftovers.
- [ ] The 9 service tiles in section 3 match `Sources/StackLight/Core/ServiceRegistry.swift`. If a provider has been added or removed since `docs/landing-copy.md` was written, update both files in the same PR.
- [ ] OG image renders correctly when the URL is pasted into Slack, Twitter/X, and iMessage.
- [ ] No tracking scripts, no analytics, no third-party fonts — keeps the "no analytics, no accounts, no tracking" claim in section 7 honest.

---

## Open questions (none blocking)

These can be settled during M2–M4, not now:

1. **Domain name.** `stacklight.app`? `getstacklight.com`? Cloudflare Pages gives a `*.pages.dev` URL by default, so this isn't a blocker.
2. **Screencast vs static dialogue** in section 4 — recommend shipping static-first (text dialogue is already powerful), record a screencast in a follow-up if conversions are weak.
3. **Pricing / signup.** None for now. The CTA points to a GitHub release. If StackLight ever monetizes, we add a "Pricing" section between Features and Security.
