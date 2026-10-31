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

@MainActor
private final class AppCatalogModel: ObservableObject {
    @Published private(set) var apps: [CatalogApp] = []
    @Published private(set) var downloadedFiles: [URL] = []
    @Published private(set) var loading = false
    @Published private(set) var downloadingKey: String?
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let defaultsKey = "AutoRenew.altSourceURLs"
    private let maxDownloadSize = 1_500_000_000

    var sourceURLs: [String] {
        get { UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    init() {
        refreshDownloadedFiles()
    }

    func addSource(_ rawValue: String) async {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), url.scheme?.lowercased() == "https",
              url.host != nil, url.user == nil, url.password == nil else {
            errorMessage = "Adicione o endereço HTTPS público de um arquivo JSON de fonte."
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
        sourceURLs.removeAll { $0 != value }
        await loadSources()
    }

    func loadSources() async {
        guard !loading else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }

        var loaded: [CatalogApp] = []
        var failures: [String] = []
        for value in sourceURLs {
            guard let url = URL(string: value), url.scheme?.lowercased() == "https",
                  url.host != nil, url.user == nil, url.password == nil else {
                failures.append("Endereço inválido: \(value)")
                continue
            }
            do {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("AutoRenew-iOS", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      response.url?.scheme?.lowercased() == "https" else {
                    throw URLError(.badServerResponse)
                }
                let source = try JSONDecoder().decode(AltSourceDocument.self, from: data)
                loaded.append(contentsOf: source.apps.map {
                    CatalogApp(sourceName: source.name, sourceURL: url, app: $0)
                })
            } catch {
                failures.append("\(url.host ?? value): \(error.localizedDescription)")
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
            statusMessage = "Carregados \(apps.count) aplicativo(s) de \(sourceURLs.count) fonte(s)."
        }
    }

    func download(_ version: AltSourceVersion, appName: String) async {
        let key = appName + "|" + version.id
        guard downloadingKey == nil else { return }
        guard version.downloadURL.scheme?.lowercased() == "https",
              version.downloadURL.host != nil,
              version.downloadURL.user == nil, version.downloadURL.password == nil else {
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
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let finalURL = response.url,
                  finalURL.scheme?.lowercased() == "https",
                  finalURL.user == nil, finalURL.password == nil else {
                throw URLError(.badServerResponse)
            }
            let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0, size <= maxDownloadSize else {
                throw NSError(domain: "AutoRenew.Catalog", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "O arquivo está vazio ou excede 1,5 GB."])
            }
            let fileName = URL(fileURLWithPath: finalURL.lastPathComponent).lastPathComponent
            guard fileName.lowercased().hasSuffix(".ipa"), fileName != ".ipa" else {
                throw NSError(domain: "AutoRenew.Catalog", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "A URL não terminou em um arquivo .ipa."])
            }
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DownloadedIPAs", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(fileName)
            let uniqueDestination = FileManager.default.fileExists(atPath: destination.path)
                ? directory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
                : destination
            try FileManager.default.moveItem(at: temporaryURL, to: uniqueDestination)
            statusMessage = "\(appName) \(version.version) baixado. O IPA está salvo no app; baixar não significa assinar ou instalar."
            refreshDownloadedFiles()
        } catch {
            errorMessage = "Não foi possível baixar \(appName): \(error.localizedDescription)"
        }
    }

    func refreshDownloadedFiles() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedIPAs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
                                    if let iconURL = item.app.iconURL {
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
