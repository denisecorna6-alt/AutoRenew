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

        // Fail closed: não consultar Anisette nem registrar sucesso com backend demonstrativo.
        if backend.isSimulationOnly {
            for app in due {
                await fail(app, trigger, "Modo demonstração: nenhuma renovação real foi executada; backend de assinatura ainda não conectado.")
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
                    let expiry = try await backend.refresh(app: app, anisette: anisette)
                    guard expiry > app.expiresAt else {
                        await fail(app, trigger, "Backend retornou validade não posterior à atual; nenhuma renovação foi registrada.")
                        break
                    }
                    await MainActor.run { AppStore.shared.didRefresh(app, newExpiry: expiry, trigger: trigger) }
                    break
                } catch let error as RefreshError where error == .authentication {
                    await fail(app, trigger, "Autenticação falhou — reabra o app e faça login")
                    break outer
                } catch let error as RefreshError where error == .simulationOnly {
                    await fail(app, trigger, "Modo demonstração: nenhuma renovação real foi executada.")
                    break
                } catch {
                    if attempt == 2 { await fail(app, trigger, "Falha: operação não confirmada (\(error))") }
                    else { try? await Task.sleep(for: .seconds(pow(2, Double(attempt + 1)))) }
                }
            }
        }
        await MainActor.run { Notifier.reschedule(AppStore.shared.apps) }
    }

    private func fail(_ app: ManagedApp, _ trigger: String, _ msg: String) async {
        await MainActor.run { AppStore.shared.log(app, trigger: trigger, success: false, message: msg) }
    }
}
