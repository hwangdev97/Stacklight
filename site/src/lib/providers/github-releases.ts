import type {
  CalendarEvent,
  FetchContext,
  ProviderFetchResult,
  ProviderModule,
} from "./types";
import { inRange, parseList } from "./types";

const COLOR = "#7c3aed";

interface Release {
  id: number;
  name: string | null;
  tag_name: string;
  body: string | null;
  draft: boolean;
  prerelease: boolean;
  published_at: string | null;
  created_at: string;
  html_url: string;
  target_commitish: string;
  author?: { login: string };
}

async function fetchRepoReleases(token: string | undefined, repo: string): Promise<Release[]> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "stacklight-calendar",
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=50`, { headers });
  if (!res.ok) throw new Error(`GitHub releases ${repo} ${res.status}: ${await res.text()}`);
  return (await res.json()) as Release[];
}

export const githubReleases: ProviderModule = {
  id: "github-releases",
  label: "GitHub Releases",
  color: COLOR,
  isConfigured(env) {
    // Token is optional for public repos — only require the repo list.
    return Boolean(env.GITHUB_REPOS);
  },
  async fetchEvents(ctx: FetchContext): Promise<ProviderFetchResult> {
    const token = ctx.env.GITHUB_TOKEN;
    const repos = parseList(ctx.env.GITHUB_REPOS);
    if (repos.length === 0) return { events: [] };

    const results = await Promise.allSettled(repos.map((r) => fetchRepoReleases(token, r)));
    const events: CalendarEvent[] = [];
    const itemErrors: { item: string; message: string }[] = [];

    results.forEach((result, i) => {
      const repo = repos[i];
      if (result.status !== "fulfilled") {
        itemErrors.push({ item: repo, message: result.reason instanceof Error ? result.reason.message : String(result.reason) });
        return;
      }
      const shortRepo = repo.split("/").pop() ?? repo;
      for (const r of result.value) {
        const when = r.published_at ?? r.created_at;
        if (!when) continue;
        const date = new Date(when);
        if (!inRange(date, ctx.from, ctx.to)) continue;
        events.push({
          id: `ghr-${r.id}`,
          provider: "github-releases",
          providerLabel: "Release",
          kind: "release",
          title: `${shortRepo} ${r.tag_name}`,
          subtitle: r.name ?? "release",
          status: r.draft ? "draft" : "success",
          startsAt: date.toISOString(),
          url: r.html_url,
          tag: r.tag_name,
          branch: r.target_commitish,
          color: COLOR,
        });
      }
    });

    return { events, itemErrors };
  },
};
