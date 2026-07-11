import type {
  CalendarEvent,
  EventStatus,
  FetchContext,
  ProviderFetchResult,
  ProviderModule,
} from "./types";
import { inRange, parseList } from "./types";

const COLOR = "#0a0a0a";

interface VercelDeployment {
  uid: string;
  name: string;
  state?: string;
  url?: string;
  created: number;
  target?: string;
  meta?: {
    githubCommitMessage?: string;
    githubCommitRef?: string;
  };
}

interface VercelResponse {
  deployments: VercelDeployment[];
}

function mapStatus(state?: string): EventStatus {
  switch (state?.toUpperCase()) {
    case "BUILDING":
      return "building";
    case "READY":
      return "success";
    case "ERROR":
      return "failed";
    case "QUEUED":
      return "queued";
    case "CANCELED":
      return "cancelled";
    default:
      return "unknown";
  }
}

export const vercel: ProviderModule = {
  id: "vercel",
  label: "Vercel",
  color: COLOR,
  isConfigured(env) {
    return Boolean(env.VERCEL_TOKEN);
  },
  async fetchEvents(ctx: FetchContext): Promise<ProviderFetchResult> {
    const token = ctx.env.VERCEL_TOKEN;
    if (!token) return { events: [] };

    const teamId = ctx.env.VERCEL_TEAM_ID;
    const projects = parseList(ctx.env.VERCEL_PROJECTS);
    const limit = projects.length ? 100 : 50;

    const params = new URLSearchParams({ limit: String(limit) });
    if (teamId) params.set("teamId", teamId);
    if (ctx.from) params.set("since", String(ctx.from.getTime()));
    if (ctx.to) params.set("until", String(ctx.to.getTime()));

    const res = await fetch(`https://api.vercel.com/v6/deployments?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new Error(`Vercel ${res.status}: ${await res.text()}`);

    const json = (await res.json()) as VercelResponse;
    const allowed = new Set(projects.map((p) => p.toLowerCase()));

    const events = json.deployments
      .filter((d) => (allowed.size === 0 ? true : allowed.has(d.name.toLowerCase())))
      .map<CalendarEvent>((d) => ({
        id: `vercel-${d.uid}`,
        provider: "vercel",
        providerLabel: "Vercel",
        kind: "deploy",
        title: d.name,
        subtitle: d.meta?.githubCommitMessage ?? d.target ?? "deploy",
        status: mapStatus(d.state),
        startsAt: new Date(d.created).toISOString(),
        url: d.url ? `https://${d.url}` : undefined,
        branch: d.meta?.githubCommitRef,
        commit: d.meta?.githubCommitMessage,
        color: COLOR,
      }))
      .filter((e) => inRange(new Date(e.startsAt), ctx.from, ctx.to));
    return { events };
  },
};
