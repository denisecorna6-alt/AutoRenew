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
            Text("O AutoRenew ainda não assina, instala ou renova apps. As datas são cadastradas manualmente e os lembretes dependem da autorização do iOS.")
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
                Text(app.bundleID).font(.caption2).foregroundStyle(.tertiary)
                Text("Expira \(app.expiresAt.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddApp = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AlphaNotice()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
                Section("Apps cadastrados manualmente") {
                    ForEach(store.apps) { AppRow(app: $0) }
                        .onDelete { store.removeApps(at: $0) }
                }
            }
            .overlay {
                if store.apps.isEmpty {
                    ContentUnavailableView("Nenhum app cadastrado", systemImage: "app.dashed",
                                           description: Text("Adicione o identificador e a data de validade informada pelo seu instalador."))
                }
            }
            .navigationTitle("AutoRenew Alpha")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Verificar renovação") {
                        busy = true
                        Task {
                            await RefreshCoordinator.shared.runIfNeeded(trigger: "alpha-check", budget: .seconds(120), force: true)
                            busy = false
                        }
                    }.disabled(busy || store.apps.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddApp = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddApp) {
                AddManagedAppView()
                    .environmentObject(store)
            }
        }
    }
}

private struct AddManagedAppView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bundleID = ""
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados do aplicativo") {
                    TextField("Nome", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Bundle ID (ex.: com.exemplo.app)", text: $bundleID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    DatePicker("Data de validade", selection: $expiresAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
                if let errorMessage {
                    Section { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                }
                Section {
                    Text("O AutoRenew não detecta a validade real no dispositivo. Informe a data exibida pelo aplicativo que fez a instalação.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Adicionar app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        if store.addApp(name: name, bundleID: bundleID, expiresAt: expiresAt) {
                            dismiss()
                        } else {
                            errorMessage = "Confira nome, Bundle ID, data futura e se o app já não está cadastrado."
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              expiresAt <= Date())
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
    @State private var notificationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lembretes") {
                    Stepper("Avisar com menos de \(Int(store.settings.thresholdHours))h",
                            value: $store.settings.thresholdHours, in: 6...120, step: 6)
                    Button("Ativar lembretes") {
                        Task {
                            let granted = await Notifier.requestAuthorization()
                            await Notifier.reschedule(store.apps, thresholdHours: store.settings.thresholdHours)
                            notificationMessage = granted
                                ? "Permissão concedida. Os lembretes futuros foram programados quando possível."
                                : "Permissão não concedida. Ative as notificações do AutoRenew nos Ajustes do iPhone."
                        }
                    }
                    if let notificationMessage {
                        Text(notificationMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("O iOS controla quando os avisos são entregues. Eles não executam assinatura ou reinstalação.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: store.settings.thresholdHours) { _, _ in
                    Task { await Notifier.reschedule(store.apps, thresholdHours: store.settings.thresholdHours) }
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
