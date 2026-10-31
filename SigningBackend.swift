import Foundation

/// Contract for a real signing implementation. Implementations must be safe to
/// share across refresh tasks and must never return until renewal is confirmed.
protocol SigningBackend: Sendable {
    var isAvailable: Bool { get }
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date
}

/// Safe placeholder used until a documented, supported signing flow is integrated.
/// It intentionally cannot claim success or modify an app's expiry.
struct StubSigningBackend: SigningBackend {
    let isAvailable = false

    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date {
        throw RefreshError.notImplemented
    }
}
