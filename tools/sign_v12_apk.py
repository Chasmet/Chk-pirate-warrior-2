"""Sign with the permanent private key; never persist it in Git or artifacts."""
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def output(name, value):
    destination = os.environ.get("GITHUB_OUTPUT")
    if destination:
        with open(destination, "a") as stream:
            stream.write(f"{name}={value}\n")


def main():
    raw = os.environ.get("CHK_SIGNING_BUNDLE", "")
    if not raw:
        output("available", "false")
        print("Signature prête : la configuration privée CHK_ANDROID_SIGNING doit être enregistrée une seule fois.")
        return
    identity = json.loads((ROOT / "android-signing/identity.json").read_text())
    bundle = json.loads(raw)
    if bundle.get("schema") != 1 or bundle.get("alias") != identity["alias"]:
        raise RuntimeError("Configuration de signature incorrecte")
    if bundle.get("certificateSha256") != identity["certificateSha256"]:
        raise RuntimeError("La clé fournie n'est pas la clé permanente de ce jeu")
    for field in ("storePassword", "keyPassword", "keystoreBase64"):
        value = bundle.get(field)
        if not isinstance(value, str) or not value or "\n" in value or "\r" in value:
            raise RuntimeError("Configuration privée incomplète")
        if os.environ.get("GITHUB_ACTIONS") == "true":
            print("::add-mask::" + value)
    key_bytes = base64.b64decode(bundle["keystoreBase64"], validate=True)
    if not 256 <= len(key_bytes) <= 65536:
        raise RuntimeError("Taille du fichier de clé incorrecte")
    tools = Path(os.environ["ANDROID_HOME"]) / "build-tools/36.1.0"
    artifact = ROOT / "artifact"
    source = artifact / "CHK_Pirate_Warrior_2_unsigned.apk"
    destination = artifact / "CHK_Pirate_Warrior_2.apk"
    if not source.is_file():
        raise RuntimeError("L'APK vérifié est absent")
    env = dict(os.environ, CHK_STORE_PASSWORD=bundle["storePassword"], CHK_KEY_PASSWORD=bundle["keyPassword"])
    with tempfile.TemporaryDirectory(prefix="chk-signing-", dir=os.environ.get("RUNNER_TEMP")) as directory:
        private_dir = Path(directory)
        private_dir.chmod(0o700)
        key = private_dir / "release.p12"
        key.write_bytes(key_bytes)
        key.chmod(0o600)
        exported = subprocess.run(["keytool", "-exportcert", "-keystore", str(key), "-storepass:env", "CHK_STORE_PASSWORD", "-alias", bundle["alias"]], env=env, check=True, capture_output=True).stdout
        if hashlib.sha256(exported).hexdigest() != identity["certificateSha256"]:
            raise RuntimeError("Le certificat réel de la clé ne correspond pas à l'identité permanente")
        aligned = private_dir / "aligned.apk"
        subprocess.run([str(tools / "zipalign"), "-f", "-P", "16", "4", str(source), str(aligned)], check=True)
        subprocess.run([str(tools / "apksigner"), "sign", "--ks", str(key), "--ks-key-alias", bundle["alias"], "--ks-pass", "env:CHK_STORE_PASSWORD", "--key-pass", "env:CHK_KEY_PASSWORD", "--min-sdk-version", "24", "--v1-signing-enabled", "false", "--v2-signing-enabled", "true", "--v3-signing-enabled", "true", "--v4-signing-enabled", "false", "--out", str(destination), str(aligned)], env=env, check=True)
        subprocess.run([str(tools / "apksigner"), "verify", "--verbose", "--print-certs", str(destination)], check=True)
        subprocess.run([str(tools / "zipalign"), "-c", "-P", "16", "4", str(destination)], check=True)
    output("available", "true")
    print("APK signé automatiquement avec la clé permanente. Fichiers privés temporaires supprimés.")


if __name__ == "__main__":
    main()
