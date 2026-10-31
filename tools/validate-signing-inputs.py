#!/usr/bin/env python3
"""Fail-closed checks for IPA archives, provisioning profiles and requested entitlements."""
import argparse
import datetime as dt
import hashlib
import plistlib
import re
import stat
import sys
import zipfile
from pathlib import PurePosixPath

def fail(message):
    print("ERRO: " + message, file=sys.stderr)
    raise SystemExit(1)

def safe_archive(path):
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            if not names:
                fail("IPA vazio.")
            seen = set()
            total = 0
            if len(names) > 100000:
                fail("IPA contém entradas demais.")
            for info in archive.infolist():
                name = info.filename
                p = PurePosixPath(name)
                mode = (info.external_attr >> 16) & 0xFFFF
                if p.is_absolute() or ".." in p.parts or name.startswith("/") or "\\\\" in name or "\\x00" in name:
                    fail("IPA contém caminho inseguro.")
                if stat.S_ISLNK(mode):
                    fail("IPA contém link simbólico; extração bloqueada.")
                normalized = str(p)
                if normalized in seen:
                    fail("IPA contém entradas duplicadas.")
                seen.add(normalized)
                if info.file_size > 1024 * 1024 * 1024:
                    fail("Entrada individual excede 1 GiB.")
                if info.compress_size == 0 and info.file_size > 0:
                    fail("Entrada ZIP possui tamanho comprimido inválido.")
                if info.compress_size > 0 and info.file_size / info.compress_size > 200:
                    fail("Taxa de compressão suspeita; possível ZIP bomb.")
                total += info.file_size
                if total > 4 * 1024 * 1024 * 1024:
                    fail("Conteúdo descompactado excede 4 GiB.")
            if not any(n.startswith("Payload/") for n in names):
                fail("IPA não contém Payload/.")
    except (OSError, zipfile.BadZipFile):
        fail("Arquivo não é um ZIP/IPA válido.")

def wildcard_match(allowed, requested):
    if allowed == requested or allowed == "*":
        return True
    if isinstance(allowed, str) and allowed.endswith("*"):
        return requested.startswith(allowed[:-1])
    return False

def entitlement_allowed(requested, allowed):
    if isinstance(requested, bool):
        return requested is False or allowed is True
    if isinstance(requested, str):
        return isinstance(allowed, str) and wildcard_match(allowed, requested)
    if isinstance(requested, list):
        return isinstance(allowed, list) and all(
            any(wildcard_match(a, r) if isinstance(a, str) and isinstance(r, str) else a == r
                for a in allowed) for r in requested
        )
    if isinstance(requested, dict):
        return isinstance(allowed, dict) and all(
            k in allowed and entitlement_allowed(v, allowed[k])
            for k, v in requested.items()
        )
    return requested == allowed

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect-ipa")
    parser.add_argument("--profile")
    parser.add_argument("--app-info")
    parser.add_argument("--entitlements")
    parser.add_argument("--identity-list")
    parser.add_argument("--bundle-id")
    parser.add_argument("--ipa")
    args = parser.parse_args()

    if args.inspect_ipa:
        safe_archive(args.inspect_ipa)
        print("IPA ZIP estruturalmente aceitável; assinatura não avaliada nesta etapa.")
        return
    if not all([args.profile, args.app_info, args.entitlements, args.identity_list, args.bundle_id, args.ipa]):
        fail("Informe todos os parâmetros de validação do perfil/entitlements.")
    safe_archive(args.ipa)
    with open(args.profile, "rb") as f: profile = plistlib.load(f)
    with open(args.app_info, "rb") as f: app_info = plistlib.load(f)
    with open(args.entitlements, "rb") as f: requested = plistlib.load(f)
    if not isinstance(requested, dict):
        fail("Arquivo de entitlements precisa conter um dicionário.")
    if app_info.get("CFBundleIdentifier") != args.bundle_id:
        fail("Bundle ID informado não corresponde ao Info.plist.")
    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, dt.datetime) or expiration.replace(tzinfo=None) <= dt.datetime.utcnow():
        fail("Provisioning profile expirado ou sem data válida.")
    profile_ent = profile.get("Entitlements")
    if not isinstance(profile_ent, dict):
        fail("Perfil não contém entitlements.")
    app_id = profile_ent.get("application-identifier", "")
    if not isinstance(app_id, str) or "." not in app_id:
        fail("application-identifier ausente/inválido no perfil.")
    prefix, pattern = app_id.split(".", 1)
    if not (pattern == "*" or args.bundle_id == pattern or
            (pattern.endswith(".*") and args.bundle_id.startswith(pattern[:-1]))):
        fail("Bundle ID não é permitido pelo perfil.")
    team_ids = profile.get("TeamIdentifier", [])
    if not isinstance(team_ids, list) or prefix not in team_ids:
        fail("Prefixo de aplicação não corresponde ao Team ID.")
    if profile.get("ProvisionedDevices") is None and not profile.get("ProvisionsAllDevices", False):
        fail("Perfil não declara escopo de instalação em dispositivo.")
    for key, value in requested.items():
        if key not in profile_ent or not entitlement_allowed(value, profile_ent[key]):
            fail("Entitlement solicitado não é permitido pelo perfil: " + key)
    if requested.get("application-identifier") != prefix + "." + args.bundle_id:
        fail("Entitlements precisam conter o application-identifier exato do app.")
    if requested.get("com.apple.developer.team-identifier") not in team_ids:
        fail("Entitlements precisam conter o Team ID correto.")
    certs = profile.get("DeveloperCertificates", [])
    profile_sha1 = {hashlib.sha1(c).hexdigest().upper() for c in certs if isinstance(c, bytes)}
    with open(args.identity_list, encoding="utf-8") as f:
        identities = set(re.findall(r"\\b([0-9A-Fa-f]{40})\\b", f.read()))
    matches = profile_sha1.intersection(x.upper() for x in identities)
    if not matches:
        fail("Nenhuma identidade de assinatura disponível corresponde a DeveloperCertificates do perfil.")
    print(sorted(matches)[0])

if __name__ == "__main__":
    main()
