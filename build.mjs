// Bundles the MCP server into a single dist/index.js with a node shebang.
// The plugin ships this bundled file so users don't need to run `pnpm install`.

import { build } from "esbuild";
import { chmodSync } from "node:fs";

await build({
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: "node20",
  format: "esm",
  outfile: "dist/index.js",
  banner: { js: "#!/usr/bin/env node" },
  // Keep node built-ins external; everything else is bundled.
  packages: "bundle",
  logLevel: "info",
});

chmodSync("dist/index.js", 0o755);
console.error("built dist/index.js");
