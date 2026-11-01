import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
COMPOSE = (ROOT / "infra/anisette/compose.yaml").read_text(encoding="utf-8")
CADDY = (ROOT / "infra/anisette/Caddyfile").read_text(encoding="utf-8")
ENV = (ROOT / "infra/anisette/.env.example").read_text(encoding="utf-8")
IGNORE = (ROOT / "infra/anisette/.gitignore").read_text(encoding="utf-8")

class AnisetteInfraPolicyTests(unittest.TestCase):
    def test_acme_email_is_required_before_compose_starts(self):
        self.assertIn("ACME_EMAIL: ${ACME_EMAIL:?", COMPOSE)
        self.assertIn("email {$ACME_EMAIL}", CADDY)
        self.assertNotIn("{$ACME_EMAIL:}", CADDY)

    def test_images_must_be_pinned_to_explicit_digests(self):
        self.assertIn("ANISETTE_IMAGE:?", COMPOSE)
        self.assertIn("CADDY_IMAGE:?", COMPOSE)
        self.assertIn("@sha256:REPLACE_WITH_VERIFIED_DIGEST", ENV)

    def test_anisette_port_is_internal_only(self):
        self.assertIn('      - "6969"', COMPOSE)
        self.assertNotIn('"6969:6969"', COMPOSE)

    def test_real_environment_file_is_ignored(self):
        self.assertIn(".env", IGNORE)

if __name__ == "__main__":
    unittest.main()
