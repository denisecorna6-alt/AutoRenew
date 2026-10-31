import Foundation

/// Contract for a future, documented signing integration.
/// Apple IDs, passwords, 2FA codes, cookies and private keys are not part of this interface.
protocol SigningBackend {
    var isAvailable: Bool { get }
    func refresh(app: ManagedApp) async throws -> Date
}

/// Safe placeholder until a supported implementation is reviewed and tested.
struct StubSigningBackend: SigningBackend {
    let isAvailable = false

    func refresh(app: ManagedApp) async throws -> Date {
        throw RefreshError.notImplemented
    }
}
