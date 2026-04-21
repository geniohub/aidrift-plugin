// AiDrift MCP server entry point. Exposes drift session tools to Claude Code
// via stdio transport. Auth is resolved from ~/.drift/profiles.json (same file
// the `drift` CLI uses), so users authenticate once via `drift auth login`.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  statusInputShape,
  listSessionsInputShape,
  searchSessionsInputShape,
  createCheckpointInputShape,
  handleStatus,
  handleListSessions,
  handleSearchSessions,
  handleCreateCheckpoint,
} from "./tools.js";

const server = new McpServer({
  name: "aidrift",
  version: "0.3.0",
});

server.registerTool(
  "aidrift_status",
  {
    description:
      "Get the current AiDrift drift score, trend, active alert, and last stable checkpoint for a session. Pass session_id or workspace_path.",
    inputSchema: statusInputShape,
  },
  (args) => handleStatus(args),
);

server.registerTool(
  "aidrift_list_sessions",
  {
    description:
      "List recent AiDrift sessions, optionally filtered by workspace path. Returns basic metadata + current score/trend.",
    inputSchema: listSessionsInputShape,
  },
  (args) => handleListSessions(args),
);

server.registerTool(
  "aidrift_search_sessions",
  {
    description:
      "Full-text search across past AiDrift sessions and their turns. Useful for finding how a similar task was handled before.",
    inputSchema: searchSessionsInputShape,
  },
  (args) => handleSearchSessions(args),
);

server.registerTool(
  "aidrift_create_checkpoint",
  {
    description:
      "Pin the current session state as a named stable checkpoint so it can be referenced or reverted to later.",
    inputSchema: createCheckpointInputShape,
  },
  (args) => handleCreateCheckpoint(args),
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // Stdout is reserved for JSON-RPC; log to stderr only.
  console.error("aidrift MCP server ready");
}

main().catch((err) => {
  console.error("aidrift MCP fatal:", err);
  process.exit(1);
});
