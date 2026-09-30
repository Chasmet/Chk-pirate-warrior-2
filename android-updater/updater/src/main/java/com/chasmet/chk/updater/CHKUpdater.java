package com.chasmet.chk.updater;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/** Only installs a newer APK with this application's existing certificate. */
public final class CHKUpdater extends GodotPlugin {
    private static final String REPO = "https://github.com/Chasmet/Chk-pirate-warrior-2/releases/download/";
    private static final String LATEST = "https://api.github.com/repos/Chasmet/Chk-pirate-warrior-2/releases/latest";
    private static final long MAX_APK = 2_000_000_000L;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final AtomicBoolean busy = new AtomicBoolean(false);
    private volatile String snapshot = "{\"state\":\"idle\",\"message\":\"Vérification disponible\",\"progress\":0}";
    private volatile JSONObject release;
    private volatile File readyApk;

    public CHKUpdater(Godot godot) { super(godot); }
    @NonNull @Override public String getPluginName() { return "CHKUpdater"; }
    @UsedByGodot public String getSnapshot() { return snapshot; }

    private void state(String state, String message, int progress) {
        try {
            JSONObject out = new JSONObject().put("state", state).put("message", message).put("progress", progress);
            if (release != null) out.put("version", release.optString("versionName"));
            snapshot = out.toString();
        } catch (Exception ignored) { /* JSONObject contains only safe scalar values. */ }
    }
    private Activity activity() throws IOException {
        Activity activity = getActivity();
        if (activity == null) throw new IOException("Application indisponible");
        return activity;
    }
    private static long code(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }
    private PackageInfo installed() throws Exception {
        Activity a = activity();
        return a.getPackageManager().getPackageInfo(a.getPackageName(), PackageManager.GET_SIGNATURES);
    }

    @UsedByGodot public void check() {
        if (!busy.compareAndSet(false, true)) return;
        state("checking", "Recherche de la dernière version…", 0);
        worker.execute(() -> {
            try {
                JSONObject latest = readJson(LATEST);
                if (latest.optBoolean("draft") || latest.optBoolean("prerelease")) throw new IOException("Version non publiée");
                JSONArray assets = latest.getJSONArray("assets");
                String manifestUrl = "";
                for (int i = 0; i < assets.length(); i++) {
                    JSONObject asset = assets.getJSONObject(i);
                    if ("update.json".equals(asset.optString("name"))) manifestUrl = asset.getString("browser_download_url");
                }
                if (manifestUrl.isEmpty()) {
                    release = null;
                    state("current", "Aucune mise à jour compatible publiée pour le moment.", 0);
                    return;
                }
                requireReleaseUrl(manifestUrl);
                JSONObject metadata = readJson(manifestUrl);
                PackageInfo current = installed();
                if (!current.packageName.equals(metadata.getString("packageName"))) throw new IOException("Identifiant d'application incorrect");
                if (metadata.getLong("versionCode") <= code(current)) {
                    release = null;
                    state("current", "Le jeu est à jour.", 100);
                    return;
                }
                String apkUrl = metadata.getString("apkUrl");
                requireReleaseUrl(apkUrl);
                long size = metadata.getLong("size");
                if (size <= 0 || size > MAX_APK || !metadata.getString("sha256").matches("[0-9a-fA-F]{64}"))
                    throw new IOException("Métadonnées de mise à jour invalides");
                boolean matched = false;
                for (int i = 0; i < assets.length(); i++) {
                    JSONObject asset = assets.getJSONObject(i);
                    if (apkUrl.equals(asset.optString("browser_download_url")) && asset.optLong("size") == size && asset.optString("name").endsWith(".apk")) matched = true;
                }
                if (!matched) throw new IOException("APK absent de la release officielle");
                release = metadata;
                state("available", "Version " + metadata.getString("versionName") + " disponible · " + (size / 1048576) + " Mo", 0);
            } catch (Exception e) {
                state("error", "Vérification impossible : " + e.getMessage(), 0);
            } finally { busy.set(false); }
        });
    }

