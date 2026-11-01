import XCTest
@testable import AutoRenew

final class SigningBackendTests: XCTestCase {
    func testUnavailableBackendFailsClosedWithoutChangingExpiry() async {
        let backend = UnavailableSigningBackend()
        let expiry = Date(timeIntervalSince1970: 1_900_000_000)
        let app = ManagedApp(
            bundleID: "com.example.fixture",
            name: "Fixture",
            expiresAt: expiry
        )

        XCTAssertFalse(backend.isAvailable)

        do {
            _ = try await backend.refresh(app: app)
            XCTFail("The unavailable backend must never report a renewal.")
        } catch let error as RefreshError {
            XCTAssertEqual(error, .integrationUnavailable)
        } catch {
            XCTFail("Unexpected error: \\(error)")
        }

        XCTAssertEqual(app.expiresAt, expiry)
    }

    func testLegacySettingsIgnoreRemovedCredentialAndAnisetteKeys() throws {
        let legacySnapshot = Data(
            #"{"appleID":"","anisetteURLs":[],"thresholdHours":48.0,"blockDomains":false}"#.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: legacySnapshot)

        XCTAssertEqual(settings.thresholdHours, 48.0)
        XCTAssertFalse(settings.blockDomains)
    }
}
