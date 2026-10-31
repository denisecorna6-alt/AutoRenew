import datetime
import hashlib
import json
import os
import plistlib
import subprocess
import stat
import sys
import tempfile
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALIDATOR = os.path.join(ROOT, "tools", "validate-signing-inputs.py")

class SigningInputValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.profile = os.path.join(self.root, "profile.plist")
        self.info = os.path.join(self.root, "Info.plist")
        self.entitlements = os.path.join(self.root, "entitlements.plist")
        self.identities = os.path.join(self.root, "identities.txt")
        self.ipa = os.path.join(self.root, "input.ipa")
        self.cert = b"synthetic-test-certificate"
        self.identity = hashlib.sha1(self.cert).hexdigest().upper()
        profile = {
            "ExpirationDate": datetime.datetime.utcnow() + datetime.timedelta(days=5),
            "TeamIdentifier": ["ABCDE12345"],
            "ApplicationIdentifierPrefix": ["ABCDE12345"],
            "ProvisionedDevices": ["TEST-DEVICE"],
            "DeveloperCertificates": [self.cert],
            "Entitlements": {
                "application-identifier": "ABCDE12345.com.example.app",
                "com.apple.developer.team-identifier": "ABCDE12345",
                "get-task-allow": True,
                "keychain-access-groups": ["ABCDE12345.*"],
            },
        }
        with open(self.profile, "wb") as f: plistlib.dump(profile, f)
        with open(self.info, "wb") as f: plistlib.dump({"CFBundleIdentifier": "com.example.app"}, f)
        requested = {
            "application-identifier": "ABCDE12345.com.example.app",
            "com.apple.developer.team-identifier": "ABCDE12345",
            "get-task-allow": False,
            "keychain-access-groups": ["ABCDE12345.com.example.app"],
        }
        with open(self.entitlements, "wb") as f: plistlib.dump(requested, f)
        with open(self.identities, "w") as f: f.write(f'  1) {self.identity} "Apple Development: Test"\n')
        with zipfile.ZipFile(self.ipa, "w") as z: z.writestr("Payload/Test.app/Info.plist", b"test")

    def tearDown(self):
        self.tmp.cleanup()

    def run_validator(self):
        return subprocess.run([
            sys.executable, VALIDATOR, "--profile", self.profile,
            "--app-info", self.info, "--entitlements", self.entitlements,
            "--identity-list", self.identities, "--bundle-id", "com.example.app",
            "--ipa", self.ipa,
        ], capture_output=True, text=True)

    def run_install_target_validator(self, provisioned_devices, requested_id="coredevice-device-1",
                                     bundle_id="com.example.app", device_list=None):
        profile_path = os.path.join(self.root, "install-profile.plist")
        devices_path = os.path.join(self.root, "devices.json")
        with open(self.profile, "rb") as f:
            profile = plistlib.load(f)
        profile["ProvisionedDevices"] = provisioned_devices
        with open(profile_path, "wb") as f:
            plistlib.dump(profile, f)
        if device_list is None:
            device_list = [{
                "identifier": "coredevice-device-1",
                "hardwareProperties": {"udid": "A" * 40},
            }]
        with open(devices_path, "w", encoding="utf-8") as f:
            json.dump({"result": {"devices": device_list}}, f)
        return subprocess.run([
            sys.executable, os.path.join(ROOT, "tools", "validate-install-target.py"),
            profile_path, bundle_id, devices_path, requested_id,
        ], capture_output=True, text=True)

    def test_install_target_accepts_device_in_profile(self):
        result = self.run_install_target_validator(["A" * 40])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Dispositivo autorizado pelo perfil", result.stdout)

    def test_install_target_rejects_device_missing_from_profile(self):
        result = self.run_install_target_validator(["B" * 40])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("UDID deste iPhone não está autorizado", result.stderr)

    def test_install_target_rejects_unknown_device_identifier(self):
        result = self.run_install_target_validator(
            ["A" * 40], device_list=[{
                "identifier": "different-device",
                "hardwareProperties": {"udid": "B" * 40},
            }]
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Dispositivo não encontrado", result.stderr)

    def test_install_target_rejects_bundle_id_mismatch(self):
        result = self.run_install_target_validator(["A" * 40], bundle_id="com.other.app")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Bundle ID do app não corresponde", result.stderr)

    def test_accepts_profile_matching_identity_and_reduced_entitlements(self):
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.identity)

    def test_rejects_entitlement_not_granted_by_profile(self):
        with open(self.entitlements, "rb") as f: values = plistlib.load(f)
        values["com.apple.developer.networking.networkextension"] = True
        with open(self.entitlements, "wb") as f: plistlib.dump(values, f)
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("não é permitido", result.stderr)

    def test_rejects_identity_not_in_profile(self):
        with open(self.identities, "w") as f: f.write("  1) " + "A" * 40 + ' "Other Identity"\n')
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DeveloperCertificates", result.stderr)

    def test_rejects_unsafe_zip_path(self):
        with zipfile.ZipFile(self.ipa, "w") as z: z.writestr("../outside.txt", b"x")
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("caminho inseguro", result.stderr)


    def test_rejects_control_characters_in_zip_paths(self):
        with zipfile.ZipFile(self.ipa, "w") as z:
            z.writestr("Payload/Test.app/bad\nname", b"x")
        result = subprocess.run(
            [sys.executable, VALIDATOR, "--inspect-ipa", self.ipa],
            capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("caracteres de controle", result.stderr)

    def test_rejects_symlink_entries(self):
        info = zipfile.ZipInfo("Payload/Test.app/link")
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(self.ipa, "w") as z:
            z.writestr(info, "target")
        result = subprocess.run(
            [sys.executable, VALIDATOR, "--inspect-ipa", self.ipa],
            capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("link simbólico", result.stderr)

    def test_rejects_suspicious_compression_ratio(self):
        with zipfile.ZipFile(self.ipa, "w", compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr("Payload/Test.app/large", b"A" * 20_000)
        result = subprocess.run(
            [sys.executable, VALIDATOR, "--inspect-ipa", self.ipa],
            capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Taxa de compressão suspeita", result.stderr)

    def test_rejects_duplicate_archive_paths(self):
        with zipfile.ZipFile(self.ipa, "w") as z:
            z.writestr("Payload/Test.app/Info.plist", b"one")
            z.writestr("Payload/Test.app/Info.plist", b"two")
        result = subprocess.run(
            [sys.executable, VALIDATOR, "--inspect-ipa", self.ipa],
            capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("entradas duplicadas", result.stderr)

if __name__ == "__main__":
    unittest.main()
