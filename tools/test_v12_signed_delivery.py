"""Integrity tests for transportation of the public Android signature bytes."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from v12_signed_delivery import apply, prepare


class SignedDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source, self.signed, self.manifest, self.output = (
            self.root / name for name in ("source.apk", "signed.apk", "delivery.json", "result.apk")
        )
        large = bytes(range(256)) * 8192
        for path, extra in ((self.source, b""), (self.signed, b"XY\x04\x00TEST")):
            with zipfile.ZipFile(path, "w") as archive:
                info = zipfile.ZipInfo("assets/game.pck")
                info.extra = extra
                archive.writestr(info, large)
                archive.writestr("AndroidManifest.xml", b"package")
        prepare(self.source, self.signed, self.manifest)

    def mutate(self, **changes):
        data = json.loads(self.manifest.read_text())
        data.update(changes)
        self.manifest.write_text(json.dumps(data))

    def test_exact_roundtrip_with_large_unchanged_asset(self):
        apply(self.manifest, self.source, self.output)
        self.assertEqual(self.signed.read_bytes(), self.output.read_bytes())

    def test_changed_game_asset_is_refused(self):
        with zipfile.ZipFile(self.signed, "w") as archive:
            archive.writestr("assets/game.pck", b"other")
        with self.assertRaises(ValueError):
            prepare(self.source, self.signed, self.manifest)

    def test_source_corruption_keeps_existing_output(self):
        self.source.write_bytes(b"corrupt")
        self.output.write_bytes(b"existing")
        with self.assertRaises(ValueError):
            apply(self.manifest, self.source, self.output)
        self.assertEqual(self.output.read_bytes(), b"existing")

    def test_corrupt_public_signature_is_refused(self):
        self.mutate(signedSha256="0" * 64)
        with self.assertRaises(ValueError):
            apply(self.manifest, self.source, self.output)
        self.assertFalse(self.output.exists())

    def test_out_of_bounds_copy_is_refused(self):
        data = json.loads(self.manifest.read_text())
        entry = next(segment for segment in data["segments"] if segment[0] == "copy")
        entry[1] = data["sourceSize"]
        self.manifest.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            apply(self.manifest, self.source, self.output)


if __name__ == "__main__":
    unittest.main()
