# -*- coding: utf-8 -*-
"""CHK Godot Direct MCP - Windows one-click installer (Tkinter, no console).
No Supabase, Render, administrator privileges or new Tailscale account needed.
Never overwrites pre-existing Funnel ports or application credentials.
"""
from __future__ import annotations

import ctypes
import hashlib
import secrets
import traceback
import datetime
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
RUNTIME_FILE = INSTALL_DIR / "runtime.json"
DIAGNOSTIC_FILE = INSTALL_DIR / "diagnostic.log"
APP_VERSION = "1.0.1"
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


def sha256_file(source: Path) -> str:
    digest = hashlib.sha256()
    with open(source, "rb") as handle:
        for part in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(part)
    return digest.hexdigest()


def install_immutable(source: Path, prefix: str, extension: str) -> Path:
    """Never overwrite the running installer or node.exe, even during upgrades."""
    digest = sha256_file(source)
    destination = INSTALL_DIR / f"{prefix}-{digest[:16]}{extension}"
    if destination.is_file():
        if sha256_file(destination) != digest:
            raise RuntimeError(f"Fichier existant modifié : {destination.name}.")
        return destination
    temp = INSTALL_DIR / f".{prefix}-{secrets.token_hex(8)}.tmp"
    try:
        shutil.copyfile(source, temp)
        if sha256_file(temp) != digest:
            raise RuntimeError("Copie incomplète : contrôle SHA256 incorrect.")
        os.replace(temp, destination)
    finally:
        temp.unlink(missing_ok=True)
    return destination


def save_runtime(executable: Path, node: Path, script: Path) -> None:
    data = {"app": str(executable), "node": str(node), "script": str(script),
            "version": APP_VERSION}
    temp = INSTALL_DIR / f".runtime-{secrets.token_hex(8)}.tmp"
    try:
        temp.write_text(json.dumps(data, indent=2), encoding="utf-8")
        os.replace(temp, RUNTIME_FILE)
    finally:
        temp.unlink(missing_ok=True)


def runtime_binaries() -> tuple[Path, Path]:
    if RUNTIME_FILE.is_file():
        data = json.loads(RUNTIME_FILE.read_text(encoding="utf-8"))
        node = Path(str(data.get("node", "")))
        script = Path(str(data.get("script", "")))
        if node.is_file() and script.is_file() and node.parent == INSTALL_DIR and script.parent == INSTALL_DIR:
            return node, script
        raise RuntimeError("Installation du moteur incomplète : cliquer sur INSTALLER ET CONNECTER.")
    return INSTALL_DIR / SERVER_BINARY, INSTALL_DIR / SERVER_SCRIPT


def write_diagnostic(error: BaseException) -> None:
    try:
        INSTALL_DIR.mkdir(parents=True, exist_ok=True)
        with open(DIAGNOSTIC_FILE, "a", encoding="utf-8") as f:
            f.write("\n" + datetime.datetime.now().isoformat(timespec="seconds") + " CHK v" + APP_VERSION + "\n")
            f.write("".join(traceback.format_exception(type(error), error, error.__traceback__)))
    except Exception:
        pass


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
                    destinations = [str(handler.get("Proxy", "")).rstrip("/") for handler in handlers.values() if isinstance(handler, dict)]
                    # Tailcale versions differ: AllowFunnel may be omitted from the
                    # status JSON. Matching the exact proxy safely establishes
                    # ownership; the public HTTP MCP check establishes reachability.
                    if any(dest in (f"http://127.0.0.1:{LOCAL_PORT}",
                                    f"http://localhost:{LOCAL_PORT}") for dest in destinations):
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
        node, script = runtime_binaries()
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
        self.title("CHK GODOT — Installation automatique v" + APP_VERSION)
        self.geometry("680x525")
        self.minsize(595, 455)
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
        self.diagnostic = ttk.Button(root, text="OUVRIR LE RAPPORT DES ERREURS", style="Main.TButton", command=self.open_diagnostic)
        self.diagnostic.pack(fill="x", pady=4)
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
            write_diagnostic(exc)
            detail = str(exc).replace("\n", " ")[:300]
            self.after(0, lambda d=detail: self.show_error(d))
        finally:
            self.after(0, self.ready)

    def show_error(self, detail: str):
        self.set_status("ERREUR : " + detail + ". Rapport disponible ci-dessous.")
        messagebox.showerror("CHK Godot — erreur d'installation",
                             detail + "\n\nL'application reste ouverte. Rapport disponible dans l'application.")

    def open_diagnostic(self):
        if not DIAGNOSTIC_FILE.exists():
            messagebox.showinfo("CHK Godot", "Aucune erreur enregistrée.")
            return
        try:
            os.startfile(str(DIAGNOSTIC_FILE))
        except OSError as exc:
            messagebox.showerror("CHK Godot", str(exc))

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
        self.update_message("Installation : copie sans écraser aucun processus Windows actif...")
        installed_exe = install_immutable(Path(sys.executable), "CHK-Godot-Application", ".exe")
        node = install_immutable(bundled("node.exe"), "node", ".exe")
        script = install_immutable(bundled("server.cjs"), "godot-server", ".cjs")
        save_runtime(installed_exe, node, script)
        save_startup(installed_exe)
        self.update_message("Démarrage du nouveau serveur local...")
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
        if not check_local_health():
            raise RuntimeError("Serveur local non démarré : clique INSTALLER ET CONNECTER. Tes clés sont conservées.")
        if status_10000(tailscale) != "ours":
            raise RuntimeError("Serveur local actif, Funnel 10000 non configuré : clique INSTALLER ET CONNECTER.")
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
