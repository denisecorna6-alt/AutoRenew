import pathlib
import tempfile
import unittest

from tools.ai_patch_policy import validate_patch, validate_workspace_paths

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "tools/ai_central.py").read_text(encoding="utf-8")
PROPOSE = (ROOT / "tools/ai_propose.py").read_text(encoding="utf-8")
PUBLISH = (ROOT / "tools/ai_publish.py").read_text(encoding="utf-8")
LEGACY = (ROOT / "tools/ai_coder.py").read_text(encoding="utf-8")
FLOW = (ROOT / ".github/workflows/ai-central.yml").read_text(encoding="utf-8")

class CentralSafety(unittest.TestCase):
    def test_three_real_provider_secrets_are_wired_only_to_review_and_proposal(self):
        for key in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY"):
            self.assertIn(key, SCRIPT)
            self.assertIn(key, PROPOSE)
            self.assertIn(key, FLOW)
            self.assertNotIn(key, PUBLISH)

    def test_manual_modes_and_scoped_jobs(self):
        self.assertIn("workflow_dispatch:", FLOW)
        self.assertIn("inputs.mode == 'review'", FLOW)
        self.assertIn("inputs.mode == 'implement'", FLOW)
        self.assertIn("contents: read", FLOW)
        self.assertIn("contents: write", FLOW)
        self.assertIn("pull-requests: write", FLOW)
        self.assertNotIn("schedule:", FLOW)

    def test_every_privileged_or_secret_job_checks_out_trusted_main(self):
        self.assertGreaterEqual(FLOW.count("ref: main"), 4)
        self.assertNotIn("ref: " + "$" + "{{ inputs.base_branch }}", FLOW)

    def test_provider_secret_job_is_read_only(self):
        proposal = FLOW.split("  propose:", 1)[1].split("  publish:", 1)[0]
        self.assertIn("contents: read", proposal)
        self.assertNotIn("contents: write", proposal)
        self.assertNotIn("pull-requests: write", proposal)
        self.assertIn("persist-credentials: false", proposal)

    def test_write_job_has_no_provider_secrets(self):
        publisher = FLOW.split("  publish:", 1)[1]
        self.assertIn("contents: write", publisher)
        self.assertIn("pull-requests: write", publisher)
        for key in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY"):
            self.assertNotIn(key, publisher)
        self.assertIn("GH_TOKEN", publisher)

    def test_proposal_never_pushes_or_opens_pull_requests(self):
        self.assertNotIn('"git", "push"', PROPOSE)
        self.assertNotIn('"gh", "pr", "create"', PROPOSE)
        self.assertIn("git fetch", PROPOSE)
        self.assertIn("git switch", PROPOSE)

    def test_publisher_does_not_call_provider_apis(self):
        self.assertNotIn("api.openai.com", PUBLISH)
        self.assertNotIn("api.anthropic.com", PUBLISH)
        self.assertNotIn("generativelanguage.googleapis.com", PUBLISH)

    def test_legacy_combined_runner_is_disabled(self):
        self.assertIn("raise SystemExit", LEGACY)
        self.assertNotIn("git push", LEGACY)
        self.assertNotIn("OPENAI_API_KEY", LEGACY)
        self.assertNotIn("python tools/ai_coder.py", FLOW)

    def test_patch_policy_accepts_text_swift_change(self):
        valid = """diff --git a/ContentView.swift b/ContentView.swift
index 1111111..2222222 100644
--- a/ContentView.swift
+++ b/ContentView.swift
@@ -1 +1 @@
-let x = 1
+let x = 2
"""
        self.assertEqual(validate_patch(valid), ["ContentView.swift"])

    def test_patch_policy_rejects_symlinks_renames_deletes_and_workflows(self):
        symlink = """diff --git a/docs/link.md b/docs/link.md
new file mode 120000
--- /dev/null
+++ b/docs/link.md
@@ -0,0 +1 @@
+../../secret
"""
        rename = """diff --git a/ContentView.swift b/Other.swift
similarity index 100%
rename from ContentView.swift
rename to Other.swift
"""
        deletion = """diff --git a/ContentView.swift b/ContentView.swift
deleted file mode 100644
--- a/ContentView.swift
+++ /dev/null
@@ -1 +0,0 @@
-let x = 1
"""
        workflow = """diff --git a/.github/workflows/pwn.yml b/.github/workflows/pwn.yml
new file mode 100644
--- /dev/null
+++ b/.github/workflows/pwn.yml
@@ -0,0 +1 @@
+name: pwn
"""
        for patch in (symlink, rename, deletion, workflow):
            with self.subTest(patch=patch[:50]):
                with self.assertRaises(ValueError):
                    validate_patch(patch)

    def test_patch_policy_rejects_traversal_and_non_allowlisted_paths(self):
        traversal = """diff --git a/../outside.swift b/../outside.swift
--- a/../outside.swift
+++ b/../outside.swift
@@ -1 +1 @@
-a
+b
"""
        workflow_config = """diff --git a/project.yml b/project.yml
--- a/project.yml
+++ b/project.yml
@@ -1 +1 @@
-a
+b
"""
        for patch in (traversal, workflow_config):
            with self.assertRaises(ValueError):
                validate_patch(patch)

    def test_workspace_rejects_symlink_parent(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "workspace"
            outside = pathlib.Path(temp) / "outside"
            root.mkdir()
            outside.mkdir()
            (root / "docs").symlink_to(outside, target_is_directory=True)
            with self.assertRaises(ValueError):
                validate_workspace_paths(["docs/new.md"], root)

    def test_project_validation_is_read_only_and_builds_all_app_schemes(self):
        self.assertIn("project-validation:", FLOW)
        self.assertIn("runs-on: macos-15", FLOW)
        self.assertIn("pull_request:", FLOW)
        self.assertIn("AutoRenewInstaller", FLOW)
        self.assertIn("build-for-testing", FLOW)
        self.assertIn("contents: read", FLOW)
        self.assertIn("actions/checkout@v7.0.1", FLOW)
        self.assertIn("actions/setup-python@v7.1.0", FLOW)
        self.assertIn("actions/upload-artifact@v7.0.2", FLOW)

    def test_proposal_preserves_failure_logs_and_redacts_keys(self):
        self.assertIn("stderr=subprocess.STDOUT", PROPOSE)
        self.assertIn("print(result.stdout", PROPOSE)
        self.assertIn("replace(secret", SCRIPT)
        self.assertIn("replace(secret", PROPOSE)

    def test_review_mode_does_not_modify_project(self):
        self.assertIn("nenhuma alteração de código/publicação executada", SCRIPT)

if __name__ == "__main__":
    unittest.main()
