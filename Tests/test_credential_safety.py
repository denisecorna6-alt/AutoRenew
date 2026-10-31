import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class CredentialSafetyTests(unittest.TestCase):
    def test_ui_and_settings_do_not_collect_credentials(self):
        ui = read("ContentView.swift")
        models = read("Models.swift")
        backend = read("SigningBackend.swift")
        self.assertNotIn("SecureField", ui)
        self.assertNotIn("Salvar credenciais", ui)
        self.assertNotIn("appleID", ui)
        self.assertNotIn("appleID", models)
        self.assertNotIn("anisetteURLs", models)
        self.assertNotIn("twoFactorCode", backend)
        self.assertNotIn("password:", backend)

    def test_stub_fails_closed_before_network(self):
        backend = read("SigningBackend.swift")
        coordinator = read("RefreshCoordinator.swift")
        self.assertIn("let isAvailable = false", backend)
        self.assertIn("throw RefreshError.notImplemented", backend)
        self.assertIn("guard backend.isAvailable else", coordinator)
        self.assertNotIn("AnisetteRouter", coordinator)
        self.assertNotIn("Date(timeIntervalSinceNow: 7 * 86_400)", backend)
        self.assertIn("Nenhuma rede", coordinator)

    def test_legacy_cleanup_is_narrow_and_migration_rewrites_snapshot(self):
        cleanup = read("LegacyCredentialCleanup.swift")
        store = read("AppStore.swift")
        self.assertIn('kSecAttrAccount as String: "applePassword"', cleanup)
        self.assertIn("SecItemDelete(query as CFDictionary)", cleanup)
        self.assertIn("LegacyCredentialCleanup.run()", store)
        self.assertIn("if restoredSnapshot { save() }", store)

    def test_notifications_do_not_claim_renewal(self):
        notifier = read("Notifier.swift").lower()
        self.assertNotIn("renovar agora", notifier)
        self.assertIn("renovação automática não está disponível", notifier)

    def test_sidestore_shortcut_guide_is_user_driven_and_credential_free(self):
        guide = read("SideStoreAutomationGuide.swift")
        ui = read("ContentView.swift")
        self.assertIn("Refresh All Apps", guide)
        self.assertIn("iOS 17", guide)
        self.assertIn("LocalDevVPN", guide)
        self.assertIn("27 segundos", guide)
        self.assertIn("SideStoreAutomationGuide()", ui)
        self.assertNotIn("PKCS12", guide)
        self.assertNotIn("Apple ID", guide)
        self.assertNotIn("URLSession", guide)

    def test_demo_apps_never_schedule_real_expiry_reminders(self):
        model = read("Models.swift")
        store = read("AppStore.swift")
        notifier = read("Notifier.swift")
        ui = read("ContentView.swift")
        self.assertIn("var isDemo: Bool? = nil", model)
        self.assertIn("isDemo: true", store)
        self.assertIn('bundleID.hasPrefix("demo.")', store)
        self.assertIn("app.isDemo = true", store)
        self.assertIn("$0.isDemo != true", notifier)
        self.assertIn("store.apps.contains(where: { $0.isActive && $0.isDemo != true })", ui)

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

    def test_background_task_success_reflects_refresh_outcome(self):
        coordinator = read("RefreshCoordinator.swift")
        scheduler = read("BackgroundScheduler.swift")
        self.assertIn("struct RefreshRunSummary", coordinator)
        self.assertIn("!cancelled && failed == 0 && deferred == 0", coordinator)
        self.assertIn("failed: due.count", coordinator)
        self.assertIn("static let deferredWork", coordinator)
        self.assertIn("if Task.isCancelled", coordinator)
        self.assertIn("summary.backgroundTaskSucceeded", scheduler)
        self.assertNotIn("success: !work.isCancelled", scheduler)

    def test_supported_interface_orientations_are_explicit(self):
        project = read("project.yml")
        self.assertIn("UISupportedInterfaceOrientations:", project)
        self.assertIn('"UISupportedInterfaceOrientations~ipad":', project)
        self.assertIn("UIInterfaceOrientationPortrait", project)
        self.assertIn("UIInterfaceOrientationLandscapeLeft", project)
        self.assertIn("UIInterfaceOrientationLandscapeRight", project)
        self.assertIn("UIInterfaceOrientationPortraitUpsideDown", project)

    def test_unused_network_permission_is_removed(self):
        project = read("project.yml")
        self.assertNotIn("NSLocalNetworkUsageDescription", project)
        self.assertFalse((ROOT / "Anisette.swift").exists())
        self.assertFalse((ROOT / "Keychain.swift").exists())

if __name__ == "__main__":
    unittest.main()
