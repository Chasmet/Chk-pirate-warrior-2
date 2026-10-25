// CHK Godot MCP - native Windows (.NET Framework 4.8) localhost dashboard.
// Build with official Windows csc.exe. No Python, PyInstaller, Render, or Supabase.
// GUI remains alive; minimized to system tray on close. HTTP panel stays on loopback.
// GitHub Actions embeds the approved Godot Node MCP JavaScript bundle as a resource.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using Microsoft.Win32;

namespace CHKGodotNative
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            if (Array.IndexOf(args, "--self-test") >= 0)
            {
                try { Dashboard.SelfTest(); Environment.Exit(0); }
                catch { Environment.Exit(1); }
                return;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Dashboard(Array.IndexOf(args, "--autorun") >= 0));
        }
    }

    sealed class Dashboard : Form
    {
        const string Version = "1.4.0";
        const int PublicHttpsPort = 443;
        const string SharedPath = "/chk-godot";
        const int PanelPort = 8792;
        const string Host = "127.0.0.1";
        const string PanelUrl = "http://127.0.0.1:8792/";
        static readonly string InstallDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CHKGodotDirectMCP");
        static readonly string ConfigPath = Path.Combine(InstallDir, "settings.json");
        static readonly string LogPath = Path.Combine(InstallDir, "native-diagnostic.log");
        readonly object gate = new object();
        readonly JavaScriptSerializer serializer = new JavaScriptSerializer();
        readonly string uiSecret = Secret(24);
        readonly bool autorun;
        readonly Label lbl;
        readonly Button btnInstall;
        readonly Button btnCopy;
        readonly NotifyIcon tray;
        TcpListener listener;
        Thread listenThread;
        Process node;
        string status = "Site local actif. Clique sur INSTALLER ET CONNECTER.";
        string hostname = "";
        string publicPrefix = "";
        bool busy = false;
        bool publicOk = false;
        bool exiting = false;
        bool localOk = false;

        internal Dashboard(bool startHidden)
        {
            autorun = startHidden;
            Text = "CHK Godot — Serveur personnel v" + Version;
            Icon = SystemIcons.Application;
            Size = new Size(590, 400);
            MinimumSize = new Size(535, 360);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(12, 20, 35);
            ForeColor = Color.White;
            Font = new Font("Segoe UI", 10F);
            lbl = new Label {
                Text = "CHARGEMENT DU SERVEUR LOCAL...", AutoSize = false, Left = 24,
                Top = 65, Width = 520, Height = 85, ForeColor = Color.LightSkyBlue
            };
            var heading = new Label {
                Text = "CHK GODOT DIRECT MCP", Left = 24, Top = 20,
                Width = 520, Height = 35, Font = new Font("Segoe UI", 17, FontStyle.Bold)
            };
            btnInstall = MakeButton("INSTALLER ET CONNECTER", 160, delegate { StartInstall(); });
            var btnWeb = MakeButton("OUVRIR LE SITE LOCAL", 205, delegate { OpenWeb(); });
            btnCopy = MakeButton("COPIER MON LIEN CHATGPT", 250, delegate { CopyChat(); });
            var btnSite = MakeButton("COPIER L'ADRESSE DU SITE LOCAL", 295, delegate { CopyLocalSite(); });
            Controls.Add(heading); Controls.Add(lbl);
            Controls.Add(btnInstall); Controls.Add(btnWeb); Controls.Add(btnCopy); Controls.Add(btnSite);
            tray = new NotifyIcon {
                Icon = SystemIcons.Application, Visible = true,
                Text = "CHK Godot MCP - PC personnel"
            };
            var menu = new ContextMenuStrip();
            menu.Items.Add("Ouvrir CHK Godot", null, delegate { ShowPanel(); });
            menu.Items.Add("Ouvrir le site local", null, delegate { OpenWeb(); });
            menu.Items.Add("Quitter complètement", null, delegate {
                exiting = true; tray.Visible = false; Application.Exit();
            });
            tray.ContextMenuStrip = menu;
            tray.DoubleClick += delegate { ShowPanel(); };
            FormClosing += OnClosing;
            Shown += delegate {
                try {
                    StartLocalPanel();
                    if (!autorun) OpenWeb();
                    else {
                        Hide();
                        ShowInTaskbar = false;
                        ThreadPool.QueueUserWorkItem(delegate { RecoverNode(); });
                    }
                } catch (Exception e) { Fail("Le serveur web ne démarre pas : " + e.Message, e); }
            };
        }

        Button MakeButton(string text, int top, EventHandler handler)
        {
            var b = new Button { Text = text, Left = 24, Top = top,
                                 Height = 39, Width = 520, BackColor = Color.LightSkyBlue,
                                 ForeColor = Color.Black, FlatStyle = FlatStyle.Flat };
            b.Click += handler;
            return b;
        }
        void OnClosing(object sender, FormClosingEventArgs e)
        {
            if (!exiting && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
                tray.ShowBalloonTip(1500, "CHK Godot", "Le serveur continue en arrière-plan.",
                                    ToolTipIcon.Info);
            }
            else {
                try { if (listener != null) listener.Stop(); } catch {}
                tray.Visible = false;
            }
        }
        void ShowPanel()
        {
            if (InvokeRequired) { BeginInvoke((Action)ShowPanel); return; }
            Show(); WindowState = FormWindowState.Normal; ShowInTaskbar = true;
            Activate();
        }
        /// <summary>
        /// Windows may return REGDB_E_CLASSNOTREG (0x80040154) when the HTTP
        /// URL file association is broken even though Chrome is installed.
        /// Launch known installed browsers by absolute exe path FIRST,
        /// without Windows URL/protocol COM associations.
        /// </summary>
        static IEnumerable<string> BrowserExecutables()
        {
            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (!String.IsNullOrEmpty(pf))
            {
                yield return Path.Combine(pf, "Google", "Chrome", "Application", "chrome.exe");
                yield return Path.Combine(pf, "Microsoft", "Edge", "Application", "msedge.exe");
                yield return Path.Combine(pf, "Mozilla Firefox", "firefox.exe");
            }
            if (!String.IsNullOrEmpty(pf86))
            {
                yield return Path.Combine(pf86, "Google", "Chrome", "Application", "chrome.exe");
                yield return Path.Combine(pf86, "Microsoft", "Edge", "Application", "msedge.exe");
                yield return Path.Combine(pf86, "Mozilla Firefox", "firefox.exe");
            }
            if (!String.IsNullOrEmpty(local))
                yield return Path.Combine(local, "Google", "Chrome", "Application", "chrome.exe");
        }
        void CopyLocalSite()
        {
            try
            {
                Clipboard.SetText(PanelUrl);
                Message("Adresse du site copiée. Ouvre Chrome et colle : " + PanelUrl);
            }
            catch (Exception ex)
            {
                Log(ex);
                Message("Adresse du site à saisir dans Chrome : " + PanelUrl);
            }
        }
        void OpenWeb()
        {
            // Unlike Process.Start(PanelUrl), this does not depend on
            // the damaged URL handler that the user's Windows reports.
            foreach (var browser in BrowserExecutables())
            {
                if (!File.Exists(browser)) continue;
                try
                {
                    Process.Start(new ProcessStartInfo(browser, "\"" + PanelUrl + "\"")
                    {
                        UseShellExecute = false,
                        CreateNoWindow = false
                    });
                    Message("Navigateur ouvert. Site local : " + PanelUrl);
                    return;
                }
                catch (Exception ex) { Log(ex); }
            }
            // ShellExecute is ONLY a secondary fallback, never the default.
            try
            {
                Process.Start(new ProcessStartInfo(PanelUrl) { UseShellExecute = true });
                Message("Navigateur ouvert. Site local : " + PanelUrl);
                return;
            }
            catch (Exception ex)
            {
                Log(ex);
                // A broken Windows browser association must NOT mark the
                // MCP as failed, rotate keys or close the panel.
                ShowPanel();
                Message("Le site est actif mais Windows ne lance pas Chrome automatiquement. "
                      + "Ouvre Chrome toi-même et colle : " + PanelUrl
                      + "  (bouton COPIER L'ADRESSE DU SITE LOCAL).");
            }
        }
        void Message(string msg)
        {
            lock(gate) { status = msg; }
            try {
                if (!IsDisposed && IsHandleCreated)
                    BeginInvoke((Action)delegate { lbl.Text = msg; });
            } catch { }
        }
        void Fail(string msg, Exception e)
        {
            Log(e);
            lock(gate) { status = "ERREUR : " + msg; busy = false; publicOk = false; }
            Message("ERREUR : " + msg);
            try {
                if (!IsDisposed && IsHandleCreated) BeginInvoke((Action)delegate {
                    ShowPanel();
                    MessageBox.Show(this, msg + "\n\nRapport : " + LogPath,
                        "CHK Godot — erreur visible", MessageBoxButtons.OK, MessageBoxIcon.Error);
                });
            } catch {}
        }
        static void Log(Exception e)
        {
            try {
                Directory.CreateDirectory(InstallDir);
                var text = Regex.Replace(e.ToString(),
                    @"\b[0-9a-fA-F]{64}\b", "[CLE MASQUEE]");
                File.AppendAllText(LogPath,
                    DateTime.Now.ToString("s") + " | " + text + Environment.NewLine);
            } catch {}
        }

        static string Secret(int length)
        {
            byte[] data = new byte[length];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(data);
            return BitConverter.ToString(data).Replace("-", "").ToLowerInvariant();
        }
        Dictionary<string, object> Config()
        {
            Directory.CreateDirectory(InstallDir);
            if (File.Exists(ConfigPath))
            {
                var old = serializer.DeserializeObject(File.ReadAllText(ConfigPath, Encoding.UTF8))
                              as Dictionary<string, object>;
                if (old == null || !old.ContainsKey("chat_token") || !old.ContainsKey("editor_token"))
                    throw new Exception("Anciennes clés invalides, conservées sans les écraser.");
                if (!Regex.IsMatch(Convert.ToString(old["chat_token"]), "^[a-f0-9]{64}$") ||
                    !Regex.IsMatch(Convert.ToString(old["editor_token"]), "^[a-f0-9]{64}$"))
                    throw new Exception("Clés invalides. Aucune suppression effectuée.");
                return old;
            }
            var config = new Dictionary<string, object>();
            config["schema"] = 1;
            config["chat_token"] = Secret(32);
            config["editor_token"] = Secret(32);
            config["local_port"] = 8791;
            config["funnel_port"] = PublicHttpsPort;
            using (var fs = new FileStream(ConfigPath, FileMode.CreateNew, FileAccess.Write))
            using (var writer = new StreamWriter(fs, new UTF8Encoding(false)))
                writer.Write(serializer.Serialize(config));
            return config;
        }
        static string GetTool(string filename)
        {
            string path = Environment.GetEnvironmentVariable("ProgramFiles");
            var attempts = new [] {
                Path.Combine(path ?? @"C:\Program Files", "Tailscale", filename),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Tailscale", filename),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Tailscale", filename)
            };
            foreach(var candidate in attempts) if (File.Exists(candidate)) return candidate;
            throw new Exception("Tailscale n'est pas trouvé. Ouvre Tailscale sur ton PC.");
        }
        static string Run(string program, string arguments, int timeoutSeconds)
        {
            var psi = new ProcessStartInfo(program, arguments) {
                UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            using(var p = Process.Start(psi))
            {
                // Both stdout and stderr are consumed asynchronously to avoid a full-pipe deadlock.
                var output = new StringBuilder();
                var error = new StringBuilder();
                p.OutputDataReceived += delegate(object a, DataReceivedEventArgs e) {
                    if (e.Data != null) lock(output) output.AppendLine(e.Data);
                };
                p.ErrorDataReceived += delegate(object a, DataReceivedEventArgs e) {
                    if (e.Data != null) lock(error) error.AppendLine(e.Data);
                };
                p.BeginOutputReadLine(); p.BeginErrorReadLine();
                if (!p.WaitForExit(timeoutSeconds * 1000)) {
                    try { p.Kill(); } catch {}
                    throw new Exception("Tailscale ne répond pas (" + timeoutSeconds + " secondes).");
                }
                p.WaitForExit();
                var detail = output.ToString() + "\n" + error.ToString();
                if (p.ExitCode != 0) throw new Exception("Commande Tailscale refusée : " + detail.Trim().Substring(0, Math.Min(detail.Trim().Length, 340)));
                return detail;
            }
        }
        string TailscaleName(string tailscale)
        {
            string data = Run(tailscale, "status --json", 20);
            var match = Regex.Match(data, "\"DNSName\"\\s*:\\s*\"([a-zA-Z0-9.-]+\\.ts\\.net)\\.?\"");
            if (!match.Success) throw new Exception("Tailscale est déconnecté ou MagicDNS est indisponible.");
            return match.Groups[1].Value.ToLowerInvariant();
        }
        // Inspect the existing Tailscale HTTPS 443 routes before any write.
        // Serve private paths must never become public just to enable Godot.
        static Dictionary<string, object> Map(object item)
        {
            return item as Dictionary<string, object> ??
                   new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        }
        static bool IsGodotProxy(object item)
        {
            var handler = Map(item);
            object target;
            if (!handler.TryGetValue("Proxy", out target)) return false;
            string url = Convert.ToString(target).TrimEnd('/');
            return url == "http://127.0.0.1:8791" ||
                   url == "http://localhost:8791";
        }
        internal static string Port443Mode(string json)
        {
            // Unknown/ambiguous config must fail closed, not replace services.
            if (String.IsNullOrWhiteSpace(json))
                throw new Exception("Statut Tailscale 443 vide : aucune route modifiée.");
            string normalized = json.Trim();
            // New Tailscale accounts can report an empty JSON config.
            if (normalized == "{}" || normalized == "null") return "empty";
            var root = Map(new JavaScriptSerializer().DeserializeObject(json));
            if (root.Count == 0)
                throw new Exception("Statut Tailscale 443 inconnu, configuration intacte.");
            var tcp = Map(root.ContainsKey("TCP") ? root["TCP"] : null);
            bool hasWebHttps = false;
            object tcpRule;
            if (tcp.TryGetValue("443", out tcpRule))
            {
                var rule = Map(tcpRule);
                object https;
                if (!rule.TryGetValue("HTTPS", out https) ||
                    !(https is bool) || !(bool)https)
                    return "occupied"; // TCP forwarding or an unknown binding
                hasWebHttps = true; // Normal Tailscale HTTPS Web 443 marker
            }
            var web = Map(root.ContainsKey("Web") ? root["Web"] : null);
            var allow = Map(root.ContainsKey("AllowFunnel") ? root["AllowFunnel"] : null);
            foreach (var entry in web)
            {
                if (!entry.Key.EndsWith(":443", StringComparison.OrdinalIgnoreCase)) continue;
                object val;
                if (!allow.TryGetValue(entry.Key, out val) || !(val is bool) || !(bool)val)
                    return "private";
                var webconfig = Map(entry.Value);
                var handlers = Map(webconfig.ContainsKey("Handlers") ?
                                   webconfig["Handlers"] : null);
                object rootHandler;
                object sharedHandler;
                if (handlers.TryGetValue("/", out rootHandler) && IsGodotProxy(rootHandler))
                    return "ours_root";
                if ((handlers.TryGetValue(SharedPath+"/", out sharedHandler) ||
                     handlers.TryGetValue(SharedPath, out sharedHandler)) &&
                     IsGodotProxy(sharedHandler))
                    return "ours_path";
                if (handlers.ContainsKey(SharedPath) || handlers.ContainsKey(SharedPath+"/"))
                    return "occupied";
                return "shared_public";
            }
            return hasWebHttps ? "occupied" : "empty";
        }
        string FunnelState(string tailscale)
        {
            string json;
            try { json = Run(tailscale, "funnel status --json", 15); }
            catch (Exception ex)
            {
                throw new Exception("Statut JSON HTTPS 443 Tailscale indisponible. "
                  + "Aucune ancienne route n'a été modifiée.", ex);
            }
            return Port443Mode(json);
        }
        static bool LocalNodeOk()
        {
            try {
                var request = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:8791/health");
                request.Timeout = 1500;
                using (var response = request.GetResponse())
                using (var reader = new StreamReader(response.GetResponseStream()))
                    return reader.ReadToEnd().Contains("\"ok\":true");
            } catch { return false; }
        }
        void RecoverNode()
        {
            try {
                var file = Path.Combine(InstallDir, "native-v1.4.0", "node.exe");
                var script = Path.Combine(InstallDir, "native-v1.4.0", "server.cjs");
                if (File.Exists(file) && File.Exists(script) && File.Exists(ConfigPath))
                    LaunchNode(Config(), file, script);
            } catch(Exception e) { Log(e); }
        }
        void InstallNode()
        {
            var root = Path.Combine(InstallDir, "native-v1.4.0");
            Directory.CreateDirectory(root);
            var nodeExe = Path.Combine(root, "node.exe");
            if (!File.Exists(nodeExe))
            {
                Message("Téléchargement sécurisé de Node.js officiel sur ce PC...");
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
                string host = "https://nodejs.org/dist/v22.16.0/";
                string zipName = "node-v22.16.0-win-x64.zip";
                var shaText = Path.Combine(root, "SHA256.txt");
                var archive = Path.Combine(root, "node.zip");
                using(var web = new WebClient()) {
                    web.DownloadFile(host + "SHASUMS256.txt", shaText);
                    web.DownloadFile(host + zipName, archive);
                }
                var manifest = File.ReadAllLines(shaText);
                string wanted = null;
                foreach (var line in manifest)
                    if (line.Trim().EndsWith(zipName, StringComparison.OrdinalIgnoreCase))
                        wanted = line.Trim().Substring(0, 64).ToLowerInvariant();
                if (wanted == null) throw new Exception("Somme SHA256 officielle Node introuvable.");
                string actual;
                using(var fs = File.OpenRead(archive))
                using(var sha = SHA256.Create())
                    actual = BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "").ToLowerInvariant();
                if (actual != wanted)
                    throw new Exception("Archive Node incorrecte : SHA256 différent. Installation arrêtée.");
                using(var z = ZipFile.OpenRead(archive))
                {
                    ZipArchiveEntry entry = null;
                    foreach(var item in z.Entries)
                        if (item.FullName.Replace("\\", "/").EndsWith("/node.exe", StringComparison.OrdinalIgnoreCase))
                            { entry = item; break; }
                    if (entry == null) throw new Exception("Node.exe n'existe pas dans le ZIP officiel.");
                    var temp = nodeExe + ".tmp";
                    if (File.Exists(temp)) File.Delete(temp);
                    entry.ExtractToFile(temp, true);
                    File.Move(temp, nodeExe);
                }
                try { File.Delete(archive); } catch {}
            }
            string target = Path.Combine(root, "server.cjs");
            if (!File.Exists(target))
            {
                using (var embedded = Assembly.GetExecutingAssembly().GetManifestResourceStream("chk.server"))
                {
                    if (embedded == null) throw new Exception("Pack incomplet : ressources MCP absentes.");
                    using (var destination = new FileStream(target, FileMode.CreateNew))
                        embedded.CopyTo(destination);
                }
            }
            Message("Serveur MCP prêt. Lancement sur le PC...");
            LaunchNode(Config(), nodeExe, target);
        }
        void LaunchNode(Dictionary<string, object> cfg, string nodeExe, string script)
        {
            if (LocalNodeOk()) { localOk = true; return; }
            var psi = new ProcessStartInfo(nodeExe, "\"" + script + "\"") {
                UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = Path.GetDirectoryName(script),
                WindowStyle = ProcessWindowStyle.Hidden
            };
            psi.EnvironmentVariables["HOST"] = "127.0.0.1";
            psi.EnvironmentVariables["PORT"] = "8791";
            psi.EnvironmentVariables["CHK_GODOT_MCP_TOKEN"] = Convert.ToString(cfg["chat_token"]);
            psi.EnvironmentVariables["CHK_GODOT_EDITOR_TOKEN"] = Convert.ToString(cfg["editor_token"]);
            psi.EnvironmentVariables["CHK_NODE_PACKAGED"] = "true";
            node = Process.Start(psi);
            for (int i=0; i<45; i++) {
                if (LocalNodeOk()) { localOk = true; return; }
                if (node.HasExited) throw new Exception("Node MCP s'est arrêté (code " + node.ExitCode + ").");
                Thread.Sleep(350);
            }
            throw new Exception("Le moteur MCP ne répond pas sur le port local 8791.");
        }
        void VerifyPublic(string name, string prefix, Dictionary<string, object> cfg)
        {
            var url = "https://" + name + prefix + "/mcp/" + Convert.ToString(cfg["chat_token"]);
            var data = Encoding.UTF8.GetBytes("{\"jsonrpc\":\"2.0\",\"id\":33,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"CHK-Godot-Native\",\"version\":\"1.4.0\"}}}");
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            var req = (HttpWebRequest)WebRequest.Create(url);
            req.Method = "POST"; req.ContentType = "application/json";
            req.Timeout = 16000; req.ReadWriteTimeout = 16000; req.ContentLength = data.Length;
            using(var stream = req.GetRequestStream()) stream.Write(data,0,data.Length);
            using(var res = req.GetResponse())
            using(var reader = new StreamReader(res.GetResponseStream())) {
                var answer = reader.ReadToEnd();
                if (!answer.Contains("CHK Godot Direct MCP") || !answer.Contains("\"id\":33"))
                    throw new Exception("Le serveur HTTPS ne répond pas comme un MCP valide.");
            }
        }
        void StartInstall()
        {
            lock(gate) {
                if (busy) return;
                busy = true; publicOk = false;
                status = "Installation sur ton PC...";
            }
            ThreadPool.QueueUserWorkItem(delegate {
                try {
                    Message("Contrôle de Tailscale...");
                    string tailscale = GetTool("tailscale.exe");
                    string name = TailscaleName(tailscale);
                    string current = FunnelState(tailscale);
                    if (current == "private")
                        throw new Exception("HTTPS 443 contient un service Tailscale privé. "
                          + "Impossible de le rendre public sans exposer d'autres routes : "
                          + "aucun service existant modifié.");
                    if (current == "occupied")
                        throw new Exception("HTTPS 443 est occupé par une autre configuration "
                          + "(TCP ou chemin Godot). Aucun service existant modifié.");
                    string prefix = (current == "shared_public" || current == "ours_path")
                                  ? SharedPath : "";
                    var cfg = Config(); // old credentials preserved
                    InstallNode();
                    Message("Activation de HTTPS 443 via Tailscale Funnel...");
                    if (current == "empty")
                    {
                        Run(tailscale, "funnel --bg --yes --https=443 http://127.0.0.1:8791", 50);
                    }
                    else if (current == "shared_public")
                    {
                        // Port 443 already PUBLIC: add /chk-godot safely without
                        // changing the existing public root application.
                        Run(tailscale,
                            "funnel --bg --yes --https=443 --set-path=/chk-godot http://127.0.0.1:8791",
                            50);
                    }
                    string after = FunnelState(tailscale);
                    if (after != (prefix == "" ? "ours_root" : "ours_path"))
                        throw new Exception("HTTPS 443 n'est pas confirmé pour Godot. "
                          + "Contrôle Tailscale nécessaire, aucune route remise à zéro.");
                    Message("Vérification du certificat HTTPS 443 et du vrai protocole MCP...");
                    VerifyPublic(name, prefix, cfg);
                    hostname = name;
                    publicPrefix = prefix;
                    lock(gate) { busy = false; publicOk = true; }
                    Message("CONNEXION VALIDÉE. Copie le lien MCP dans ChatGPT.");
                    SaveAutostart();
                } catch(Exception ex) {
                    Fail(ex.Message, ex);
                }
            });
        }
        void SaveAutostart()
        {
            try {
                string file = Assembly.GetExecutingAssembly().Location;
                // Avoid overwriting an EXE that Windows has already locked.
                var dir = Path.Combine(InstallDir,"native-v1.4.0");
                Directory.CreateDirectory(dir);
                var dest = Path.Combine(dir, "CHK-Godot-Natif.exe");
                if (!File.Exists(dest)) File.Copy(file,dest);
                using(var reg = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
                    reg.SetValue("CHKGodotDirectMCP", "\"" + dest + "\" --autorun",RegistryValueKind.String);
            } catch(Exception e) { Log(e); }
        }
        void CopyChat()
        {
            lock(gate) {
                if (!publicOk) { Message("Lien indisponible : installe puis vérifie le HTTPS."); return; }
            }
            try {
                var cfg = Config();
                Clipboard.SetText("https://" + hostname + publicPrefix + "/mcp/" + Convert.ToString(cfg["chat_token"]));
                Message("Lien ChatGPT copié dans le presse-papiers Windows.");
            } catch(Exception e){ Fail("Copie impossible : " + e.Message, e); }
        }
        void StartLocalPanel()
        {
            listener = new TcpListener(IPAddress.Loopback, PanelPort);
            listener.Start(8);
            listenThread = new Thread(ServeLoop) { IsBackground=true,Name="CHK Godot localhost" };
            listenThread.Start();
            Message("Site local actif : " + PanelUrl);
        }
        void ServeLoop()
        {
            while (!exiting) {
                try {
                    var socket = listener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(delegate { Respond(socket); });
                }
                catch(SocketException e) { if (!exiting) Log(e); break; }
                catch(ObjectDisposedException) { break; }
                catch(Exception e) { Log(e); Thread.Sleep(400); }
            }
        }
        static string HeaderValue(Dictionary<string,string> headers,string key)
        {
            string value;return headers.TryGetValue(key,out value)?value:"";
        }
        void Respond(TcpClient socket)
        {
            using(socket)
            {
                try {
                    socket.ReceiveTimeout=4000;socket.SendTimeout=4000;
                    var stream=socket.GetStream();
                    var reader=new StreamReader(stream,new UTF8Encoding(false),false,4096,true);
                    var line=reader.ReadLine();
                    if (line==null || line.Length>1800) return;
                    var parts=line.Split(' ');
                    if(parts.Length<2)return;
                    string verb=parts[0],route=parts[1].Split('?')[0];
                    var h=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
                    string head;int count=0;
                    while((head=reader.ReadLine())!=null && head.Length>0) {
                        count+=head.Length; if (count>16000) return;
                        int at=head.IndexOf(':');
                        if(at>0)h[head.Substring(0,at).Trim()]=head.Substring(at+1).Trim();
                    }
                    string browserHost=HeaderValue(h,"Host");
                    if(browserHost!="127.0.0.1:8792" && browserHost!="localhost:8792") {
                        Reply(stream,403,"application/json","{\"error\":\"Host local requis\"}");return;
                    }
                    if(verb=="GET" && route=="/") {
                        Reply(stream,200,"text/html; charset=utf-8",WebPage().Replace("__UI_TOKEN__",uiSecret));return;
                    }
                    if(verb=="GET" && route=="/api/health") {
                        Reply(stream,200,"application/json","{\"name\":\"CHK Godot Native\",\"version\":\"1.4.0\"}");return;
                    }
                    if(verb=="GET" && route=="/api/status") {
                        bool running,publicReady;string msg;
                        lock(gate){running=busy;publicReady=publicOk;msg=status;}
                        Reply(stream,200,"application/json",serializer.Serialize(new {
                            message=msg,busy=running,public_ok=publicReady,
                            local_ok=LocalNodeOk(),configured=File.Exists(ConfigPath),
                            version=Version
                        }));return;
                    }
                    if(verb!="POST") { Reply(stream,404,"application/json","{\"error\":\"Not Found\"}");return; }
                    string origin=HeaderValue(h,"Origin");
                    if(origin!="" && origin!="http://127.0.0.1:8792" && origin!="http://localhost:8792") {
                        Reply(stream,403,"application/json","{\"error\":\"Origine refusée\"}");return;
                    }
                    if(HeaderValue(h,"X-CHK-UI")!=uiSecret) {
                        Reply(stream,403,"application/json","{\"error\":\"Jeton local incorrect\"}");return;
                    }
                    if(route=="/api/install") {
                        StartInstall();
                        Reply(stream,200,"application/json","{\"ok\":true}");return;
                    }
                    if(route=="/api/diagnostic") {
                        var report=File.Exists(LogPath)?File.ReadAllText(LogPath):"Aucun diagnostic.";
                        if(report.Length>10000)report=report.Substring(report.Length-10000);
                        report=Regex.Replace(report,@"\b[a-f0-9]{64}\b","[CLE MASQUEE]",RegexOptions.IgnoreCase);
                        Reply(stream,200,"application/json",serializer.Serialize(new{report=report}));return;
                    }
                    if(route=="/api/copy-chat" || route=="/api/copy-editor" || route=="/api/copy-godot_url") {
                        bool publicReady;string name;
                        lock(gate){publicReady=publicOk;name=hostname;}
                        if(route!="/api/copy-editor" && !publicReady) {
                            Reply(stream,409,"application/json","{\"error\":\"Acces public non verifie\"}");return;
                        }
                        var cfg=Config();
                        string url=route=="/api/copy-chat"?"https://"+name+publicPrefix+"/mcp/"+cfg["chat_token"]:
                                  route=="/api/copy-editor"?Convert.ToString(cfg["editor_token"]):
                                  "https://"+name+publicPrefix;
                        Reply(stream,200,"application/json",serializer.Serialize(new{value=url}));return;
                    }
                    Reply(stream,404,"application/json","{\"error\":\"Commande inconnue\"}");
                } catch(Exception e) { Log(e); }
            }
        }
        static void Reply(NetworkStream stream,int code,string mime,string value)
        {
            var bytes=Encoding.UTF8.GetBytes(value);
            string reason=code==200?"OK":code==403?"Forbidden":code==409?"Conflict":"Not Found";
            string head="HTTP/1.1 "+code+" "+reason+"\r\nContent-Type: "+mime+
                        "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n"+
                        "X-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\n"+
                        "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'\r\n"+
                        "Connection: close\r\nContent-Length: "+bytes.Length+"\r\n\r\n";
            var h=Encoding.ASCII.GetBytes(head);
            stream.Write(h,0,h.Length);stream.Write(bytes,0,bytes.Length);stream.Flush();
        }
        string WebPage()
        {
            using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("chk.web"))
            {
                if(stream==null)throw new Exception("Ressource de page web manquante.");
                using(var reader=new StreamReader(stream,Encoding.UTF8))
                    return reader.ReadToEnd();
            }
        }
        internal static void SelfTest()
        {
            if(PanelPort!=8792 || Version!="1.4.0") throw new Exception("Version invalide");
            if(String.IsNullOrEmpty(Secret(32)))throw new Exception("RNG fail");
            // Regression: do not overwrite existing port 443 or expose
            // private Serve routes when attaching a Godot Funnel.
            if (Port443Mode("{}") != "empty") throw new Exception("Empty 443 config");
            if (Port443Mode("{\"TCP\":{\"443\":{\"TCPForward\":\"127.0.0.1:9000\"}}}") != "occupied")
                throw new Exception("Occupied TCP 443 must be preserved");
            const string private443 = "{\"Web\":{\"pc.example.ts.net:443\":{\"Handlers\":{\"/\":{\"Proxy\":\"http://127.0.0.1:7777\"}}}},\"AllowFunnel\":{\"pc.example.ts.net:443\":false}}";
            if (Port443Mode(private443) != "private")
                throw new Exception("Private 443 must remain private");
            const string existingPublic = "{\"Web\":{\"pc.example.ts.net:443\":{\"Handlers\":{\"/\":{\"Proxy\":\"http://127.0.0.1:7777\"}}}},\"AllowFunnel\":{\"pc.example.ts.net:443\":true}}";
            const string publicWithHttpsMarker = "{\"TCP\":{\"443\":{\"HTTPS\":true}},\"Web\":{\"pc.example.ts.net:443\":{\"Handlers\":{\"/\":{\"Proxy\":\"http://127.0.0.1:7777\"}}}},\"AllowFunnel\":{\"pc.example.ts.net:443\":true}}";
            if (Port443Mode(publicWithHttpsMarker) != "shared_public")
                throw new Exception("Ordinary Tailscale HTTPS marker misidentified as TCP collision");
            if (Port443Mode(existingPublic) != "shared_public")
                throw new Exception("Existing public root must be shared, not replaced");
            const string ownRoot = "{\"Web\":{\"pc.example.ts.net:443\":{\"Handlers\":{\"/\":{\"Proxy\":\"http://127.0.0.1:8791\"}}}},\"AllowFunnel\":{\"pc.example.ts.net:443\":true}}";
            if (Port443Mode(ownRoot) != "ours_root")
                throw new Exception("Existing Godot root should be reused");
            const string ownSubpath = "{\"Web\":{\"pc.example.ts.net:443\":{\"Handlers\":{\"/\":{\"Proxy\":\"http://127.0.0.1:7777\"},\"/chk-godot/\":{\"Proxy\":\"http://127.0.0.1:8791\"}}}},\"AllowFunnel\":{\"pc.example.ts.net:443\":true}}";
            if (Port443Mode(ownSubpath) != "ours_path")
                throw new Exception("Existing Godot subpath should be reused");
            const string otherSubpath = "{\"Web\":{\"pc.example.ts.net:443\":{\"Handlers\":{\"/chk-godot/\":{\"Proxy\":\"http://127.0.0.1:7777\"}}}},\"AllowFunnel\":{\"pc.example.ts.net:443\":true}}";
            if (Port443Mode(otherSubpath) != "occupied")
                throw new Exception("Other subpath must be preserved");
            using(var r=Assembly.GetExecutingAssembly().GetManifestResourceStream("chk.web"))
                if(r==null || r.Length<1000)throw new Exception("Ressource web absente");
            using(var r=Assembly.GetExecutingAssembly().GetManifestResourceStream("chk.server"))
                if(r==null || r.Length<5000)throw new Exception("Ressource MCP absente");
        }
    }
}
