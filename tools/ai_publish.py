#!/usr/bin/env python3
"""Privileged publisher stage. It has a GitHub write token but no AI-provider secrets."""
import os
import re
import subprocess
import sys
import tempfile
import shutil
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
    patch_source = artifact / "ai-change.patch"
    report_source = artifact / "ai-coding-report.md"
    base_sha_source = artifact / "ai-base-sha.txt"
    if artifact.is_symlink() or not artifact.is_dir():
        raise RuntimeError("Diretório de artefato inválido.")
    if any(item.is_symlink() for item in artifact.iterdir()):
        raise RuntimeError("Artefato contém symlink.")
    if (not patch_source.is_file() or not report_source.is_file() or not base_sha_source.is_file()):
        raise RuntimeError("Artefato de proposta incompleto.")
    if {item.name for item in artifact.iterdir()} != {"ai-change.patch", "ai-coding-report.md", "ai-base-sha.txt"}:
        raise RuntimeError("Artefato contém arquivos inesperados.")
    patch = patch_source.read_text(encoding="utf-8")
    base_sha = base_sha_source.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9a-f]{40}", base_sha):
        raise RuntimeError("SHA da branch-base inválido.")
    files = validate_patch(patch)
    shutil.rmtree(artifact)

    with tempfile.NamedTemporaryFile(prefix="autorenew-ai-publish-", suffix=".patch", delete=False) as temporary:
        patch_path = temporary.name
    try:
        Path(patch_path).write_text(patch, encoding="utf-8")
        run(["git", "fetch", "--no-tags", "origin",
             "refs/heads/" + base + ":refs/remotes/origin/" + base])
        current_base_sha = run(["git", "rev-parse", "refs/remotes/origin/" + base])
        if current_base_sha != base_sha:
            raise RuntimeError("A branch-base mudou depois da revisão; gere uma nova proposta.")
        run_id = os.getenv("GITHUB_RUN_ID", "local")
        if not re.fullmatch(r"[A-Za-z0-9-]+", run_id):
            raise RuntimeError("GITHUB_RUN_ID inválido.")
        branch = "codex/alpha-ai-work-" + run_id
        run(["git", "switch", "-c", branch, "refs/remotes/origin/" + base])

        # No target-branch scripts are executed. Validate parents before applying patch data.
        validate_workspace_paths(files)
        run(["git", "apply", "--check", patch_path])
        run(["git", "apply", patch_path])
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
                "This privileged publisher received no OpenAI, Anthropic or Gemini API keys and executed no target-branch scripts or tests.\n"
                "Patch allowlist, symlink/path checks and staged diff check passed.\n"
                "Project CI runs separately with read-only permissions. Human review remains required.\n"
                "No merge, Beta/Stable release, signing or installation was performed.\n\n"
                "Files: " + ", ".join(files) + "\n\n"
                "See the originating Actions run for the full reviewer report.")
        run(["gh", "pr", "create", "--base", base, "--head", branch, "--title", title, "--body", body])
        report_path = Path(os.getenv("AI_PUBLISH_REPORT_PATH", str(Path(tempfile.gettempdir()) / "ai-publish-report.md")))
        report_path.write_text(
            "Alpha PR created for " + base + ". Files: " + ", ".join(files) + "\n",
            encoding="utf-8"
        )
        print("PR Alpha criada. Nenhum teste, merge ou release executado no job privilegiado.")
    finally:
        try:
            os.unlink(patch_path)
        except OSError:
            pass

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("ERRO: " + str(exc), file=sys.stderr)
        sys.exit(1)
