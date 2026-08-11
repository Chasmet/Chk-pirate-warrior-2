import express from "express";
import { createServer as createHttpServer } from "node:http";
import { randomUUID, createHash, timingSafeEqual } from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

const PORT = Number(process.env.PORT ?? 3000);
const MCP_TOKEN = String(process.env.MCP_TOKEN ?? "").trim();
const MCP_TOKEN_SHA256 = "64ba5a4381cdffd7d833d652c63e6a98a30c004eba749d7bef50804fde38040f";
const REQUEST_TIMEOUT_MS = Number(process.env.GODOT_REQUEST_TIMEOUT_MS ?? 120000);
const RELAY_PATHS = new Set(["/relay/godot", "/relay/chk-pirate-warrior-2"]);

const app = express();
app.use(express.json({ limit: "20mb" }));
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS");
  res.setHeader(
    "Access-Control-Allow-Headers",
    "Content-Type, Accept, Authorization, Mcp-Session-Id, MCP-Protocol-Version, Last-Event-ID",
  );
  res.setHeader("Access-Control-Expose-Headers", "Mcp-Session-Id");
  if (req.method === "OPTIONS") {
    res.sendStatus(204);
    return;
  }
  next();
});

const httpServer = createHttpServer(app);
const wss = new WebSocketServer({ noServer: true, maxPayload: 20 * 1024 * 1024 });

let relay = null;
let relayMetadata = null;
let relayConnectedAt = 0;
let relayLastSeenAt = 0;
const pending = new Map();
const sessions = new Map();

function relayReady() {
  return relay && relay.readyState === WebSocket.OPEN;
}

function rejectPending(message) {
  for (const [id, item] of pending.entries()) {
    clearTimeout(item.timer);
    item.reject(new Error(message));
    pending.delete(id);
  }
}

function sendRelayJson(value) {
  if (!relayReady()) throw new Error("Aucun éditeur Godot n'est connecté au relais MCP.");
  relay.send(JSON.stringify(value));
}

async function callGodot(method, params = {}) {
  if (!relayReady()) {
    throw new Error("Aucun projet Godot n'est actuellement connecté. Ouvre un projet équipé du relais Godot MCP dans l'éditeur Godot 4.7+.");
  }
  const id = randomUUID();
  const payload = { jsonrpc: "2.0", id, method, params };
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Godot n'a pas répondu à ${method} dans le délai prévu.`));
    }, REQUEST_TIMEOUT_MS);
    pending.set(id, { resolve, reject, timer, method });
    try {
      sendRelayJson({ type: "request", payload });
    } catch (error) {
      clearTimeout(timer);
      pending.delete(id);
      reject(error);
    }
  });
}

wss.on("connection", (ws, request) => {
  if (relay && relay.readyState === WebSocket.OPEN) {
    relay.close(4001, "Replaced by newer Godot editor connection");
  }
  relay = ws;
  relayMetadata = null;
  relayConnectedAt = Date.now();
  relayLastSeenAt = Date.now();
  console.log(`[relay] Godot connected from ${request.socket.remoteAddress ?? "unknown"}`);

  ws.on("message", (data, isBinary) => {
    if (isBinary) return;
    relayLastSeenAt = Date.now();
    let msg;
    try {
      msg = JSON.parse(data.toString("utf8"));
    } catch {
      return;
    }
    if (msg?.type === "hello") {
      relayMetadata = msg.metadata ?? {};
      console.log("[relay] hello", relayMetadata);
      return;
    }
    if (msg?.type === "heartbeat") return;
    if (msg?.type !== "response" || !msg.payload) return;

    const response = msg.payload;
    const id = String(response.id ?? "");
    const item = pending.get(id);
    if (!item) return;
    clearTimeout(item.timer);
    pending.delete(id);
    if (response.error) {
      const detail = typeof response.error === "object"
        ? (response.error.message ?? JSON.stringify(response.error))
        : String(response.error);
      item.reject(new Error(detail));
    } else {
      item.resolve(response.result ?? {});
    }
  });

  ws.on("close", () => {
    if (relay === ws) {
      relay = null;
      relayMetadata = null;
      rejectPending("La connexion avec l'éditeur Godot a été fermée.");
    }
    console.log("[relay] Godot disconnected");
  });

  ws.on("error", (error) => console.error("[relay] websocket error", error));
});

