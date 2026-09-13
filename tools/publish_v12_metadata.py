"""Validate the permanent Android identity before publishing release metadata.

The first V12 signature may replace only the recorded legacy release in the
channel. It is a new installation, not an in-place upgrade of the legacy APK.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPO = "https://github.com/Chasmet/Chk-pirate-warrior-2/releases/download/"
API = "https://api.github.com/repos/Chasmet/Chk-pirate-warrior-2/releases/latest"


def certificate(signer, path):
    result = subprocess.run([str(signer), "verify", "--print-certs", str(path)], check=True, capture_output=True, text=True)
    values = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)", result.stdout)
    if not values:
        raise RuntimeError("APK sans certificat Android vérifiable")
    return sorted(values)


def package_info(aapt, path):
    result = subprocess.check_output([str(aapt), "dump", "badging", str(path)], text=True)
    match = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", result)
    if not match:
        raise RuntimeError("Identité APK illisible")
    return {"packageName": match[1], "versionCode": int(match[2]), "versionName": match[3]}


def validate_transition(identity, release, asset, previous, current, old_cert, new_cert, previous_digest):
    expected = identity["certificateSha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", expected) or new_cert != [expected]:
        raise RuntimeError("PUBLICATION BLOQUÉE : la signature diffère de la clé permanente")
    if previous["packageName"] != identity["packageName"] or current["packageName"] != identity["packageName"]:
        raise RuntimeError("PUBLICATION BLOQUÉE : identifiant Android différent")
    if current["versionCode"] <= previous["versionCode"]:
        raise RuntimeError("PUBLICATION BLOQUÉE : numéro de version non croissant")
    if old_cert == new_cert:
        return "update"
    legacy = identity.get("bootstrapPredecessor", {})
    if (release.get("id") == legacy.get("releaseId")
            and release.get("tag_name") == legacy.get("tag")
            and asset.get("id") == legacy.get("assetId")
            and previous_digest == legacy.get("apkSha256")):
        return "new_install"
    raise RuntimeError("PUBLICATION BLOQUÉE : certificat précédent incompatible avec la référence autorisée")


def main():
    artifact = ROOT / "artifact"
    apk = artifact / "CHK_Pirate_Warrior_2.apk"
    tools = Path(os.environ["ANDROID_HOME"]) / "build-tools/36.1.0"
    identity = json.loads((ROOT / "android-signing/identity.json").read_text())
    new_cert = certificate(tools / "apksigner", apk)
    request = urllib.request.Request(API, headers={"User-Agent": "CHK-APK-CI"})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    prior = next((a for a in release.get("assets", []) if a["name"].lower().endswith(".apk")), None)
    if prior is None:
        raise RuntimeError("Aucun APK précédent pour vérifier le circuit de publication")
    url = prior["browser_download_url"]
    if not url.startswith(REPO):
        raise RuntimeError("Adresse d'APK précédent inattendue")
    previous_apk = artifact / "previous-release.apk"
    try:
        subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "300", url, "--output", str(previous_apk)], check=True)
        previous = package_info(tools / "aapt", previous_apk)
        current = package_info(tools / "aapt", apk)
        with previous_apk.open("rb") as stream:
            previous_digest = hashlib.file_digest(stream, "sha256").hexdigest()
        mode = validate_transition(identity, release, prior, previous, current,
                                   certificate(tools / "apksigner", previous_apk), new_cert, previous_digest)
    finally:
        previous_apk.unlink(missing_ok=True)
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    tag = "v" + current["versionName"]
    metadata = {"schema": 1, **current, "size": apk.stat().st_size, "sha256": digest,
                "apkUrl": f"{REPO}{tag}/{apk.name}", "signingCertificateSha256": new_cert[0], "installationMode": mode}
    (artifact / "update.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (artifact / "SHA256.txt").write_text(f"{digest}  {apk.name}\n")
    (artifact / "SIGNATURE.txt").write_text("Certificat permanent SHA-256 : " + new_cert[0] + "\nMode : " + mode + "\n")
    notes = (ROOT / "docs/RELEASE_V12.md").read_text()
    if mode == "new_install":
        notes = ("Première version V12 signée avec la nouvelle clé permanente. Elle ne remplace pas directement les anciennes versions signées avec une clé perdue. Désinstaller une ancienne version efface ses sauvegardes locales. Les prochaines V12 utiliseront cette même clé.\n\n" + notes)
    (artifact / "RELEASE_NOTES.md").write_text(notes)
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"tag={tag}\ninstallation_mode={mode}\n")
    print("Signature permanente, package et version vérifiés. Mode : " + mode)


if __name__ == "__main__":
    main()
