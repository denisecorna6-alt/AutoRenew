#!/usr/bin/env python3
"""Fail-closed validation of a development provisioning profile for a selected iPhone."""
import datetime as dt
import json
import plistlib
import re
import sys


def fail(message):
    raise SystemExit("ERRO: " + message)


def validate(profile_path, bundle_id, devices_path, requested_id):
    with open(profile_path, "rb") as f:
        profile = plistlib.load(f)

    entitlements = profile.get("Entitlements", {})
    application_id = entitlements.get("application-identifier", "")
    if not isinstance(application_id, str) or "." not in application_id:
        fail("Perfil sem application-identifier válido.")
    prefix, pattern = application_id.split(".", 1)
    bundle_matches = pattern == "*" or pattern == bundle_id or (
        pattern.endswith(".*") and bundle_id.startswith(pattern[:-1])
    )
    if not bundle_matches:
        fail("Bundle ID do app não corresponde ao perfil de provisionamento.")
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    if not isinstance(prefixes, list) or prefix not in prefixes:
        fail("Prefixo de aplicação não corresponde ao perfil.")
    team_id = entitlements.get("com.apple.developer.team-identifier")
    team_ids = profile.get("TeamIdentifier", [])
    if not isinstance(team_ids, list) or team_id not in team_ids:
        fail("Team ID do app não corresponde ao perfil.")

    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, dt.datetime):
        fail("Perfil de provisionamento sem validade.")
    if expiration <= dt.datetime.now(expiration.tzinfo):
        fail("Perfil de provisionamento expirado.")

    try:
        with open(devices_path, encoding="utf-8") as f:
            listing = json.load(f)
    except (OSError, json.JSONDecodeError):
        fail("Não foi possível ler a lista JSON de dispositivos do Xcode.")

    devices = listing.get("result", {}).get("devices", [])
    if not isinstance(devices, list):
        fail("A lista de dispositivos do Xcode tem formato inválido.")
    matches = [
        item for item in devices
        if isinstance(item, dict) and (
            requested_id == item.get("identifier")
            or requested_id == item.get("hardwareProperties", {}).get("udid")
            or requested_id == item.get("properties", {}).get("udid")
        )
    ]
    if len(matches) != 1:
        fail("Dispositivo não encontrado de forma única na lista JSON do devicectl.")

    device = matches[0]
    hardware = device.get("hardwareProperties", {})
    properties = device.get("properties", {})
    udid = hardware.get("udid") or properties.get("udid")
    if not isinstance(udid, str) or not udid:
        candidate = device.get("identifier", "")
        udid = candidate if re.fullmatch(r"[0-9A-Fa-f]{40}", candidate) else None
    if not udid:
        fail("O Xcode não forneceu o UDID do dispositivo; não é possível validar o perfil.")

    provisioned_devices = profile.get("ProvisionedDevices", [])
    all_devices = profile.get("ProvisionsAllDevices", False) is True
    authorized = {
        value.upper() for value in provisioned_devices
        if isinstance(value, str)
    } if isinstance(provisioned_devices, list) else set()
    if not all_devices and udid.upper() not in authorized:
        fail("O UDID deste iPhone não está autorizado pelo perfil de provisionamento.")

    return udid


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("Uso: validate-install-target.py <profile.plist> <bundle-id> <devices.json> <device-id>")
    print("Dispositivo autorizado pelo perfil: " + validate(*sys.argv[1:]))