httpServer.on("upgrade", (request, socket, head) => {
  let pathname = "";
  try {
    pathname = new URL(request.url ?? "/", "http://localhost").pathname;
  } catch {
    socket.destroy();
    return;
  }
  if (!RELAY_PATHS.has(pathname)) {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(request, socket, head, (ws) => wss.emit("connection", ws, request));
});

setInterval(() => {
  if (!relayReady()) return;
  try {
    sendRelayJson({ type: "ping", at: Date.now() });
  } catch {
    // close handler will update state
  }
}, 25000).unref();

function statusSnapshot() {
  return {
    service: "Godot MCP Android relay",
    godot_connected: Boolean(relayReady()),
    active_project: relayMetadata?.project ?? null,
    connected_at_millis: relayConnectedAt || null,
    last_seen_at_millis: relayLastSeenAt || null,
    godot: relayMetadata,
    pending_requests: pending.size,
  };
}

function createMcpServer() {
  const server = new McpServer({ name: "godot-android", version: "1.1.0" });

  server.registerTool("godot_status", {
    title: "État de Godot",
    description: "Vérifie quel projet Godot est actuellement connecté et disponible pour ChatGPT.",
    inputSchema: {},
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
  }, async () => {
    const status = statusSnapshot();
    return {
      structuredContent: status,
      content: [{ type: "text", text: JSON.stringify(status, null, 2) }],
    };
  });

  server.registerTool("godot_run", {
    title: "Piloter Godot 4.7",
    description: "Exécute une commande du Godot MCP/CLI 0.8.x dans le projet actuellement ouvert dans l'éditeur Godot connecté. Fonctionne pour CHK Pirate Warrior 2 comme pour de futurs projets Godot équipés du relais.",
    inputSchema: {
      method: z.string().trim().min(1).max(160).describe("Méthode Godot MCP, par exemple engine.search, scene.get_tree ou node.get."),
      params: z.record(z.string(), z.unknown()).optional().describe("Paramètres de la commande Godot MCP."),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false, idempotentHint: false },
  }, async ({ method, params }) => {
    try {
      const result = await callGodot(method, params ?? {});
      return {
        structuredContent: { method, project: relayMetadata?.project ?? null, result },
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }],
      };
    }
  });

  return server;
}

function tokenOk(req) {
  const incoming = String(req.params.token ?? "");
  if (MCP_TOKEN.length >= 16 && incoming === MCP_TOKEN) return true;
  if (!incoming) return false;
  const digest = createHash("sha256").update(incoming).digest("hex");
  const a = Buffer.from(digest, "utf8");
  const b = Buffer.from(MCP_TOKEN_SHA256, "utf8");
  return a.length === b.length && timingSafeEqual(a, b);
}

function mcpError(res, status, message) {
  res.status(status).json({ jsonrpc: "2.0", error: { code: -32000, message }, id: null });
}

app.get("/", (_req, res) => {
  res.json({ ok: true, ...statusSnapshot(), mcp: MCP_TOKEN ? "configured" : "token-hash-fallback" });
});
app.get("/status", (_req, res) => res.json(statusSnapshot()));

app.post("/mcp/:token", async (req, res) => {
  if (!tokenOk(req)) { mcpError(res, 404, "MCP endpoint not found"); return; }
  const sessionId = req.headers["mcp-session-id"];
  try {
    if (typeof sessionId === "string") {
      const existing = sessions.get(sessionId);
      if (!existing) { mcpError(res, 404, "MCP session not found"); return; }
      await existing.transport.handleRequest(req, res, req.body);
      return;
    }
    if (!isInitializeRequest(req.body)) { mcpError(res, 400, "MCP initialization required"); return; }
    const server = createMcpServer();
    let transport;
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (id) => sessions.set(id, { transport, server }),
    });
    transport.onclose = () => {
      const id = transport.sessionId;
      if (id) sessions.delete(id);
      void server.close().catch(() => undefined);
    };
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  } catch (error) {
    console.error("MCP POST failed", error);
    if (!res.headersSent) mcpError(res, 500, "MCP request failed");
  }
});

async function handleMcpSession(req, res) {
  if (!tokenOk(req)) { mcpError(res, 404, "MCP endpoint not found"); return; }
  const sessionId = req.headers["mcp-session-id"];
  if (typeof sessionId !== "string") { mcpError(res, 400, "Missing Mcp-Session-Id header"); return; }
  const existing = sessions.get(sessionId);
  if (!existing) { mcpError(res, 404, "MCP session not found"); return; }
  try {
    await existing.transport.handleRequest(req, res);
  } catch (error) {
    console.error(`MCP ${req.method} failed`, error);
    if (!res.headersSent) mcpError(res, 500, "MCP request failed");
  }
}
app.get("/mcp/:token", handleMcpSession);
app.delete("/mcp/:token", handleMcpSession);

httpServer.listen(PORT, "0.0.0.0", () => {
  console.log(`Godot MCP relay listening on :${PORT}`);
  console.log("Relay paths: /relay/godot (current), /relay/chk-pirate-warrior-2 (compatibility)");
});
