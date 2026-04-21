// MCP tool handlers. Each tool is a thin wrapper around an AiDrift API call.
// Input shapes use Zod so the SDK can expose JSON Schema to Claude; we only
// parse for type narrowing, not for validation-that-blocks (the API re-validates).

import { z } from "zod";
import { api, ApiError } from "./api.js";
import { NotAuthenticatedError } from "./auth.js";

type TextResult = {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
};

function ok(payload: unknown): TextResult {
  const text =
    typeof payload === "string"
      ? payload
      : JSON.stringify(payload, null, 2);
  return { content: [{ type: "text", text }] };
}

function fail(message: string): TextResult {
  return { content: [{ type: "text", text: `error: ${message}` }], isError: true };
}

async function run<T>(work: () => Promise<T>): Promise<TextResult> {
  try {
    return ok(await work());
  } catch (err) {
    if (err instanceof NotAuthenticatedError) return fail(err.message);
    if (err instanceof ApiError) return fail(`${err.status} ${err.message}`);
    return fail(err instanceof Error ? err.message : String(err));
  }
}

// ---------- types (narrow what we actually use) ----------

interface SessionDto {
  id: string;
  taskDescription: string;
  provider: string;
  workspacePath: string | null;
  startedAt: string;
  endedAt: string | null;
  currentScore?: number | null;
  trend?: "improving" | "stable" | "drifting" | null;
}

interface StatusDto {
  session: SessionDto;
  currentScore: number | null;
  trend: "improving" | "stable" | "drifting";
  turnCount: number;
  alert: {
    active: boolean;
    reasons: string[];
    type: string;
    recommendation: string | null;
  };
  lastStableCheckpoint: {
    id: string;
    turnId: string;
    summary: string;
    scoreAtCheckpoint: number;
    createdAt: string;
  } | null;
}

interface CheckpointDto {
  id: string;
  sessionId: string;
  turnId: string;
  summary: string;
  scoreAtCheckpoint: number;
  source: string;
  createdAt: string;
}

async function findLatestOpenSession(
  workspacePath: string,
): Promise<SessionDto | null> {
  const sessions = await api<SessionDto[]>("/sessions", {
    query: { workspacePath, limit: 20 },
  });
  return sessions.find((s) => s.endedAt === null) ?? sessions[0] ?? null;
}

// ---------- aidrift_status ----------

export const statusInputShape = {
  session_id: z
    .string()
    .optional()
    .describe("AiDrift session ID. If omitted, uses the latest session in workspace_path."),
  workspace_path: z
    .string()
    .optional()
    .describe("Absolute workspace path. Required when session_id is not set."),
};

export async function handleStatus(args: {
  session_id?: string;
  workspace_path?: string;
}): Promise<TextResult> {
  return run(async () => {
    let id = args.session_id;
    if (!id) {
      if (!args.workspace_path) {
        throw new Error("either session_id or workspace_path is required");
      }
      const s = await findLatestOpenSession(args.workspace_path);
      if (!s) throw new Error(`no AiDrift session found for workspace ${args.workspace_path}`);
      id = s.id;
    }
    return api<StatusDto>(`/sessions/${id}/status`);
  });
}

// ---------- aidrift_list_sessions ----------

export const listSessionsInputShape = {
  workspace_path: z
    .string()
    .optional()
    .describe("Filter by workspace path (absolute)."),
  limit: z
    .number()
    .int()
    .min(1)
    .max(200)
    .optional()
    .describe("Max sessions to return (1-200, default 10)."),
};

export async function handleListSessions(args: {
  workspace_path?: string;
  limit?: number;
}): Promise<TextResult> {
  return run(() =>
    api<SessionDto[]>("/sessions", {
      query: {
        workspacePath: args.workspace_path,
        limit: args.limit ?? 10,
      },
    }),
  );
}

// ---------- aidrift_search_sessions ----------

export const searchSessionsInputShape = {
  query: z
    .string()
    .min(2)
    .max(200)
    .describe("Search query (min 2 chars, matches task text + turn prompts/responses)."),
  workspace_path: z.string().optional().describe("Restrict results to this workspace."),
  provider: z
    .string()
    .optional()
    .describe("Filter by provider (claude-code, codex, ...)."),
  limit: z
    .number()
    .int()
    .min(1)
    .max(100)
    .optional()
    .describe("Max results (default 30)."),
};

export async function handleSearchSessions(args: {
  query: string;
  workspace_path?: string;
  provider?: string;
  limit?: number;
}): Promise<TextResult> {
  return run(() =>
    api<unknown>("/search", {
      query: {
        q: args.query,
        workspacePath: args.workspace_path,
        provider: args.provider,
        limit: args.limit,
      },
    }),
  );
}

// ---------- aidrift_create_checkpoint ----------

export const createCheckpointInputShape = {
  session_id: z.string().describe("AiDrift session ID."),
  turn_id: z.string().describe("Turn ID to anchor the checkpoint on."),
  summary: z
    .string()
    .min(1)
    .describe("Human-readable description of why this is a good stable point."),
  git_sha: z
    .string()
    .min(7)
    .max(64)
    .optional()
    .describe("Optional git commit SHA associated with this checkpoint."),
};

export async function handleCreateCheckpoint(args: {
  session_id: string;
  turn_id: string;
  summary: string;
  git_sha?: string;
}): Promise<TextResult> {
  return run(() =>
    api<CheckpointDto>(`/sessions/${args.session_id}/checkpoints`, {
      method: "POST",
      body: {
        turnId: args.turn_id,
        summary: args.summary,
        gitSha: args.git_sha,
      },
    }),
  );
}
