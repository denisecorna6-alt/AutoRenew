import XCTest
@testable import AutoRenew

final class InstallerDeepLinkTests: XCTestCase {
    func testDisplaysDownloadHostWithoutAssumingInstall() {
        XCTAssertEqual(InstallerDeepLink.displayHost(for: URL(string: "https://example.com/build.ipa")), "example.com")
        XCTAssertEqual(InstallerDeepLink.displayHost(for: nil), "origem desconhecida")
    }

    func testAcceptsHTTPSIPAInstallHandoff() throws {
        let link = URL(string: "autorenewinstaller://install?url=https%3A%2F%2Fexample.com%2Fbuild.ipa")!
        XCTAssertEqual(try InstallerDeepLink.parse(link).absoluteString, "https://example.com/build.ipa")
    }

    func testRejectsUnknownSchemeOrAction() {
        XCTAssertThrowsError(try InstallerDeepLink.parse(URL(string: "https://example.com/build.ipa")!))
        XCTAssertThrowsError(try InstallerDeepLink.parse(URL(string: "autorenewinstaller://pair?url=https%3A%2F%2Fexample.com%2Fbuild.ipa")!))
    }

    func testRejectsHTTPAndNonIPAURLs() {
        let http = URL(string: "autorenewinstaller://install?url=http%3A%2F%2Fexample.com%2Fbuild.ipa")!
        let html = URL(string: "autorenewinstaller://install?url=https%3A%2F%2Fexample.com%2Fbuild.html")!
        XCTAssertThrowsError(try InstallerDeepLink.parse(http))
        XCTAssertThrowsError(try InstallerDeepLink.parse(html))
    }

    func testRejectsCredentialsFragmentsAndExtraParameters() {
        let credentialed = URL(string: "autorenewinstaller://install?url=https%3A%2F%2Fuser%3Apass%40example.com%2Fbuild.ipa")!
        let fragment = URL(string: "autorenewinstaller://install?url=https%3A%2F%2Fexample.com%2Fbuild.ipa%23fragment")!
        let extra = URL(string: "autorenewinstaller://install?url=https%3A%2F%2Fexample.com%2Fbuild.ipa&confirm=true")!
        XCTAssertThrowsError(try InstallerDeepLink.parse(credentialed))
        XCTAssertThrowsError(try InstallerDeepLink.parse(fragment))
        XCTAssertThrowsError(try InstallerDeepLink.parse(extra))
    }
}
