import SwiftUI
import UniformTypeIdentifiers

private struct AltSourceDocument: Decodable {
    let name: String
    let subtitle: String?
    let apps: [AltSourceApp]
}

private struct AltSourceApp: Decodable, Identifiable {
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: URL?
    let versions: [AltSourceVersion]

    var safeIconURL: URL? {
        guard let iconURL, AltSourcePolicy.isSafeHTTPSURL(iconURL) else { return nil }
        return iconURL
    }

    var id: String { bundleIdentifier }
}

private struct AltSourceVersion: Decodable, Identifiable {
    let version: String
    let buildVersion: String?
    let date: String?
    let localizedDescription: String?
    let downloadURL: URL
    let size: Int?
    let minOSVersion: String?

    var id: String { version + "-" + (buildVersion ?? "") }
}

private struct CatalogApp: Identifiable {
    let sourceName: String
    let sourceURL: URL
    let app: AltSourceApp
    var id: String { sourceURL.absoluteString + "|" + app.bundleIdentifier }
}

enum AltSourcePolicy {
    static let maximumSourceCount = 20
    static let maximumSourceJSONBytes = 5_000_000
    static let maximumAppsPerSource = 500
    static let maximumVersionsPerApp = 50

    static func isSafeHTTPSURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
        url.host != nil &&
        url.user == nil &&
        url.password == nil
    }

    static func isSourceDataWithinLimit(_ byteCount: Int) -> Bool {
        byteCount >= 0 && byteCount <= maximumSourceJSONBytes
    }

    static func isWithinCatalogLimits(sourceCount: Int, appCount: Int) -> Bool {
        sourceCount <= maximumSourceCount && appCount <= maximumAppsPerSource
    }

    static func isValidAppMetadata(name: String, bundleIdentifier: String, versionCount: Int) -> Bool {
        !name.isEmpty && name.count <= 120 &&
        !bundleIdentifier.isEmpty && bundleIdentifier.count <= 255 &&
        versionCount <= maximumVersionsPerApp
    }

    static func isValidVersionMetadata(version: String, downloadURL: URL) -> Bool {
        !version.isEmpty && version.count <= 64 && isSafeHTTPSURL(downloadURL)
    }
}

@MainActor
private final class AppCatalogModel: ObservableObject {
    @Published private(set) var apps: [CatalogApp] = []
    @Published private(set) var downloadedFiles: [URL] = []
    @Published private(set) var loading = false
    @Published private(set) var downloadingKey: String?
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let defaultsKey = "AutoRenew.altSourceURLs"

