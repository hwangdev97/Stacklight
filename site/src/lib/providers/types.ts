export type EventKind = "release" | "deploy" | "ci" | "pr";

export type EventStatus =
  | "success"
  | "failed"
  | "building"
  | "queued"
  | "cancelled"
  | "reviewing"
  | "draft"
  | "unknown";

export interface CalendarEvent {
  id: string;
  provider: string;
  providerLabel: string;
  kind: EventKind;
  title: string;
  subtitle?: string;
  status: EventStatus;
  startsAt: string;
  endsAt?: string;
  url?: string;
  branch?: string;
  commit?: string;
  tag?: string;
  color: string;
}

export interface ProviderError {
  provider: string;
  message: string;
}

export interface FetchContext {
  from: Date;
  to: Date;
  env: Record<string, string | undefined>;
}

export interface ProviderFetchResult {
  events: CalendarEvent[];
  itemErrors?: { item: string; message: string }[];
}

export interface ProviderModule {
  id: string;
  label: string;
  color: string;
  isConfigured(env: Record<string, string | undefined>): boolean;
  fetchEvents(ctx: FetchContext): Promise<ProviderFetchResult>;
}

export function inRange(date: Date, from: Date, to: Date): boolean {
  const t = date.getTime();
  return t >= from.getTime() && t <= to.getTime();
}

export function parseList(raw: string | undefined): string[] {
  if (!raw) return [];
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}
