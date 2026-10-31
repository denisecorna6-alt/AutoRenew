#!/usr/bin/env python3
"""Validate a decoded provisioning profile against one app bundle and selected device."""
import argparse
import datetime
import plistlib
import sys

def validate_profile(profile, info, device_id, now=None):
    device_id = device_id.strip()
    if not device_id:
        raise ValueError("identificador do dispositivo vazio")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime.datetime):
        raise ValueError("perfil sem ExpirationDate válida")
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
    else:
        expiry = expiry.astimezone(datetime.timezone.utc)
    current = now or datetime.datetime.now(datetime.timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=datetime.timezone.utc)
    else:
        current = current.astimezone(datetime.timezone.utc)
    if expiry <= current:
        raise ValueError("perfil de provisionamento expirado")

    bundle_id = info.get("CFBundleIdentifier")
    entitlements = profile.get("Entitlements")
    teams = profile.get("TeamIdentifier")
    prefixes = profile.get("ApplicationIdentifierPrefix")
    if not isinstance(bundle_id, str) or not bundle_id or not isinstance(entitlements, dict):
        raise ValueError("Info.plist ou Entitlements inválidos")
    if not isinstance(teams, list) or not teams or not all(isinstance(x, str) for x in teams):
        raise ValueError("TeamIdentifier ausente ou inválido")
    if not isinstance(prefixes, list) or not all(isinstance(x, str) for x in prefixes):
        raise ValueError("ApplicationIdentifierPrefix ausente ou inválido")

    app_identifier = entitlements.get("application-identifier")
    if not isinstance(app_identifier, str) or "." not in app_identifier:
        raise ValueError("application-identifier ausente")
    prefix, pattern = app_identifier.split(".", 1)
    if prefix not in prefixes:
        raise ValueError("prefixo do application-identifier não corresponde ao perfil")
    if pattern == "*":
        matches = True
    elif pattern.endswith(".*"):
        matches = bundle_id.startswith(pattern[:-1])
    else:
        matches = bundle_id == pattern
    if not matches:
        raise ValueError("Bundle ID não é permitido pelo perfil")
    if entitlements.get("com.apple.developer.team-identifier") not in teams:
        raise ValueError("Team ID do entitlement não corresponde ao perfil")

    if profile.get("ProvisionsAllDevices") is not True:
        devices = profile.get("ProvisionedDevices")
        if not isinstance(devices, list) or not any(
            isinstance(value, str) and value.casefold() == device_id.casefold()
            for value in devices
        ):
            raise ValueError("UDID do dispositivo selecionado não está autorizado pelo perfil")

    certificates = profile.get("DeveloperCertificates")
    if not isinstance(certificates, list) or not certificates or not all(
        isinstance(value, bytes) and value for value in certificates
    ):
        raise ValueError("perfil não contém DeveloperCertificates válidos")
    return bundle_id

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True)
    parser.add_argument("--info", required=True)
    parser.add_argument("--device-id", required=True)
    args = parser.parse_args()
    try:
        with open(args.profile, "rb") as stream:
            profile = plistlib.load(stream)
        with open(args.info, "rb") as stream:
            info = plistlib.load(stream)
        bundle_id = validate_profile(profile, info, args.device_id)
        print("OK: " + bundle_id + " autorizado para o dispositivo selecionado.")
    except (OSError, plistlib.InvalidFileException, ValueError, TypeError) as exc:
        print("Erro: " + str(exc), file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
