import Foundation

struct RefreshRunSummary {
    let considered: Int
    let renewed: Int
    let deferred: Int
    let failed: Int
    let skipped: Bool
    let cancelled: Bool

    var backgroundTaskSucceeded: Bool {
        !cancelled && failed == 0 && deferred == 0
    }

    static let noWork = RefreshRunSummary(
        considered: 0, renewed: 0, deferred: 0, failed: 0,
        skipped: true, cancelled: false
    )
}

actor RefreshCoordinator {
    static let shared = RefreshCoordinator()
    private var backend: SigningBackend = StubSigningBackend()
    private var running = false

    func setBackend(_ backend: SigningBackend) { self.backend = backend }

    @discardableResult
    func runIfNeeded(trigger: String, budget: Duration, force: Bool = false) async -> RefreshRunSummary {
        guard !running else { return .noWork }
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
        guard !due.isEmpty else { return .noWork }

        // Fail closed before any network access while no reviewed signer exists.
        guard backend.isAvailable else {
            for app in due {
                await fail(app, trigger,
                           "Renovação real indisponível nesta Alpha. Nenhuma rede, assinatura ou alteração de validade foi executada.")
            }
            await rescheduleNotifications()
            return RefreshRunSummary(
                considered: due.count, renewed: 0, deferred: 0, failed: due.count,
                skipped: true, cancelled: false
            )
        }

        var renewed = 0
        var deferred = 0
        var failed = 0
        var cancelled = false

        for (index, app) in due.enumerated() {
            if Task.isCancelled {
                cancelled = true
                deferred += due.count - index
                break
            }
            if clock.now >= deadline {
                deferred += due.count - index
                break
            }
            do {
                let newExpiry = try await backend.refresh(app: app)
                guard newExpiry > app.expiresAt else {
                    await fail(app, trigger,
                               "O backend não confirmou uma validade posterior. Nenhuma alteração foi feita.")
                    failed += 1
                    continue
                }
                await MainActor.run {
                    AppStore.shared.didRefresh(app, newExpiry: newExpiry, trigger: trigger)
                }
                renewed += 1
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
                failed += 1
            } catch {
                await fail(app, trigger,
                           "Falha inesperada. O estado da assinatura permanece desconhecido.")
                failed += 1
            }
        }

        await rescheduleNotifications()
        return RefreshRunSummary(
            considered: due.count, renewed: renewed, deferred: deferred,
            failed: failed, skipped: false, cancelled: cancelled
        )
    }

    private func rescheduleNotifications() async {
        let (apps, thresholdHours) = await MainActor.run {
            (AppStore.shared.apps, AppStore.shared.settings.thresholdHours)
        }
        await Notifier.reschedule(apps, thresholdHours: thresholdHours)
    }

    private func fail(_ app: ManagedApp, _ trigger: String, _ message: String) async {
        await MainActor.run {
            AppStore.shared.log(app, trigger: trigger, success: false, message: message)
        }
    }
}
