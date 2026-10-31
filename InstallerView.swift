import SwiftUI
import UniformTypeIdentifiers

private struct GitHubRelease: Decodable, Identifiable {
    struct Asset: Decodable, Identifiable {
        let id: Int
        let name: String
        let browserDownloadURL: URL
        let size: Int
        enum CodingKeys: String, CodingKey {
            case id, name, size
            case browserDownloadURL = "browser_download_url"
        }
    }

    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let publishedAt: Date?
    let htmlURL: URL
    let prerelease: Bool
    let draft: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case id, name, body, prerelease, draft, assets
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case htmlURL = "html_url"
    }

    var displayName: String { name?.isEmpty == false ? name! : tagName }
    var ipaAssets: [Asset] { assets.filter { $0.name.lowercased().hasSuffix(".ipa") } }
    var channel: String {
        let value = (tagName + " " + (name ?? "")).lowercased()
        if value.contains("alpha") { return "Alpha" }
        if value.contains("beta") || prerelease { return "Beta" }
        return "Stable"
    }
}

@MainActor
private final class InstallerCatalog: ObservableObject {
    @Published private(set) var releases: [GitHubRelease] = []
    @Published private(set) var downloadedFiles: [URL] = []
    @Published private(set) var isLoading = false
    @Published private(set) var downloadingAssetID: Int?
    @Published private(set) var isDownloadingDirectURL = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let releasesURL = URL(string: "https://api.github.com/repos/xlightxt/AutoRenew/releases?per_page=100")!

