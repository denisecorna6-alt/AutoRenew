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

    private let channels = ["Todas", "Stable", "Beta", "Alpha"]

    private var visibleReleases: [GitHubRelease] {
        selectedChannel == "Todas" ? catalog.releases : catalog.releases.filter { $0.channel == selectedChannel }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Central de instalação", systemImage: "arrow.down.app.fill")
                            .font(.title2.bold())
                        Text("Encontre versões publicadas do AutoRenew, baixe arquivos IPA ou importe um IPA que já esteja no iPhone.")
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
                                ShareLink(item: file) {
                                    Label("Compartilhar / abrir em outro instalador", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section("Conta Apple e assinatura") {
                    Label("Login Apple ainda não conectado", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.headline)
                    Text("O Apple ID não é necessário para baixar um IPA público. Ele só entra em um fluxo de assinatura compatível. A Alpha ainda não implementa esse fluxo; não digite sua senha aqui.")
                        .font(.caption).foregroundStyle(.secondary)
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
            .fileImporter(isPresented: $showingIPAImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { result in
                do {
                    if case .success(let url) = result {
                        try catalog.importIPA(from: url)
                    }
                } catch {
                    catalog.errorMessage = "Não foi possível importar o IPA: \(error.localizedDescription)"
                }
            }
        }
    }
}