    @UsedByGodot public void download() {
        if (release == null || !busy.compareAndSet(false, true)) return;
        JSONObject metadata = release;
        state("downloading", "Téléchargement…", 0);
        worker.execute(() -> {
            HttpURLConnection connection = null;
            File partial = null;
            try {
                File directory = new File(activity().getCacheDir(), "chk-updates");
                if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Stockage indisponible");
                long expected = metadata.getLong("size");
                if (directory.getUsableSpace() < expected + 32 * 1048576L) throw new IOException("Espace libre insuffisant");
                partial = new File(directory, "update.part");
                connection = connect(metadata.getString("apkUrl"));
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                long bytes = 0;
                int lastProgress = -1;
                try (InputStream in = connection.getInputStream(); FileOutputStream out = new FileOutputStream(partial)) {
                    byte[] buffer = new byte[65536];
                    int read;
                    while ((read = in.read(buffer)) != -1) {
                        if (Thread.currentThread().isInterrupted()) throw new IOException("Téléchargement interrompu");
                        bytes += read;
                        if (bytes > expected) throw new IOException("Taille de fichier incorrecte");
                        out.write(buffer, 0, read);
                        digest.update(buffer, 0, read);
                        int progress = (int) (bytes * 100 / expected);
                        if (progress != lastProgress) {
                            lastProgress = progress;
                            state("downloading", "Téléchargement " + progress + " %", progress);
                        }
                    }
                    out.getFD().sync();
                }
                if (bytes != expected || !hex(digest.digest()).equalsIgnoreCase(metadata.getString("sha256")))
                    throw new IOException("Téléchargement incomplet ou fichier altéré. Réessaie.");
                verifyArchive(partial, metadata.getLong("versionCode"));
                File complete = new File(directory, "update.apk");
                if (complete.exists() && !complete.delete()) throw new IOException("Ancien téléchargement verrouillé");
                if (!partial.renameTo(complete)) throw new IOException("Impossible de finaliser le téléchargement");
                readyApk = complete;
                state("ready", "APK vérifié. Prêt à installer en conservant la progression.", 100);
            } catch (Exception e) {
                if (partial != null) partial.delete();
                readyApk = null;
                state("error", "Mise à jour interrompue : " + e.getMessage(), 0);
            } finally {
                if (connection != null) connection.disconnect();
                busy.set(false);
            }
        });
    }

    private void verifyArchive(File file, long expectedCode) throws Exception {
        PackageInfo existing = installed();
        PackageInfo next = activity().getPackageManager().getPackageArchiveInfo(file.getAbsolutePath(), PackageManager.GET_SIGNATURES);
        if (next == null || !existing.packageName.equals(next.packageName) || code(next) != expectedCode || code(next) <= code(existing))
            throw new IOException("Cet APK ne met pas à jour cette application");
        if (existing.signatures == null || next.signatures == null || existing.signatures.length != next.signatures.length)
            throw new IOException("Signature Android non reconnue");
        for (int i = 0; i < existing.signatures.length; i++) {
            if (!Arrays.equals(existing.signatures[i].toByteArray(), next.signatures[i].toByteArray()))
                throw new IOException("Clé Android différente : installation bloquée pour protéger la sauvegarde");
        }
    }

    @UsedByGodot public void install() {
        if (readyApk == null || release == null || busy.get()) return;
        try {
            Activity a = activity();
            verifyArchive(readyApk, release.getLong("versionCode"));
            a.runOnUiThread(() -> {
                try {
                    if (Build.VERSION.SDK_INT >= 26 && !a.getPackageManager().canRequestPackageInstalls()) {
                        state("permission", "Autorise cette application, puis touche Installer à nouveau.", 100);
                        a.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + a.getPackageName())));
                        return;
                    }
                    Uri uri = FileProvider.getUriForFile(a, a.getPackageName()+".chkupdates", readyApk);
                    Intent intent = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive");
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    a.startActivity(intent);
                    state("ready", "Valide la mise à jour dans la fenêtre Android.", 100);
                } catch (Exception e) { state("error", "Installation impossible : " + e.getMessage(), 0); }
            });
        } catch (Exception e) { state("error", e.getMessage(), 0); }
    }

    private static void requireReleaseUrl(String value) throws IOException {
        if (!value.startsWith(REPO)) throw new IOException("Adresse de mise à jour non autorisée");
    }
    private static HttpURLConnection connect(String value) throws IOException {
        URL url = new URL(value);
        for (int redirects = 0; redirects < 6; redirects++) {
            String host = url.getHost();
            if (!"https".equals(url.getProtocol()) || !(host.equals("github.com") || host.equals("api.github.com") || host.endsWith(".githubusercontent.com")))
                throw new IOException("Adresse de téléchargement non autorisée");
            HttpURLConnection c = (HttpURLConnection) url.openConnection();
            c.setInstanceFollowRedirects(false);
            c.setConnectTimeout(15000); c.setReadTimeout(30000);
            c.setRequestProperty("User-Agent", "CHK-Pirate-Warrior-2-Updater");
            int status = c.getResponseCode();
            if (status >= 300 && status < 400) {
                String location = c.getHeaderField("Location"); c.disconnect();
                if (location == null) throw new IOException("Redirection incomplète");
                url = new URL(url, location); continue;
            }
            if (status != 200) { c.disconnect(); throw new IOException("Serveur HTTP " + status); }
            return c;
        }
        throw new IOException("Trop de redirections");
    }
    private static JSONObject readJson(String url) throws Exception {
        HttpURLConnection connection = connect(url);
        try (InputStream in = connection.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192]; int read;
            while ((read = in.read(buffer)) != -1) {
                if (out.size() + read > 2 * 1048576) throw new IOException("Réponse trop volumineuse");
                out.write(buffer, 0, read);
            }
            return new JSONObject(out.toString("UTF-8"));
        } finally { connection.disconnect(); }
    }
    private static String hex(byte[] bytes) {
        StringBuilder out = new StringBuilder();
        for (byte b : bytes) out.append(String.format(java.util.Locale.ROOT, "%02x", b & 255));
        return out.toString();
    }
    @Override public void onMainDestroy() { worker.shutdownNow(); super.onMainDestroy(); }
}
