import Foundation

/// Backend real só pode ser ativado após autenticação, assinatura, instalação e confirmação no dispositivo.
protocol SigningBackend: Sendable {
    var isSimulationOnly: Bool { get }
    func login(appleID: String, password: String, anisette: AnisetteData,
               twoFactorCode: @escaping () async -> String?) async throws
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date
}

/// Backend seguro de demonstração: nunca simula uma renovação bem-sucedida.
struct StubSigningBackend: SigningBackend {
    let isSimulationOnly = true

    func login(appleID: String, password: String, anisette: AnisetteData,
               twoFactorCode: @escaping () async -> String?) async throws {
        throw RefreshError.simulationOnly
    }

    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date {
        throw RefreshError.simulationOnly
    }
}
