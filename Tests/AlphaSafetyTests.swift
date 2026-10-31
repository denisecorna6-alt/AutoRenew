import XCTest
@testable import AutoRenew

final class AlphaSafetyTests: XCTestCase {
    func testStubBackendNeverClaimsRenewalOrChangesExpiry() async {
        let backend = StubSigningBackend()
        XCTAssertFalse(backend.isAvailable)
        let expiry = Date(timeIntervalSinceNow: 24 * 3600)
        let app = ManagedApp(bundleID: "test.example", name: "Test", expiresAt: expiry)
        let anisette = AnisetteData(headers: ["X-Apple-I-MD": "test"])

        do {
            _ = try await backend.refresh(app: app, anisette: anisette)
            XCTFail("The stub backend must never report a successful renewal")
        } catch let error as RefreshError {
            XCTAssertEqual(error, .notImplemented)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(app.expiresAt, expiry)
    }

    func testAnisetteDataRequiresExpectedNonemptyHeader() {
        XCTAssertFalse(AnisetteData(headers: [:]).isValid)
        XCTAssertFalse(AnisetteData(headers: ["X-Apple-I-MD": ""]).isValid)
        XCTAssertTrue(AnisetteData(headers: ["X-Apple-I-MD": "test"]).isValid)
    }

    func testAnisetteDataRejectsFutureAndExpiredTimestamps() {
        let headers = ["X-Apple-I-MD": "test"]
        XCTAssertFalse(AnisetteData(headers: headers, fetched: Date().addingTimeInterval(60)).isValid)
        XCTAssertFalse(AnisetteData(headers: headers, fetched: Date().addingTimeInterval(-301)).isValid)
        XCTAssertTrue(AnisetteData(headers: headers, fetched: Date().addingTimeInterval(-30)).isValid)
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

    func testProfileImportCopiesFileAndCalculatesSHA256() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDirectory.appendingPathComponent("sample.mobileprovision")
        let bytes = Data("profile-test-content".utf8)
        try bytes.write(to: source)

        let profile = try ProfileImporter.importProfile(from: source, into: destinationDirectory)
        let stored = destinationDirectory.appendingPathComponent(profile.storedFileName)

        XCTAssertEqual(profile.sha256, ProfileImporter.sha256(bytes))
        XCTAssertEqual(profile.byteCount, bytes.count)
        XCTAssertEqual(try Data(contentsOf: stored), bytes)
        XCTAssertEqual(profile.originalFileName, "sample.mobileprovision")
    }

    func testProfileImportRejectsOtherFileExtensions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("not-a-profile.txt")
        try Data("not a profile".utf8).write(to: source)

        XCTAssertThrowsError(try ProfileImporter.importProfile(from: source, into: root)) { error in
            XCTAssertEqual(error as? ProfileImportError, .unsupportedFile)
        }
    }
}
