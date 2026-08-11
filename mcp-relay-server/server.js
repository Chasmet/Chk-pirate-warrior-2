import express from "express";
import { createServer as createHttpServer } from "node:http";
import { randomUUID, createHash, timingSafeEqual } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
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

// Render starts this service with `cd mcp-relay-server && npm start`, so the
// checked-out Godot project is one directory above. This is the Internet fallback:
// even when Android suspends Godot, Goddo can still inspect the real V8 checkout.
const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const PROJECT_FILE = path.join(PROJECT_ROOT, "project.godot");
const CLOUD_BRANCH = process.env.RENDER_GIT_BRANCH || "agent/v8-godot47-mcp-phone";
const CLOUD_PROJECT_NAME = "CHK Pirate Warrior 2";
const CLOUD_MAX_READ = 2 * 1024 * 1024;
const CLOUD_TEXT_EXTS = new Set([
  ".gd", ".tscn", ".tres", ".godot", ".cfg", ".ini", ".json", ".md", ".txt",
  ".cs", ".shader", ".gdshader", ".xml", ".yml", ".yaml", ".csv",
]);

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

function cloudReady() {
  try {
    return fs.statSync(PROJECT_FILE).isFile();
  } catch {
    return false;
  }
}

function normalizeProjectPath(input, fallback = "") {
  let raw = String(input ?? fallback).trim();
  if (!raw) return "";
  if (raw.startsWith("res://")) raw = raw.slice(6);
  raw = raw.replaceAll("\\", "/");
  const abs = path.resolve(PROJECT_ROOT, raw);
  const rel = path.relative(PROJECT_ROOT, abs);
  if (rel.startsWith("..") || path.isAbsolute(rel) && rel === abs) {
    throw new Error("Chemin en dehors du projet refusé.");
  }
  return abs;
}

function displayProjectPath(abs) {
  return `res://${path.relative(PROJECT_ROOT, abs).replaceAll("\\", "/")}`;
}

function readTextFile(input, fallback = "") {
  const abs = normalizeProjectPath(input, fallback);
  if (!abs || !fs.existsSync(abs) || !fs.statSync(abs).isFile()) {
    throw new Error(`Fichier introuvable: ${String(input || fallback)}`);
  }
  const size = fs.statSync(abs).size;
  if (size > CLOUD_MAX_READ) {
    throw new Error(`Fichier trop volumineux pour une lecture texte (${size} octets).`);
  }
  return { abs, size, content: fs.readFileSync(abs, "utf8") };
}

function parseProjectGodot() {
  const { content } = readTextFile("project.godot");
  const name = content.match(/^config\/name="([^"]*)"/m)?.[1] || CLOUD_PROJECT_NAME;
  const mainScene = content.match(/^run\/main_scene="([^"]*)"/m)?.[1] || null;
  const featuresRaw = content.match(/^config\/features=PackedStringArray\((.*)\)$/m)?.[1] || "";
  const features = [...featuresRaw.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  return { name, main_scene: mainScene, features, content };
}

function listFiles(dirAbs, out, maxEntries, depth, maxDepth) {
  if (out.length >= maxEntries || depth > maxDepth) return;
  let entries = [];
  try {
    entries = fs.readdirSync(dirAbs, { withFileTypes: true });
  } catch {
    return;
  }
  entries.sort((a, b) => a.name.localeCompare(b.name));
  for (const entry of entries) {
    if (out.length >= maxEntries) break;
    if ([".git", ".godot", ".cloud-godot", "node_modules"].includes(entry.name)) continue;
    const abs = path.join(dirAbs, entry.name);
    out.push({ path: displayProjectPath(abs), type: entry.isDirectory() ? "dir" : "file" });
    if (entry.isDirectory()) listFiles(abs, out, maxEntries, depth + 1, maxDepth);
  }
}

