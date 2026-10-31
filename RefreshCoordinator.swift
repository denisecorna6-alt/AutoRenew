import Foundation

actor RefreshCoordinator {
    static let shared = RefreshCoordinator()
    private var backend: SigningBackend = UnavailableSigningBackend()
    private var running = false

    func setBackend(_ b: SigningBackend) { backend = b }

    func runIfNeeded(trigger: String, budget: Duration, force: Bool = false) async {
        guard !running else { return }
        running = true; defer { running = false }

        let clock = ContinuousClock()
        let deadline = clock.now + budget
        let (apps, settings) = await MainActor.run {
            (AppStore.shared.apps.filter(\.isActive), AppStore.shared.settings)
        }
        let due = apps.filter { force || $0.expiresAt.timeIntervalSinceNow < settings.thresholdHours * 3600 }
                      .sorted { $0.expiresAt < $1.expiresAt }
        guard !due.isEmpty else { return }

        // Não consultar Anisette nem alterar expirações enquanto não existir
        // um backend real conectado. Isso evita sucesso fictício e chamadas inúteis.
        guard backend.isAvailable else {
            for app in due {
                await fail(app, trigger, "Assinatura real indisponível: integração SideSign/Minimuxer pendente")
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
                    await MainActor.run { AppStore.shared.didRefresh(app, newExpiry: expiry, trigger: trigger) }
                    break
                } catch let e as RefreshError where e == .authentication {
                    await fail(app, trigger, "Autenticação falhou — reabra o app e faça login")
                    break outer                       // nunca repetir erro de auth (evita bloqueio da conta)
                } catch let e as RefreshError where e == .integrationUnavailable {
                    await fail(app, trigger, "Assinatura real indisponível: integração SideSign/Minimuxer pendente")
                    break outer
                } catch {
                    if attempt == 2 { await fail(app, trigger, "Falha: \(error)") }
                    else { try? await Task.sleep(for: .seconds(pow(2, Double(attempt + 1)))) }  // backoff
                }
            }
        }
        await MainActor.run { Notifier.reschedule(AppStore.shared.apps) }
    }

    private func fail(_ app: ManagedApp, _ trigger: String, _ msg: String) async {
        await MainActor.run { AppStore.shared.log(app, trigger: trigger, success: false, message: msg) }
    }
}
