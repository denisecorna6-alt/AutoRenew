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

    func testProfileImportRejectsFilesLargerThan25MB() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("oversized.mobileprovision")
        let bytes = Data(repeating: 0x41, count: ProfileImporter.maximumFileSize + 1)
        try bytes.write(to: source)

        XCTAssertThrowsError(try ProfileImporter.importProfile(from: source, into: root)) { error in
            XCTAssertEqual(error as? ProfileImportError, .fileTooLarge)
        }
    }

    func testIPAInspectorAcceptsZIPContainerAndComputesDigest() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("sample.ipa")
        let bytes = Data([0x50, 0x4B, 0x03, 0x04, 0x10, 0x20, 0x30, 0x40])
        try bytes.write(to: source)

        let inspection = try IPAInspector.inspect(fileURL: source)
        XCTAssertEqual(inspection.fileName, "sample.ipa")
        XCTAssertEqual(inspection.byteCount, bytes.count)
        XCTAssertEqual(inspection.sha256.count, 64)
    }

    func testIPAInspectorRejectsNonZIPFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("not-an-ipa.ipa")
        try Data("not a zip archive".utf8).write(to: source)

        XCTAssertThrowsError(try IPAInspector.inspect(fileURL: source)) { error in
            XCTAssertEqual(error as? IPAInspectionError, .invalidArchive)
        }
    }

    func testIPAInspectorRejectsWrongExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("archive.zip")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: source)

        XCTAssertThrowsError(try IPAInspector.inspect(fileURL: source)) { error in
            XCTAssertEqual(error as? IPAInspectionError, .unsupportedExtension)
        }
    }


    func testProvisioningProfileParserExtractsMetadataAndMatchesBundleID() throws {
        let expiration = Date(timeIntervalSince1970: 2_000_000_000)
        let data = try makeProvisioningProfilePayload(
            applicationIdentifier: "ABCDE12345.com.example.reader",
            expirationDate: expiration
        )

        let profile = try ProvisioningProfileParser.parse(data)
        XCTAssertEqual(profile.name, "Alpha Development")
        XCTAssertEqual(profile.uuid, "PROFILE-UUID")
        XCTAssertEqual(profile.teamIdentifiers, ["ABCDE12345"])
        XCTAssertEqual(profile.developerCertificates, [Data([0x30, 0x01, 0x00])])
        XCTAssertTrue(profile.matches(bundleIdentifier: "com.example.reader"))
        XCTAssertFalse(profile.matches(bundleIdentifier: "com.example.other"))

        let report = profile.metadataReport(for: "com.example.reader", now: Date(timeIntervalSince1970: 1_900_000_000))
        XCTAssertTrue(report.metadataIsCompatible)
        XCTAssertFalse(report.cmsSignatureVerified)
        XCTAssertTrue(report.hasDeviceInstallScope)
    }

    func testProvisioningProfileParserSupportsWildcardBundleIDSafely() throws {
        let data = try makeProvisioningProfilePayload(
            applicationIdentifier: "ABCDE12345.com.example.*",
            expirationDate: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let profile = try ProvisioningProfileParser.parse(data)

        XCTAssertTrue(profile.matches(bundleIdentifier: "com.example.reader"))
        XCTAssertFalse(profile.matches(bundleIdentifier: "com.example"))
        XCTAssertFalse(profile.matches(bundleIdentifier: "com.examples.reader"))
        XCTAssertFalse(profile.matches(bundleIdentifier: "com.example.*"))
    }

    func testProvisioningProfileMetadataReportsExpiredProfiles() throws {
        let data = try makeProvisioningProfilePayload(
            applicationIdentifier: "ABCDE12345.com.example.reader",
            expirationDate: Date(timeIntervalSince1970: 1_000)
        )
        let profile = try ProvisioningProfileParser.parse(data)
        let report = profile.metadataReport(
            for: "com.example.reader",
            now: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertTrue(report.isExpired)
        XCTAssertFalse(report.metadataIsCompatible)
        XCTAssertFalse(report.cmsSignatureVerified)
    }

    func testProvisioningProfileParserRejectsMissingCMSPlistPayload() {
        XCTAssertThrowsError(try ProvisioningProfileParser.parse(Data("not a profile".utf8))) { error in
            XCTAssertEqual(error as? ProvisioningProfileParseError, .payloadNotFound)
        }
    }

    private func makeProvisioningProfilePayload(
        applicationIdentifier: String,
        expirationDate: Date
    ) throws -> Data {
        let plist: [String: Any] = [
            "Name": "Alpha Development",
            "UUID": "PROFILE-UUID",
            "CreationDate": Date(timeIntervalSince1970: 1_700_000_000),
            "ExpirationDate": expirationDate,
            "TeamIdentifier": ["ABCDE12345"],
            "ApplicationIdentifierPrefix": ["ABCDE12345"],
            "ProvisionedDevices": ["00008030-TEST-DEVICE"],
            "DeveloperCertificates": [Data([0x30, 0x01, 0x00])],
            "Entitlements": [
                "application-identifier": applicationIdentifier,
                "get-task-allow": true,
                "com.apple.developer.team-identifier": "ABCDE12345"
            ]
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        return Data("CMS-ENVELOPE-TEST".utf8) + plistData + Data("CMS-TRAILER".utf8)
    }


    func testInstallerDownloadPolicyRejectsHTTPRedirect() throws {
        let source = URL(string: "https://github.com/example/app.ipa")!
        let responseURL = URL(string: "http://example.invalid/app.ipa")!
        let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        XCTAssertThrowsError(try InstallerDownloadPolicy.validatedReleaseFilename(
            sourceURL: source, response: response, assetName: "AutoRenew.ipa", fileSize: 1024
        )) { error in
            XCTAssertEqual(error as? InstallerDownloadError, .insecureURL)
        }
    }

    func testInstallerDownloadPolicyRejectsOversizedAndInvalidAssets() throws {
        let source = URL(string: "https://github.com/example/app.ipa")!
        let response = HTTPURLResponse(url: source, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        XCTAssertThrowsError(try InstallerDownloadPolicy.validatedReleaseFilename(
            sourceURL: source, response: response, assetName: "AutoRenew.ipa",
            fileSize: InstallerDownloadPolicy.maximumFileSize + 1
        )) { error in
            XCTAssertEqual(error as? InstallerDownloadError, .invalidFileSize)
        }
        XCTAssertThrowsError(try InstallerDownloadPolicy.validatedReleaseFilename(
            sourceURL: source, response: response, assetName: "readme.txt", fileSize: 1024
        )) { error in
            XCTAssertEqual(error as? InstallerDownloadError, .invalidFilename)
        }
    }

    func testInstallerDownloadPolicyKeepsExistingIPAAndCreatesUniqueName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = root.appendingPathComponent("AutoRenew.ipa")
        try Data("keep me".utf8).write(to: existing)

        let destination = InstallerDownloadPolicy.uniqueDestination(in: root, filename: "AutoRenew.ipa")
        XCTAssertNotEqual(destination, existing)
        XCTAssertTrue(destination.lastPathComponent.hasSuffix(".ipa"))
        XCTAssertEqual(try Data(contentsOf: existing), Data("keep me".utf8))
    }


    func testRenewalDateMustBeFutureAndLaterThanCurrentExpiry() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let currentExpiry = now.addingTimeInterval(24 * 3600)

        XCTAssertTrue(RefreshCoordinator.isValidRenewalDate(
            currentExpiry.addingTimeInterval(7 * 24 * 3600),
            previous: currentExpiry,
            now: now
        ))
        XCTAssertFalse(RefreshCoordinator.isValidRenewalDate(
            currentExpiry, previous: currentExpiry, now: now
        ))
        XCTAssertFalse(RefreshCoordinator.isValidRenewalDate(
            now.addingTimeInterval(-60), previous: currentExpiry, now: now
        ))
    }

}