function sceneTreeFromText(scenePath) {
  const { abs, content } = readTextFile(scenePath);
  const nodes = [];
  const re = /^\[node\s+([^\]]+)\]$/gm;
  let match;
  while ((match = re.exec(content)) !== null) {
    const attrs = match[1];
    const name = attrs.match(/\bname="([^"]+)"/)?.[1] ?? null;
    const type = attrs.match(/\btype="([^"]+)"/)?.[1] ?? null;
    const parent = attrs.match(/\bparent="([^"]+)"/)?.[1] ?? null;
    const instance = attrs.match(/\binstance=([^\s]+)/)?.[1] ?? null;
    nodes.push({ name, type, parent, instance });
  }
  return { scene_path: displayProjectPath(abs), nodes, node_count: nodes.length };
}

function validateSceneText(scenePath) {
  const { abs, content } = readTextFile(scenePath);
  const issues = [];
  for (const m of content.matchAll(/^\[ext_resource\s+([^\]]+)\]$/gm)) {
    const attrs = m[1];
    const p = attrs.match(/\bpath="([^"]+)"/)?.[1];
    if (!p || !p.startsWith("res://")) continue;
    try {
      const dep = normalizeProjectPath(p);
      if (!fs.existsSync(dep)) issues.push({ type: "missing_ext_resource", path: p });
    } catch {
      issues.push({ type: "invalid_ext_resource", path: p });
    }
  }
  return {
    path: displayProjectPath(abs),
    valid: issues.length === 0,
    issue_count: issues.length,
    issues,
    note: "Validation Internet légère des dépendances texte; les erreurs moteur/animation nécessitent un éditeur Godot vivant.",
  };
}

function searchProject(query, maxResults = 80) {
  const q = String(query ?? "").trim().toLowerCase();
  if (!q) throw new Error("Paramètre de recherche manquant (query/search/pattern).");
  const files = [];
  listFiles(PROJECT_ROOT, files, 5000, 0, 20);
  const results = [];
  for (const item of files) {
    if (results.length >= maxResults) break;
    if (item.type !== "file") continue;
    const rel = item.path.slice(6);
    const ext = path.extname(rel).toLowerCase();
    if (!CLOUD_TEXT_EXTS.has(ext) && !["project.godot"].includes(path.basename(rel))) continue;
    const abs = normalizeProjectPath(rel);
    let stat;
    try { stat = fs.statSync(abs); } catch { continue; }
    if (stat.size > CLOUD_MAX_READ) continue;
    let text;
    try { text = fs.readFileSync(abs, "utf8"); } catch { continue; }
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length && results.length < maxResults; i += 1) {
      const line = lines[i];
      if (line.toLowerCase().includes(q)) {
        results.push({ path: item.path, line: i + 1, text: line.slice(0, 400) });
      }
    }
  }
  return { query: String(query), count: results.length, results, truncated: results.length >= maxResults };
}

