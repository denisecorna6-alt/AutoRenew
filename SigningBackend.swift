import Foundation

/// Ponto de integração com AltSign + minimuxer.
protocol SigningBackend {
    func login(appleID: String, password: String, anisette: AnisetteData,
               twoFactorCode: @escaping () async -> String?) async throws
    /// Reassina/reinstala o app e retorna a nova data de expiração.
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date
}

/// Backend simulado para testar agendamento, notificações e UI.
struct StubSigningBackend: SigningBackend {
    func login(appleID: String, password: String, anisette: AnisetteData,
               twoFactorCode: @escaping () async -> String?) async throws {}
    func refresh(app: ManagedApp, anisette: AnisetteData) async throws -> Date {
        try await Task.sleep(for: .milliseconds(400))
        return Date(timeIntervalSinceNow: 7 * 86_400)
    }
}

/*
 TODO backend real (AltSignBackend):
  1. ALTAppleAPI.shared.authenticate(...) -> ALTAccount + ALTAppleAPISession (persistir no Keychain)
  2. fetchTeams -> fetchCertificates; reutilizar certificado se o serial local existir, senão recriar
  3. fetchAppIDs (reutilizar) -> fetchProvisioningProfile(for:team:)
  4. ALTSigner(team:certificate:).signApp(at:provisioningProfiles:)
  5. minimuxer: instalar o IPA via loopback (VPN ativa + pairing file)
*/
