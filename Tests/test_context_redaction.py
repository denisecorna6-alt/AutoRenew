import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from sanitize_context import redact_sensitive

class ContextRedactionTests(unittest.TestCase):
    def test_redacts_common_provider_and_github_tokens(self):
        value = "OPENAI_API_KEY=sk-proj-ABCDEFGHIJKLMNOPQRSTUVWXYZ123456 ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
        redacted = redact_sensitive(value)
        self.assertNotIn("sk-proj-", redacted)
        self.assertNotIn("ghp_", redacted)
        self.assertIn("[REDACTED", redacted)

    def test_redacts_bearer_and_cookie_headers(self):
        value = "Authorization: Bearer abcdefghijklmnopqrstuvwxyz012345\nCookie: session=secret"
        redacted = redact_sensitive(value)
        self.assertNotIn("abcdefghijklmnopqrstuvwxyz012345", redacted)
        self.assertNotIn("session=secret", redacted)

    def test_redacts_private_key_blocks_and_apple_id_values(self):
        value = "Apple ID: user@example.com\n-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----"
        redacted = redact_sensitive(value)
        self.assertNotIn("user@example.com", redacted)
        self.assertNotIn("secret\n", redacted)
        self.assertIn("[REDACTED KEY MATERIAL]", redacted)

if __name__ == "__main__":
    unittest.main()
