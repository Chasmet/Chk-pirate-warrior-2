# -*- coding: utf-8 -*-
"""CHK Godot Direct MCP - Windows one-click installer (Tkinter, no console).
No Supabase, Render, administrator privileges or new Tailscale account needed.
Never overwrites pre-existing Funnel ports or application credentials.
"""
from __future__ import annotations

import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import messagebox, ttk
import urllib.error
import urllib.request
import webbrowser
import winreg

APP_NAME = "CHK Godot Direct MCP"
APP_ID = "CHKGodotDirectMCP"
INSTALL_DIR = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / APP_ID
CONFIG_FILE = INSTALL_DIR / "settings.json"
GUI_BINARY = "CHK-Godot-Installation.exe"
SERVER_BINARY = "node.exe"
SERVER_SCRIPT = "server.cjs"
LOCAL_PORT = 8791
FUNNEL_PORT = 10000
STARTUP_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
URL_LOGIN = re.compile(r"https://(?:login\.tailscale\.com|tailscale\.com)/[^\s\"'<>]+", re.I)
HEX_SECRET = re.compile(r"^[0-9a-f]{64}$")
MUTEX_NAME = "Local\\CHKGodotDirectMCP-Supervisor"


def bundled(name: str) -> Path:
    root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    candidate = root / "runtime" / name
    if not candidate.is_file():
        raise RuntimeError("Pack incomplet : fichier intégré manquant : " + name)
    return candidate


def run_hidden(argv: list[str], timeout: int = 18) -> subprocess.CompletedProcess:
    return subprocess.run(
        argv, capture_output=True, text=True, errors="replace",
        timeout=timeout, creationflags=NO_WINDOW, stdin=subprocess.DEVNULL
    )


def installed_config() -> dict:
    if not CONFIG_FILE.is_file():
        raise RuntimeError("Aucune installation : utilise INSTALLER ET CONNECTER.")
    cfg = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    if (not HEX_SECRET.fullmatch(str(cfg.get("chat_token", ""))) or
            not HEX_SECRET.fullmatch(str(cfg.get("editor_token", ""))) or
            cfg.get("chat_token") == cfg.get("editor_token")):
        raise RuntimeError("Configuration privée invalide, conservée sans la modifier.")
    return cfg


def create_config_once() -> dict:
    if CONFIG_FILE.exists():
        return installed_config()
    import secrets
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)
    cfg = {
        "schema": 1, "chat_token": secrets.token_hex(32),
        "editor_token": secrets.token_hex(32),
        "local_port": LOCAL_PORT, "funnel_port": FUNNEL_PORT
    }
    # Never overwrite existing tokens, even after an interrupted installation.
    try:
        with open(CONFIG_FILE, "x", encoding="utf-8") as fp:
            json.dump(cfg, fp, ensure_ascii=False, indent=2)
    except FileExistsError:
        return installed_config()
    return cfg


def tls_hostname(tailscale: str) -> str:
    result = run_hidden([tailscale, "status", "--json"], 20)
    if result.returncode != 0:
        raise RuntimeError("Tailscale ne répond pas : ouvre Tailscale et connecte-toi.")
    try:
        info = json.loads(result.stdout)
        name = str(info.get("Self", {}).get("DNSName", "")).rstrip(".").lower()
        state = str(info.get("BackendState", ""))
    except (ValueError, AttributeError) as exc:
        raise RuntimeError("Statut Tailscale non lisible.") from exc
    if state != "Running":
        raise RuntimeError("Tailscale n'est pas connecté (état : " + state[:32] + ").")
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{3,200}\.ts\.net", name):
        raise RuntimeError("Nom DNS Tailscale absent. Vérifie MagicDNS dans Tailscale.")
    return name


def find_tailscale() -> str:
    candidates = [
        shutil.which("tailscale.exe"),
        Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Tailscale" / "tailscale.exe",
        Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Tailscale" / "tailscale.exe",
    ]
    for item in candidates:
        if item and Path(item).is_file():
            return str(item)
    raise RuntimeError("Tailscale Windows introuvable. Ouvre l'application Tailscale déjà installée.")


