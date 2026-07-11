import type {
  CalendarEvent,
  EventStatus,
  FetchContext,
  ProviderFetchResult,
  ProviderModule,
} from "./types";
import { inRange, parseList } from "./types";

const COLOR = "#06b6d4";

interface NetlifyDeploy {
  id: string;
  name: string;
  state: string;
  context: string;
  branch: string | null;
  title: string | null;
  deploy_url: string | null;
  url: string | null;
  created_at: string;
  updated_at: string;
}

function mapStatus(state: string): EventStatus {
  switch (state) {
    case "ready":
      return "success";
    case "error":
      return "failed";
    case "building":
    case "uploading":
    case "uploaded":
    case "preparing":
    case "prepared":
    case "processing":
    case "processed":
    case "enqueued":
      return "building";
    case "skipped":
    case "cancelled":
      return "cancelled";
    default:
      return "unknown";
  }
}

async function fetchSiteDeploys(token: string, site: string): Promise<NetlifyDeploy[]> {
  const res = await fetch(
    `https://api.netlify.com/api/v1/sites/${site}/deploys?per_page=50`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!res.ok) throw new Error(`Netlify ${site} ${res.status}: ${await res.text()}`);
  return (await res.json()) as NetlifyDeploy[];
}

export const netlify: ProviderModule = {
  id: "netlify",
  label: "Netlify",
  color: COLOR,
  isConfigured(env) {
    return Boolean(env.NETLIFY_TOKEN && env.NETLIFY_SITES);
  },
  async fetchEvents(ctx: FetchContext): Promise<ProviderFetchResult> {
    const token = ctx.env.NETLIFY_TOKEN;
    const sites = parseList(ctx.env.NETLIFY_SITES);
    if (!token || sites.length === 0) return { events: [] };

    const results = await Promise.allSettled(sites.map((s) => fetchSiteDeploys(token, s)));
    const events: CalendarEvent[] = [];
    const itemErrors: { item: string; message: string }[] = [];

    results.forEach((result, i) => {
      const site = sites[i];
      if (result.status !== "fulfilled") {
        itemErrors.push({ item: site, message: result.reason instanceof Error ? result.reason.message : String(result.reason) });
        return;
      }
      for (const d of result.value) {
        const date = new Date(d.created_at);
        if (!inRange(date, ctx.from, ctx.to)) continue;
        events.push({
          id: `netlify-${d.id}`,
          provider: "netlify",
          providerLabel: "Netlify",
          kind: "deploy",
          title: d.name,
          subtitle: d.title ?? d.context,
          status: mapStatus(d.state),
          startsAt: date.toISOString(),
          endsAt: d.updated_at,
          url: d.deploy_url ?? d.url ?? undefined,
          branch: d.branch ?? undefined,
          color: COLOR,
        });
      }
    });

    return { events, itemErrors };
  },
};
