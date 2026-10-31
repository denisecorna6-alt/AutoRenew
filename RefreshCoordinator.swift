import Foundation

struct RefreshRunSummary: Sendable {
    let considered: Int
    let renewed: Int
    let failed: Int
    let skipped: Bool
    let message: String
}

/// Coordinates one refresh pass at a time. A backend must be explicitly configured;
/// the default backend remains fail-closed and can never report a renewal.
actor RefreshCoordinator {
    static let shared = RefreshCoordinator()

    private var backend: any SigningBackend
    private var running = false

    init(backend: any SigningBackend = StubSigningBackend()) {
        self.backend = backend
    }

    func setBackend(_ backend: any SigningBackend) {
        self.backend = backend
    }

    func runIfNeeded(
        trigger: String,
        budget: Duration,
        force: Bool = false
    ) async -> RefreshRunSummary {
        guard !running else {
            return RefreshRunSummary(
                considered: 0, renewed: 0, failed: 0, skipped: true,
                message: "Uma verificação já está em andamento."
            )
        }

        running = true
        defer { running = false }

        let clock = ContinuousClock()
        let deadline = clock.now + budget
        let selectedBackend = backend
        let (apps, settings) = await MainActor.run {
            (AppStore.shared.apps.filter(\.isActive), AppStore.shared.settings)
        }
        let due = apps
            .filter { force || $0.expiresAt.timeIntervalSinceNow < settings.thresholdHours * 3600 }
            .sorted { $0.expiresAt < $1.expiresAt }

        guard !due.isEmpty else {
            return RefreshRunSummary(
                considered: 0, renewed: 0, failed: 0, skipped: false,
                message: "Nenhum aplicativo precisa de renovação neste momento."
            )
        }

        guard selectedBackend.isAvailable else {
            for app in due {
                await fail(
                    app, trigger,
                    "Renovação real indisponível: nenhum backend de assinatura funcional foi configurado. Nenhuma alteração foi feita."
                )
            }
            await rescheduleNotifications()
            return RefreshRunSummary(
                considered: due.count, renewed: 0, failed: due.count, skipped: false,
                message: "Backend de assinatura indisponível."
            )
        }

        let router = AnisetteRouter(
            urls: settings.anisetteURLs,
            remoteRequestsEnabled: settings.allowRemoteAnisette
        )
        var renewed = 0
        var failed = 0

        for (index, app) in due.enumerated() {
            guard !Task.isCancelled, clock.now < deadline else { break }

            // Do not renew an app that was removed, disabled, or edited after the
            // initial snapshot was taken.
            let isStillCurrent = await MainActor.run {
                AppStore.shared.apps.contains {
                    $0.id == app.id && $0.isActive && $0.expiresAt == app.expiresAt
                }
            }
            guard isStillCurrent else { continue }

            do {
                let anisette = try await fetchAnisette(
                    using: router, clock: clock, deadline: deadline
                )
                // Do not retry a signing request after an ambiguous network error:
                // the remote operation may have succeeded even if its response was lost.
                let newExpiry = try await selectedBackend.refresh(app: app, anisette: anisette)

                guard Self.isValidRenewalDate(newExpiry, previous: app.expiresAt) else {
                    await fail(
                        app, trigger,
                        "O backend não retornou uma validade futura e posterior à atual. Nenhuma alteração foi feita."
                    )
                    failed += 1
                    continue
                }

                let committed = await MainActor.run {
                    AppStore.shared.didRefresh(
                        app, newExpiry: newExpiry, trigger: trigger
                    )
                }
                if committed {
                    renewed += 1
                } else {
                    await fail(
                        app, trigger,
                        "O aplicativo mudou durante a operação. A validade retornada não foi aplicada."
                    )
                    failed += 1
                }
            } catch let error as RefreshError {
                switch error {
                case .authentication:
                    // Authentication failure is account-wide. Mark remaining due
                    // apps clearly instead of repeating the same failing login.
                    for pending in due[index...] {
                        await fail(
                            pending, trigger,
                            "Autenticação recusada. Nenhuma renovação foi confirmada; confira a sessão e tente novamente."
                        )
                        failed += 1
                    }
                    await rescheduleNotifications()
                    return RefreshRunSummary(
                        considered: due.count, renewed: renewed, failed: failed,
                        skipped: false, message: "A autenticação falhou."
                    )
                case .notImplemented:
                    for pending in due[index...] {
                        await fail(
                            pending, trigger,
                            "O backend selecionado não implementa renovação real. Nenhuma alteração foi feita."
                        )
                        failed += 1
                    }
                    await rescheduleNotifications()
                    return RefreshRunSummary(
                        considered: due.count, renewed: renewed, failed: failed,
                        skipped: false, message: "O backend não implementa renovação."
                    )
                case .network:
                    await fail(
                        app, trigger,
                        "Falha de rede durante a assinatura. O resultado pode ser indeterminado; a operação não foi repetida e a validade não foi alterada."
                    )
                    failed += 1
                case .anisetteUnavailable:
                    await fail(
                        app, trigger,
                        "Nenhum serviço Anisette configurado respondeu com dados válidos. A assinatura não foi iniciada."
                    )
                    failed += 1
                case .other:
                    await fail(
                        app, trigger,
                        "Falha não classificada no backend. A validade não foi alterada."
                    )
                    failed += 1
                }
            } catch is CancellationError {
                break
            } catch {
                await fail(
                    app, trigger,
                    "Falha inesperada: \(error.localizedDescription). A validade não foi alterada."
                )
                failed += 1
            }
        }

        await rescheduleNotifications()
        let message = Task.isCancelled || clock.now >= deadline
            ? "Verificação interrompida pelo cancelamento ou pelo limite de tempo."
            : "Verificação concluída."
        return RefreshRunSummary(
            considered: due.count, renewed: renewed, failed: failed,
            skipped: false, message: message
        )
    }

    nonisolated static func isValidRenewalDate(
        _ proposed: Date,
        previous: Date,
        now: Date = Date()
    ) -> Bool {
        proposed > now && proposed > previous
    }

    private func fetchAnisette(
        using router: AnisetteRouter,
        clock: ContinuousClock,
        deadline: ContinuousClock.Instant
    ) async throws -> AnisetteData {
        for attempt in 0..<3 {
            guard !Task.isCancelled, clock.now < deadline else {
                throw CancellationError()
            }
            do {
                return try await router.fetch()
            } catch let error as RefreshError
                where error == .network || error == .anisetteUnavailable {
                guard attempt < 2 else { throw error }
                let delay = Duration.seconds(1 << attempt)
                guard clock.now + delay < deadline else { throw error }
                try await Task.sleep(for: delay)
            }
        }
        throw RefreshError.anisetteUnavailable
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
