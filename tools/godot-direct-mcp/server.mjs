import http from "node:http";
import { randomUUID, createHash, timingSafeEqual } from "node:crypto";
import { WebSocket, WebSocketServer } from "ws";

export const VERSION = "1.0.0";
const PROTOCOL_VERSION = "2025-06-18";
const MAX_REQUEST_BYTES = 256 * 1024;
const MAX_PENDING = 8;

const tools = [
  {
    name: "godot_status",
    title: "Etat du Godot connecte",
    description: "Verifie que le vrai editeur Godot est connecte, sa version et la derniere communication. Un depot GitHub accessible ne constitue PAS un editeur en direct.",
    inputSchema: { type: "object", properties: {} },
    annotations: { readOnlyHint: true, destructiveHint: false }
  },
  {
    name: "godot_run",
    title: "Developper dans Godot",
    description: "Execute UNE commande du moteur Godot MCP/CLI officiel dans l'editeur reel: scenes, noeuds, scripts, modeles 3D GLB, materiaux, lumieres, camera, physique, animations, debugging, capture et jeu en execution. Utiliser d'abord les commandes de lecture et observer le resultat apres une modification. Le serveur ne fournit pas de shell arbitraire.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      required: ["method"],
      properties: {
        method: { type: "string", minLength: 3, maxLength: 120, description: "Exemples: scene.get_tree, node.get, editor.activity, debug.status (selon le catalogue reel du plugin)." },
        params: { type: "object", description: "Arguments transmis a la commande Godot." }
      }
    },
    annotations: { readOnlyHint: false, destructiveHint: true }
  },
  {
    name: "godot_batch",
    title: "Sequence de developpement Godot",
    description: "Execute 1 a 12 commandes Godot dans l'ordre. Stoppe au premier echec, ne rejoue jamais une commande dont l'issue est incertaine. Pour ajouter des objets, animer, eclairer ou corriger un bug en plusieurs etapes.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      required: ["commands"],
      properties: {
        commands: {
          type: "array", minItems: 1, maxItems: 12,
          items: {
            type: "object", additionalProperties: false, required: ["method"],
            properties: { method: { type: "string" }, params: { type: "object" } }
          }
        }
      }
    },
    annotations: { readOnlyHint: false, destructiveHint: true }
  }
];

const equalSecret = (actual, expected) => {
  if (typeof actual !== "string" || typeof expected !== "string") return false;
  return timingSafeEqual(createHash("sha256").update(actual).digest(), createHash("sha256").update(expected).digest());
};

const json = (res, status, value, headers = {}) => {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    ...headers
  });
  res.end(JSON.stringify(value));
};

const ok = (id, result) => ({ jsonrpc: "2.0", id, result });
const rpcError = (id, code, message) => ({ jsonrpc: "2.0", id, error: { code, message } });
const textResult = (data, error = false) => ({
  content: [{ type: "text", text: JSON.stringify(data) }],
  isError: Boolean(error)
});
const methodAllowed = m => typeof m === "string" && /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){1,3}$/.test(m) && m.length <= 120 &&
  !/^(shell|system|process|exec|terminal|os)\./.test(m);

