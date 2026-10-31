import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CatalogView().tabItem { Label("Installer", systemImage: "square.grid.2x2") }
            DashboardView().tabItem { Label("Apps", systemImage: "app.badge.clock") }
            LogsView().tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
            SettingsView().tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

struct AlphaNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("ALPHA · versão de testes", systemImage: "flask")
                .font(.headline)
            Text("A renovação real ainda não está conectada. Esta versão apenas acompanha datas de demonstração e envia lembretes; não altera validade, assina ou reinstala apps.")
                .font(.caption)
            Text("Não use esta versão como garantia para manter apps assinados.")
                .font(.caption.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AppRow: View {
    let app: ManagedApp
    private var tint: Color { app.daysLeft > 3 ? .green : app.daysLeft > 1 ? .yellow : .red }
    var body: some View {
        HStack(spacing: 12) {
            Gauge(value: min(max(app.daysLeft / 7, 0), 1)) {
            } currentValueLabel: {
                Text("\(max(Int(app.daysLeft.rounded(.up)), 0))d")
            }
            .gaugeStyle(.accessoryCircularCapacity).tint(tint)
            VStack(alignment: .leading) {
                Text(app.name).font(.headline)
                Text("Expira \(app.expiresAt.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AlphaNotice()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
                Section("Apps monitorados (dados de demonstração)") {
                    ForEach(store.apps) { AppRow(app: $0) }
                        .onDelete { store.apps.remove(atOffsets: $0) }
                }
            }
            .overlay {
                if store.apps.isEmpty {
                    ContentUnavailableView("Nenhum app", systemImage: "app.dashed",
                                           description: Text("Toque em + para adicionar um app de demonstração."))
                }
            }
            .navigationTitle("AutoRenew Alpha")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Verificar disponibilidade") {
                        busy = true
                        Task {
                            await RefreshCoordinator.shared.runIfNeeded(trigger: "alpha-check", budget: .seconds(120), force: true)
                            busy = false
                        }
                    }.disabled(busy || store.apps.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.addDemoApp() } label: { Image(systemName: "plus") }
                }
            }
        }
    }
}

struct LogsView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack {
            List(store.attempts.reversed()) { attempt in
                VStack(alignment: .leading, spacing: 2) {
                    Label(attempt.bundleID, systemImage: attempt.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(attempt.success ? .green : .red)
                    Text(attempt.message).font(.caption)
                    Text("\(attempt.date.formatted()) · \(attempt.trigger)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Logs")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Lembretes") {
                    Stepper("Avisar com menos de \(Int(store.settings.thresholdHours))h",
                            value: $store.settings.thresholdHours, in: 6...120, step: 6)
                    Text("Os lembretes não renovam nem reinstalam aplicativos. A renovação real ainda não está disponível.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Privacidade") {
                    Text("Esta Alpha não solicita nem armazena Apple ID, senha, códigos 2FA, cookies, tokens ou chaves privadas. Nenhum servidor Anisette é consultado enquanto não existir um backend revisado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
