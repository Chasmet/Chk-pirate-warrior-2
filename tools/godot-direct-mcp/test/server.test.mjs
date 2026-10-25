import test from "node:test";
import assert from "node:assert/strict";
import { WebSocket } from "ws";
import { createDirectGodotServer } from "../server.mjs";

const CHAT = "a".repeat(64);
const EDITOR = "b".repeat(64);

function start() {
  const app = createDirectGodotServer({ host: "127.0.0.1", port: 0, chatToken: CHAT, editorToken: EDITOR, timeoutMs: 1400 });
  return new Promise(resolve => app.server.listen(0, "127.0.0.1", () => {
    const port = app.server.address().port;
    resolve({ ...app, base: "http://127.0.0.1:" + port, ws: "ws://127.0.0.1:" + port });
  }));
}
async function call(app, method, params = {}, path = "/mcp/" + CHAT) {
  const result = await fetch(app.base + path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 123, method, params })
  });
  return { status: result.status, body: await result.json() };
}
async function openWS(url) {
  return await new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    ws.once("open", () => resolve(ws));
    ws.once("error", reject);
  });
}
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

test("requires independent strong credentials", () => {
  assert.throws(() => createDirectGodotServer({ chatToken: "x", editorToken: "y" }));
  assert.throws(() => createDirectGodotServer({ chatToken: CHAT, editorToken: CHAT }));
});

test("MCP auth, initialization, tool discovery and offline reporting", async () => {
  const app = await start();
  try {
    const denied = await call(app, "tools/list", {}, "/mcp/" + "z".repeat(64));
    assert.equal(denied.status, 404);
    const initialized = await call(app, "initialize", { protocolVersion: "2025-06-18" });
    assert.equal(initialized.status, 200);
    assert.equal(initialized.body.result.serverInfo.name, "CHK Godot Direct MCP");
    const list = await call(app, "tools/list");
    assert.deepEqual(list.body.result.tools.map(t => t.name), ["godot_status", "godot_run", "godot_batch"]);
    const status = await call(app, "tools/call", { name: "godot_status", arguments: {} });
    assert.equal(JSON.parse(status.body.result.content[0].text).editor_connected, false);
    const unavailable = await call(app, "tools/call", { name: "godot_run", arguments: { method: "scene.get_tree" } });
    assert.equal(unavailable.body.result.isError, true);
    assert.match(unavailable.body.result.content[0].text, /editor_offline/);
  } finally { await app.close(); }
});

test("connected editor receives JSON-RPC and returns real scene result", async () => {
  const app = await start();
  let ws;
  try {
    ws = await openWS(app.ws + "/relay/godot/" + EDITOR);
    ws.send(JSON.stringify({ type: "hello", metadata: { project: "CHK Pirate Warrior 2", godot_version: "4.7.0" } }));
    await pause(30);
    assert.equal(app.liveStatus().editor_connected, true);
    assert.equal(app.liveStatus().editor.project, "CHK Pirate Warrior 2");
    ws.on("message", data => {
      const message = JSON.parse(data.toString());
      if (message.type === "request") ws.send(JSON.stringify({
        type: "response",
        payload: { jsonrpc: "2.0", id: message.payload.id, result: { scene_path: "res://scenes/main/main.tscn", method: message.payload.method } }
      }));
    });
    const result = await call(app, "tools/call", { name: "godot_run", arguments: { method: "scene.get_tree", params: {} } });
    assert.equal(result.status, 200);
    assert.equal(result.body.result.isError, false);
    assert.match(result.body.result.content[0].text, /res:\/\/scenes\/main\/main.tscn/);
    const batch = await call(app, "tools/call", { name: "godot_batch", arguments: { commands: [{ method: "scene.get_tree" }, { method: "editor.activity" }] } });
    assert.equal(batch.body.result.isError, false);
    assert.equal(JSON.parse(batch.body.result.content[0].text).completed_steps, 2);
  } finally {
    if (ws) ws.terminate();
    await app.close();
  }
});

test("rejects unauthenticated WebSocket and unsupported methods", async () => {
  const app = await start();
  try {
    await assert.rejects(openWS(app.ws + "/relay/godot/WRONG"), /401/);
    assert.equal(app.liveStatus().editor_connected, false);
    const rejected = await call(app, "tools/call", { name: "godot_run", arguments: { method: "shell.exec" } });
    assert.match(rejected.body.result.content[0].text, /invalid_godot_command/);
    const health = await fetch(app.base + "/health").then(r => r.json());
    assert.equal(health.ok, true);
    assert.equal(health.editor_connected, false);
  } finally { await app.close(); }
});

test("does not repeat an uncertain command after editor disconnect", async () => {
  const app = await start();
  let ws;
  try {
    ws = await openWS(app.ws + "/relay/godot/" + EDITOR);
    ws.on("message", () => ws.terminate());
    const result = await call(app, "tools/call", { name: "godot_run", arguments: { method: "node.set", params: { name: "Hero" } } });
    assert.equal(result.body.result.isError, true);
    assert.match(result.body.result.content[0].text, /unconfirmed/);
  } finally {
    if (ws) ws.terminate();
    await app.close();
  }
});
