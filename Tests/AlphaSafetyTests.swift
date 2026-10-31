import XCTest
@testable import AutoRenew

final class AlphaSafetyTests: XCTestCase {
    func testStubBackendNeverClaimsRenewal() async {
        let backend = StubSigningBackend()
        let app = ManagedApp(bundleID: "test.example", name: "Test",
                             expiresAt: Date(timeIntervalSinceNow: 24 * 3600))
        let anisette = AnisetteData(headers: ["X-Apple-I-MD": "test"])

        do {
            _ = try await backend.refresh(app: app, anisette: anisette)
            XCTFail("The stub backend must never report a successful renewal")
        } catch let error as RefreshError {
            XCTAssertEqual(error, .notImplemented)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertGreaterThan(app.expiresAt, Date())
    }

    func testAnisetteDataRequiresExpectedHeader() {
        XCTAssertFalse(AnisetteData(headers: [:]).isValid)
        XCTAssertTrue(AnisetteData(headers: ["X-Apple-I-MD": "test"]).isValid)
    }

    func testRouterRejectsNonHTTPSProviders() async {
        let router = AnisetteRouter(urls: ["http://example.invalid/anisette"])
        do {
            _ = try await router.fetch()
            XCTFail("Non-HTTPS Anisette endpoints must be rejected")
        } catch let error as RefreshError {
            XCTAssertEqual(error, .anisetteUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