    var sourceURLs: [String] {
        get { UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    init() {
        refreshDownloadedFiles()
    }

    func addSource(_ rawValue: String) async {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), AltSourcePolicy.isSafeHTTPSURL(url) else {
            errorMessage = "Adicione o endereço HTTPS público de um arquivo JSON de fonte."
            return
        }
        guard sourceURLs.count < AltSourcePolicy.maximumSourceCount else {
            errorMessage = "O catálogo aceita no máximo 20 fontes."
            return
        }
        guard !sourceURLs.contains(url.absoluteString) else {
            errorMessage = "Essa fonte já está adicionada."
            return
        }
        sourceURLs.append(url.absoluteString)
        await loadSources()
    }

    func removeSource(_ value: String) async {
        sourceURLs.removeAll { $0 == value }
        await loadSources()
    }

    private func fetchSourceData(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AutoRenew-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = response.url,
              AltSourcePolicy.isSafeHTTPSURL(finalURL) else {
            throw URLError(.badServerResponse)
        }
        if response.expectedContentLength > Int64(AltSourcePolicy.maximumSourceJSONBytes) {
            throw NSError(domain: "AutoRenew.Catalog", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "O JSON da fonte excede o limite de 5 MB."])
        }

        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(min(Int64(AltSourcePolicy.maximumSourceJSONBytes), response.expectedContentLength)))
        }
        for try await byte in bytes {
            guard AltSourcePolicy.isSourceDataWithinLimit(data.count + 1) else {
                throw NSError(domain: "AutoRenew.Catalog", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "O JSON da fonte excede o limite de 5 MB."])
            }
            data.append(byte)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        return (data, response)
    }

    func loadSources() async {
        guard !loading else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }

        var loaded: [CatalogApp] = []
        var failures: [String] = []
        if sourceURLs.count > AltSourcePolicy.maximumSourceCount {
            failures.append("Somente as primeiras 20 fontes foram carregadas.")
        }

        for value in sourceURLs.prefix(AltSourcePolicy.maximumSourceCount) {
            guard let url = URL(string: value), AltSourcePolicy.isSafeHTTPSURL(url) else {
                failures.append("Endereço de fonte inválido.")
                continue
            }
            do {
                let (data, _) = try await fetchSourceData(from: url)
                let source = try JSONDecoder().decode(AltSourceDocument.self, from: data)
                guard !source.name.isEmpty,
                      source.name.count <= 120,
                      AltSourcePolicy.isWithinCatalogLimits(sourceCount: 1, appCount: source.apps.count) else {
                    throw NSError(domain: "AutoRenew.Catalog", code: 4,
                                  userInfo: [NSLocalizedDescriptionKey: "A fonte excede os limites de metadados do catálogo."])
                }
                for app in source.apps {
                    guard AltSourcePolicy.isValidAppMetadata(
                        name: app.name,
                        bundleIdentifier: app.bundleIdentifier,
                        versionCount: app.versions.count
                    ), app.versions.allSatisfy({
                        AltSourcePolicy.isValidVersionMetadata(version: $0.version, downloadURL: $0.downloadURL)
                    }) else {
                        throw NSError(domain: "AutoRenew.Catalog", code: 4,
                                      userInfo: [NSLocalizedDescriptionKey: "A fonte contém metadados ou links de versão inválidos."])
                    }
                }
                loaded.append(contentsOf: source.apps.map {
                    CatalogApp(sourceName: source.name, sourceURL: url, app: $0)
                })
            } catch {
                failures.append("\(url.host ?? "fonte"): \(error.localizedDescription)")
            }
        }

        apps = loaded.sorted {
            $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
        }
        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
        if sourceURLs.isEmpty {
            statusMessage = "Adicione uma fonte AltStore compatível para procurar aplicativos."
        } else {
            statusMessage = "Carregados \(apps.count) aplicativo(s) de até \(AltSourcePolicy.maximumSourceCount) fonte(s)."
        }
    }

    func download(_ version: AltSourceVersion, appName: String) async {
        let key = appName + "|" + version.id
        guard downloadingKey == nil else { return }
        guard AltSourcePolicy.isSafeHTTPSURL(version.downloadURL) else {
            errorMessage = "O link da versão não é HTTPS ou contém credenciais."
            return
        }

        downloadingKey = key
        errorMessage = nil
        statusMessage = nil
        defer { downloadingKey = nil }

        do {
            var request = URLRequest(url: version.downloadURL)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            let (temporaryURL, response) = try await BoundedIPADownloader.download(for: request)
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let finalURL = response.url,
                  AltSourcePolicy.isSafeHTTPSURL(finalURL) else {
                throw InstallerDownloadError.insecureURL
            }
            let fileName = URL(fileURLWithPath: finalURL.lastPathComponent).lastPathComponent
            guard fileName.lowercased().hasSuffix(".ipa"), fileName != ".ipa" else {
                throw InstallerDownloadError.invalidFilename
            }
            let inspection = try IPAInspector.inspect(fileURL: temporaryURL)
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DownloadedIPAs", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let destination = InstallerDownloadPolicy.uniqueDestination(in: directory, filename: fileName)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: destination.path
            )
            statusMessage = "\(appName) \(version.version) baixado. \(inspection.validationScope) SHA-256: \(inspection.sha256.prefix(16))…"
            refreshDownloadedFiles()
        } catch {
            errorMessage = "Não foi possível baixar \(appName): \(error.localizedDescription)"
        }
    }

    func refreshDownloadedFiles() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedIPAs", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        downloadedFiles = ((try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []).filter { $0.pathExtension.lowercased() == "ipa" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}

struct AppCatalogView: View {
    @StateObject private var model = AppCatalogModel()
    @State private var searchText = ""
    @State private var showingAddSource = false
    @State private var newSourceURL = ""

