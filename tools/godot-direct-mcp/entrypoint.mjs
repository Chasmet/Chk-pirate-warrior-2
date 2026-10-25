// Node.js bundle entry point; the GUI supervisor supplies private credentials.
import { createDirectGodotServer } from "./server.mjs";
const app = createDirectGodotServer();
app.server.listen(app.config.port, app.config.host, () => {
  console.log("CHK Godot Direct MCP listening on loopback " + app.config.port);
});
async function shutdown() { await app.close(); process.exit(0); }
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
