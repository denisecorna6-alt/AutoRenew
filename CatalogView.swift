import SwiftUI

struct CatalogView: View {
    @AppStorage("catalog.sourceURL") private var sourceAddress = ""
    @State private var snapshot: CatalogSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section("Adicionar catálogo") {
                    TextField("URL HTTPS do catálogo JSON", text: $sourceAddress)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        loadCatalog()
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Carregando…" : "Carregar catálogo")
                        }
                    }
                    .disabled(isLoading || sourceAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }

                if let snapshot {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.name).font(.headline)
                            Text(snapshot.identifier).font(.caption).foregroundStyle(.secondary)
                            Text("\(snapshot.apps.count) aplicativos · Atualizado \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Section("Aplicativos") {
                        ForEach(snapshot.apps) { app in
                            CatalogAppRow(app: app) { url in openURL(url) }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "Nenhum catálogo carregado",
                            systemImage: "square.grid.2x2",
                            description: Text("Informe uma URL HTTPS de uma fonte SideStore/AltSource em JSON.")
                        )
                    }
                }

                Section {
                    Text("O AutoRenew apenas consulta metadados públicos do catálogo. Esta tela não instala, assina, atualiza nem renova aplicativos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Installer")
        }
    }

    private func loadCatalog() {
        let trimmed = sourceAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            errorMessage = "Informe uma URL válida."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let loaded = try await CatalogProvider.shared.load(from: url)
                await MainActor.run {
                    snapshot = loaded
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

private struct CatalogAppRow: View {
    let app: CatalogApp
    let onDownload: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: app.iconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "app.dashed").resizable().scaledToFit().padding(10)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.headline)
                    Text(app.developer).font(.caption).foregroundStyle(.secondary)
                    Text(app.bundleIdentifier).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            if let subtitle = app.subtitle { Text(subtitle).font(.subheadline) }
            Text(app.description).font(.caption).foregroundStyle(.secondary).lineLimit(3)

            ForEach(app.versions) { version in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Versão \(version.version)").font(.subheadline.weight(.medium))
                        Text(version.date?.formatted(date: .abbreviated, time: .omitted) ?? "Data não informada")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: version.size, countStyle: .file))
                        .font(.caption2).foregroundStyle(.secondary)
                    Button("Abrir IPA") { onDownload(version.downloadURL) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
