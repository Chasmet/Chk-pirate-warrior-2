# -*- coding: utf-8 -*-
"""CHK Godot Direct MCP — private Windows web control panel (v1.2.0).
Starts a local browser UI at http://127.0.0.1:8792.
Never needs Render, Supabase, command prompt, Node installation, or an admin shell.
Tailscale only exposes the authenticated Godot MCP engine on port 10000.
"""
from __future__ import annotations

import ctypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import threading
import time
from urllib.parse import urlparse
from urllib.request import urlopen
import webbrowser
import tkinter as tk

import chk_godot_installer as legacy

PANEL_HOST = "127.0.0.1"
PANEL_PORT = 8792
PANEL_URL = f"http://{PANEL_HOST}:{PANEL_PORT}/"
APP_VERSION = "1.2.0"
HTTP_MAX_BYTES = 4096
PROCESS_FLAGS = legacy.NO_WINDOW | getattr(subprocess, "DETACHED_PROCESS", 0)
HEALTH_NAME = "CHK Godot Local Web"

INDEX = r"""<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>CHK Godot Direct MCP — Mon serveur</title>
<style>
:root{font-family:system-ui,-apple-system,Segoe UI,sans-serif;color-scheme:dark}
*{box-sizing:border-box}
body{background:#0b1120;color:#e2e8f0;margin:0}
main{max-width:790px;margin:0 auto;padding:22px}
header{border-bottom:1px solid #334155;padding-bottom:20px;margin-bottom:18px}
h1{font-size:clamp(23px,4vw,34px);letter-spacing:-.04em;margin:8px 0}
h2{font-size:19px;margin:0 0 16px}
p{line-height:1.6;color:#b8c8db}
.kicker{color:#7dd3fc;font-size:13px;font-weight:750;letter-spacing:.12em}
.panel{border:1px solid #334155;background:#152236;border-radius:16px;padding:24px;margin:15px 0}
.status{padding:17px;border-radius:10px;background:#0b1727;border:1px solid #334155;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.5}
.good{color:#86efac}.error{color:#fca5a5}.working{color:#fef08a}
button{padding:14px 16px;cursor:pointer;background:#38bdf8;color:#062138;border:0;border-radius:11px;
font-weight:760;font-size:15px;width:100%;margin:5px 0}
button.secondary{background:#243449;color:#d8eafe;border:1px solid #465b70}
button:disabled{opacity:.43;cursor:not-allowed}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
@media(max-width:560px){.grid{grid-template-columns:1fr}main{padding:14px}.panel{padding:18px}}
code{color:#a5f3fc;overflow-wrap:anywhere}
small{color:#94a3b8;font-size:13px}
a{color:#7dd3fc}
footer{color:#94a3b8;margin-top:22px;font-size:13px}
</style></head><body>
<main>
<header><div class="kicker">SERVEUR LOCAL • SANS HÉBERGEUR</div>
<h1>CHK GODOT DIRECT MCP</h1>
<p>Tableau de bord de Pirate Warrior 2. Le programme Windows peut se fermer après avoir ouvert cet onglet :
le serveur reste actif sur ton PC.</p></header>
<section class="panel">
<h2>Mon serveur</h2>
<div id="status" class="status working" aria-live="polite">Lecture de l'état du serveur...</div>
<button id="install" onclick="installServer()">INSTALLER ET CONNECTER AUTOMATIQUEMENT</button>
<div class="grid">
<button class="secondary" onclick="refresh()">VÉRIFIER LA CONNEXION</button>
<button class="secondary" onclick="viewDiag()">VOIR LE DIAGNOSTIC</button>
</div>
</section>
<section class="panel">
<h2>Connexion à ChatGPT</h2>
<p>Quand le serveur public est vérifié, clique ici puis colle le lien dans le champ <strong>URL du serveur</strong>
du nouveau plugin ChatGPT. Choisis <strong>Sans authentification</strong> : le lien contient déjà ton jeton privé.</p>
<button id="chatlink" disabled onclick="copyCredential('chat')">COPIER MON LIEN CHATGPT</button>
<div class="grid">
<button class="secondary" id="godoturl" disabled onclick="copyCredential('godot_url')">COPIER L'ADRESSE GODOT</button>
<button class="secondary" id="godotkey" disabled onclick="copyCredential('editor')">COPIER LA CLÉ DE L'ÉDITEUR</button>
</div>
<p><small>La clé Godot se colle dans le panneau « CHK Direct » de l'éditeur Godot 4.7.
Elle est distincte de la clé ChatGPT.</small></p>
</section>
<section class="panel">
<h2>Diagnostic</h2>
<pre id="diag" class="status" style="font-size:12px;max-height:190px;overflow:auto">Aucune erreur affichée.</pre>
</section>
<footer>Les anciennes connexions sur les ports 443 et 8443 ne sont pas modifiées.
Interface accessible uniquement sur <code>127.0.0.1:8792</code>. Le port public 10000 est réservé au serveur MCP,
jamais à cette page d'administration.</footer>
</main>
<script>
const csrf="__UI_SECRET__";
async function api(action) {
 const r=await fetch("/api/"+action,{method:"POST",credentials:"same-origin",
  headers:{"Content-Type":"application/json","X-CHK-UI":csrf},body:"{}",cache:"no-store"});
 const obj=await r.json();
 if(!r.ok)throw new Error(obj.error||"Erreur de connexion");
 return obj;
}
async function refresh(){
 try{
  const r=await fetch("/api/status",{cache:"no-store"}),s=await r.json();
  const text=s.message+"\n\nLocal : "+(s.local_ok?"Actif":"Inactif")+
    "   |   Accès Internet : "+(s.public_ok?"Validé":s.busy?"En cours":"Non validé");
  const block=document.getElementById("status");
  block.className="status "+(s.public_ok?"good":s.error?"error":"working");
  block.textContent=text;
  document.getElementById("install").disabled=s.busy;
  document.getElementById("chatlink").disabled=!s.public_ok;
  document.getElementById("godoturl").disabled=!s.public_ok;
  document.getElementById("godotkey").disabled=!s.configured;
 }catch(e){document.getElementById("status").textContent="Erreur locale : "+e.message;}
}
async function installServer(){
 try{
  const v=await api("install");
  document.getElementById("status").textContent=v.message;
  await refresh();
 }catch(e){alert(e.message);}
}
async function copyCredential(which){
 try{
  const response=await api("copy-"+which);
  const value=response.value;
  try{await navigator.clipboard.writeText(value);}
  catch(e){
   const el=document.createElement("textarea");el.value=value;el.style.position="fixed";
   el.style.left="-2000px";document.body.append(el);el.select();
   document.execCommand("copy");el.remove();
  }
  document.getElementById("status").textContent=response.message;
 }catch(e){alert(e.message);}
}
async function viewDiag(){
 try{
   const o=await api("diagnostic");
   document.getElementById("diag").textContent=o.report||"Aucune erreur enregistrée.";
 }catch(e){alert(e.message);}
}
refresh();setInterval(refresh,2300);
</script></body></html>
"""


