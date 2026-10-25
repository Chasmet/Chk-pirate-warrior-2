"""CHK Godot: web dashboard on localhost, with a real native Windows host.
No CMD, Render, Supabase or external HTTP requests. Do not run arbitrary binaries.
"""
from __future__ import annotations
import http.server
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import webbrowser
from pathlib import Path

HOST = "127.0.0.1"
DASHBOARD_PORT = 8793
GODOT_PORT = 8792
MAX_EXE = 130 * 1024 * 1024
HOME = Path(os.environ.get("LOCALAPPDATA") or (Path.home() / ".local" / "share")) / "CHK-Godot-Lanceur"

PAGE = r"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>CHK Godot — Lanceur local</title>
<style>*{box-sizing:border-box}body{font-family:Segoe UI,Arial,sans-serif;background:#101a29;color:#f4f7fd;max-width:800px;margin:35px auto;padding:16px}
h1{font-size:32px}.box{padding:22px;background:#1d2c40;margin:17px 0;border:1px solid #354d67;border-radius:17px}
p{color:#cadaeb;line-height:1.5}button,.btn{padding:14px 18px;margin:5px;border:0;border-radius:10px;background:#24d3b6;color:#10202c;cursor:pointer;font-size:16px;font-weight:700}
.secondary{background:#3d526b;color:white}label{display:block;border:2px dashed #7592ae;padding:20px;cursor:pointer;text-align:center;border-radius:10px}
#file{display:none}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#101723;padding:13px;border-radius:9px;max-height:260px;overflow:auto}
.ok{color:#68efac}.error{color:#ffb1ab}a{color:inherit;text-decoration:none}small{color:#9eb1ca}</style></head><body>
<h1>CHK Godot — Lanceur Web Local</h1><p>Ouvre et contrôle le programme sur ce PC. Pas de CMD, pas de Render, pas de Supabase.</p>
<section class="box"><h2>État du serveur Godot</h2><p id="status">Vérification...</p><p id="detail"></p>
<button onclick="send('start')">Démarrer</button><button class="secondary" onclick="send('stop')">Arrêter</button>
<button class="secondary" onclick="refresh()">Vérifier</button>
<a class="btn secondary" href="http://127.0.0.1:8792/" target="_blank">Ouvrir Godot</a></section>
<section class="box"><h2>Importer le programme hors OneDrive</h2>
<p>Choisis CHK-Godot-Installation.exe depuis ton dossier Téléchargements. Il sera copié dans le dossier local Windows et démarré.</p>
<label for="file">Choisir mon programme CHK-Godot (.exe)</label>
<input type="file" id="file" accept=".exe" onchange="upload(this.files[0])">
<p id="notice"></p></section>
<section class="box"><h2>Pourquoi ça ne marche pas ?</h2><p>Les erreurs d'exécution s'affichent ici, même si le programme Godot s'arrête.</p>
<pre id="log">Aucun diagnostic.</pre></section>
<small>Tableau de bord : 127.0.0.1:8793 · Service Godot : 127.0.0.1:8792 · 100 % local.</small>
<script>
const token="__TOKEN__";let busy=false;
async function req(p,opt={}){const r=await fetch('/api/'+p,{...opt,cache:'no-store',headers:{'X-CHK-Token':token,...(opt.headers||{})}});
const j=await r.json();if(!r.ok)throw Error(j.error||'Échec');return j}
async function refresh(){if(busy)return;try{let s=await req('status');
document.getElementById('status').textContent=s.online?'Connecté : Godot répond':'Hors ligne : le service Godot ne répond pas';
document.getElementById('status').className=s.online?'ok':'error';
document.getElementById('detail').textContent=s.message;
document.getElementById('log').textContent=s.log||'Aucune erreur enregistrée.';
}catch(e){document.getElementById('detail').textContent=e.message;}}
async function send(name){busy=true;try{let r=await req(name,{method:'POST'});document.getElementById('notice').textContent=r.message}catch(e){document.getElementById('notice').textContent='Erreur : '+e.message}busy=false;refresh();}
async function upload(file){if(!file)return;busy=true;document.getElementById('notice').textContent='Copie locale en cours...';
try{let r=await req('import',{method:'POST',body:file,headers:{'Content-Type':'application/octet-stream','X-Name':file.name}});
document.getElementById('notice').textContent=r.message;
let started=await req('start',{method:'POST'});
document.getElementById('notice').textContent+=' '+started.message;
}catch(e){document.getElementById('notice').textContent='Erreur : '+e.message}
busy=false;refresh();}
setInterval(refresh,2500);refresh();
</script></body></html>"""


def port_open(port=GODOT_PORT):
    try:
        with socket.create_connection((HOST, port), timeout=0.6):
            return True
    except OSError:
        return False


def valid_pe(path):
    try:
        with path.open("rb") as f:
            if f.read(2) != b"MZ":
                return False
            f.seek(60)
            offset = int.from_bytes(f.read(4), "little")
            if not 64 <= offset <= 8192:
                return False
            f.seek(offset)
            return f.read(4) == b"PE\0\0"
    except OSError:
        return False


class Launcher:
    def __init__(self, directory=HOME):
        self.directory = Path(directory)
        self.exe = self.directory / "CHK-Godot-Installation.exe"
        self.logfile = self.directory / "godot-demarrage.log"
        self.process = None
        self.lock = threading.Lock()
        self.token = secrets.token_urlsafe(32)

    def logs(self):
        try:
            with self.logfile.open("rb") as f:
                f.seek(max(0, self.logfile.stat().st_size - 4500))
                return f.read().decode("utf-8", "replace")[-4000:]
        except OSError:
            return ""

    def status(self):
        online = port_open()
        with self.lock:
            proc = self.process
            code = proc.poll() if proc else None
        if online:
            message = "Le service Godot répond sur le port 8792."
        elif code is not None:
            message = f"Le programme s'est refermé (code {code}). Voir les erreurs ci-dessous."
        elif proc:
            message = "Exécutable lancé ; attente de la réponse Godot sur 8792..."
        elif not self.exe.is_file():
            message = "Sélectionne ton installateur CHK-Godot dans Téléchargements."
        else:
            message = "Fichier présent. Clique sur Démarrer."
        return dict(online=online, message=message, installed=self.exe.is_file(), log=self.logs())

    def import_file(self, body, n, name):
        if not re.fullmatch(r"CHK-Godot-Installation(?: \(\d+\))?\.exe", name, re.I):
            raise ValueError("Sélectionne CHK-Godot-Installation.exe, pas un autre programme.")
        if not 10000 <= n <= MAX_EXE:
            raise ValueError("Taille de fichier invalide.")
        self.directory.mkdir(parents=True, exist_ok=True)
        tmp = self.directory / "nouvelle-version.tmp"
        try:
            with tmp.open("wb") as f:
                remaining = n
                while remaining:
                    chunk = body.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError("Transfert interrompu ; essaie le fichier depuis Téléchargements.")
                    f.write(chunk)
                    remaining -= len(chunk)
            if not valid_pe(tmp):
                raise ValueError("Ce fichier n'est pas un vrai programme Windows.")
            with self.lock:
                if self.process is not None and self.process.poll() is None:
                    raise ValueError("Arrête le programme avant de le remplacer.")
                if self.exe.is_file():
                    shutil.copy2(self.exe, self.directory / "version-precedente.exe")
                os.replace(tmp, self.exe)
            return {"message": "Fichier copié hors OneDrive."}
        finally:
            tmp.unlink(missing_ok=True)

    def start(self):
        with self.lock:
            if port_open():
                return {"message": "Godot fonctionne déjà."}
            if self.process is not None and self.process.poll() is None:
                return {"message": "Démarrage déjà demandé."}
            if not self.exe.is_file():
                raise ValueError("Commence par choisir le fichier CHK-Godot-Installation.exe.")
            self.directory.mkdir(parents=True, exist_ok=True)
            with self.logfile.open("ab") as log:
                log.write(b"\n=== Demarrage CHK Godot ===\n")
                try:
                    self.process = subprocess.Popen([str(self.exe)], cwd=str(self.directory),
                                                    stdout=log, stderr=subprocess.STDOUT,
                                                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                except OSError as exc:
                    log.write(("Windows bloque ce programme : " + str(exc) + "\n").encode("utf-8", "replace"))
                    raise ValueError("Windows a refusé le démarrage : regarde les erreurs.") from exc
        return {"message": "Démarrage demandé. Le site reste ouvert."}

    def stop(self):
        with self.lock:
            if self.process is not None and self.process.poll() is None:
                self.process.terminate()
                return {"message": "Arrêt demandé."}
        return {"message": "Aucun programme lancé depuis ce site."}


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def json(self, value, status=200):
        data = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def valid_host(self):
        return self.headers.get("Host") in (f"{HOST}:{DASHBOARD_PORT}", f"localhost:{DASHBOARD_PORT}")

    def do_GET(self):
        if not self.valid_host():
            return self.json({"error": "Adresse non locale"}, 403)
        if self.path == "/":
            raw = PAGE.replace("__TOKEN__", self.server.launcher.token).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'")
            self.send_header("X-Frame-Options", "DENY")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
        elif self.path == "/api/status":
            self.json(self.server.launcher.status())
        else:
            self.json({"error": "Page inconnue"}, 404)

    def do_POST(self):
        if not self.valid_host() or self.headers.get("Origin", "") not in ("", f"http://{HOST}:{DASHBOARD_PORT}", f"http://localhost:{DASHBOARD_PORT}") or self.headers.get("X-CHK-Token") != self.server.launcher.token:
            return self.json({"error": "Action refusée"}, 403)
        try:
            if self.path == "/api/start":
                result = self.server.launcher.start()
            elif self.path == "/api/stop":
                result = self.server.launcher.stop()
            elif self.path == "/api/import":
                if self.headers.get("Content-Type") != "application/octet-stream":
                    raise ValueError("Format du transfert invalide.")
                try:
                    size = int(self.headers.get("Content-Length", ""))
                except ValueError:
                    raise ValueError("Taille du fichier absente.")
                result = self.server.launcher.import_file(self.rfile, size, self.headers.get("X-Name", ""))
            else:
                return self.json({"error": "Commande inconnue"}, 404)
            self.json(result)
        except ValueError as exc:
            self.json({"error": str(exc)}, 400)
        except Exception as exc:
            self.json({"error": type(exc).__name__}, 500)


class LocalServer(http.server.ThreadingHTTPServer):
    def __init__(self, launcher):
        super().__init__((HOST, DASHBOARD_PORT), Handler)
        self.launcher = launcher


def main():
    HOME.mkdir(parents=True, exist_ok=True)
    url = f"http://{HOST}:{DASHBOARD_PORT}/"
    try:
        server = LocalServer(Launcher())
    except OSError as exc:
        if getattr(exc, "winerror", None) == 10048 or getattr(exc, "errno", None) in (48, 98):
            webbrowser.open(url)
            return
        try:
            from tkinter import Tk, messagebox
            root = Tk()
            root.withdraw()
            messagebox.showerror("CHK Godot", "Impossible de démarrer le lanceur : " + str(exc))
            root.destroy()
        except Exception:
            print(str(exc), file=sys.stderr)
        return
    threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever(0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
