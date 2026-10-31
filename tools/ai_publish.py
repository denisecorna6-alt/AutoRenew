#!/usr/bin/env python3
"""Privileged publisher stage. It has a GitHub write token but no AI-provider secrets."""
import os
import re
import subprocess
import sys
from pathlib import Path

from tools.ai_patch_policy import validate_patch, changed_paths, validate_workspace_paths

def run(args):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode:
        if result.stdout:
            print(result.stdout, file=sys.stderr)
        raise RuntimeError("Comando falhou: " + " ".join(args))
    return result.stdout.strip()

def main():
    base = os.getenv("AI_BASE_BRANCH", "").strip()
    if not re.fullmatch(r"codex/alpha-[A-Za-z0-9._-]+", base):
        raise RuntimeError("Destino deve ser codex/alpha-*.")
    if not os.getenv("GH_TOKEN", "").strip():
        raise RuntimeError("Token de publicação ausente.")

    artifact = Path("ai-proposal-output")
    patch_path = artifact / "ai-change.patch"
    report_path = artifact / "ai-coding-report.md"
    if not patch_path.is_file() or not report_path.is_file():
        raise RuntimeError("Artefato de proposta incompleto.")
    patch = patch_path.read_text(encoding="utf-8")
    files = validate_patch(patch)

    run(["git", "fetch", "--no-tags", "origin",
         "refs/heads/" + base + ":refs/remotes/origin/" + base])
    run_id = os.getenv("GITHUB_RUN_ID", "local")
    if not re.fullmatch(r"[A-Za-z0-9-]+", run_id):
        raise RuntimeError("GITHUB_RUN_ID inválido.")
    branch = "codex/alpha-ai-work-" + run_id
    run(["git", "switch", "-c", branch, "refs/remotes/origin/" + base])

    # Validate every existing path component before applying untrusted patch data.
    validate_workspace_paths(files)
    run(["git", "apply", "--check", str(patch_path)])
    run(["git", "apply", str(patch_path)])
    paths = changed_paths()
    if not paths or set(paths) != set(files):
        raise RuntimeError("Arquivos alterados não correspondem exatamente ao patch aprovado.")
    run(["git", "-c", "core.attributesFile=/dev/null", "-c", "core.hooksPath=/dev/null",
         "add", "--"] + paths)
    run(["git", "diff", "--cached", "--check"])
    run(["git", "config", "user.name", "github-actions[bot]"])
    run(["git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com"])
    run(["git", "-c", "core.hooksPath=/dev/null", "commit", "-m", "[AI Alpha] " + run_id])
    run(["git", "-c", "core.hooksPath=/dev/null", "push", "origin", "HEAD"])

    title = "[AI Alpha] " + run_id
    body = ("AI-assisted Alpha proposal.\n\n"
            "The selected implementer and two independent reviewers approved the patch in the read-only proposal job.\n"
            "The privileged publisher received no OpenAI, Anthropic or Gemini API keys and executed no target-branch scripts or tests.\n"
            "Patch allowlist, symlink/path checks and staged diff check passed.\n"
            "Project CI runs separately with read-only permissions. Human review remains required.\n"
            "No merge, Beta/Stable release, signing or installation was performed.\n\n"
            "Files: " + ", ".join(files) + "\n\n"
            "See the originating Actions run for the full reviewer report.")
    run(["gh", "pr", "create", "--base", base, "--head", branch, "--title", title, "--body", body])
    Path("ai-publish-report.md").write_text(
        "Alpha PR created for " + base + ". Files: " + ", ".join(files) + "\n",
        encoding="utf-8"
    )
    print("PR Alpha criada. Nenhum teste, merge ou release executado no job privilegiado.")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("ERRO: " + str(exc), file=sys.stderr)
        sys.exit(1)
