import datetime
import hashlib
import os
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALIDATOR = os.path.join(ROOT, "tools", "validate-signing-inputs.py")
SIGNER = os.path.join(ROOT, "tools", "sign-ipa-macos.sh")
DEVICE_INSTALLER = os.path.join(ROOT, "tools", "install-to-iphone.sh")

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
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) + datetime.timedelta(days=5),
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

    def test_rejects_expired_profile(self):
        with open(self.profile, "rb") as f: profile = plistlib.load(f)
        profile["ExpirationDate"] = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) - datetime.timedelta(days=1)
        with open(self.profile, "wb") as f: plistlib.dump(profile, f)
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expirado", result.stderr)

    def test_signer_uses_secure_gui_prompt_and_restores_keychain_search_list(self):
        script = open(SIGNER, encoding="utf-8").read()
        self.assertNotIn("P12_PASSWORD", script)
        self.assertIn('security import "$P12" -k "$KEYCHAIN"', script)
        self.assertIn('security list-keychains -d user > "$ORIGINAL_KEYCHAINS_FILE"', script)
        self.assertIn('security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}"', script)

    def test_device_installer_validates_before_extracting_and_verifies_cms(self):
        script = open(DEVICE_INSTALLER, encoding="utf-8").read()
        validate = script.index('validate-signing-inputs.py" --inspect-ipa')
        extract = script.index('ditto -x -k "$IPA_PATH"')
        self.assertLess(validate, extract)
        self.assertIn('security cms -V -i "$APP_PATH/embedded.mobileprovision"', script)

    def test_rejects_unsafe_zip_path(self):
        with zipfile.ZipFile(self.ipa, "w") as z: z.writestr("../outside.txt", b"x")
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("caminho inseguro", result.stderr)

if __name__ == "__main__":
    unittest.main()
