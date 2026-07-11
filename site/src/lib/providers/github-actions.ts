import type {
  CalendarEvent,
  EventStatus,
  FetchContext,
  ProviderFetchResult,
  ProviderModule,
} from "./types";
import { inRange, parseList } from "./types";

const COLOR = "#16a34a";

interface WorkflowRun {
  id: number;
  name: string | null;
  status: string | null;
  conclusion: string | null;
  head_branch: string | null;
  html_url: string;
  created_at: string;
  updated_at: string;
  head_commit?: { message?: string };
}

interface RunsResponse {
  workflow_runs: WorkflowRun[];
}

function mapStatus(run: WorkflowRun): EventStatus {
  if (run.status === "queued") return "queued";
  if (run.status === "in_progress") return "building";
  if (run.status === "completed") {
    switch (run.conclusion) {
      case "success":
        return "success";
      case "failure":
      case "timed_out":
        return "failed";
      case "cancelled":
      case "skipped":
        return "cancelled";
      default:
        return "unknown";
    }
  }
  return "unknown";
}

async function fetchRepoRuns(
  token: string,
  repo: string,
  from: Date,
): Promise<WorkflowRun[]> {
  const created = `>=${from.toISOString().slice(0, 10)}`;
  const params = new URLSearchParams({ per_page: "50", created });
  const res = await fetch(`https://api.github.com/repos/${repo}/actions/runs?${params}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "stacklight-calendar",
    },
  });
  if (!res.ok) throw new Error(`GitHub actions ${repo} ${res.status}: ${await res.text()}`);
  return ((await res.json()) as RunsResponse).workflow_runs;
}

export const githubActions: ProviderModule = {
  id: "github-actions",
  label: "GitHub Actions",
  color: COLOR,
  isConfigured(env) {
    return Boolean(env.GITHUB_TOKEN && env.GITHUB_REPOS);
  },
  async fetchEvents(ctx: FetchContext): Promise<ProviderFetchResult> {
    const token = ctx.env.GITHUB_TOKEN;
    const repos = parseList(ctx.env.GITHUB_REPOS);
    if (!token || repos.length === 0) return { events: [] };

    const results = await Promise.allSettled(
      repos.map((r) => fetchRepoRuns(token, r, ctx.from)),
    );
    const events: CalendarEvent[] = [];
    const itemErrors: { item: string; message: string }[] = [];

    results.forEach((result, i) => {
      const repo = repos[i];
      if (result.status !== "fulfilled") {
        itemErrors.push({ item: repo, message: result.reason instanceof Error ? result.reason.message : String(result.reason) });
        return;
      }
      const shortRepo = repo.split("/").pop() ?? repo;
      for (const run of result.value) {
        const date = new Date(run.created_at);
        if (!inRange(date, ctx.from, ctx.to)) continue;
        events.push({
          id: `gha-${run.id}`,
          provider: "github-actions",
          providerLabel: "CI",
          kind: "ci",
          title: `${shortRepo} · ${run.name ?? "workflow"}`,
          subtitle: run.head_commit?.message ?? run.head_branch ?? undefined,
          status: mapStatus(run),
          startsAt: date.toISOString(),
          endsAt: run.updated_at,
          url: run.html_url,
          branch: run.head_branch ?? undefined,
          commit: run.head_commit?.message,
          color: COLOR,
        });
      }
    });

    return { events, itemErrors };
  },
};
