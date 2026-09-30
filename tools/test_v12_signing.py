"""Publication guard tests: a new signature is never silently accepted."""
import copy
import unittest
from publish_v12_metadata import validate_transition


class SigningContinuityTests(unittest.TestCase):
    def setUp(self):
        self.identity = {"packageName": "com.chasmet.chkpiratewarrior2", "certificateSha256": "a" * 64,
                         "bootstrapPredecessor": {"releaseId": 10, "tag": "legacy", "assetId": 20, "apkSha256": "b" * 64}}
        self.args = [self.identity, {"id": 10, "tag_name": "legacy"}, {"id": 20},
                     {"packageName": self.identity["packageName"], "versionCode": 118},
                     {"packageName": self.identity["packageName"], "versionCode": 1200004},
                     ["c" * 64], ["a" * 64], "b" * 64]

    def test_exact_legacy_can_start_permanent_signature(self):
        self.assertEqual(validate_transition(*self.args), "new_install")

    def test_same_certificate_updates_without_reset(self):
        self.args[5] = ["a" * 64]
        self.args[1] = {"id": 99, "tag_name": "v12.0.4"}
        self.assertEqual(validate_transition(*self.args), "update")

    def test_other_key_is_blocked_even_for_bootstrap(self):
        self.args[6] = ["d" * 64]
        with self.assertRaises(RuntimeError):
            validate_transition(*self.args)

    def test_bootstrap_cannot_accept_another_release_asset_or_digest(self):
        mutations = [(1, {"id": 11, "tag_name": "legacy"}), (1, {"id": 10, "tag_name": "other"}),
                     (2, {"id": 21}), (7, "d" * 64)]
        for index, value in mutations:
            with self.subTest(index=index, value=value):
                args = copy.deepcopy(self.args)
                args[index] = value
                with self.assertRaises(RuntimeError):
                    validate_transition(*args)

    def test_changed_package_is_blocked(self):
        for index in (3, 4):
            args = copy.deepcopy(self.args)
            args[index]["packageName"] = "different.application"
            with self.assertRaises(RuntimeError):
                validate_transition(*args)

    def test_same_or_older_version_is_blocked(self):
        for value in (117, 118):
            self.args[4]["versionCode"] = value
            with self.assertRaises(RuntimeError):
                validate_transition(*self.args)

    def test_additional_signer_is_blocked(self):
        self.args[6].append("e" * 64)
        with self.assertRaises(RuntimeError):
            validate_transition(*self.args)


if __name__ == "__main__":
    unittest.main(verbosity=2)