def status_10000(tailscale: str) -> str:
    # Fail closed on a pre-existing mapping: never overwrite other services.
    output = run_hidden([tailscale, "funnel", "status", "--json"], 18)
    if output.returncode == 0:
        try:
            data = json.loads(output.stdout)
            web = data.get("Web", {})
            for hostname, entry in web.items():
                if hostname.endswith(":" + str(FUNNEL_PORT)):
                    handlers = entry.get("Handlers", {})
                    destinations = [str(handler.get("Proxy", "")) for handler in handlers.values() if isinstance(handler, dict)]
                    allowed = data.get("AllowFunnel", {})
                    if any(dest == f"http://127.0.0.1:{LOCAL_PORT}" for dest in destinations) and allowed.get(hostname) is True:
                        return "ours"
                    return "occupied"
            # Some Tailscale builds use different JSON keys; conservatively refuse.
            if str(FUNNEL_PORT) in output.stdout:
                return "occupied"
            return "empty"
        except (ValueError, AttributeError):
            pass
    fallback = run_hidden([tailscale, "funnel", "status"], 18)
    if fallback.returncode != 0:
        raise RuntimeError("Impossible de contrôler les ports Tailscale. Aucun changement effectué.")
    if re.search(r"(?:\:|\b)" + str(FUNNEL_PORT) + r"\b", fallback.stdout):
        # Text status cannot prove ownership, so refuse overwrite.
        return "occupied"
    return "empty"


def check_local_health() -> bool:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8791/health", timeout=2) as reply:
            data = json.loads(reply.read(8192).decode("utf-8"))
            return reply.status == 200 and data.get("ok") is True and data.get("version") == "1.0.0"
    except (OSError, ValueError, urllib.error.URLError):
        return False


def check_public_mcp(hostname: str, token: str) -> None:
    url = f"https://{hostname}:{FUNNEL_PORT}/mcp/{token}"
    payload = json.dumps({
        "jsonrpc": "2.0", "id": 27, "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "CHK Installation", "version": "1.0.0"}
        }
    }).encode("utf-8")
    req = urllib.request.Request(url, data=payload, method="POST",
                                 headers={"Content-Type": "application/json", "Accept": "application/json"})
    # SSL certificate validation is left ENABLED (Python default).
    try:
        with urllib.request.urlopen(req, timeout=15) as reply:
            packet = json.loads(reply.read(16384).decode("utf-8"))
            if reply.status != 200 or packet.get("id") != 27 or \
               packet.get("result", {}).get("serverInfo", {}).get("name") != "CHK Godot Direct MCP":
                raise RuntimeError("Le serveur public répond, mais le protocole MCP est invalide.")
    except (OSError, ValueError, urllib.error.URLError) as exc:
        raise RuntimeError("HTTPS public indisponible ou MCP non validé : vérifie le port 10000 de Tailscale.") from exc


def save_startup(installed_exe: Path) -> None:
    with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, STARTUP_KEY, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, APP_ID, 0, winreg.REG_SZ, f'"{installed_exe}" --serve')


def launch_supervisor(installed_exe: Path) -> None:
    if check_local_health():
        return
    subprocess.Popen(
        [str(installed_exe), "--serve"],
        cwd=str(INSTALL_DIR), stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=NO_WINDOW | getattr(subprocess, "DETACHED_PROCESS", 0),
        close_fds=True
    )
    for _ in range(35):
        if check_local_health():
            return
        time.sleep(0.35)
    raise RuntimeError("Le serveur local ne démarre pas. Réessaie avec le bouton VÉRIFIER.")


def supervisor() -> int:
    # Exactly one process per Windows session, so auto-start and manual start
    # cannot create duplicate long-running supervisors.
    mutex = ctypes.windll.kernel32.CreateMutexW(None, False, MUTEX_NAME)
    if not mutex:
        return 2
    try:
        if ctypes.windll.kernel32.GetLastError() == 183:
            return 0
        cfg = installed_config()
        node = INSTALL_DIR / SERVER_BINARY
        script = INSTALL_DIR / SERVER_SCRIPT
        if not node.is_file() or not script.is_file():
            return 3
        env = os.environ.copy()
        env.update({
            "HOST": "127.0.0.1", "PORT": str(LOCAL_PORT),
            "CHK_GODOT_MCP_TOKEN": cfg["chat_token"],
            "CHK_GODOT_EDITOR_TOKEN": cfg["editor_token"],
            "NODE_ENV": "production"
        })
        while True:
            if check_local_health():
                time.sleep(6)
                continue
            try:
                child = subprocess.Popen(
                    [str(node), str(script)],
                    cwd=str(INSTALL_DIR), env=env,
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    creationflags=NO_WINDOW
                )
                child.wait()
            except OSError:
                return 4
            time.sleep(4)
    finally:
        ctypes.windll.kernel32.CloseHandle(mutex)


