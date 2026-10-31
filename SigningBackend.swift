import Foundation

/// Contract for a supported signing implementation.
/// Credentials and 2FA values are deliberately not part of this interface.
protocol SigningBackend {
    var isAvailable: Bool { get }
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date
}

/// Safe placeholder used until a documented, supported signing flow is integrated.
struct StubSigningBackend: SigningBackend {
    let isAvailable = false

    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date {
        throw RefreshError.notImplemented
    }
}
