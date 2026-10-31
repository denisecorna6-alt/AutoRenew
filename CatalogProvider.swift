import Foundation

/// Minimal, defensive reader for SideStore-compatible source JSON.
///
/// This intentionally handles public catalog metadata only. It does not perform
/// Apple authentication, signing, installation, or refresh operations.
struct CatalogApp: Identifiable, Sendable {
    let id: String
    let name: String
    let developer: String?
    let bundleIdentifier: String?
    let subtitle: String?
    let iconURL: URL?
    let versions: [CatalogVersion]
}

struct CatalogVersion: Identifiable, Sendable {
    let id: String
    let version: String
    let date: Date?
    let downloadURL: URL?
    let size: Int64?
    let minimumOSVersion: String?
    let description: String?
}

struct CatalogSnapshot: Sendable {
    let sourceURL: URL
    let name: String
    let apps: [CatalogApp]
    let fetchedAt: Date
}

enum CatalogProviderError: LocalizedError {
    case insecureURL
    case invalidResponse
    case responseTooLarge
    case invalidJSON
    case missingApps
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .insecureURL: return "A fonte precisa usar HTTPS."
        case .invalidResponse: return "A fonte retornou uma resposta HTTP inválida."
        case .responseTooLarge: return "O catálogo excede o limite de 5 MB."
        case .invalidJSON: return "O catálogo não contém JSON válido."
        case .missingApps: return "O catálogo não contém uma lista de aplicativos."
        case .invalidSource(let reason): return reason
        }
    }
}

/// Fetches public SideStore-style source documents. No credentials are accepted
/// or sent, redirects to non-HTTPS destinations are rejected, and response size
/// is bounded before parsing.
actor CatalogProvider {
    static let shared = CatalogProvider()
    private let maximumResponseBytes = 5 * 1_024 * 1_024

    func load(from sourceURL: URL) async throws -> CatalogSnapshot {
        guard sourceURL.scheme?.lowercased() == "https",
              sourceURL.host != nil,
              sourceURL.user == nil,
              sourceURL.password == nil else {
            throw CatalogProviderError.insecureURL
        }

        var request = URLRequest(url: sourceURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw CatalogProviderError.invalidResponse
        }
        guard data.count <= maximumResponseBytes else {
            throw CatalogProviderError.responseTooLarge
        }
        if let finalURL = response.url, finalURL.scheme?.lowercased() != "https" {
            throw CatalogProviderError.insecureURL
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CatalogProviderError.invalidJSON
        }
        guard let object = root as? [String: Any],
              let rawApps = object["apps"] as? [[String: Any]] else {
            throw CatalogProviderError.missingApps
        }

        let sourceName = (object["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let apps = rawApps.compactMap(Self.parseApp)
        guard !apps.isEmpty || rawApps.isEmpty else {
            throw CatalogProviderError.invalidSource(
                "Nenhum aplicativo possui os campos mínimos válidos."
            )
        }

        return CatalogSnapshot(
            sourceURL: sourceURL,
            name: sourceName.flatMap { $0.isEmpty ? nil : $0 } ?? sourceURL.host ?? "Source",
            apps: apps,
            fetchedAt: Date()
        )
    }

    private static func parseApp(_ value: [String: Any]) -> CatalogApp? {
        guard let name = nonEmptyString(value["name"]) else { return nil }
        let bundleID = nonEmptyString(value["bundleIdentifier"])
        let stableID = bundleID ?? name.lowercased()
        let icon = secureURL(value["iconURL"])
        let versions = (value["versions"] as? [[String: Any]] ?? []).compactMap(parseVersion)

        return CatalogApp(
            id: stableID,
            name: name,
            developer: nonEmptyString(value["developerName"]),
            bundleIdentifier: bundleID,
            subtitle: nonEmptyString(value["localizedDescription"]),
            iconURL: icon,
            versions: versions
        )
    }

    private static func parseVersion(_ value: [String: Any]) -> CatalogVersion? {
        guard let version = nonEmptyString(value["version"]) else { return nil }
        let date: Date?
        if let rawDate = value["date"] as? String {
            let formatter = ISO8601DateFormatter()
            date = formatter.date(from: rawDate)
        } else {
            date = nil
        }
        let size: Int64?
        if let number = value["size"] as? NSNumber, number.int64Value >= 0 {
            size = number.int64Value
        } else {
            size = nil
        }

        return CatalogVersion(
            id: "\(version)-\(value["buildVersion"] as? String ?? "")",
            version: version,
            date: date,
            downloadURL: secureURL(value["downloadURL"]),
            size: size,
            minimumOSVersion: nonEmptyString(value["minOSVersion"]),
            description: nonEmptyString(value["versionDescription"])
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func secureURL(_ value: Any?) -> URL? {
        guard let raw = nonEmptyString(value),
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil else { return nil }
        return url
    }
}