async function callCloud(method, params = {}) {
  if (!cloudReady()) throw new Error("Le projet Internet Goddo n'est pas disponible sur le serveur.");
  const p = params ?? {};
  const project = parseProjectGodot();
  switch (method) {
    case "cloud.status":
    case "project.info":
      return {
        mode: "goddo_internet",
        project: project.name,
        branch: CLOUD_BRANCH,
        godot_target: project.features,
        main_scene: project.main_scene,
        repository_checkout: true,
        read_only_fallback: true,
      };
    case "project.get_setting": {
      const key = String(p.key ?? p.setting ?? "").trim();
      if (!key) throw new Error("Paramètre key/setting manquant.");
      const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const match = project.content.match(new RegExp(`^${escaped}=(.*)$`, "m"));
      return { key, raw_value: match?.[1] ?? null, found: Boolean(match) };
    }
    case "scene.content":
    case "fs.read":
    case "script.read": {
      const target = String(p.path ?? p.file ?? "").trim();
      if (!target) throw new Error("Paramètre path manquant.");
      const { abs, size, content } = readTextFile(target);
      return { path: displayProjectPath(abs), size, content, mode: "goddo_internet" };
    }
    case "scene.tree":
    case "scene.get_tree": {
      const target = String(p.path ?? p.scene_path ?? project.main_scene ?? "").trim();
      if (!target) throw new Error("Aucune scène cible et aucune scène principale configurée.");
      return { ...sceneTreeFromText(target), mode: "goddo_internet" };
    }
    case "scene.validate": {
      const target = String(p.path ?? p.scene_path ?? project.main_scene ?? "").trim();
      if (!target) throw new Error("Aucune scène cible et aucune scène principale configurée.");
      return { ...validateSceneText(target), mode: "goddo_internet" };
    }
    case "fs.list":
    case "project.files": {
      const target = String(p.path ?? "res://");
      const abs = normalizeProjectPath(target);
      const entries = [];
      listFiles(abs, entries, Math.min(Math.max(Number(p.limit ?? 300), 1), 2000), 0, Math.min(Math.max(Number(p.max_depth ?? 4), 0), 20));
      return { path: displayProjectPath(abs), entries, count: entries.length, mode: "goddo_internet" };
    }
    case "engine.search":
    case "project.search":
    case "fs.search": {
      const query = p.query ?? p.search ?? p.pattern ?? p.text;
      return { ...searchProject(query, Math.min(Math.max(Number(p.limit ?? 80), 1), 300)), mode: "goddo_internet" };
    }
    default:
      throw new Error(
        `La commande '${method}' nécessite actuellement l'éditeur Godot vivant. ` +
        "Goddo Internet est connecté en mode dépôt pour project.info, project.get_setting, project.files, " +
        "scene.content, scene.tree, scene.validate, fs.read, fs.list et engine.search. " +
        "Les modifications persistantes doivent être enregistrées sur GitHub par ChatGPT.",
      );
  }
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
  if (!relayReady()) return callCloud(method, params);
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
  const live = Boolean(relayReady());
  const internet = cloudReady();
  let project = relayMetadata?.project ?? null;
  if (!project && internet) {
    try { project = parseProjectGodot().name; } catch { project = CLOUD_PROJECT_NAME; }
  }
  return {
    service: "Goddo MCP",
    godot_connected: live || internet,
    connection_mode: live ? "live_editor" : (internet ? "goddo_internet" : "offline"),
    live_editor_connected: live,
    internet_project_available: internet,
    active_project: project,
    cloud_branch: internet ? CLOUD_BRANCH : null,
    connected_at_millis: live ? (relayConnectedAt || null) : null,
    last_seen_at_millis: live ? (relayLastSeenAt || null) : null,
    godot: live ? relayMetadata : (internet ? {
      project,
      project_path: "Render repository checkout",
      godot_version: "4.7 target",
      platform: "Internet / GitHub checkout",
      model: "Goddo Internet",
      mode: "repository_fallback",
    } : null),
    pending_requests: pending.size,
  };
}

function createMcpServer() {
  const server = new McpServer({ name: "goddo", version: "1.2.0" });

  server.registerTool("godot_status", {
    title: "État de Goddo / Godot",
    description: "Vérifie si Goddo peut travailler. Priorité à l'éditeur Godot vivant; sinon bascule automatiquement sur Goddo Internet avec la copie du projet GitHub sur Render.",
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
    title: "Piloter Goddo / Godot 4.7",
    description: "Exécute une commande Godot MCP. Si un éditeur Godot est connecté, utilise les commandes complètes Godot MCP/CLI. Sinon Goddo Internet lit et analyse directement le dépôt du projet (project.info, project.get_setting, project.files, scene.content, scene.tree, scene.validate, fs.read, fs.list, engine.search).",
    inputSchema: {
      method: z.string().trim().min(1).max(160).describe("Méthode Godot MCP, par exemple project.info, scene.tree, scene.content, fs.read, fs.list ou engine.search."),
      params: z.record(z.string(), z.unknown()).optional().describe("Paramètres de la commande Godot MCP."),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false, idempotentHint: false },
  }, async ({ method, params }) => {
    try {
      const result = await callGodot(method, params ?? {});
      const mode = relayReady() ? "live_editor" : "goddo_internet";
      return {
        structuredContent: { method, mode, project: statusSnapshot().active_project, result },
        content: [{ type: "text", text: JSON.stringify({ mode, result }, null, 2) }],
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
  console.log(`Goddo MCP listening on :${PORT}`);
  console.log("Relay paths: /relay/godot (live editor), Internet repository fallback enabled");
});