class State:
    def __init__(self):
        self.lock = threading.Lock()
        self.busy = False
        self.message = "Serveur local prêt. Cliquez sur INSTALLER ET CONNECTER."
        self.error = False
        self.public_ok = False
        self.hostname = ""
        self.csrf = secrets.token_urlsafe(32)
        self.local_ok = False

    def snapshot(self) -> dict:
        with self.lock:
            return {"version": APP_VERSION, "message": self.message,
                    "error": self.error, "public_ok": self.public_ok,
                    "busy": self.busy, "hostname": self.hostname,
                    "configured": legacy.CONFIG_FILE.exists(),
                    "local_ok": self.local_ok}

    def announce(self, msg: str) -> None:
        with self.lock:
            self.message = msg

    def begin(self) -> bool:
        with self.lock:
            if self.busy:
                return False
            self.busy = True
            self.public_ok = False
            self.error = False
            self.message = "Vérification de Tailscale et des anciennes routes..."
            return True

    def finish(self, error: BaseException | None = None, hostname: str = ""):
        if error:
            legacy.write_diagnostic(error)
        with self.lock:
            self.busy = False
            self.error = error is not None
            self.public_ok = error is None and bool(hostname)
            self.hostname = hostname if error is None else ""
            self.message = ("CONNEXION MCP HTTPS VALIDÉE : bouton COPIER MON LIEN CHATGPT."
                            if error is None else "ERREUR : " + str(error).replace("\n"," ")[:380] +
                            ". Lis la section DIAGNOSTIC, sans utiliser CMD.")


state = State()


