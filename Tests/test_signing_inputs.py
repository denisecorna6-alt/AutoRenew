import datetime
import hashlib
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALIDATOR = os.path.join(ROOT, "tools", "validate-signing-inputs.py")
INSTALLER = os.path.join(ROOT, "tools", "install-to-iphone.sh")
INSTALLER_VIEW = os.path.join(ROOT, "InstallerView.swift")
CATALOG_VIEW = os.path.join(ROOT, "AppCatalogView.swift")
VAULT = os.path.join(ROOT, "SigningIdentityVault.swift")

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
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=5),
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
        with open(self.profile, "rb") as f: values = plistlib.load(f)
        values["ExpirationDate"] = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)
        with open(self.profile, "wb") as f: plistlib.dump(values, f)
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expirado", result.stderr)

    def test_catalog_and_installer_use_bounded_ipa_downloads(self):
        for path in (INSTALLER_VIEW, CATALOG_VIEW):
            source = Path(path).read_text(encoding="utf-8")
            self.assertIn("BoundedIPADownloader.download(for: request)", source)
            self.assertNotIn("URLSession.shared.download(for: request)", source)
        catalog = Path(CATALOG_VIEW).read_text(encoding="utf-8")
        self.assertIn("IPAInspector.inspect(fileURL: temporaryURL)", catalog)
        self.assertIn("maximumSourceJSONBytes", catalog)
        self.assertIn("URLSession.shared.bytes(for: request)", catalog)
        self.assertNotIn("URLSession.shared.data(for: request)", catalog)

    def test_device_installer_preflights_archive_and_verifies_each_profile(self):
        script = Path(INSTALLER).read_text(encoding="utf-8")
        preflight = script.index('python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa')
        extraction = script.index('ditto -x -k "$IPA_PATH"')
        cms_verify = script.index('security cms -V -i "$PROFILE"')
        cms_decode = script.index('security cms -D -i "$PROFILE"')
        self.assertLess(preflight, extraction)
        self.assertLess(cms_verify, cms_decode)
        self.assertIn("CFBundleIdentifier", script)
        self.assertIn("DeveloperCertificates", script)
        self.assertIn("-name '*.appex'", script)

    def test_signing_vault_source_exists(self):
        self.assertTrue(Path(VAULT).is_file(), VAULT)

    def test_signing_vault_uses_explicit_certificate_status_guards(self):
        source = Path(VAULT).read_text(encoding="utf-8")
        self.assertIn("let certificateStatus = SecIdentityCopyCertificate(identity, &certificate)", source)
        self.assertIn("guard certificateStatus == errSecSuccess else", source)
        self.assertIn("guard let certificate else", source)

    def test_rejects_unsafe_zip_path(self):
        with zipfile.ZipFile(self.ipa, "w") as z: z.writestr("../outside.txt", b"x")
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("caminho inseguro", result.stderr)

if __name__ == "__main__":
    unittest.main()
