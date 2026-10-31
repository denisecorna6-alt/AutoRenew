import Foundation
import CoreFoundation

/// Reads public SideStore/AltSource JSON metadata only.
/// This component does not authenticate with Apple, sign, install, or refresh apps.
struct CatalogApp: Identifiable, Sendable {
    let id: String
    let name: String
    let developer: String
    let bundleIdentifier: String
    let subtitle: String?
    let description: String
    let iconURL: URL
    let versions: [CatalogVersion]
}

struct CatalogVersion: Identifiable, Sendable {
    let id: String
    let version: String
    let date: Date?
    let downloadURL: URL
    let size: Int64
    let minimumOSVersion: String?
    let maximumOSVersion: String?
    let description: String?
}

struct CatalogSnapshot: Sendable {
    let sourceURL: URL
    let identifier: String
    let name: String
    let apps: [CatalogApp]
    let fetchedAt: Date
}

enum CatalogProviderError: LocalizedError {
    case insecureURL
    case invalidResponse
    case responseTooLarge
    case invalidJSON
    case missingSourceFields
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .insecureURL: return "A fonte e os downloads precisam usar HTTPS."
        case .invalidResponse: return "A fonte retornou uma resposta HTTP inválida."
        case .responseTooLarge: return "O catálogo excede o limite de 5 MB."
        case .invalidJSON: return "O catálogo não contém JSON válido."
        case .missingSourceFields: return "O catálogo precisa informar name, identifier e apps."
        case .invalidSource(let reason): return reason
        }
    }
}

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

        // Stream the body so the size limit is enforced while receiving bytes,
        // rather than after URLSession has already allocated the whole response.
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw CatalogProviderError.invalidResponse
        }
        if let finalURL = response.url, finalURL.scheme?.lowercased() != "https" {
            throw CatalogProviderError.insecureURL
        }
        if let length = http.value(forHTTPHeaderField: "Content-Length"),
           let expected = Int64(length), expected > Int64(maximumResponseBytes) {
            throw CatalogProviderError.responseTooLarge
        }

        var data = Data()
        data.reserveCapacity(min(maximumResponseBytes, 64 * 1_024))
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else {
                throw CatalogProviderError.responseTooLarge
            }
            data.append(byte)
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CatalogProviderError.invalidJSON
        }
        guard let object = root as? [String: Any],
              let sourceName = Self.nonEmptyString(object["name"]),
              let identifier = Self.nonEmptyString(object["identifier"]),
              let rawApps = object["apps"] as? [[String: Any]] else {
            throw CatalogProviderError.missingSourceFields
        }

        let apps = rawApps.compactMap(Self.parseApp)
        guard apps.count == rawApps.count else {
            throw CatalogProviderError.invalidSource(
                "Um ou mais apps não possuem os campos obrigatórios do formato SideStore."
            )
        }
        let identifiers = apps.map(\.bundleIdentifier)
        guard Set(identifiers).count == identifiers.count else {
            throw CatalogProviderError.invalidSource("O catálogo contém bundle identifiers duplicados.")
        }

        return CatalogSnapshot(
            sourceURL: sourceURL,
            identifier: identifier,
            name: sourceName,
            apps: apps,
            fetchedAt: Date()
        )
    }

    private static func parseApp(_ value: [String: Any]) -> CatalogApp? {
        guard let name = nonEmptyString(value["name"]),
              let bundleID = nonEmptyString(value["bundleIdentifier"]),
              let developer = nonEmptyString(value["developerName"]),
              let description = nonEmptyString(value["localizedDescription"]),
              let iconURL = secureURL(value["iconURL"]) else { return nil }

        var versions: [CatalogVersion]
        if let rawVersions = value["versions"] as? [[String: Any]] {
            versions = rawVersions.compactMap(parseVersion)
            guard versions.count == rawVersions.count, !versions.isEmpty else { return nil }
        } else if let version = nonEmptyString(value["version"]),
                  let downloadURL = secureURL(value["downloadURL"]),
                  let size = nonNegativeSize(value["size"]),
                  let date = parseDate(value["versionDate"]) {
            // Backward compatibility with legacy AltSource fields.
            versions = [CatalogVersion(
                id: version + "-" + downloadURL.absoluteString,
                version: version,
                date: date,
                downloadURL: downloadURL,
                size: size,
                minimumOSVersion: nil,
                maximumOSVersion: nil,
                description: nonEmptyString(value["versionDescription"])
            )]
        } else {
            return nil
        }

        return CatalogApp(
            id: bundleID,
            name: name,
            developer: developer,
            bundleIdentifier: bundleID,
            subtitle: nonEmptyString(value["subtitle"]),
            description: description,
            iconURL: iconURL,
            versions: versions
        )
    }

    private static func parseVersion(_ value: [String: Any]) -> CatalogVersion? {
        guard let version = nonEmptyString(value["version"]),
              let date = parseDate(value["date"]),
              let downloadURL = secureURL(value["downloadURL"]),
              let size = nonNegativeSize(value["size"]) else { return nil }

        return CatalogVersion(
            id: version + "-" + date.timeIntervalSince1970.description + "-" + downloadURL.absoluteString,
            version: version,
            date: date,
            downloadURL: downloadURL,
            size: size,
            minimumOSVersion: nonEmptyString(value["minOSVersion"]),
            maximumOSVersion: nonEmptyString(value["maxOSVersion"]),
            description: nonEmptyString(value["localizedDescription"])
        )
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let raw = nonEmptyString(value) else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: raw)
    }

    private static func nonNegativeSize(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              number.doubleValue >= 0,
              number.doubleValue <= Double(Int64.max),
              number.doubleValue.rounded(.towardZero) == number.doubleValue else { return nil }
        return number.int64Value
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