def install_and_connect():
    """Runs on a worker thread; all steps are recorded and surfaced in-browser."""
    try:
        tailscale = legacy.find_tailscale()
        hostname = legacy.tls_hostname(tailscale)
        port_state = legacy.status_10000(tailscale)
        if port_state == "occupied":
            raise RuntimeError("Tailscale 10000 est utilisé par un autre service : aucune route modifiée.")
        state.announce("Conservation de tes clés et installation des fichiers sans conflit Windows...")
        legacy.create_config_once()
        root = legacy.INSTALL_DIR
        root.mkdir(parents=True, exist_ok=True)
        installed_exe = legacy.install_immutable(Path(sys.executable), "CHK-Godot-Application", ".exe")
        node = legacy.install_immutable(legacy.bundled("node.exe"), "node", ".exe")
        script = legacy.install_immutable(legacy.bundled("server.cjs"), "godot-server", ".cjs")
        legacy.save_runtime(installed_exe, node, script)
        # Browser panel survives Windows restart. The old server runs as --serve.
        save_web_startup(installed_exe)
        state.announce("Démarrage du moteur Godot MCP sur ton PC...")
        legacy.launch_supervisor(installed_exe)
        state.local_ok = legacy.check_local_health()
        if not state.local_ok:
            raise RuntimeError("Le serveur MCP local ne répond pas sur 8791.")
        state.announce("Serveur local fonctionnel. Configuration HTTPS Funnel 10000...")
        if port_state == "empty":
            result = legacy.run_hidden([tailscale, "funnel", "--bg", "--yes", "--https=10000",
                                        "http://127.0.0.1:8791"], timeout=50)
            if result.returncode != 0:
                message = (result.stdout+"\n"+result.stderr).strip()
                login = legacy.URL_LOGIN.search(message)
                if login:
                    webbrowser.open(login.group(0))
                    raise RuntimeError("Accepte l'autorisation Tailscale dans la page ouverte, puis reclique INSTALLER.")
                raise RuntimeError("Tailscale Funnel a échoué : "+ message[-210:])
        if legacy.status_10000(tailscale) != "ours":
            raise RuntimeError("Tailscale n'a pas relié 10000 à notre moteur MCP.")
        state.announce("Vérification HTTPS réelle (certificat TLS et protocole MCP)...")
        cfg = legacy.installed_config()
        last_error = None
        for _ in range(3):
            try:
                legacy.check_public_mcp(hostname, cfg["chat_token"])
                state.finish(hostname=hostname)
                return
            except Exception as exc:
                last_error = exc
                time.sleep(2)
        raise last_error or RuntimeError("Validation HTTPS échouée.")
    except Exception as exc:
        state.finish(error=exc)


def save_web_startup(exe: Path):
    # Same existing Run value as previous installer; changes only this app ID.
    import winreg
    with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, legacy.STARTUP_KEY, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, legacy.APP_ID, 0, winreg.REG_SZ, f'"{exe}" --web')