function readJson(req) {
  return new Promise((resolve, reject) => {
    let total = 0, chunks = [];
    req.on("data", chunk => {
      total += chunk.length;
      if (total > MAX_REQUEST_BYTES) {
        reject(new Error("request_too_large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString("utf8"))); }
      catch { reject(new Error("invalid_json")); }
    });
    req.on("error", reject);
  });
}

export function createDirectGodotServer(settings = {}) {
  const cfg = {
    host: settings.host ?? process.env.HOST ?? "127.0.0.1",
    port: Number(settings.port ?? process.env.PORT ?? "8791"),
    chatToken: settings.chatToken ?? process.env.CHK_GODOT_MCP_TOKEN ?? "",
    editorToken: settings.editorToken ?? process.env.CHK_GODOT_EDITOR_TOKEN ?? "",
    timeoutMs: Number(settings.timeoutMs ?? 45000)
  };
  if (cfg.chatToken.length < 48 || cfg.editorToken.length < 48 ||
      equalSecret(cfg.chatToken, cfg.editorToken)) {
    throw new Error("Configure CHK_GODOT_MCP_TOKEN and CHK_GODOT_EDITOR_TOKEN: distinct, >=48 characters.");
  }
  if (!Number.isInteger(cfg.port) || cfg.port < 0 || cfg.port > 65535) throw new Error("Invalid port");

  let connected = null;
  let connectedAt = null;
  let lastSeen = null;
  let editorInfo = null;
  const pending = new Map();

  function failPending(reason) {
    for (const [id, job] of pending) {
      clearTimeout(job.timer);
      job.reject(new Error(reason));
      pending.delete(id);
    }
  }
  function editorActive() {
    return connected?.readyState === WebSocket.OPEN;
  }
  function liveStatus() {
    return {
      service: "CHK Godot Direct MCP", version: VERSION,
      editor_connected: editorActive(), transport: "Godot MCP/CLI WebSocket",
      editor: editorActive() ? editorInfo : null,
      connected_at: editorActive() ? connectedAt : null,
      last_seen: editorActive() ? lastSeen : null,
      pending_commands: pending.size,
      backend: "self-hosted", supabase: false, render: false
    };
  }
  async function run(method, params = {}) {
    if (!methodAllowed(method) || !params || typeof params !== "object" || Array.isArray(params))
      throw new Error("invalid_godot_command");
    if (!editorActive()) throw new Error("editor_offline: open the Godot editor and enable CHK Direct MCP");
    if (pending.size >= MAX_PENDING) throw new Error("editor_busy");
    const id = randomUUID();
    const payload = { jsonrpc: "2.0", id, method, params };
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error("execution_unconfirmed_timeout: do not replay a write without inspecting the editor"));
      }, cfg.timeoutMs);
      pending.set(id, { resolve, reject, timer });
      try {
        connected.send(JSON.stringify({ type: "request", payload }), err => {
          if (err && pending.has(id)) {
            clearTimeout(timer);
            pending.delete(id);
            reject(new Error("send_failed"));
          }
        });
      } catch {
        clearTimeout(timer);
        pending.delete(id);
        reject(new Error("send_failed"));
      }
    });
  }
  async function executeTool(name, args) {
    if (name === "godot_status") return textResult(liveStatus());
    if (name === "godot_run") {
      const result = await run(args.method, args.params ?? {});
      if (result.error) return textResult({ method: args.method, error: result.error }, true);
      return textResult({ method: args.method, result: result.result ?? null });
    }
    if (name === "godot_batch") {
      if (!Array.isArray(args.commands) || args.commands.length < 1 || args.commands.length > 12)
        throw new Error("commands must be 1..12");
      const outcomes = [];
      for (const command of args.commands) {
        const result = await run(command.method, command.params ?? {});
        outcomes.push({ method: command.method, ...(result.error ? { error: result.error } : { result: result.result ?? null }) });
        if (result.error) return textResult({ completed_steps: outcomes.length - 1, stopped: true, outcomes }, true);
      }
      return textResult({ completed_steps: outcomes.length, stopped: false, outcomes });
    }
    throw new Error("unknown_tool");
  }

  const server = http.createServer(async (req, res) => {
    res.setHeader("referrer-policy", "no-referrer");
    res.setHeader("x-frame-options", "DENY");
    const path = new URL(req.url, "http://localhost").pathname;
    if (req.method === "GET" && path === "/health") {
      return json(res, 200, { ok: true, version: VERSION, editor_connected: editorActive() });
    }
    if (!equalSecret(path, "/mcp/" + cfg.chatToken)) return json(res, 404, { error: "not_found" });
    if (req.method !== "POST") return json(res, 405, { error: "POST_required" }, { allow: "POST" });
    if (req.headers.origin) return json(res, 403, { error: "browser_origin_forbidden" });
    if (!(req.headers["content-type"] || "").startsWith("application/json")) return json(res, 415, { error: "application_json_required" });
    try {
      const rpc = await readJson(req);
      if (!rpc || rpc.jsonrpc !== "2.0" || typeof rpc.method !== "string" || Array.isArray(rpc)) {
        return json(res, 400, rpcError(rpc?.id ?? null, -32600, "Invalid request"));
      }
      if (rpc.id === undefined) { res.writeHead(202); return res.end(); }
      if (rpc.method === "initialize")
        return json(res, 200, ok(rpc.id, {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "CHK Godot Direct MCP", version: VERSION },
          instructions: "Use godot_status first. godot_run executes Godot editor MCP commands; check effects and do not repeat uncertain writes."
        }));
      if (rpc.method === "ping") return json(res, 200, ok(rpc.id, {}));
      if (rpc.method === "tools/list") return json(res, 200, ok(rpc.id, { tools }));
      if (rpc.method === "tools/call") {
        const name = rpc.params?.name;
        if (!tools.some(t => t.name === name)) return json(res, 200, rpcError(rpc.id, -32601, "Unknown tool"));
        try { return json(res, 200, ok(rpc.id, await executeTool(name, rpc.params?.arguments ?? {}))); }
        catch (error) { return json(res, 200, ok(rpc.id, textResult({ error: error.message }, true))); }
      }
      return json(res, 200, rpcError(rpc.id, -32601, "Method not found"));
    } catch (e) {
      if (res.destroyed) return;
      return json(res, e.message === "invalid_json" ? 400 : 413, rpcError(null, -32700, e.message === "invalid_json" ? "Parse error" : "Invalid body"));
    }
  });

  const websocket = new WebSocketServer({ noServer: true, maxPayload: 2 * 1024 * 1024, perMessageDeflate: false });
  server.on("upgrade", (req, socket, head) => {
    const path = new URL(req.url, "http://localhost").pathname;
    if (!equalSecret(path, "/relay/godot/" + cfg.editorToken) || req.headers.origin) {
      socket.write("HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n");
      socket.destroy();
      return;
    }
    websocket.handleUpgrade(req, socket, head, ws => websocket.emit("connection", ws));
  });

  websocket.on("connection", ws => {
    if (connected) connected.close(1000, "replaced");
    failPending("editor_disconnected: command outcome unconfirmed");
    connected = ws;
    connectedAt = new Date().toISOString();
    lastSeen = connectedAt;
    editorInfo = null;
    ws.on("message", data => {
      if (ws !== connected) return;
      let packet;
      try { packet = JSON.parse(data.toString("utf8")); } catch { return; }
      lastSeen = new Date().toISOString();
      if (packet?.type === "hello" && packet.metadata && typeof packet.metadata === "object") {
        const fields = ["project", "godot_version", "platform", "model"];
        editorInfo = Object.fromEntries(fields.filter(k => typeof packet.metadata[k] === "string").map(k => [k, packet.metadata[k].slice(0,180)]));
        return;
      }
      if (packet?.type === "response") {
        const response = packet.payload;
        const id = response?.id;
        const pendingJob = typeof id === "string" ? pending.get(id) : null;
        if (!pendingJob) return;
        clearTimeout(pendingJob.timer);
        pending.delete(id);
        pendingJob.resolve(response);
      }
    });
    ws.on("close", () => {
      if (connected === ws) {
        connected = null;
        editorInfo = null;
        failPending("editor_disconnected: command outcome unconfirmed");
      }
    });
    ws.on("error", () => { /* close handler clears pending commands */ });
  });

  async function close() {
    failPending("server_stopped");
    for (const client of websocket.clients) client.terminate();
    await new Promise(resolve => websocket.close(resolve));
    if (server.listening) await new Promise((resolve, reject) => server.close(err => err ? reject(err) : resolve()));
  }
  return { server, close, liveStatus, config: { host: cfg.host, port: cfg.port } };
}

if (process.argv[1] && import.meta.url === new URL("file://" + process.argv[1]).href) {
  const app = createDirectGodotServer();
  app.server.listen(app.config.port, app.config.host, () => {
    console.log("CHK Godot Direct MCP " + VERSION + " on " + app.config.host + ":" + app.config.port);
    console.log("Use TLS reverse proxy, never expose this HTTP port directly.");
  });
}
