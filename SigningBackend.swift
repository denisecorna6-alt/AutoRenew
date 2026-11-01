import Foundation

/// Boundary between the scheduler and the real signing/reinstallation engine.
protocol SigningBackend {
    var isAvailable: Bool { get }
    func refresh(app: ManagedApp) async throws -> Date
}

/// Safe default until the official integrations and their prerequisites are reviewed.
/// This implementation never returns a replacement expiry date.
struct UnavailableSigningBackend: SigningBackend {
    let isAvailable = false

    func refresh(app: ManagedApp) async throws -> Date {
        throw RefreshError.integrationUnavailable
    }
}

/*
SideSign and Minimuxer are intentionally not wired in this branch yet.
Their API, licensing and device prerequisites are documented in CONTRIBUTING.md.
*/
