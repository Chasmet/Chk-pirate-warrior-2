"""Transport the public bytes of a signed APK without exposing its private key.

Only unchanged, compressed ZIP entry contents are copied from the exact APK
already built and tested in CI. All new headers, alignment padding, the APK
signature block and ZIP directory are included as public literal bytes.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import struct
import zipfile
import zlib

CHUNK = 1024 * 1024
MAX_LITERAL = 8 * CHUNK
MAX_SEGMENTS = 10000


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def data_offset(stream, entry):
    stream.seek(entry.header_offset)
    header = stream.read(30)
    if len(header) != 30 or header[:4] != b"PK\x03\x04":
        raise ValueError("En-tête APK invalide")
    name_length, extra_length = struct.unpack_from("<HH", header, 26)
    return entry.header_offset + 30 + name_length + extra_length


def equivalent_data(old, new, old_offset, new_offset, size):
    old.seek(old_offset)
    new.seek(new_offset)
    while size:
        count = min(CHUNK, size)
        if old.read(count) != new.read(count):
            return False
        size -= count
    return True


def prepare(source, signed, manifest):
    source, signed, manifest = map(Path, (source, signed, manifest))
    source_size, signed_size = source.stat().st_size, signed.stat().st_size
    segments, literals, cursor = [], bytearray(), 0
    with zipfile.ZipFile(source) as old_zip, zipfile.ZipFile(signed) as new_zip, source.open("rb") as old, signed.open("rb") as new:
        old_entries = {info.filename: info for info in old_zip.infolist()}
        for info in sorted(new_zip.infolist(), key=lambda item: item.header_offset):
            if info.header_offset < cursor:
                raise ValueError("Entrées APK chevauchantes")
            end_header = data_offset(new, info)
            if end_header + info.compress_size > signed_size:
                raise ValueError("APK signé tronqué")
            literal_size = end_header - cursor
            if literal_size:
                new.seek(cursor)
                segments.append(["literal", len(literals), literal_size])
                literals.extend(new.read(literal_size))
            previous = old_entries.get(info.filename)
            if previous is None or (previous.CRC, previous.compress_size, previous.file_size, previous.compress_type) != (info.CRC, info.compress_size, info.file_size, info.compress_type):
                raise ValueError("Contenu APK modifié pendant la signature")
            old_offset = data_offset(old, previous)
            if old_offset + info.compress_size > source_size or not equivalent_data(old, new, old_offset, end_header, info.compress_size):
                raise ValueError("Fichier du jeu altéré pendant la signature")
            if info.compress_size:
                segments.append(["copy", old_offset, info.compress_size])
            cursor = end_header + info.compress_size
        new.seek(cursor)
        tail = new.read()
        if tail:
            segments.append(["literal", len(literals), len(tail)])
            literals.extend(tail)
    if not segments or len(segments) > MAX_SEGMENTS or len(literals) > MAX_LITERAL:
        raise ValueError("Livraison Android trop volumineuse ou mal formée")
    data = {"schema": 1, "format": "apk-content-spans-v1", "sourceSha256": digest(source),
            "signedSha256": digest(signed), "sourceSize": source_size, "signedSize": signed_size,
            "segments": segments,
            "literalZlibBase64": base64.b64encode(zlib.compress(literals, 9)).decode("ascii")}
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(data, separators=(",", ":")) + "\n")
    print(f"Signature transportée : {len(literals)} octets publics, {len(segments)} segments. Clé privée absente.")



def apply_signing_block_overlay(data, source, destination):
    required_ints = (
        "sourceSize", "signedSize", "sourceCentralDirectoryOffset",
        "sourceEocdOffset", "signedCentralDirectoryOffset", "centralDirectorySize",
    )
    for field in ("sourceSha256", "signedSha256"):
        value = data.get(field)
        if not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
            raise ValueError("Empreinte SHA-256 incorrecte")
    for field in required_ints:
        value = data.get(field)
        if type(value) is not int or value < 0:
            raise ValueError("Valeur numérique de livraison incorrecte")
    if not 0 < data["sourceSize"] <= 2 * 1024**3 or not 0 < data["signedSize"] <= 2 * 1024**3:
        raise ValueError("Taille de livraison incorrecte")

    block = base64.b64decode(data.get("signingBlockBase64", ""), validate=True)
    if not block or len(block) > MAX_LITERAL or not block.endswith(b"APK Sig Block 42"):
        raise ValueError("Bloc de signature Android invalide")
    if data["signedCentralDirectoryOffset"] != data["sourceCentralDirectoryOffset"] + len(block):
        raise ValueError("Décalage du répertoire signé incohérent")
    if data["signedSize"] != data["sourceSize"] + len(block):
        raise ValueError("Taille APK signée incohérente")
    if data["sourceCentralDirectoryOffset"] + data["centralDirectorySize"] != data["sourceEocdOffset"]:
        raise ValueError("Répertoire ZIP source incohérent")
    if data["signedCentralDirectoryOffset"] >= 2**32:
        raise ValueError("Décalage ZIP non pris en charge")
    if source.stat().st_size != data["sourceSize"] or digest(source) != data["sourceSha256"]:
        raise ValueError("L'APK source ne correspond pas à la compilation validée")

    with source.open("rb") as stream:
        stream.seek(data["sourceEocdOffset"])
        eocd = bytearray(stream.read())
    if len(eocd) < 22 or eocd[:4] != b"PK\x05\x06":
        raise ValueError("Fin de ZIP APK invalide")
    comment_length = struct.unpack_from("<H", eocd, 20)[0]
    if len(eocd) != 22 + comment_length:
        raise ValueError("Commentaire ZIP ou données finales incohérentes")
    if struct.unpack_from("<I", eocd, 12)[0] != data["centralDirectorySize"]:
        raise ValueError("Taille du répertoire ZIP incorrecte")
    if struct.unpack_from("<I", eocd, 16)[0] != data["sourceCentralDirectoryOffset"]:
        raise ValueError("Décalage du répertoire ZIP incorrect")
    struct.pack_into("<I", eocd, 16, data["signedCentralDirectoryOffset"])

    temporary = destination.with_name(destination.name + ".tmp")
    try:
        with source.open("rb") as old, temporary.open("wb") as output:
            remaining = data["sourceCentralDirectoryOffset"]
            while remaining:
                part = old.read(min(CHUNK, remaining))
                if not part:
                    raise ValueError("APK source tronqué")
                output.write(part)
                remaining -= len(part)
            output.write(block)
            remaining = data["centralDirectorySize"]
            while remaining:
                part = old.read(min(CHUNK, remaining))
                if not part:
                    raise ValueError("Répertoire APK tronqué")
                output.write(part)
                remaining -= len(part)
            output.write(eocd)
        if temporary.stat().st_size != data["signedSize"] or digest(temporary) != data["signedSha256"]:
            raise ValueError("APK restitué différent de l'APK signé")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    print("APK signé restitué à l'identique depuis le bloc public. Vérification Android obligatoire avant publication.")


def apply(manifest, source, destination):
    manifest, source, destination = map(Path, (manifest, source, destination))
    if source.resolve() == destination.resolve() or manifest.stat().st_size > 2 * MAX_LITERAL:
        raise ValueError("Chemin ou taille du manifeste incorrect")
    data = json.loads(manifest.read_text())
    if data.get("schema") == 2 and data.get("format") == "apk-signing-block-overlay-v1":
        apply_signing_block_overlay(data, source, destination)
        return
    if data.get("schema") != 1 or data.get("format") != "apk-content-spans-v1":
        raise ValueError("Format de livraison inconnu")
    for field in ("sourceSha256", "signedSha256"):
        value = data.get(field)
        if not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
            raise ValueError("Empreinte SHA-256 incorrecte")
    for field in ("sourceSize", "signedSize"):
        if type(data.get(field)) is not int or not 0 < data[field] <= 2 * 1024**3:
            raise ValueError("Taille de livraison incorrecte")
    segments = data.get("segments")
    if not isinstance(segments, list) or not 0 < len(segments) <= MAX_SEGMENTS:
        raise ValueError("Segments de livraison incorrects")
    compressed = base64.b64decode(data["literalZlibBase64"], validate=True)
    if len(compressed) > MAX_LITERAL:
        raise ValueError("Littéraux compressés trop grands")
    decoder = zlib.decompressobj()
    literals = decoder.decompress(compressed, MAX_LITERAL + 1)
    if len(literals) > MAX_LITERAL or decoder.unconsumed_tail or not decoder.eof or decoder.unused_data:
        raise ValueError("Littéraux invalides")
    total = 0
    for segment in segments:
        if (not isinstance(segment, list) or len(segment) != 3 or segment[0] not in ("copy", "literal")
                or any(type(value) is not int or value < 0 for value in segment[1:])):
            raise ValueError("Segment invalide")
        kind, offset, size = segment
        if not size or offset + size > (data["sourceSize"] if kind == "copy" else len(literals)):
            raise ValueError("Segment hors limites")
        total += size
    if total != data["signedSize"]:
        raise ValueError("Taille de sortie incohérente")
    if source.stat().st_size != data["sourceSize"] or digest(source) != data["sourceSha256"]:
        raise ValueError("L'APK source ne correspond pas à la compilation validée")
    temporary = destination.with_name(destination.name + ".tmp")
    try:
        with source.open("rb") as old, temporary.open("wb") as output:
            for kind, offset, size in segments:
                if kind == "literal":
                    output.write(literals[offset:offset + size])
                else:
                    old.seek(offset)
                    while size:
                        part = old.read(min(CHUNK, size))
                        if not part:
                            raise ValueError("APK source tronqué")
                        output.write(part)
                        size -= len(part)
        if temporary.stat().st_size != data["signedSize"] or digest(temporary) != data["signedSha256"]:
            raise ValueError("APK restitué différent de l'APK signé")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    print("APK signé restitué à l'identique. Vérification Android obligatoire avant publication.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("prepare", "apply"):
        sub = subparsers.add_parser(command)
        for field in (("source", "signed", "manifest") if command == "prepare"
                      else ("manifest", "source", "destination")):
            sub.add_argument(field)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.source, args.signed, args.manifest)
    else:
        apply(args.manifest, args.source, args.destination)
