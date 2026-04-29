# StackLight Landing Page Copy

> Plain-English landing copy aimed at a broad audience — PMs, designers, and indie devs all.
> Highlights the differentiator: **users can hand off configuration to an AI agent** (Claude Code, Codex, Cursor, etc.) instead of hunting for tokens themselves.
> Drop these strings into your marketing site's HTML / MDX / components. No code changes required in this repo — the AI-setup workflow this copy describes already lives at `.claude/skills/stacklight-setup/`.

---

## 1. Hero

**H1**
All your deploys. One menu bar.

**Subhead**
StackLight watches every deploy and pull request you ship — across Vercel, GitHub, Cloudflare, Netlify, Railway, Fly.io, Xcode Cloud, and TestFlight — and lives quietly in your Mac menu bar.

**Primary CTA**
Download for macOS

**Secondary CTA**
View on GitHub →

*Microcopy under buttons:* Free and open source · macOS 13+ · No account required.

---

## 2. The "tab fatigue" problem

**H2**
Stop tab-hunting your own ship status.

**Body**
You shipped something an hour ago. Did it actually deploy? Did the build go green? Is there a PR waiting on you? Right now you'd open four dashboards to find out. StackLight gives you the answer in one glance — a triangle in your menu bar that turns red when something needs you.

---

## 3. Supported services

**H2**
Nine services. One place.

*(Render as a logo grid, two rows. Caption under each.)*

| Service | Caption |
|---|---|
| Vercel | Deploy status |
| Cloudflare Pages | Deploy status |
| Netlify | Deploy status |
| Railway | Deploy status |
| Fly.io | Machine deploys |
| GitHub Actions | Workflow runs |
| GitHub Pull Requests | Open PRs across repos |
| Xcode Cloud | Build status |
| TestFlight | Build processing & review |

**Body line under the grid**
More services on the way. Each one is a single file in the codebase — easy to add, easy to fork.

---

## 4. The AI-setup section (the differentiator)

**H2**
Don't feel like hunting for API tokens? Hand it to your AI.

**Subhead**
StackLight ships with an AI setup recipe. If you use Claude Code, Codex, Cursor, or any agent that can run on your machine, just say "set up StackLight" — and the agent does the boring part for you.

**Three columns**

**Finds what you already have**
Already logged into the GitHub CLI? Already exported `VERCEL_TOKEN`? The agent picks those up automatically, so you're not pasting credentials you've already given your machine.

**Asks only what's missing**
For anything it can't find — like your Cloudflare account ID or your TestFlight app IDs — it asks once, in plain English, and tells you where to find each value.

**Checks before it hands it back**
Every token gets test-pinged against the real API before the agent calls the setup done. No silent failures, no "why isn't this working" half an hour later.

**Pull-quote block (light background)**

> *You: "Set up StackLight."*
> *Agent: "I found your GitHub token via `gh`. I need a Vercel token and your Cloudflare account ID — paste them here."*
> *You paste them.*
> *Agent: "Validated all four. Open StackLight → Settings and paste these values. Done."*

**Body line below**
Don't use an AI assistant? You can still set everything up by hand in the Settings window — every field comes with a hint and a docs link.

---

## 5. Features

**H2**
Built like a Mac app should be.

*(Six small feature cards, two rows of three.)*

**1. Lives in the menu bar**
No Dock icon, no Electron weight. A triangle that turns red when something breaks.

**2. Native macOS notifications**
Get pinged when a deploy fails or a build is ready for review. Nothing else.

**3. Multi-repo, multi-project**
Watch as many GitHub repos, Vercel projects, or TestFlight apps as you want — one token, all of them.

**4. Refresh on your terms**
Set how often StackLight checks — anywhere from every 30 seconds to every 5 minutes.

**5. Branch filtering**
Only care about `main` and `staging`? Tell Vercel to ignore the rest.

**6. Launch at login**
One toggle. Forget StackLight is even running until something breaks.

---

## 6. How it works

**H2**
Three steps to a quieter dashboard life.

**Step 1 — Install**
Download StackLight, drag it to Applications, launch it. The triangle appears in your menu bar.

**Step 2 — Connect your services**
Click the triangle → Settings, pick a service, and paste your token. *(Or: ask your AI assistant to do it — see above.)*

**Step 3 — Get back to work**
StackLight quietly polls in the background. You only hear from it when something needs your attention.

---

## 7. Security & privacy

**H2**
Your tokens never leave your Mac.

- **Stored in macOS Keychain.** The same vault that holds your iCloud and Wi-Fi passwords.
- **No servers.** StackLight talks directly to Vercel, GitHub, Cloudflare, etc. — there's no "StackLight cloud" in between.
- **No analytics.** No accounts. No tracking. Open source, MIT-licensed — read the code yourself.

---

## 8. Final CTA

**H2**
Get every deploy in one click.

**Body**
Free, open source, and small enough that you'll forget it's running.

**Primary CTA**
Download for macOS

**Secondary link**
Star on GitHub →

*Footer microcopy:* Made for developers, designers, and PMs who ship for a living.

---

## Notes for whoever ships this

- **Tone:** plain-spoken, slightly self-aware. No "revolutionize," no "supercharge," no "10x."
- **The AI section is the differentiator** — keep it visible (above the fold of the second screen) and don't water it down.
- **The pull-quote dialogue** in section 4 is the single highest-impact piece of copy on the page — it shows the workflow instead of just claiming it. Don't cut it.
- **Don't say "computer use" or "Codex" by name in the H2** — broad audiences don't know those terms. Section 4's body names them; the H2 just says "your AI."
- **Leave room** for a screenshot of the menu bar dropdown next to the hero, and a short looping screencast (≤8 sec) of the AI agent setup conversation next to section 4.
- **Before publishing,** cross-check the service list in section 3 against `Sources/StackLight/Core/ServiceRegistry.swift` in case providers were added or removed since this draft.