    init() {
        refreshDownloadedFiles()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var request = URLRequest(url: releasesURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("AutoRenew-iOS-Installer", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            releases = try decoder.decode([GitHubRelease].self, from: data)
                .filter { !$0.draft && !$0.ipaAssets.isEmpty }
                .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        } catch {
            errorMessage = "Não foi possível carregar as versões públicas: \(error.localizedDescription)"
        }
    }

    func download(_ asset: GitHubRelease.Asset) async {
        guard downloadingAssetID == nil else { return }
        downloadingAssetID = asset.id
        statusMessage = nil
        errorMessage = nil
        defer { downloadingAssetID = nil }

        do {
            var request = URLRequest(url: asset.browserDownloadURL)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DownloadedIPAs", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let safeName = URL(fileURLWithPath: asset.name).lastPathComponent
            let destination = directory.appendingPathComponent(safeName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            statusMessage = "Download concluído: \(safeName). O arquivo foi salvo no AutoRenew."
            refreshDownloadedFiles()
        } catch {
            errorMessage = "Falha ao baixar \(asset.name): \(error.localizedDescription)"
        }
    }

    func downloadIPA(from rawValue: String) async {
        guard !isDownloadingDirectURL else { return }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              url.host != nil,
              url.pathExtension.lowercased() == "ipa" else {
            errorMessage = "Informe um link HTTPS direto para um arquivo .ipa. Links com usuário/senha ou HTTP não são aceitos."
            return
        }

        isDownloadingDirectURL = true
        errorMessage = nil
        statusMessage = nil
        defer { isDownloadingDirectURL = false }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let finalURL = response.url,
                  finalURL.scheme?.lowercased() == "https",
                  finalURL.user == nil, finalURL.password == nil else {
                throw URLError(.badServerResponse)
            }
            let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0, size <= 1_500_000_000 else {
                throw NSError(domain: "AutoRenew.Installer", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "O IPA está vazio ou excede 1,5 GB."])
            }

            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DownloadedIPAs", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let suggestedName = finalURL.lastPathComponent
            let safeName = URL(fileURLWithPath: suggestedName).lastPathComponent
            guard safeName.lowercased().hasSuffix(".ipa"), safeName != ".ipa" else {
                throw NSError(domain: "AutoRenew.Installer", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "O servidor não forneceu um nome de arquivo .ipa válido."])
            }
            let destination = directory.appendingPathComponent(safeName)
            let uniqueDestination = FileManager.default.fileExists(atPath: destination.path)
                ? directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
                : destination
            try FileManager.default.moveItem(at: temporaryURL, to: uniqueDestination)
            statusMessage = "IPA baixado por HTTPS: \(uniqueDestination.lastPathComponent). Ainda precisa ser validado e assinado."
            refreshDownloadedFiles()
        } catch {
            errorMessage = "Falha no download do link: \(error.localizedDescription)"
        }
    }

    func importIPA(from source: URL) throws {
        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 1_500_000_000 else {
            throw NSError(domain: "AutoRenew.Installer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "O arquivo excede o limite de 1,5 GB."])
        }
        guard source.pathExtension.lowercased() == "ipa" else {
            throw NSError(domain: "AutoRenew.Installer", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Selecione um arquivo .ipa."])
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedIPAs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        statusMessage = "IPA importado: \(destination.lastPathComponent)."
        refreshDownloadedFiles()
    }

    func refreshDownloadedFiles() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedIPAs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        downloadedFiles = ((try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        )) ?? []).filter { $0.pathExtension.lowercased() == "ipa" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}

struct InstallerView: View {
    @StateObject private var catalog = InstallerCatalog()
    @State private var selectedChannel = "Todas"
    @State private var showingIPAImporter = false
    @StateObject private var signingVault = SigningIdentityVault()
    @ObservedObject private var appStore = AppStore.shared
    @State private var showingP12Importer = false
    @State private var showingProfileImporter = false
    @State private var pendingP12URL: URL?
    @State private var p12Password = ""
    @State private var certificateMessage: String?
    @State private var profileMessage: String?
    @State private var directIPALink = ""
    @State private var preparedIPA: IPAInspection?
    @State private var preparationMessage: String?
    @State private var pendingDeepLinkURL: URL?

    private let channels = ["Todas", "Stable", "Beta", "Alpha"]

    private var visibleReleases: [GitHubRelease] {
        selectedChannel == "Todas" ? catalog.releases : catalog.releases.filter { $0.channel == selectedChannel }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AutoRenew Installer", systemImage: "arrow.down.app.fill")
                            .font(.title2.bold())
                        Text("Aplicativo independente para baixar versões Stable, Beta e Alpha do AutoRenew, importar IPAs e encaminhar arquivos para ferramentas compatíveis.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label("O download não instala nem assina o aplicativo.", systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                Section("Versões do AutoRenew") {
                    Picker("Canal", selection: $selectedChannel) {
                        ForEach(channels, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if catalog.isLoading && catalog.releases.isEmpty {
                        HStack { Spacer(); ProgressView("Carregando versões…"); Spacer() }
                    } else if visibleReleases.isEmpty {
                        ContentUnavailableView(
                            "Nenhum IPA publicado",
                            systemImage: "shippingbox",
                            description: Text(catalog.releases.isEmpty
                                ? "Ainda não há Releases públicas com arquivos IPA. Builds de CI e artefatos Alpha privados não aparecem neste catálogo."
                                : "Não há arquivos IPA publicados neste canal.")
                        )
                    } else {
                        ForEach(visibleReleases) { release in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(release.displayName).font(.headline)
                                        Text("\(release.channel) · \(release.tagName)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(release.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Data indisponível")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                ForEach(release.ipaAssets) { asset in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(asset.name).font(.subheadline)
                                            Text(ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file))
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            Task { await catalog.download(asset) }
                                        } label: {
                                            if catalog.downloadingAssetID == asset.id {
                                                ProgressView()
                                            } else {
                                                Label("Baixar", systemImage: "arrow.down.circle")
                                            }
                                        }
                                        .disabled(catalog.downloadingAssetID != nil)
                                    }
                                }
                                if let url = URL(string: release.htmlURL.absoluteString) {
                                    Link("Notas e detalhes da versão", destination: url)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }

                Section("Baixar IPA por link") {
                    TextField("https://exemplo.com/app.ipa", text: $directIPALink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task {
                            await catalog.downloadIPA(from: directIPALink)
                        }
                    } label: {
                        Label(catalog.isDownloadingDirectURL ? "Baixando…" : "Baixar IPA pelo link", systemImage: "link")
                    }
                    .disabled(catalog.isDownloadingDirectURL || directIPALink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Aceita somente links HTTPS diretos terminados em .ipa. O app verifica o endereço final e limita o arquivo a 1,5 GB.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Seus arquivos IPA") {
                    Button {
                        showingIPAImporter = true
                    } label: {
                        Label("Importar IPA do app Arquivos", systemImage: "folder.badge.plus")
                    }
                    if catalog.downloadedFiles.isEmpty {
                        Text("Nenhum IPA salvo neste dispositivo.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(catalog.downloadedFiles, id: \.absoluteString) { file in
                            VStack(alignment: .leading, spacing: 5) {
                                Label(file.lastPathComponent, systemImage: "doc.zipper")
                                    .font(.subheadline)
                                Button {
                                    do {
                                        preparedIPA = try IPAInspector.inspect(fileURL: file)
                                        preparationMessage = nil
                                    } catch {
                                        preparedIPA = nil
                                        preparationMessage = error.localizedDescription
                                    }
                                } label: {
                                    Label("Verificar e preparar instalação", systemImage: "checkmark.shield")
                                        .font(.caption)
                                }
                                ShareLink(item: file) {
                                    Label("Compartilhar IPA", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    if let preparedIPA {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("IPA preparado para encaminhamento", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                            Text(preparedIPA.fileName).font(.caption)
                            Text("\(ByteCountFormatter.string(fromByteCount: Int64(preparedIPA.byteCount), countStyle: .file)) · SHA-256 \(preparedIPA.sha256.prefix(16))…")
                                .font(.caption2).foregroundStyle(.secondary)
                            ShareLink(item: preparedIPA.fileURL) {
                                Label("Enviar para AltStore / SideStore", systemImage: "arrow.up.forward.app")
                            }
                            Text("Na folha de compartilhamento, escolha AltStore ou SideStore se aparecerem. A assinatura e a instalação serão realizadas pelo aplicativo escolhido; o AutoRenew não consegue confirmar o resultado.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    if let preparationMessage {
                        Text(preparationMessage)
                            .font(.caption).foregroundStyle(.red)
                    }
                    Text("A verificação confere extensão, tamanho e assinatura inicial do contêiner ZIP, além de calcular SHA-256. Ela não valida assinatura Apple, perfil, malware ou compatibilidade.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Conta Apple e certificados") {
                    Label("Apple ID não conectado", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.headline)
                    Text("Por segurança, esta versão não coleta senha Apple ID nem códigos 2FA. A Apple não oferece um login genérico de Apple ID que autorize assinar IPAs. Sign in with Apple identifica o usuário no app, mas não concede permissões de Developer Program.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Você pode importar sua identidade de assinatura .p12. O arquivo permanece criptografado pela própria senha e protegido pelo iOS; a senha é usada apenas para validar a importação e não é salva.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        showingP12Importer = true
                    } label: {
                        Label("Importar certificado e chave (.p12)", systemImage: "key.horizontal")
                    }
                    if let pendingP12URL {
                        Text("Selecionado: \(pendingP12URL.lastPathComponent)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Senha do arquivo .p12", text: $p12Password)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Validar e guardar com proteção do iOS") {
                            do {
                                try signingVault.importIdentity(from: pendingP12URL, password: p12Password)
                                certificateMessage = "Identidade validada e guardada localmente. A senha não foi armazenada."
                                self.pendingP12URL = nil
                                p12Password = ""
                            } catch {
                                certificateMessage = error.localizedDescription
                                p12Password = ""
                            }
                        }
                        .disabled(p12Password.isEmpty)
                        Button("Cancelar importação", role: .cancel) {
                            self.pendingP12URL = nil
                            p12Password = ""
                        }
                    }
                    if signingVault.records.isEmpty {
                        Text("Nenhuma identidade de assinatura importada.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(signingVault.records) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(record.displayName, systemImage: "checkmark.seal")
                                    .font(.subheadline.weight(.medium))
                                Text("Importado em \(record.importedAt.formatted(date: .abbreviated, time: .shortened)) · SHA-256 \(record.sha256.prefix(12))…")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Button("Remover identidade", role: .destructive) {
                                    signingVault.remove(record)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    Text("Importar o certificado ainda não assina nem instala IPA. A assinatura requer compatibilidade do perfil, Bundle ID e dispositivo, além de um mecanismo de assinatura suportado. O arquivo .p12 é guardado localmente; a senha não é persistida.")
                        .font(.caption).foregroundStyle(.orange)
                }

                Section("Perfis de provisionamento") {
                    Text("Importe o .mobileprovision correspondente ao certificado e ao app. Nesta versão o arquivo é guardado localmente e seu SHA-256 é registrado; o conteúdo CMS ainda não é interpretado nem validado.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        showingProfileImporter = true
                    } label: {
                        Label("Importar perfil (.mobileprovision)", systemImage: "doc.badge.plus")
                    }
                    if appStore.profiles.isEmpty {
                        Text("Nenhum perfil importado.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(appStore.profiles) { profile in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.originalFileName).font(.subheadline.weight(.medium))
                                Text("\(profile.formattedSize) · SHA-256 \(profile.sha256.prefix(12))…")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Button("Remover perfil", role: .destructive) {
                                    appStore.removeProfile(profile)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }

                if let message = catalog.statusMessage {
                    Section { Label(message, systemImage: "checkmark.circle").foregroundStyle(.green) }
                }
                if let error = catalog.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Installer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await catalog.load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(catalog.isLoading)
                    .accessibilityLabel("Atualizar catálogo")
                }
            }
            .task { await catalog.load() }
            .refreshable { await catalog.load() }
            .onOpenURL { incomingURL in
                do {
                    pendingDeepLinkURL = try InstallerDeepLink.parse(incomingURL)
                    catalog.errorMessage = nil
                } catch {
                    catalog.errorMessage = error.localizedDescription
                }
            }
            .alert("Baixar IPA externo?", isPresented: Binding(
                get: { pendingDeepLinkURL != nil },
                set: { if !$0 { pendingDeepLinkURL = nil } }
            )) {
                Button("Baixar IPA") {
                    guard let url = pendingDeepLinkURL else { return }
                    pendingDeepLinkURL = nil
                    directIPALink = url.absoluteString
                    Task { await catalog.downloadIPA(from: url.absoluteString) }
                }
                Button("Cancelar", role: .cancel) { pendingDeepLinkURL = nil }
            } message: {
                Text("O link solicita apenas o download de um IPA por HTTPS de \\(pendingDeepLinkURL?.host ?? "origem desconhecida"). O arquivo será salvo para inspeção. Não haverá assinatura nem instalação automática.")
            }
            .fileImporter(isPresented: $showingIPAImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { result in
                do {
                    if case .success(let url) = result {
                        try catalog.importIPA(from: url)
                    }
                } catch {
                    catalog.errorMessage = "Não foi possível importar o IPA: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showingP12Importer, allowedContentTypes: [UTType(filenameExtension: "p12", conformingTo: .data) ?? .data]) { result in
                switch result {
                case .success(let url):
                    pendingP12URL = url
                    p12Password = ""
                    certificateMessage = nil
                case .failure(let error):
                    certificateMessage = "Não foi possível selecionar o certificado: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showingProfileImporter, allowedContentTypes: [UTType(filenameExtension: "mobileprovision", conformingTo: .data) ?? .data]) { result in
                switch result {
                case .success(let url):
                    do {
                        let profile = try appStore.importProfile(from: url)
                        profileMessage = "Perfil importado localmente. SHA-256: \(profile.sha256). O conteúdo ainda não foi validado."
                    } catch {
                        profileMessage = error.localizedDescription
                    }
                case .failure(let error):
                    profileMessage = "Não foi possível selecionar o perfil: \(error.localizedDescription)"
                }
            }
            .alert("Perfil de provisionamento", isPresented: Binding(
                get: { profileMessage != nil },
                set: { if !$0 { profileMessage = nil } }
            )) {
                Button("OK") { profileMessage = nil }
            } message: {
                Text(profileMessage ?? "")
            }
            .alert("Certificado de assinatura", isPresented: Binding(
                get: { certificateMessage != nil },
                set: { if !$0 { certificateMessage = nil } }
            )) {
                Button("OK") { certificateMessage = nil }
            } message: {
                Text(certificateMessage ?? "")
            }
        }
    }
}
