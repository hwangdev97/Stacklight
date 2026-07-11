import type { APIRoute } from "astro";
import { aggregate, type CalendarEvent } from "../../lib/providers";

export const prerender = false;

function buildDemoEvents(from: Date, to: Date): CalendarEvent[] {
  const ms = to.getTime() - from.getTime();
  const day = (n: number, h = 10, m = 0) => {
    const d = new Date(from.getTime() + n * ms / 35);
    d.setHours(h, m, 0, 0);
    return d.toISOString();
  };
  return [
    { id: "d-1", provider: "github-releases", providerLabel: "Release", kind: "release", title: "stacklight v1.4.0", subtitle: "Calendar view", status: "success", startsAt: day(2, 14, 0), url: "https://github.com", tag: "v1.4.0", color: "#7c3aed" },
    { id: "d-2", provider: "vercel", providerLabel: "Vercel", kind: "deploy", title: "marketing-site", subtitle: "Update hero copy", status: "success", startsAt: day(3, 9, 12), branch: "main", color: "#0a0a0a" },
    { id: "d-3", provider: "github-actions", providerLabel: "CI", kind: "ci", title: "stacklight · build", subtitle: "fix: tokens null check", status: "success", startsAt: day(3, 9, 30), endsAt: day(3, 9, 36), branch: "main", color: "#16a34a" },
    { id: "d-4", provider: "netlify", providerLabel: "Netlify", kind: "deploy", title: "docs", subtitle: "Add calendar API page", status: "success", startsAt: day(5, 11, 15), color: "#06b6d4" },
    { id: "d-5", provider: "vercel", providerLabel: "Vercel", kind: "deploy", title: "marketing-site", subtitle: "preview", status: "failed", startsAt: day(7, 16, 40), branch: "feat/calendar", color: "#0a0a0a" },
    { id: "d-6", provider: "github-actions", providerLabel: "CI", kind: "ci", title: "stacklight · test", subtitle: "feat: week view", status: "building", startsAt: day(10, 8, 30), endsAt: day(10, 8, 45), color: "#16a34a" },
    { id: "d-7", provider: "github-releases", providerLabel: "Release", kind: "release", title: "stacklight v1.4.1", subtitle: "Hotfix", status: "success", startsAt: day(12, 18, 0), tag: "v1.4.1", color: "#7c3aed" },
    { id: "d-8", provider: "vercel", providerLabel: "Vercel", kind: "deploy", title: "blog", subtitle: "Publish weekly digest", status: "success", startsAt: day(14, 10, 5), branch: "main", color: "#0a0a0a" },
    { id: "d-9", provider: "github-actions", providerLabel: "CI", kind: "ci", title: "stacklight · release", subtitle: "v1.5.0", status: "success", startsAt: day(15, 14, 0), endsAt: day(15, 14, 18), color: "#16a34a" },
    { id: "d-10", provider: "github-releases", providerLabel: "Release", kind: "release", title: "stacklight v1.5.0", subtitle: "Mobile companion app", status: "success", startsAt: day(15, 15, 30), tag: "v1.5.0", color: "#7c3aed" },
    { id: "d-11", provider: "netlify", providerLabel: "Netlify", kind: "deploy", title: "status-page", subtitle: "incident postmortem", status: "success", startsAt: day(18, 11, 0), color: "#06b6d4" },
    { id: "d-12", provider: "vercel", providerLabel: "Vercel", kind: "deploy", title: "dashboard", subtitle: "perf: optimize queries", status: "success", startsAt: day(20, 13, 45), branch: "main", color: "#0a0a0a" },
    { id: "d-13", provider: "github-actions", providerLabel: "CI", kind: "ci", title: "stacklight · e2e", subtitle: "nightly", status: "failed", startsAt: day(22, 2, 0), endsAt: day(22, 2, 22), color: "#16a34a" },
    { id: "d-14", provider: "github-releases", providerLabel: "Release", kind: "release", title: "stacklight-cli v0.3.0", subtitle: "JSON output", status: "success", startsAt: day(24, 9, 0), tag: "v0.3.0", color: "#7c3aed" },
    { id: "d-15", provider: "vercel", providerLabel: "Vercel", kind: "deploy", title: "marketing-site", subtitle: "Add changelog page", status: "success", startsAt: day(26, 16, 20), branch: "main", color: "#0a0a0a" },
  ];
}

function parseDate(value: string | null, fallback: Date): Date {
  if (!value) return fallback;
  const d = new Date(value);
  return isNaN(d.getTime()) ? fallback : d;
}

export const GET: APIRoute = async ({ url, locals }) => {
  const params = url.searchParams;
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  const from = parseDate(params.get("from"), monthStart);
  const to = parseDate(params.get("to"), monthEnd);

  const runtimeEnv = ((locals as any)?.runtime?.env ?? {}) as Record<string, string | undefined>;
  const env: Record<string, string | undefined> = {
    ...(typeof process !== "undefined" ? (process.env as Record<string, string | undefined>) : {}),
    ...runtimeEnv,
  };
  try {
    const isDemo = url.searchParams.get("demo") === "1" || env.DEMO === "1";
    const result = await aggregate({ from, to, env });
    if (isDemo) {
      result.events = [...buildDemoEvents(from, to), ...result.events]
        .sort((a, b) => a.startsAt.localeCompare(b.startsAt));
    }
    return new Response(
      JSON.stringify({
        from: from.toISOString(),
        to: to.toISOString(),
        ...result,
      }),
      {
        status: 200,
        headers: {
          "content-type": "application/json",
          "cache-control": "private, max-age=30",
        },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : String(err) }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }
};