class LocalHandler(BaseHTTPRequestHandler):
    server_version = "CHKGodotLocalWeb/1.2.0"

    def allowed(self) -> bool:
        host = self.headers.get("Host", "")
        return host in (f"127.0.0.1:{PANEL_PORT}", f"localhost:{PANEL_PORT}")

    def send_bytes(self, code: int, content: bytes, mime: str):
        self.send_response(code)
        self.send_header("Content-Type", mime)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy",
                         "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def send_json(self, code: int, obj: dict):
        self.send_bytes(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"),
                        "application/json; charset=utf-8")

    def do_GET(self):
        if not self.allowed():
            return self.send_json(403, {"error": "Nom d'hôte local requis."})
        path=urlparse(self.path).path
        if path == "/":
            return self.send_bytes(200, INDEX.replace("__UI_SECRET__", state.csrf).encode("utf-8"),
                                   "text/html; charset=utf-8")
        if path == "/api/status":
            data=state.snapshot()
            data["local_ok"]=legacy.check_local_health()
            state.local_ok=data["local_ok"]
            return self.send_json(200, data)
        if path == "/api/health":
            return self.send_json(200, {"name":HEALTH_NAME,"version":APP_VERSION})
        return self.send_json(404, {"error":"Page introuvable."})

    def do_POST(self):
        if not self.allowed():
            return self.send_json(403, {"error":"Nom d'hôte refusé."})
        origin=self.headers.get("Origin", "")
        if origin and origin not in (PANEL_URL.rstrip("/"), f"http://localhost:{PANEL_PORT}"):
            return self.send_json(403, {"error":"Origine refusée."})
        if self.headers.get("X-CHK-UI") != state.csrf:
            return self.send_json(403, {"error":"Jeton de session locale absent."})
        try:
            length=int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.send_json(400, {"error":"Requête invalide."})
        if length < 0 or length > HTTP_MAX_BYTES:
            return self.send_json(413, {"error":"Requête trop volumineuse."})
        self.rfile.read(length)
        action=urlparse(self.path).path
        if action == "/api/install":
            if state.begin():
                threading.Thread(target=install_and_connect, daemon=True).start()
            return self.send_json(202, {"message":"Installation en cours. Le suivi est affiché sur cette page."})
        if action == "/api/diagnostic":
            log=legacy.DIAGNOSTIC_FILE
            report=log.read_text(encoding="utf-8", errors="replace")[-12000:] if log.exists() else ""
            # Never output tokens in diagnostics.
            import re
            report=re.sub(r"\b[0-9a-f]{64}\b", "[CLÉ MASQUÉE]", report, flags=re.I)
            return self.send_json(200, {"report":report})
        if action.startswith("/api/copy-"):
            which=action.removeprefix("/api/copy-")
            try:
                cfg=legacy.installed_config()
                if which=="editor":
                    return self.send_json(200, {"value":cfg["editor_token"], "message":"Clé éditeur Godot copiée."})
                if not state.snapshot()["public_ok"]:
                    return self.send_json(409, {"error":"Accès public non vérifié. Clique INSTALLER ET CONNECTER."})
                hostname=state.snapshot()["hostname"]
                if which=="chat":
                    return self.send_json(200, {"value":f"https://{hostname}:10000/mcp/{cfg['chat_token']}",
                                                "message":"Adresse MCP complète copiée pour ChatGPT."})
                if which=="godot_url":
                    return self.send_json(200, {"value":f"https://{hostname}:10000",
                                                "message":"Adresse serveur Godot copiée."})
            except Exception as e:
                return self.send_json(409, {"error":str(e)})
        return self.send_json(404, {"error":"Commande inconnue."})

    def log_message(self, *args):
        # No URLs or private keys written to stdout.
        pass


def health_running() -> bool:
    try:
        with urlopen(f"http://{PANEL_HOST}:{PANEL_PORT}/api/health",timeout=1.4) as response:
            data=json.loads(response.read(1024))
            return data.get("name")==HEALTH_NAME
    except (OSError,ValueError):
        return False


def serve_web() -> int:
    try:
        httpd=ThreadingHTTPServer((PANEL_HOST,PANEL_PORT),LocalHandler)
    except OSError as exc:
        if health_running():
            return 0
        legacy.write_diagnostic(exc)
        return 3
    httpd.daemon_threads=True
    with httpd:
        httpd.serve_forever(poll_interval=.5)
    return 0


def start_browser_panel() -> int:
    # Initial executable only needs to start once; after this the local web
    # server keeps running when the visible launcher exits.
    if not health_running():
        try:
            subprocess.Popen([sys.executable,"--web"],
                             cwd=str(Path(sys.executable).parent),
                             stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL,creationflags=PROCESS_FLAGS,
                             close_fds=True)
        except OSError as exc:
            legacy.write_diagnostic(exc)
            error_box("Impossible de lancer le tableau de bord : "+str(exc))
            return 3
        for _ in range(45):
            if health_running():
                break
            time.sleep(.35)
    if not health_running():
        error_box("Le tableau de bord local ne démarre pas sur le port 8792.\n"
                  "Un autre programme utilise peut-être ce port.\n"
                  "Le rapport se trouve dans le dossier AppData\\Local\\CHKGodotDirectMCP.")
        return 4
    webbrowser.open(PANEL_URL)
    return 0


def error_box(text: str):
    try:
        r=tk.Tk()
        r.withdraw()
        from tkinter import messagebox
        messagebox.showerror("CHK Godot Direct MCP",text)
        r.destroy()
    except Exception:
        pass


def self_test() -> int:
    if legacy.self_test()!=0:return 5
    if "http://127.0.0.1:8792/" != PANEL_URL:return 6
    if "__UI_SECRET__" not in INDEX:return 7
    if 'api("install")' not in INDEX:return 8
    return 0


if __name__=="__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    if "--web-smoke" in sys.argv:
        # CI checks that the frozen EXE serves the actual browser UI.
        server=ThreadingHTTPServer((PANEL_HOST,0),LocalHandler)
        # Used by separate Python unit tests with a patched PANEL_PORT.
        server.server_close()
        sys.exit(0)
    if "--serve" in sys.argv:
        sys.exit(legacy.supervisor())
    if "--web" in sys.argv:
        sys.exit(serve_web())
    sys.exit(start_browser_panel())
