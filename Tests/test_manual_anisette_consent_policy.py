import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
REFRESH = (ROOT / "RefreshCoordinator.swift").read_text(encoding="utf-8")
SETTINGS = (ROOT / "Models.swift").read_text(encoding="utf-8")
VIEW = (ROOT / "ContentView.swift").read_text(encoding="utf-8")

class ManualAnisetteConsentPolicyTests(unittest.TestCase):
    def test_background_refresh_never_enables_remote_anisette(self):
        self.assertIn("remoteRequestsEnabled: false", REFRESH)
        self.assertNotIn("remoteRequestsEnabled: settings.allowRemoteAnisette", REFRESH)

    def test_remote_opt_in_defaults_to_disabled(self):
        self.assertIn("var allowRemoteAnisette = false", SETTINGS)
        self.assertIn("allowRemoteAnisette = try values.decodeIfPresent(Bool.self, forKey: .allowRemoteAnisette) ?? false", SETTINGS)

    def test_network_test_is_explicitly_gated_in_settings_ui(self):
        self.assertIn("guard store.settings.allowRemoteAnisette else", VIEW)
        self.assertIn("RemoteAnisetteProvider(", VIEW)

if __name__ == "__main__":
    unittest.main()
