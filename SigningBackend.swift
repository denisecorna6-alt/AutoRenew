import Foundation

/// Interface entre o agendador e o mecanismo real de assinatura/reinstalação.
protocol SigningBackend {
    var isAvailable: Bool { get }

    func login(appleID: String, password: String, anisette: AnisetteData,
               twoFactorCode: @escaping () async -> String?) async throws
    /// Reassina/reinstala o app e retorna a nova data de expiração.
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date
}

/// Implementação segura enquanto SideSign/Minimuxer não estiverem integrados.
/// Nunca simula uma nova data de expiração nem registra sucesso falso.
struct UnavailableSigningBackend: SigningBackend {
    let isAvailable = false

    func login(appleID: String, password: String, anisette: AnisetteData,
               twoFactorCode: @escaping () async -> String?) async throws {
        throw RefreshError.integrationUnavailable
    }

    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date {
        throw RefreshError.integrationUnavailable
    }
}

/*
 Próximas etapas para o backend real:
 1. Mapear AnisetteData para SideSign.AnisetteData e autenticar via DeveloperPortal.
 2. Buscar/criar App ID, certificado de desenvolvimento e provisioning profile.
 3. Extrair o IPA, assinar o .app e extensões com AppBundleSigner.
 4. Instalar o bundle assinado no dispositivo usando Minimuxer somente quando
    houver pairing file válido e transporte/VPN configurados.
 5. Persistir sessão e material privado no Keychain; nunca registrar senha ou tokens.
 */
