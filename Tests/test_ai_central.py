import pathlib
import unittest

SCRIPT = pathlib.Path("tools/ai_central.py").read_text(encoding="utf-8")
CODER = pathlib.Path("tools/ai_coder.py").read_text(encoding="utf-8")
FLOW = pathlib.Path(".github/workflows/ai-central.yml").read_text(encoding="utf-8")

class CentralSafety(unittest.TestCase):
    def test_three_secret_names(self):
        for key in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY"):
            self.assertIn(key, SCRIPT)
            self.assertIn(key, CODER)
            self.assertIn(key, FLOW)
    def test_manual_modes_and_scoped_write_job(self):
        self.assertIn("workflow_dispatch:", FLOW)
        self.assertIn("inputs.mode == 'implement'", FLOW)
        self.assertIn("contents: read", FLOW)
        self.assertIn("contents: write", FLOW)
        self.assertIn("pull-requests: write", FLOW)
        self.assertNotIn("schedule:", FLOW)
    def test_coder_has_alpha_and_path_guards(self):
        self.assertIn("codex/alpha-", CODER)
        self.assertIn(".github/", CODER)
        self.assertIn("SigningBackend.swift", CODER)
        self.assertIn('run(["git","diff","--check"])', CODER)
    def test_redacts_secrets(self):
        self.assertIn('replace(secret,"[REDACTED]")', SCRIPT)
        self.assertIn('replace(key,"[REDACTED]")', CODER)
    def test_review_mode_does_not_modify_project(self):
        self.assertIn("nenhuma alteração de código/publicação executada", SCRIPT)

if __name__ == "__main__":
    unittest.main()
