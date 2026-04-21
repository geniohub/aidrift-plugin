// Minimal HTTP client for the MCP server. JWT refresh is intentionally NOT
// implemented here — if the access token is expired, tool handlers surface a
// clean "run `drift auth login`" message and let the user re-auth via the CLI
// (which owns the refresh-token lifecycle).

import { resolveAuth, NotAuthenticatedError } from "./auth.js";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

type QueryValue = string | number | boolean | undefined | null;

function buildQuery(params?: Record<string, QueryValue>): string {
  if (!params) return "";
  const entries = Object.entries(params).filter(
    ([, v]) => v !== undefined && v !== null && v !== "",
  );
  if (entries.length === 0) return "";
  const search = new URLSearchParams();
  for (const [k, v] of entries) search.append(k, String(v));
  return `?${search.toString()}`;
}

export interface ApiOptions {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  body?: unknown;
  query?: Record<string, QueryValue>;
}

export async function api<T>(path: string, opts: ApiOptions = {}): Promise<T> {
  const { apiBaseUrl, bearer } = resolveAuth();
  if (!bearer) throw new NotAuthenticatedError();

  const url = `${apiBaseUrl}${path}${buildQuery(opts.query)}`;
  const headers: Record<string, string> = {
    Authorization: `Bearer ${bearer}`,
  };
  let body: string | undefined;
  if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(opts.body);
  }

  const res = await fetch(url, { method: opts.method ?? "GET", headers, body });

  if (!res.ok) {
    let message = res.statusText;
    try {
      const parsed = (await res.json()) as { error?: string };
      if (parsed.error) message = parsed.error;
    } catch {
      // ignore non-JSON bodies
    }
    throw new ApiError(res.status, message);
  }

  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}
