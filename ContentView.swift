import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        TabView {
            AppCatalogView().tabItem { Label("Catálogo", systemImage: "square.grid.2x2.fill") }
            DashboardView().tabItem { Label("Apps", systemImage: "app.badge.clock") }
            LogsView().tabItem { Label("Atividade", systemImage: "list.bullet.rectangle") }
            SettingsView().tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

struct AlphaNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("ALPHA · acompanhamento manual", systemImage: "flask")
                .font(.headline)
            Text("Cadastre seus apps e receba lembretes de expiração. A renovação e a leitura automática dos certificados ainda não estão integradas.")
                .font(.caption)
            Text("As datas são informadas por você e não são verificadas pelo AutoRenew.")
                .font(.caption.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AppRow: View {
    let app: ManagedApp
    private var tint: Color {
        app.daysLeft <= 0 ? .red : app.daysLeft <= 1 ? .orange : app.daysLeft <= 3 ? .yellow : .green
    }
    private var status: String {
        app.daysLeft <= 0 ? "Prazo informado expirado" :
        app.daysLeft <= 1 ? "Vence em breve" :
        app.daysLeft <= 3 ? "Atenção" : "Dentro do prazo informado"
    }

    var body: some View {
        HStack(spacing: 12) {
            Gauge(value: min(max(app.daysLeft / 7, 0), 1)) {
            } currentValueLabel: {
                Text("\(max(Int(app.daysLeft.rounded(.up)), 0))d")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.headline)
                Text(app.bundleID).font(.caption2).foregroundStyle(.secondary)
                Text(status).font(.caption).foregroundStyle(tint)
                Text("Data informada: \(app.expiresAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var busy = false
    @State private var showingAddApp = false
    @State private var refreshMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AlphaNotice()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
                Section("Seus aplicativos") {
                    if store.apps.isEmpty {
                        ContentUnavailableView(
                            "Nenhum app cadastrado",
                            systemImage: "app.dashed",
                            description: Text("Adicione nome, Bundle ID e data de expiração para começar.")
                        )
                    } else {
                        ForEach(store.apps) { AppRow(app: $0) }
                            .onDelete { offsets in
                                store.apps.remove(atOffsets: offsets)
                                Notifier.reschedule(store.apps)
                            }
                    }
                }
            }
            .navigationTitle("AutoRenew")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Verificar agora") {
                        busy = true
                        Task {
                            let summary = await RefreshCoordinator.shared.runIfNeeded(
                                trigger: "manual", budget: .seconds(30), force: true
                            )
                            refreshMessage = "\(summary.message)\nRenovados: \(summary.renewed) · Falhas: \(summary.failed)"
                            busy = false
                        }
                    }
                    .disabled(busy || store.apps.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddApp = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Adicionar aplicativo")
                }
            }
            .sheet(isPresented: $showingAddApp) {
                AddAppView()
            }
            .alert("Resultado da verificação", isPresented: Binding(
                get: { refreshMessage != nil },
                set: { if !$0 { refreshMessage = nil } }
            )) {
                Button("OK", role: .cancel) { refreshMessage = nil }
            } message: {
                Text(refreshMessage ?? "")
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
                    DatePicker("Data de expiração", selection: $expiry,
                               in: Date.distantPast...,
                               displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Text("O cadastro é manual: confira a data no SideStore/AltStore. O AutoRenew ainda não lê a lista de apps instalados.")
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
            List(store.attempts.reversed()) { attempt in
                VStack(alignment: .leading, spacing: 2) {
                    Label(attempt.bundleID,
                          systemImage: attempt.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(attempt.success ? .green : .red)
                    Text(attempt.message).font(.caption)
                    Text("\(attempt.date.formatted()) · \(attempt.trigger)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Atividade")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingProfileImporter = false
    @State private var profileImportMessage: String?

    private var mobileProvisionType: UTType {
        UTType(filenameExtension: "mobileprovision", conformingTo: .data) ?? .data
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacidade e integração") {
                    Text("Esta Alpha não solicita nem armazena senha Apple ID, código 2FA ou sessão da Apple. A integração real de assinatura ainda não foi implementada.")
                    Text("Não informe credenciais Apple nesta versão.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Section("Perfis de provisionamento importados") {
                    Text("Importe um arquivo .mobileprovision para manter uma cópia privada no app e registrar seu hash SHA-256. Nesta etapa, o conteúdo CMS ainda não é decodificado; validade, equipe, UDID e revogação permanecem desconhecidos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showingProfileImporter = true
                    } label: {
                        Label("Importar perfil", systemImage: "doc.badge.plus")
                    }
                    if store.profiles.isEmpty {
                        Text("Nenhum perfil importado.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.profiles) { profile in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.originalFileName).font(.subheadline.weight(.medium))
                                Text("\(profile.formattedSize) · Importado \(profile.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("SHA-256: \(profile.sha256)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .textSelection(.enabled)
                                Text("Conteúdo não interpretado · validade desconhecida")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Button("Remover cópia local", role: .destructive) {
                                    store.removeProfile(profile)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section("Alertas de expiração") {
                    Stepper("Verificar quando faltar menos de \(Int(store.settings.thresholdHours))h",
                            value: $store.settings.thresholdHours, in: 6...120, step: 6)
                    Text("Os lembretes locais são programados para 48h, 24h e 6h antes da data cadastrada. O iOS pode limitar tarefas em segundo plano.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Integração em desenvolvimento") {
                    Text("Login Apple, Anisette, inventário de certificados e assinatura ainda não estão conectados. Esta versão não lê os apps instalados.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("O bloqueio de domínios por VPN também não está implementado e exigiria permissões específicas.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
            .fileImporter(
                isPresented: $showingProfileImporter,
                allowedContentTypes: [mobileProvisionType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedURL = urls.first else { return }
                    do {
                        let profile = try store.importProfile(from: selectedURL)
                        profileImportMessage = "Perfil copiado localmente. SHA-256: \(profile.sha256). O conteúdo ainda não foi validado."
                    } catch {
                        profileImportMessage = error.localizedDescription
                    }
                case .failure(let error):
                    profileImportMessage = "Falha na importação: \(error.localizedDescription)"
                }
            }
            .alert("Importação de perfil", isPresented: Binding(
                get: { profileImportMessage != nil },
                set: { if !$0 { profileImportMessage = nil } }
            )) {
                Button("OK") { profileImportMessage = nil }
            } message: {
                Text(profileImportMessage ?? "")
            }
        }
    }
}
