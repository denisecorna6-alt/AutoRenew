import Foundation

actor RefreshCoordinator {
    static let shared = RefreshCoordinator()
    private var backend: SigningBackend = StubSigningBackend()
    private var running = false

    func setBackend(_ backend: SigningBackend) { self.backend = backend }

    func runIfNeeded(trigger: String, budget: Duration, force: Bool = false) async {
        guard !running else { return }
        running = true
        defer { running = false }

        let clock = ContinuousClock()
        let deadline = clock.now + budget
        let (apps, settings) = await MainActor.run {
            (AppStore.shared.apps.filter(\.isActive), AppStore.shared.settings)
        }
        let due = apps
            .filter { force || $0.expiresAt.timeIntervalSinceNow < settings.thresholdHours * 3600 }
            .sorted { $0.expiresAt < $1.expiresAt }
        guard !due.isEmpty else { return }

        // Fail closed before network access when no real signer is configured.
        guard backend.isAvailable else {
            for app in due {
                await fail(app, trigger,
                           "Renovação real indisponível: integração de assinatura ainda não implementada. Nenhuma alteração foi feita.")
            }
            await MainActor.run { Notifier.reschedule(AppStore.shared.apps) }
            return
        }

        let router = AnisetteRouter(urls: settings.anisetteURLs)
        outer: for app in due {
            for attempt in 0..<3 {
                if Task.isCancelled || clock.now >= deadline { break outer }
                do {
                    let anisette = try await router.fetch()
                    let newExpiry = try await backend.refresh(app: app, anisette: anisette)
                    guard newExpiry > app.expiresAt else {
                        await fail(app, trigger,
                                   "O backend não confirmou uma validade posterior. Nenhuma alteração foi feita.")
                        break
                    }
                    await MainActor.run {
                        AppStore.shared.didRefresh(app, newExpiry: newExpiry, trigger: trigger)
                    }
                    break
                } catch let error as RefreshError {
                    switch error {
                    case .notImplemented:
                        await fail(app, trigger,
                                   "Renovação real indisponível: integração de assinatura ainda não implementada. Nenhuma alteração foi feita.")
                        break outer
                    case .authentication:
                        await fail(app, trigger, "Autenticação falhou. Nenhuma renovação foi realizada.")
                        break outer
                    case .network, .anisetteUnavailable:
                        if attempt == 2 {
                            let message = error == .network
                                ? "Falha de rede após 3 tentativas. Estado da assinatura não foi alterado."
                                : "Serviço Anisette indisponível após 3 tentativas. Estado da assinatura não foi alterado."
                            await fail(app, trigger, message)
                        } else {
                            try? await Task.sleep(for: .seconds(pow(2, Double(attempt + 1))))
                        }
                    case .other:
                        await fail(app, trigger,
                                   "Falha não classificada. Estado da assinatura não foi alterado.")
                        break
                    }
                    if error == .other { break }
                } catch {
                    await fail(app, trigger,
                               "Falha inesperada: \(error.localizedDescription). Estado da assinatura não foi alterado.")
                    break
                }
            }
        }
        await MainActor.run { Notifier.reschedule(AppStore.shared.apps) }
    }

    private func fail(_ app: ManagedApp, _ trigger: String, _ message: String) async {
        await MainActor.run {
            AppStore.shared.log(app, trigger: trigger, success: false, message: message)
        }
    }
}
