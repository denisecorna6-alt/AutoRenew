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

    func testRemoteAnisetteV3ProviderFailsClosedUntilProvisioningExists() async {
        let provider = RemoteAnisetteProvider(url: URL(string: "https://ani.sidestore.io")!)
        do {
            _ = try await provider.fetch()
            XCTFail("A root GET must not be treated as an Anisette V3 implementation")
        } catch let error as RefreshError {
            XCTAssertEqual(error, .anisetteUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(AppSettings().anisetteURLs.isEmpty)
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

    func testAnisetteV3HeadersRequestUsesPOSTAndBase64ProvisioningState() throws {
        let state = AnisetteV3ProvisioningState(
            identifier: Data([0x01, 0x02, 0x03]),
            adiPB: Data([0x04, 0x05, 0x06])
        )
        let request = try AnisetteV3HeadersClient.makeRequest(
            serverURL: URL(string: "https://anisette.example/")!,
            state: state
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://anisette.example/v3/get_headers")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object["identifier"], Data([0x01, 0x02, 0x03]).base64EncodedString())
        XCTAssertEqual(object["adi_pb"], Data([0x04, 0x05, 0x06]).base64EncodedString())
    }

    func testAnisetteV3HeadersRequestRejectsInsecureOrCredentialBearingURLs() throws {
        let state = AnisetteV3ProvisioningState(identifier: Data([1]), adiPB: Data([2]))
        for rawURL in [
            "http://anisette.example",
            "https://user:pass@anisette.example",
            "https://anisette.example/path?token=secret",
            "https://anisette.example/#fragment"
        ] {
            XCTAssertThrowsError(try AnisetteV3HeadersClient.makeRequest(
                serverURL: URL(string: rawURL)!, state: state
            ))
        }
    }

    func testAnisetteV3HeadersResponseMapsRequiredAppleHeaders() throws {
        let payload = Data("""
        {
          "result": "Headers",
          "X-Apple-I-MD-M": "machine",
          "X-Apple-I-MD": "otp",
          "X-Apple-I-MD-RINFO": "routing"
        }
        """.utf8)

        let anisette = try AnisetteV3HeadersClient.decodeResponse(payload)
        XCTAssertEqual(anisette.headers["X-Apple-I-MD-M"], "machine")
        XCTAssertEqual(anisette.headers["X-Apple-I-MD"], "otp")
        XCTAssertEqual(anisette.headers["X-Apple-I-MD-RINFO"], "routing")
        XCTAssertTrue(anisette.isValid)
    }

    func testAnisetteV3HeadersResponseRejectsServerErrorsAndMissingHeaders() {
        for payload in [
            Data(#"{"result":"GetHeadersError","message":"unavailable"}"#.utf8),
            Data(#"{"result":"Headers","X-Apple-I-MD-M":"machine"}"#.utf8),
            Data("not-json".utf8)
        ] {
            XCTAssertThrowsError(try AnisetteV3HeadersClient.decodeResponse(payload))
        }
    }

    func testAnisetteV3ProvisioningStateRejectsEmptyAndOversizedData() {
        XCTAssertFalse(AnisetteV3ProvisioningState(identifier: Data(), adiPB: Data([1])).isUsable)
        XCTAssertFalse(AnisetteV3ProvisioningState(identifier: Data([1]), adiPB: Data()).isUsable)
        XCTAssertTrue(AnisetteV3ProvisioningState(identifier: Data([1]), adiPB: Data([2])).isUsable)
    }


    func testAnisetteV3StoredStateRoundTripsWithoutLosingProvisioningData() throws {
        let identifier = Data(repeating: 0x11, count: 16)
        let adiPB = Data(repeating: 0x22, count: 128)
        let state = try AnisetteV3StoredState(identifier: identifier, adiPB: adiPB)
        let encoded = try PropertyListEncoder().encode(state)
        let decoded = try PropertyListDecoder().decode(AnisetteV3StoredState.self, from: encoded)

        XCTAssertEqual(decoded.identifier, identifier)
        XCTAssertEqual(decoded.adiPB, adiPB)
        XCTAssertEqual(decoded.provisioningState?.identifier, identifier)
        XCTAssertEqual(decoded.provisioningState?.adiPB, adiPB)
    }

    func testAnisetteV3StoredStateAllowsUnprovisionedIdentifierOnly() throws {
        let state = try AnisetteV3StoredState(identifier: Data(repeating: 0x33, count: 16))
        XCTAssertNil(state.adiPB)
        XCTAssertNil(state.provisioningState)
    }

    func testAnisetteV3StoredStateRejectsInvalidIdentifierAndADIBlob() {
        XCTAssertThrowsError(try AnisetteV3StoredState(identifier: Data(repeating: 0x01, count: 15)))
        XCTAssertThrowsError(try AnisetteV3StoredState(
            identifier: Data(repeating: 0x01, count: 16),
            adiPB: Data()
        ))
        XCTAssertThrowsError(try AnisetteV3StoredState(
            identifier: Data(repeating: 0x01, count: 16),
            adiPB: Data(repeating: 0x02, count: 1_000_001)
        ))
    }


    func testAnisetteV3ProvisioningProtocolEnforcesDocumentedMessageSequence() throws {
        var machine = AnisetteV3ProvisioningStateMachine()
        XCTAssertEqual(
            try machine.receive(json: Data(#"{"result":"GiveIdentifier"}"#.utf8)),
            .sendIdentifier
        )
        XCTAssertEqual(
            try machine.receive(json: Data(#"{"result":"GiveStartProvisioningData"}"#.utf8)),
            .requestStartProvisioning
        )
        XCTAssertEqual(
            try machine.receive(json: Data(#"{"result":"GiveEndProvisioningData","cpim":"client-metadata"}"#.utf8)),
            .requestFinishProvisioning(cpim: "client-metadata")
        )
        let adi = Data(repeating: 0x5A, count: 64)
        let encoded = adi.base64EncodedString()
        XCTAssertEqual(
            try machine.receive(json: Data(#"{"result":"ProvisioningSuccess","adi_pb":"\#(encoded)"}"#.utf8)),
            .completed(adiPB: adi)
        )
        XCTAssertThrowsError(try machine.receive(json: Data(#"{"result":"GiveIdentifier"}"#.utf8))) { error in
            XCTAssertEqual(error as? AnisetteV3ProvisioningProtocolError, .alreadyCompleted)
        }
    }

    func testAnisetteV3ProvisioningProtocolRejectsOutOfOrderAndTimeout() throws {
        var machine = AnisetteV3ProvisioningStateMachine()
        XCTAssertThrowsError(try machine.receive(json: Data(#"{"result":"GiveStartProvisioningData"}"#.utf8))) { error in
            XCTAssertEqual(error as? AnisetteV3ProvisioningProtocolError, .unexpectedMessage)
        }
        XCTAssertThrowsError(try machine.receive(json: Data(#"{"result":"Timeout"}"#.utf8))) { error in
            XCTAssertEqual(error as? AnisetteV3ProvisioningProtocolError, .timedOut)
        }
    }

    func testAnisetteV3ProvisioningProtocolRejectsMalformedAndOversizedMessages() {
        for payload in [
            Data(#"{"result":"UnknownStep"}"#.utf8),
            Data(#"{"result":"GiveEndProvisioningData","cpim":""}"#.utf8),
            Data(#"{"result":"ProvisioningSuccess","adi_pb":"not-base64!"}"#.utf8),
            Data(#"{"result":"ProvisioningSuccess","adi_pb":""}"#.utf8),
            Data(#"{"result":"GiveEndProvisioningData"}"#.utf8)
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(AnisetteV3ProvisioningMessage.self, from: payload))
        }
    }

    func testAnisetteV3ProvisioningRepliesUseExactJSONFieldsAndBase64Identifier() throws {
        let identifier = Data(repeating: 0xA5, count: 16)
        let identifierObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: AnisetteV3ProvisioningReply.identifier(identifier).jsonData()) as? [String: String]
        )
        XCTAssertEqual(identifierObject["identifier"], identifier.base64EncodedString())

        let startObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: AnisetteV3ProvisioningReply.spim("spim-value").jsonData()) as? [String: String]
        )
        XCTAssertEqual(startObject["spim"], "spim-value")

        let finishObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: AnisetteV3ProvisioningReply.finish(ptm: "ptm-value", tk: "tk-value").jsonData()) as? [String: String]
        )
        XCTAssertEqual(finishObject["ptm"], "ptm-value")
        XCTAssertEqual(finishObject["tk"], "tk-value")
    }

    func testAnisetteV3ProvisioningRepliesRejectInvalidSensitivePayloads() {
        XCTAssertThrowsError(try AnisetteV3ProvisioningReply.identifier(Data([1])).jsonData())
        XCTAssertThrowsError(try AnisetteV3ProvisioningReply.spim("").jsonData())
        XCTAssertThrowsError(try AnisetteV3ProvisioningReply.finish(ptm: "", tk: "tk").jsonData())
    }


    func testAnisetteV3AppleRequestUsesSecureAppleEndpointAndDerivedIdentityHeaders() throws {
        let identifier = Data((0..<16).map { UInt8($0) })
        let clientInfo = AnisetteV3AppleClientInfo(clientInfo: "test-client", userAgent: "Xcode")
        let request = try AnisetteV3AppleProvisioningClient.makeAppleRequest(
            url: URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!,
            method: "GET",
            body: nil,
            identifier: identifier,
            clientInfo: clientInfo,
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Mme-Client-Info"), "test-client")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Xcode")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "text/x-xml-plist")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Mme-Device-Id"), "00010203-0405-0607-0809-0A0B0C0D0E0F")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Apple-I-MD-LU")?.count, 64)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Apple-I-TimeZone"), "UTC")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Apple-Locale"), "en_US")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Apple-I-Client-Time"), "1970-01-01T00:00:00+00:00")
    }

    func testAnisetteV3AppleRequestRejectsNonAppleHostsAndInvalidIdentity() {
        let clientInfo = AnisetteV3AppleClientInfo(clientInfo: "test-client", userAgent: "Xcode")
        for rawURL in ["http://gsa.apple.com/lookup", "https://apple.com.attacker.example/lookup"] {
            XCTAssertThrowsError(try AnisetteV3AppleProvisioningClient.makeAppleRequest(
                url: URL(string: rawURL)!,
                method: "GET",
                body: nil,
                identifier: Data(repeating: 1, count: 16),
                clientInfo: clientInfo
            ))
        }
        XCTAssertThrowsError(try AnisetteV3AppleProvisioningClient.makeAppleRequest(
            url: URL(string: "https://gsa.apple.com/lookup")!,
            method: "GET",
            body: nil,
            identifier: Data([1, 2, 3]),
            clientInfo: clientInfo
        ))
    }

    func testAnisetteV3AppleProvisioningPlistsUseHeaderAndRequestDictionaries() throws {
        let startData = try AnisetteV3AppleProvisioningClient.makeProvisioningPlist(cpim: nil)
        let start = try XCTUnwrap(PropertyListSerialization.propertyList(from: startData, options: [], format: nil) as? [String: Any])
        XCTAssertNotNil(start["Header"] as? [String: Any])
        XCTAssertEqual((start["Request"] as? [String: Any])?.count, 0)

        let finishData = try AnisetteV3AppleProvisioningClient.makeProvisioningPlist(cpim: "cpim-value")
        let finish = try XCTUnwrap(PropertyListSerialization.propertyList(from: finishData, options: [], format: nil) as? [String: Any])
        XCTAssertEqual((finish["Request"] as? [String: String])?["cpim"], "cpim-value")
    }

    func testAnisetteV3AppleProvisioningParsesAppleURLBagAndSPIM() throws {
        let plist: [String: Any] = [
            "urls": [
                "midStartProvisioning": "https://gsa.apple.com/start",
                "midFinishProvisioning": "https://gsa.apple.com/finish"
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let urls = try AnisetteV3AppleProvisioningClient.parseProvisioningURLs(data)
        XCTAssertEqual(urls.start.absoluteString, "https://gsa.apple.com/start")
        XCTAssertEqual(urls.finish.absoluteString, "https://gsa.apple.com/finish")

        let spimPlist: [String: Any] = ["Response": ["spim": "server-metadata"]]
        let spimData = try PropertyListSerialization.data(fromPropertyList: spimPlist, format: .xml, options: 0)
        XCTAssertEqual(try AnisetteV3AppleProvisioningClient.parseSPIM(spimData), "server-metadata")
    }

    func testAnisetteV3AppleProvisioningParsesPTMAndTK() throws {
        let plist: [String: Any] = ["Response": ["ptm": "persistent-token", "tk": "trust-key"]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        XCTAssertEqual(
            try AnisetteV3AppleProvisioningClient.parseFinishData(data),
            AnisetteV3AppleFinishData(ptm: "persistent-token", tk: "trust-key")
        )
    }

    func testAnisetteV3AppleProvisioningRejectsInvalidURLsAndMalformedPlists() throws {
        let unsafe: [String: Any] = [
            "urls": [
                "midStartProvisioning": "https://gsa.apple.com/start",
                "midFinishProvisioning": "https://apple.com.attacker.example/finish"
            ]
        ]
        let unsafeData = try PropertyListSerialization.data(fromPropertyList: unsafe, format: .xml, options: 0)
        XCTAssertThrowsError(try AnisetteV3AppleProvisioningClient.parseProvisioningURLs(unsafeData))
        XCTAssertThrowsError(try AnisetteV3AppleProvisioningClient.parseSPIM(Data("not a plist".utf8)))
        XCTAssertThrowsError(try AnisetteV3AppleProvisioningClient.parseFinishData(
            try PropertyListSerialization.data(fromPropertyList: ["Response": ["ptm": "only-one"]], format: .xml, options: 0)
        ))
        XCTAssertThrowsError(try AnisetteV3AppleProvisioningClient.makeProvisioningPlist(cpim: ""))
    }

}
