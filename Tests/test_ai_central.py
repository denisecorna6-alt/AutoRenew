import pathlib
import unittest

SCRIPT = pathlib.Path("tools/ai_central.py").read_text(encoding="utf-8")
FLOW = pathlib.Path(".github/workflows/ai-central.yml").read_text(encoding="utf-8")

class CentralSafety(unittest.TestCase):
    def test_three_secret_names(self):
        for key in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY"):
            self.assertIn(key, SCRIPT)
            self.assertIn(key, FLOW)
    def test_read_only_and_manual(self):
        self.assertIn("contents: read", FLOW)
        self.assertNotIn("contents: write", FLOW)
        self.assertNotIn("schedule:", FLOW)
    def test_redacts_secret_in_http_error(self):
        self.assertIn('replace(secret,"[REDACTED]")', SCRIPT)
    def test_report_is_review_only(self):
        self.assertIn("nenhuma alteração de código/publicação executada", SCRIPT)

if __name__ == "__main__":
    unittest.main()
