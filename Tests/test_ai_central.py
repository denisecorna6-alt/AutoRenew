import pathlib
import unittest

from tools.ai_coder import validate_patch

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

    def test_implement_jobs_use_trusted_main_checkout(self):
        self.assertGreaterEqual(FLOW.count("ref: main"), 3)
        self.assertNotIn("ref: " + "$" + "{{ inputs.base_branch }}", FLOW)
        self.assertIn('run(["git", "switch", "-c", branch, "refs/remotes/origin/" + base])', CODER)
        self.assertIn("git fetch", CODER)

    def test_privileged_worker_never_executes_target_tests(self):
        self.assertNotIn("unittest", CODER)
        self.assertNotIn("py_compile", CODER)
        self.assertIn("No target-branch scripts or tests were executed", CODER)

    def test_patch_allowlist_rejects_symlinks_and_renames(self):
        valid = """diff --git a/ContentView.swift b/ContentView.swift
index 1111111..2222222 100644
--- a/ContentView.swift
+++ b/ContentView.swift
@@ -1 +1 @@
-let x = 1
+let x = 2
"""
        self.assertEqual(validate_patch(valid), ["ContentView.swift"])
        symlink = """diff --git a/docs/link.md b/docs/link.md
new file mode 120000
--- /dev/null
+++ b/docs/link.md
@@ -0,0 +1 @@
+../../secret
"""
        with self.assertRaises(ValueError):
            validate_patch(symlink)
        rename = """diff --git a/ContentView.swift b/Other.swift
similarity index 100%
rename from ContentView.swift
rename to Other.swift
"""
        with self.assertRaises(ValueError):
            validate_patch(rename)
        workflow = """diff --git a/.github/workflows/pwn.yml b/.github/workflows/pwn.yml
new file mode 100644
--- /dev/null
+++ b/.github/workflows/pwn.yml
@@ -0,0 +1 @@
+name: pwn
"""
        with self.assertRaises(ValueError):
            validate_patch(workflow)

    def test_coder_has_alpha_and_path_guards(self):
        self.assertIn("codex/alpha-", CODER)
        self.assertIn(".github/", CODER)
        self.assertIn("SigningBackend.swift", CODER)
        self.assertIn('run(["git", "diff", "--cached", "--check"])', CODER)

    def test_project_validation_runs_on_alpha_push_and_pr(self):
        self.assertIn("project-validation:", FLOW)
        self.assertIn("runs-on: macos-15", FLOW)
        self.assertIn("pull_request:", FLOW)
        self.assertIn("AutoRenewInstaller", FLOW)
        self.assertIn("build-for-testing", FLOW)
        self.assertIn("actions/checkout@v7.0.1", FLOW)
        self.assertIn("actions/setup-python@v7.1.0", FLOW)
        self.assertIn("actions/upload-artifact@v7.0.2", FLOW)

    def test_coder_preserves_failure_logs(self):
        self.assertIn("stderr=subprocess.STDOUT", CODER)
        self.assertIn("print(result.stdout", CODER)

    def test_redacts_secrets(self):
        self.assertIn("replace(secret", SCRIPT)
        self.assertIn("replace(secret", CODER)

    def test_review_mode_does_not_modify_project(self):
        self.assertIn("nenhuma alteração de código/publicação executada", SCRIPT)

if __name__ == "__main__":
    unittest.main()