    private var visibleApps: [CatalogApp] {
        guard !searchText.isEmpty else { return model.apps }
        return model.apps.filter {
            $0.app.name.localizedCaseInsensitiveContains(searchText) ||
            $0.app.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Catálogo de IPAs", systemImage: "square.grid.2x2.fill")
                            .font(.title2.bold())
                        Text("Adicione fontes compatíveis com AltStore/SideStore, encontre aplicativos e baixe versões diretamente para o iPhone.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Nesta Alpha, o catálogo baixa e guarda o IPA. Assinatura e instalação ainda não estão integradas.")
                            .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button {
                        showingAddSource = true
                    } label: {
                        Label("Adicionar fonte JSON", systemImage: "plus.circle.fill")
                    }
                    if model.sourceURLs.isEmpty {
                        Text("Nenhuma fonte adicionada.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(model.sourceURLs, id: \.self) { value in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(URL(string: value)?.host ?? value).font(.subheadline)
                                    Text(value).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await model.removeSource(value) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                } header: {
                    Text("Fontes")
                } footer: {
                    Text("Use apenas fontes de desenvolvedores em que você confia. O AutoRenew valida HTTPS, mas não certifica a segurança ou legitimidade dos IPAs.")
                }

                Section("Aplicativos disponíveis") {
                    if model.loading && model.apps.isEmpty {
                        HStack { Spacer(); ProgressView("Carregando fontes…"); Spacer() }
                    } else if visibleApps.isEmpty {
                        ContentUnavailableView(
                            "Nenhum aplicativo encontrado",
                            systemImage: "square.grid.2x2",
                            description: Text(model.sourceURLs.isEmpty
                                ? "Adicione uma fonte para preencher o catálogo."
                                : "Atualize as fontes ou tente outra busca.")
                        )
                    } else {
                        ForEach(visibleApps) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    if let iconURL = item.app.safeIconURL {
                                        AsyncImage(url: iconURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "app.fill").foregroundStyle(.secondary)
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Image(systemName: "app.fill")
                                            .font(.title2).frame(width: 48, height: 48)
                                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.app.name).font(.headline)
                                        Text(item.app.subtitle ?? item.app.bundleIdentifier)
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text("Por \(item.app.developerName ?? "Desenvolvedor desconhecido") · \(item.sourceName)")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                if let description = item.app.localizedDescription, !description.isEmpty {
                                    Text(description).font(.caption).lineLimit(4)
                                }
                                if item.app.versions.isEmpty {
                                    Text("Esta fonte não listou versões para download.")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    ForEach(item.app.versions) { version in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Versão \(version.version)\(version.buildVersion.map { " (\($0))" } ?? "")")
                                                    .font(.subheadline.weight(.medium))
                                                HStack(spacing: 8) {
                                                    if let date = version.date { Text(date) }
                                                    if let size = version.size {
                                                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                                    }
                                                    if let minOS = version.minOSVersion { Text("iOS \(minOS)+") }
                                                }
                                                .font(.caption2).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button {
                                                Task { await model.download(version, appName: item.app.name) }
                                            } label: {
                                                if model.downloadingKey == item.app.name + "|" + version.id {
                                                    ProgressView()
                                                } else {
                                                    Label("Baixar", systemImage: "arrow.down.circle")
                                                }
                                            }
                                            .disabled(model.downloadingKey != nil)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }

                if !model.downloadedFiles.isEmpty {
                    Section("IPAs baixados") {
                        ForEach(model.downloadedFiles, id: \.absoluteString) { file in
                            HStack {
                                Label(file.lastPathComponent, systemImage: "doc.zipper")
                                    .lineLimit(1)
                                Spacer()
                                ShareLink(item: file) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                }

                if let status = model.statusMessage {
                    Section { Text(status).font(.caption).foregroundStyle(.secondary) }
                }
                if let error = model.errorMessage {
                    Section("Avisos") { Text(error).font(.caption).foregroundStyle(.red) }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar apps ou fontes")
            .navigationTitle("Catálogo")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await model.loadSources() }
                    } label: {
                        if model.loading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(model.loading)
                    .accessibilityLabel("Atualizar fontes")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSource = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Adicionar fonte")
                }
            }
            .sheet(isPresented: $showingAddSource) {
                NavigationStack {
                    Form {
                        Section("Endereço da fonte") {
                            TextField("https://exemplo.com/source.json", text: $newSourceURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Section {
                            Text("Fontes AltStore são compatíveis com SideStore. O AutoRenew lê metadados e links de IPA; ele não herda automaticamente os recursos de assinatura e instalação do SideStore.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Adicionar fonte")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showingAddSource = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Adicionar") {
                                let value = newSourceURL
                                newSourceURL = ""
                                showingAddSource = false
                                Task { await model.addSource(value) }
                            }
                            .disabled(newSourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .task {
                if model.apps.isEmpty && !model.sourceURLs.isEmpty {
                    await model.loadSources()
                }
            }
        }
    }
}
