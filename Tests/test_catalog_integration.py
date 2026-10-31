import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class CatalogIntegrationTests(unittest.TestCase):
    def test_catalog_is_primary_installer_tab(self):
        ui = read("ContentView.swift")
        self.assertIn("CatalogView().tabItem", ui)
        self.assertIn('Label("Installer"', ui)

    def test_catalog_fetch_is_bounded_and_https_only(self):
        source = read("CatalogProvider.swift")
        self.assertIn("URLSession.shared.bytes(for: request)", source)
        self.assertIn("maximumResponseBytes = 5 * 1_024 * 1_024", source)
        self.assertIn("data.count < maximumResponseBytes", source)
        self.assertIn('sourceURL.scheme?.lowercased() == "https"', source)
        self.assertIn('finalURL.scheme?.lowercased() != "https"', source)
        self.assertIn('url.scheme?.lowercased() == "https"', source)

    def test_side_store_required_fields_and_legacy_fallback(self):
        source = read("CatalogProvider.swift")
        for field in ('object["name"]', 'object["identifier"]', 'object["apps"]',
                      'value["bundleIdentifier"]', 'value["developerName"]',
                      'value["localizedDescription"]', 'value["iconURL"]',
                      'value["versions"]', 'value["date"]', 'value["downloadURL"]',
                      'value["size"]'):
            self.assertIn(field, source)
        self.assertIn("Backward compatibility with legacy AltSource fields", source)

    def test_catalog_never_claims_to_install_or_renew(self):
        source = read("CatalogView.swift")
        self.assertIn("não instala, assina, atualiza nem renova", source)
        self.assertIn('Button("Abrir IPA")', source)
        self.assertNotIn("SigningBackend", source)
        self.assertNotIn("RefreshCoordinator", source)

if __name__ == "__main__":
    unittest.main()
