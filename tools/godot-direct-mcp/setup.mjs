import { randomBytes } from "node:crypto";
import { writeFile, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const path = join(here, ".env");
try {
  const old = await readFile(path, "utf8");
  if (!old.includes("CHK_GODOT_MCP_TOKEN=") || !old.includes("CHK_GODOT_EDITOR_TOKEN="))
    throw new Error(".env exists but is incomplete: do not overwrite secrets without inspection.");
  console.log("Existing .env preserved. No token was replaced.");
} catch (error) {
  if (error.code !== "ENOENT") throw error;
  const chatToken = randomBytes(32).toString("hex");
  const editorToken = randomBytes(32).toString("hex");
  const content = [
    "# Private local file: never commit or share it",
    "HOST=127.0.0.1",
    "PORT=8791",
    "CHK_GODOT_MCP_TOKEN=" + chatToken,
    "CHK_GODOT_EDITOR_TOKEN=" + editorToken,
    ""
  ].join("\n");
  await writeFile(path, content, { flag: "wx", mode: 0o600 });
  console.log("Created private .env with two distinct 256-bit access tokens.");
}
console.log("Run npm install, then npm start. Public HTTPS requires a tunnel/reverse proxy.");
