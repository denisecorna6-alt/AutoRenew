import Foundation

/// Contract for a supported signing implementation.
/// Credentials and 2FA values are deliberately not part of this interface.
protocol SigningBackend {
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date
}

/// Safe placeholder used until a documented, supported signing flow is integrated.
/// It must never report a successful renewal or extend an app's expiry.
struct StubSigningBackend: SigningBackend {
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date {
        throw RefreshError.notImplemented
    }
}