class Installer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("CHK GODOT — Installation automatique")
        self.geometry("620x445")
        self.minsize(565, 410)
        self.configure(bg="#111827")
        self.busy = False
        self.verified_host = ""
        self.tail = ""

        st = ttk.Style(self)
        st.theme_use("clam")
        st.configure("Main.TFrame", background="#111827")
        st.configure("Title.TLabel", background="#111827", foreground="#ffffff", font=("Segoe UI", 17, "bold"))
        st.configure("Body.TLabel", background="#111827", foreground="#cbd5e1", font=("Segoe UI", 10))
        st.configure("State.TLabel", background="#111827", foreground="#93c5fd", font=("Segoe UI", 10, "bold"))
        st.configure("Main.TButton", font=("Segoe UI", 10, "bold"), padding=8)

        root = ttk.Frame(self, style="Main.TFrame", padding=24)
        root.pack(fill="both", expand=True)
        ttk.Label(root, text="CHK GODOT DIRECT MCP", style="Title.TLabel").pack(anchor="w")
        ttk.Label(root,
                  text="Serveur indépendant • ChatGPT ↔ Godot • Tailscale déjà installé",
                  style="Body.TLabel").pack(anchor="w", pady=(5, 20))
        self.install = ttk.Button(root, text="1  INSTALLER ET CONNECTER AUTOMATIQUEMENT",
                                  style="Main.TButton", command=self.install_now)
        self.install.pack(fill="x", pady=4)
        self.verify = ttk.Button(root, text="2  VÉRIFIER MON SERVEUR", style="Main.TButton",
                                 command=self.verify_now)
        self.verify.pack(fill="x", pady=4)
        self.copy_chat = ttk.Button(root, text="3  COPIER MON LIEN CHATGPT", style="Main.TButton",
                                    command=self.copy_chat_url, state="disabled")
        self.copy_chat.pack(fill="x", pady=4)
        self.copy_godot = ttk.Button(root, text="COPIER LA CLÉ DE L'ÉDITEUR GODOT",
                                     style="Main.TButton", command=self.copy_editor_token,
                                     state="disabled")
        self.copy_godot.pack(fill="x", pady=4)
        self.state = ttk.Label(root, text="État : prêt pour l'installation.", style="State.TLabel",
                               wraplength=550, justify="left")
        self.state.pack(fill="x", pady=(18, 5))
        ttk.Label(root, text="Ne modifie pas le MCP existant sur 8443, ni IIS sur 443.",
                  style="Body.TLabel").pack(anchor="w", pady=(10, 2))
        ttk.Label(root, text="Après redémarrage Windows, le serveur se relance automatiquement.",
                  style="Body.TLabel").pack(anchor="w")
        self.after(350, self.initial_state)

    def initial_state(self):
        try:
            installed_config()
            self.copy_godot.config(state="normal")
            self.set_status("Installation existante détectée. Clique VÉRIFIER MON SERVEUR.")
        except Exception:
            pass

    def set_status(self, message: str):
        self.state.config(text="État : " + message)

    def background(self, worker):
        if self.busy:
            return
        self.busy = True
        self.install.config(state="disabled")
        self.verify.config(state="disabled")
        self.copy_chat.config(state="disabled")
        threading.Thread(target=self._run_worker, args=(worker,), daemon=True).start()

    def _run_worker(self, worker):
        try:
            worker()
        except Exception as exc:
            detail = str(exc).replace("\n", " ")[:300]
            self.after(0, lambda d=detail: self.set_status("ATTENTION — " + d))
        finally:
            self.after(0, self.ready)

    def ready(self):
        self.busy = False
        self.install.config(state="normal")
        self.verify.config(state="normal")
        if CONFIG_FILE.is_file():
            self.copy_godot.config(state="normal")

    def update_message(self, msg):
        self.after(0, lambda: self.set_status(msg))

    def install_now(self):
        self.background(self._install)

    def verify_now(self):
        self.background(self._verify)

    def _install(self):
        tailscale = find_tailscale()
        hostname = tls_hostname(tailscale)
        self.update_message("Tailscale connecté. Vérification de la place libre sur 10000...")
        port_state = status_10000(tailscale)
        if port_state == "occupied":
            raise RuntimeError("Port Tailscale 10000 déjà occupé : aucune route existante n'a été modifiée.")
        cfg = create_config_once()
        installed_exe = INSTALL_DIR / GUI_BINARY
        node = INSTALL_DIR / SERVER_BINARY
        script = INSTALL_DIR / SERVER_SCRIPT
        self.update_message("Installation locale du serveur et conservation de tes clés...")
        if Path(sys.executable).resolve() != installed_exe.resolve():
            shutil.copy2(sys.executable, installed_exe)
        shutil.copy2(bundled("node.exe"), node)
        shutil.copy2(bundled("server.cjs"), script)
        save_startup(installed_exe)
        launch_supervisor(installed_exe)
        self.update_message("Serveur local actif. Activation automatique de Funnel HTTPS 10000...")
        if port_state == "empty":
            command = [tailscale, "funnel", "--bg", "--yes", "--https=10000",
                       "http://127.0.0.1:8791"]
            outcome = run_hidden(command, 45)
            if outcome.returncode != 0:
                info = outcome.stdout + "\n" + outcome.stderr
                login = URL_LOGIN.search(info)
                if login:
                    self.after(0, lambda u=login.group(0): webbrowser.open(u))
                    raise RuntimeError("Autorise Tailscale dans la page Internet ouverte, puis clique VÉRIFIER.")
                raise RuntimeError("Tailscale Funnel a refusé 10000 : " + info.strip()[-180:])
        self._verify(hostname_override=hostname)

    def _verify(self, hostname_override: str = ""):
        cfg = installed_config()
        tailscale = find_tailscale()
        hostname = hostname_override or tls_hostname(tailscale)
        if status_10000(tailscale) != "ours":
            raise RuntimeError("Port public 10000 non relié à ce serveur. Clique INSTALLER ET CONNECTER.")
        if not check_local_health():
            raise RuntimeError("Serveur Node local hors ligne. Clique INSTALLER ET CONNECTER.")
        self.update_message("Vérification du véritable HTTPS MCP externe...")
        check_public_mcp(hostname, cfg["chat_token"])
        self.verified_host = hostname
        self.after(0, self.success)

    def success(self):
        self.copy_chat.config(state="normal")
        self.copy_godot.config(state="normal")
        self.set_status("CONNEXION HTTPS MCP VALIDÉE. Clique COPIER MON LIEN CHATGPT.")

    def copy_chat_url(self):
        if not self.verified_host:
            return
        cfg = installed_config()
        secret_url = f"https://{self.verified_host}:{FUNNEL_PORT}/mcp/{cfg['chat_token']}"
        self.clipboard_clear()
        self.clipboard_append(secret_url)
        self.update()
        self.set_status("Lien complet copié. Dans ChatGPT : URL du serveur, Sans authentification.")

    def copy_editor_token(self):
        cfg = installed_config()
        self.clipboard_clear()
        self.clipboard_append(cfg["editor_token"])
        self.update()
        self.set_status("Clé EDITEUR copiée. Dans Godot : dock CHK Direct (champ jeton éditeur).")


def self_test() -> int:
    for filename in ("node.exe", "server.cjs"):
        if not bundled(filename).is_file():
            return 5
    if not HEX_SECRET.fullmatch("f" * 64):
        return 6
    if FUNNEL_PORT != 10000 or LOCAL_PORT != 8791:
        return 7
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    if "--serve" in sys.argv:
        sys.exit(supervisor())
    Installer().mainloop()
