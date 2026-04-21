// Resolves AiDrift API credentials from ~/.drift/profiles.json.
// Mirrors the logic in packages/cli/src/auth/profiles.ts — kept here as a
// minimal standalone read so the bundled MCP server has no runtime coupling
// to the CLI package.

import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const DEFAULT_API_URL =
  process.env.AIDRIFT_API_URL ?? "https://drift.geniohub.com/api";

interface Profile {
  apiBaseUrl: string;
  email?: string;
  accessToken?: string;
  refreshToken?: string;
  pat?: string;
}

interface ProfilesFile {
  active: string;
  profiles: Record<string, Profile>;
}

export interface ResolvedAuth {
  apiBaseUrl: string;
  bearer: string | null;
  tokenType: "pat" | "jwt" | null;
}

export function resolveAuth(): ResolvedAuth {
  const file = join(homedir(), ".drift", "profiles.json");
  if (!existsSync(file)) {
    return { apiBaseUrl: DEFAULT_API_URL, bearer: null, tokenType: null };
  }

  let data: ProfilesFile;
  try {
    data = JSON.parse(readFileSync(file, "utf8")) as ProfilesFile;
  } catch {
    return { apiBaseUrl: DEFAULT_API_URL, bearer: null, tokenType: null };
  }

  const profileName = process.env.AIDRIFT_PROFILE ?? data.active;
  const profile = data.profiles?.[profileName];
  if (!profile) {
    return { apiBaseUrl: DEFAULT_API_URL, bearer: null, tokenType: null };
  }

  const apiBaseUrl = profile.apiBaseUrl ?? DEFAULT_API_URL;
  if (profile.pat) {
    return { apiBaseUrl, bearer: profile.pat, tokenType: "pat" };
  }
  if (profile.accessToken) {
    return { apiBaseUrl, bearer: profile.accessToken, tokenType: "jwt" };
  }
  return { apiBaseUrl, bearer: null, tokenType: null };
}

export class NotAuthenticatedError extends Error {
  constructor() {
    super(
      "AiDrift credentials not found. Run `drift auth login` (or set AIDRIFT_PROFILE) before calling AiDrift tools.",
    );
    this.name = "NotAuthenticatedError";
  }
}
