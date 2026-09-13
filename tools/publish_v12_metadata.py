"""Check the installed release identity before allowing an APK publication.

No key creation, no identity changes, no substitution of another signing key.
Called only after apksigner has signed the new Gradle-built APK.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifact"
APK = ARTIFACT / "CHK_Pirate_Warrior_2.apk"
API = "https://api.github.com/repos/Chasmet/Chk-pirate-warrior-2/releases/latest"
SIGNER = Path(os.environ["ANDROID_HOME"]) / "build-tools/36.1.0/apksigner"
AAPT = SIGNER.parent / "aapt"


def certificate(path):
    result = subprocess.run([str(SIGNER), "verify", "--print-certs", str(path)], check=True, capture_output=True, text=True)
    values = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)", result.stdout)
    if not values:
        raise RuntimeError("APK sans certificat Android vérifiable")
    return sorted(values)


new_cert = certificate(APK)
request = urllib.request.Request(API, headers={"User-Agent": "CHK-APK-CI"})
with urllib.request.urlopen(request, timeout=30) as response:
    release = json.load(response)
prior = next((a for a in release.get("assets", []) if a["name"].lower().endswith(".apk")), None)
if prior is None:
    raise RuntimeError("Aucun APK précédent pour vérifier la continuité de signature")
url = prior["browser_download_url"]
if not url.startswith("https://github.com/Chasmet/Chk-pirate-warrior-2/releases/download/"):
    raise RuntimeError("Adresse d'APK précédent inattendue")
previous = ARTIFACT / "previous-release.apk"
subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "300", url, "--output", str(previous)], check=True)
try:
    if certificate(previous) != new_cert:
        raise RuntimeError("PUBLICATION BLOQUÉE : la clé diffère de celle de la dernière release. Aucune mise à jour incompatible publiée.")
    previous_info = subprocess.check_output([str(AAPT), "dump", "badging", str(previous)], text=True)
    current_info = subprocess.check_output([str(AAPT), "dump", "badging", str(APK)], text=True)
    pattern = r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'"
    old = re.search(pattern, previous_info)
    new = re.search(pattern, current_info)
    if not old or not new or old[1] != new[1] or int(new[2]) <= int(old[2]):
        raise RuntimeError("Identité ou numéro de version incompatible avec l'APK précédent")
finally:
    previous.unlink(missing_ok=True)
digest = hashlib.file_digest(APK.open("rb"), "sha256").hexdigest()
tag = "v" + new[3]
metadata = {"schema": 1, "packageName": new[1], "versionCode": int(new[2]), "versionName": new[3],
    "size": APK.stat().st_size, "sha256": digest,
    "apkUrl": f"https://github.com/Chasmet/Chk-pirate-warrior-2/releases/download/{tag}/{APK.name}"}
(ARTIFACT / "update.json").write_text(json.dumps(metadata, indent=2)+"\n")
(ARTIFACT / "SHA256.txt").write_text(f"{digest}  {APK.name}\n")
with open(os.environ["GITHUB_OUTPUT"], "a") as output:
    output.write(f"tag={tag}\n")
print("Signature, package et version compatibles avec la release précédente.")
