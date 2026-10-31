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

        // Fail closed before any network access while no reviewed signer exists.
        guard backend.isAvailable else {
            for app in due {
                await fail(app, trigger,
                           "Renovação real indisponível nesta Alpha. Nenhuma rede, assinatura ou alteração de validade foi executada.")
            }
            await MainActor.run { Notifier.reschedule(AppStore.shared.apps) }
            return
        }

        for app in due {
            guard !Task.isCancelled, clock.now < deadline else { break }
            do {
                let newExpiry = try await backend.refresh(app: app)
                guard newExpiry > app.expiresAt else {
                    await fail(app, trigger,
                               "O backend não confirmou uma validade posterior. Nenhuma alteração foi feita.")
                    continue
                }
                await MainActor.run {
                    AppStore.shared.didRefresh(app, newExpiry: newExpiry, trigger: trigger)
                }
            } catch let error as RefreshError {
                let message: String
                switch error {
                case .notImplemented:
                    message = "Renovação real indisponível. Nenhuma alteração foi feita."
                case .network:
                    message = "Falha de rede. O estado da assinatura permanece desconhecido."
                case .other:
                    message = "Falha não classificada. Nenhuma alteração foi feita."
                }
                await fail(app, trigger, message)
            } catch {
                await fail(app, trigger,
                           "Falha inesperada. O estado da assinatura permanece desconhecido.")
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
