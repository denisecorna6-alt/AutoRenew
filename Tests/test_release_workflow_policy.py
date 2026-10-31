import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BETA = (ROOT / ".github/workflows/beta-ipa.yml").read_text(encoding="utf-8")
OFFICIAL = (ROOT / ".github/workflows/official-ipa.yml").read_text(encoding="utf-8")

class ReleaseSafetyPolicy(unittest.TestCase):
    def test_beta_and_official_ipa_jobs_are_read_only(self):
        for workflow in (BETA, OFFICIAL):
            self.assertIn("contents: read", workflow)
            self.assertNotIn("contents: write", workflow)
            self.assertNotIn("gh release create", workflow)
            self.assertIn("actions/upload-artifact", workflow)

    def test_no_tag_trigger_can_publish_a_release(self):
        for workflow in (BETA, OFFICIAL):
            self.assertNotIn("tags:", workflow)
            self.assertNotIn("refs/tags/", workflow)
            self.assertNotIn("gh release", workflow)

    def test_every_ipa_artifact_is_explicitly_unsigned(self):
        self.assertIn("AutoRenew-Beta-unsigned.ipa", BETA)
        self.assertIn("AutoRenew-Beta-unsigned-IPA", BETA)
        self.assertIn("AutoRenew-Official-unsigned.ipa", OFFICIAL)
        self.assertIn("AutoRenew-Official-unsigned-IPA", OFFICIAL)
        self.assertIn("retention-days:", BETA)
        self.assertIn("retention-days:", OFFICIAL)

if __name__ == "__main__":
    unittest.main()
