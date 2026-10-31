"""Strict allowlist for AI-generated Git patches; never executes repository code."""
import re
from pathlib import Path
import subprocess

BLOCKED_NAMES = {
    "Keychain.swift", "SigningBackend.swift", "RefreshCoordinator.swift",
    "Anisette.swift", "SigningIdentityVault.swift"
}

def validate_patch(patch):
    if "GIT binary patch" in patch or "Binary files " in patch:
        raise ValueError("Patches binários não são permitidos.")
    if re.search(r"^(?:old mode |new mode |rename from |rename to |copy from |copy to )", patch, re.M):
        raise ValueError("Mudanças de modo, rename e copy não são permitidas.")
    if re.search(r"^new file mode (?!100644$)", patch, re.M):
        raise ValueError("Somente arquivos regulares 100644 podem ser criados.")
    if re.search(r"^\+\+\+ /dev/null$", patch, re.M):
        raise ValueError("Exclusão de arquivos não é permitida.")

    sections = re.split(r"(?=^diff --git )", patch, flags=re.M)
    sections = [section for section in sections if section.startswith("diff --git ")]
    if not sections or len(sections) > 20:
        raise ValueError("Patch vazio ou excede 20 arquivos.")

    files = []
    for section in sections:
        first = section.splitlines()[0]
        header = re.fullmatch(r"diff --git a/(\S+) b/(\S+)", first)
        old = re.search(r"^--- (.+)$", section, re.M)
        new = re.search(r"^\+\+\+ (.+)$", section, re.M)
        if not header or not old or not new:
            raise ValueError("Cabeçalho de patch inválido.")
        old_name, new_name = header.group(1), header.group(2)
        old_marker, new_marker = old.group(1), new.group(1)
        if old_name != new_name:
            raise ValueError("Renomeação de arquivo não permitida.")
        if new_marker == "/dev/null" or not new_marker.startswith("b/"):
            raise ValueError("Destino de patch inválido.")
        if new_marker[2:] != new_name:
            raise ValueError("Caminho de destino divergente.")
        if old_marker != "/dev/null" and old_marker != "a/" + old_name:
            raise ValueError("Caminho de origem divergente.")
        if old_marker != "/dev/null" and old_marker[2:] != new_name:
            raise ValueError("Renomeação de arquivo não permitida.")

        name = new_name
        if not re.fullmatch(r"[A-Za-z0-9._/-]+", name):
            raise ValueError("Nome de arquivo contém caracteres não permitidos.")
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or ".git" in path.parts or ".github" in path.parts:
            raise ValueError("Caminho sensível bloqueado: " + name)
        if path.name in BLOCKED_NAMES or any(word in path.name.lower()
                for word in ("signing", "keychain", "provision", "certificate", "anisette", "entitlement")):
            raise ValueError("Arquivo sensível bloqueado: " + name)
        if not (path.suffix == ".swift" or name.startswith(("Tests/", "docs/")) or name == "README.md"):
            raise ValueError("Arquivo fora da allowlist: " + name)
        files.append(name)

    if len(set(files)) != len(files):
        raise ValueError("Patch contém caminhos duplicados.")
    return files

def validate_workspace_paths(files, root=None):
    base = Path(root or Path.cwd()).resolve()
    for name in files:
        current = base
        for part in Path(name).parts:
            current = current / part
            if current.is_symlink():
                raise ValueError("Symlink existente no caminho de destino: " + name)
            resolved = current.resolve(strict=False)
            try:
                resolved.relative_to(base)
            except ValueError:
                raise ValueError("Caminho de destino sai do workspace: " + name) from None
    return True

def changed_paths():
    result = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.returncode:
        raise RuntimeError("Não foi possível conferir o estado do Git.")
    paths = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        entry = raw.decode("utf-8")
        if len(entry) < 4:
            raise RuntimeError("Estado Git inesperado.")
        status, path = entry[:2], entry[3:]
        if any(flag in status for flag in ("R", "C", "D", "U")):
            raise RuntimeError("Rename, cópia, exclusão ou conflito detectado.")
        paths.append(path)
    return paths
