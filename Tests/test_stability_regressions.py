import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class StabilityRegressionTests(unittest.TestCase):
    def test_swiftui_interpolations_and_environment_keypaths_are_not_double_escaped(self):
        ui = read("ContentView.swift")
        self.assertNotIn(r"\\(", ui)
        self.assertNotIn(r"\\.", ui)
        self.assertIn(r"@Environment(\.dismiss)", ui)
        self.assertIn(r"Text(\"\\(max(Int(app.daysLeft.rounded(.up)), 0))d\")", ui)

    def test_refresh_coordinator_uses_current_notification_api(self):
        coordinator = read("RefreshCoordinator.swift")
        self.assertNotIn("Notifier.reschedule(AppStore.shared.apps)", coordinator)
        self.assertIn("await Notifier.reschedule(apps, thresholdHours: thresholdHours)", coordinator)

    def test_notification_permission_is_user_initiated(self):
        app = read("AutoRenewApp.swift")
        ui = read("ContentView.swift")
        self.assertNotIn("Notifier.requestAuth()", app)
        self.assertIn("Notifier.requestAuthorization()", ui)
        self.assertIn("Button(\"Ativar lembretes\")", ui)

if __name__ == "__main__":
    unittest.main()
