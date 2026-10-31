import Foundation

actor RefreshCoordinator {
    static let shared = RefreshCoordinator()
    private var backend: SigningBackend = StubSigningBackend()
    private var running = false

    func setBackend(_ b: SigningBackend) { backend = b }

    func runIfNeeded(trigger: String, budget: Duration, force: Bool = false) async {
        guard !running else { return }
        running = true
        defer { running = false }

        let clock = ContinuousClock()
        let deadline = clock.now + budget
        let (apps, settings) = await MainActor.run {
            (AppStore.shared.apps.filter(\.isActive), AppStore.shared.settings)
        }
        let due = apps.filter { force || $0.expiresAt.timeIntervalSinceNow < settings.thresholdHours * 3600 }
                      .sorted { $0.expiresAt < $1.expiresAt }
        guard !due.isEmpty else { return }

        let router = AnisetteRouter(urls: settings.anisetteURLs)
        for app in due {
            if Task.isCancelled || clock.now >= deadline { break }
            do {
                let anisette = try await router.fetch()
                let expiry = try await backend.refresh(app: app, anisette: anisette)
                await MainActor.run {
                    AppStore.shared.didRefresh(app, newExpiry: expiry, trigger: trigger)
                }
            } catch let error as RefreshError {
                switch error {
                case .notImplemented:
                    await fail(app, trigger,
                               "Renovação real indisponível: integração de assinatura ainda não implementada. Nenhuma alteração foi feita.")
                    return
                case .authentication:
                    await fail(app, trigger, "Autenticação falhou. Nenhuma renovação foi realizada.")
                    return
                case .anisetteUnavailable:
                    await fail(app, trigger, "Serviço Anisette indisponível. Estado da assinatura não foi alterado.")
                case .network:
                    await fail(app, trigger, "Falha de rede. Estado da assinatura não foi alterado.")
                case .other:
                    await fail(app, trigger, "Falha não classificada. Estado da assinatura não foi alterado.")
                }
            } catch {
                await fail(app, trigger,
                           "Falha inesperada: \(error.localizedDescription). Estado da assinatura não foi alterado.")
            }
        }
        await MainActor.run { Notifier.reschedule(AppStore.shared.apps) }
    }

    private func fail(_ app: ManagedApp, _ trigger: String, _ msg: String) async {
        await MainActor.run {
            AppStore.shared.log(app, trigger: trigger, success: false, message: msg)
        }
    }
}
