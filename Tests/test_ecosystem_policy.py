import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class EcosystemSafetyPolicy(unittest.TestCase):
    def test_external_downloads_are_streamed_with_hard_limits(self):
        policy = read("InstallerDownloadPolicy.swift")
        self.assertIn("URLSession.shared.bytes(for: request)", policy)
        self.assertIn("maximumBytes", policy)
        self.assertIn("received <= maximumBytes", policy)
        self.assertIn("response.url", policy)
        self.assertIn('url.scheme?.lowercased() == "https"', policy)
        for path in ("AppCatalogView.swift", "InstallerView.swift"):
            source = read(path)
            self.assertIn("InstallerDownloadPolicy.fetchData", source)
            self.assertIn("InstallerDownloadPolicy.download", source)

    def test_signing_helper_preserves_all_ipa_root_content(self):
        script = read("tools/sign-ipa-macos.sh")
        self.assertIn('EXTRACTED="$WORK/extracted"', script)
        self.assertIn('ditto -x -k "$IPA_PATH" "$EXTRACTED"', script)
        self.assertIn('ditto -c -k --sequesterRsrc "$EXTRACTED" "$WORK/signed.ipa"', script)
        self.assertNotIn("--keepParent Payload", script)
        self.assertIn('BUNDLE="$EXTRACTED/$REL_BUNDLE"', script)

    def test_signing_helper_never_exposes_pkcs12_password_in_process_args(self):
        script = read("tools/sign-ipa-macos.sh")
        self.assertIn("security find-identity -v -p codesigning", script)
        self.assertIn("security cms -V -i", script)
        self.assertNotIn("P12_PASSWORD", script)
        self.assertNotIn("security import", script)
        self.assertNotIn("security list-keychains", script)
        self.assertNotIn("security create-keychain", script)

    def test_device_install_verifies_cms_and_profile_identity(self):
        script = read("tools/install-to-iphone.sh")
        self.assertIn("security cms -V -i", script)
        self.assertIn("application-identifier", script)
        self.assertIn("Bundle ID do app não corresponde", script)
        self.assertIn("codesign --verify --deep --strict", script)

    def test_signing_backend_stays_fail_closed(self):
        backend = read("SigningBackend.swift")
        self.assertIn("let isAvailable = false", backend)
        self.assertIn("throw RefreshError.notImplemented", backend)
        coordinator = read("RefreshCoordinator.swift")
        self.assertIn("guard selectedBackend.isAvailable", coordinator)
        self.assertIn("Nenhuma alteração foi feita", coordinator)

    def test_app_records_reject_invalid_bundle_ids_and_past_expiry(self):
        store = read("AppStore.swift")
        self.assertIn('of: #\"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$\"#', store)
        self.assertIn("normalizedName.count <= 80", store)
        self.assertIn("normalizedID.count <= 255", store)
        self.assertIn("expiresAt > Date()", store)
        self.assertIn("func removeApps(at offsets: IndexSet)", store)

    def test_manual_refresh_forces_all_apps_and_reports_result(self):
        dashboard = read("ContentView.swift")
        self.assertIn('trigger: "manual", budget: .seconds(30), force: true', dashboard)
        self.assertIn("summary.renewed", dashboard)
        self.assertIn("summary.failed", dashboard)

    def test_private_signing_material_and_downloads_are_excluded_from_backups(self):
        vault = read("SigningIdentityVault.swift")
        profiles = read("ProfileInventory.swift")
        catalog = read("AppCatalogView.swift")
        self.assertIn("isExcludedFromBackup = true", vault)
        self.assertIn(".completeFileProtection", vault)
        self.assertIn("records.removeAll { $0.id == id }", vault)
        self.assertIn("isExcludedFromBackup = true", profiles)
        self.assertIn("isExcludedFromBackup = true", catalog)

    def test_notification_consent_is_user_initiated_and_bounded(self):
        app = read("AutoRenewApp.swift")
        ui = read("ContentView.swift")
        notifier = read("Notifier.swift")
        coordinator = read("RefreshCoordinator.swift")
        self.assertNotIn("Notifier.requestAuth()", app)
        self.assertIn('Button("Ativar lembretes")', ui)
        self.assertIn("requestAuthorization", notifier)
        self.assertIn("notificationSettings()", notifier)
        self.assertIn("maximumPendingReminders = 60", notifier)
        self.assertIn("await Notifier.reschedule", coordinator)

    def test_supported_interface_orientations_are_explicit(self):
        project = read("project.yml")
        self.assertIn("UISupportedInterfaceOrientations:", project)
        self.assertIn('"UISupportedInterfaceOrientations~ipad":', project)
        self.assertIn("UIInterfaceOrientationPortrait", project)
        self.assertIn("UIInterfaceOrientationLandscapeLeft", project)
        self.assertIn("UIInterfaceOrientationLandscapeRight", project)

    def test_unused_local_network_permission_is_not_requested(self):
        project = read("project.yml")
        self.assertNotIn("NSLocalNetworkUsageDescription", project)

    def test_ci_runs_tests_and_builds_both_targets_for_main_prs(self):
        workflow = read(".github/workflows/official-ci.yml")
        self.assertIn("pull_request:", workflow)
        self.assertIn("branches: [main, beta]", workflow)
        self.assertIn("python3 -m unittest discover", workflow)
        self.assertIn("-scheme AutoRenew", workflow)
        self.assertIn("-scheme AutoRenewInstaller", workflow)
        self.assertIn("contents: read", workflow)
        self.assertNotIn("contents: write", workflow)

    def test_two_apps_and_unit_test_target_are_declared(self):
        project = read("project.yml")
        self.assertIn("  AutoRenew:", project)
        self.assertIn("  AutoRenewInstaller:", project)
        self.assertIn("  AutoRenewTests:", project)

    def test_ai_central_is_manual_and_does_not_merge_or_release(self):
        workflow = read(".github/workflows/ai-central.yml")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("schedule:", workflow)
        self.assertNotIn("gh pr merge", workflow)
        self.assertNotIn("gh release create", workflow)

if __name__ == "__main__":
    unittest.main()
