import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Apps", systemImage: "app.badge.clock") }
            LogsView().tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
            SettingsView().tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
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
                Text(app.bundleID).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var busy = false
    @State private var showingAddApp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Acompanhamento disponível · assinatura automática em desenvolvimento", systemImage: "info.circle")
                        .font(.headline)
                    Text("Você pode cadastrar seus apps e receber alertas antes da expiração. A renovação e reinstalação automáticas ainda não estão disponíveis; nenhuma data será estendida sem uma assinatura real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Seus aplicativos") {
                    if store.apps.isEmpty {
                        ContentUnavailableView("Nenhum app cadastrado", systemImage: "app.dashed",
                                               description: Text("Adicione nome, Bundle ID e data de expiração para começar a acompanhar."))
                    } else {
                        ForEach(store.apps) { AppRow(app: $0) }
                            .onDelete { offsets in
                                store.apps.remove(atOffsets: offsets)
                                Notifier.reschedule(store.apps)
                            }
                        .listRowSeparator(.visible)
                    }
                }
            }
            .navigationTitle("AutoRenew")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Verificar agora") {
                        busy = true
                        Task {
                            await RefreshCoordinator.shared.runIfNeeded(trigger: "manual", budget: .seconds(30))
                            busy = false
                        }
                    }.disabled(busy || store.apps.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddApp = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Adicionar aplicativo")
                }
            }
            .sheet(isPresented: $showingAddApp) {
                AddAppView()
            }
        }
    }
}

struct AddAppView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bundleID = ""
    @State private var expiry = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados do aplicativo") {
                    TextField("Nome (ex.: Meu App)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Bundle ID (ex.: com.empresa.app)", text: $bundleID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    DatePicker("Data de expiração", selection: $expiry, in: Date.distantPast..., displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Text("O cadastro é manual: confira a data de expiração no SideStore/AltStore. O AutoRenew ainda não lê a lista de apps instalados.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
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
                        guard store.addApp(name: name, bundleID: bundleID, expiresAt: expiry) else {
                            errorMessage = "Preencha os campos e use um Bundle ID que ainda não esteja cadastrado."
                            return
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct LogsView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack {
            List(store.attempts.reversed()) { a in
                VStack(alignment: .leading, spacing: 2) {
                    Label(a.bundleID, systemImage: a.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(a.success ? .green : .red)
                    Text(a.message).font(.caption)
                    Text("\(a.date.formatted()) · \(a.trigger)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Atividade")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var password = ""
    @State private var credentialStatus = "Senha armazenada no Keychain do iPhone."

    var body: some View {
        NavigationStack {
            Form {
                Section("Apple ID") {
                    TextField("E-mail", text: $store.settings.appleID)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    SecureField("Senha", text: $password)
                    Button("Salvar senha com segurança") {
                        guard !password.isEmpty else { return }
                        Keychain.set(password, for: "applePassword")
                        password = ""
                        credentialStatus = "Senha salva no Keychain."
                    }
                    Text(credentialStatus).font(.caption).foregroundStyle(.secondary)
                    Text("As credenciais ainda não são usadas para login: a integração SideSign está pendente. Não compartilhe sua senha com ninguém.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Servidores Anisette") {
                    TextField("URLs separadas por vírgula", text: Binding(
                        get: { store.settings.anisetteURLs.joined(separator: ", ") },
                        set: { store.settings.anisetteURLs = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Ainda não conectados ao fluxo de autenticação SideSign.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Alertas") {
                    Stepper("Avisar com menos de \(Int(store.settings.thresholdHours))h",
                            value: $store.settings.thresholdHours, in: 6...120, step: 6)
                    Toggle("Bloquear domínios OCSP/PPQ (VPN)", isOn: $store.settings.blockDomains)
                    Text("O bloqueio por VPN exige uma extensão Network Extension e permissões específicas; não está ativo nesta build.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
