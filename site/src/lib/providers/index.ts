import type { CalendarEvent, FetchContext, ProviderError, ProviderModule } from "./types";
import { vercel } from "./vercel";
import { githubReleases } from "./github-releases";
import { githubActions } from "./github-actions";
import { netlify } from "./netlify";

export const PROVIDERS: ProviderModule[] = [
  githubReleases,
  vercel,
  githubActions,
  netlify,
];

export interface AggregateResult {
  events: CalendarEvent[];
  errors: ProviderError[];
  configuredProviders: { id: string; label: string; color: string }[];
}

export async function aggregate(ctx: FetchContext): Promise<AggregateResult> {
  const configured = PROVIDERS.filter((p) => p.isConfigured(ctx.env));
  const settled = await Promise.allSettled(configured.map((p) => p.fetchEvents(ctx)));

  const events: CalendarEvent[] = [];
  const errors: ProviderError[] = [];

  settled.forEach((res, i) => {
    const provider = configured[i];
    if (res.status === "fulfilled") {
      events.push(...res.value.events);
      for (const ie of res.value.itemErrors ?? []) {
        errors.push({ provider: `${provider.id}:${ie.item}`, message: ie.message });
      }
    } else {
      errors.push({
        provider: provider.id,
        message: res.reason instanceof Error ? res.reason.message : String(res.reason),
      });
    }
  });

  events.sort((a, b) => a.startsAt.localeCompare(b.startsAt));

  return {
    events,
    errors,
    configuredProviders: PROVIDERS.map((p) => ({ id: p.id, label: p.label, color: p.color })),
  };
}

export type { CalendarEvent, ProviderError } from "./types";
