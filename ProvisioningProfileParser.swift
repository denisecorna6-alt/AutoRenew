import Foundation

/// Metadata decoded from the plist payload embedded in a .mobileprovision file.
/// Important: extracting the plist does NOT verify the CMS signature or Apple's trust chain.
struct ProvisioningProfileMetadata {
    let name: String
    let uuid: String
    let teamIdentifiers: [String]
    let applicationIdentifierPrefixes: [String]
    let applicationIdentifier: String
    let creationDate: Date?
    let expirationDate: Date
    let provisionedDevices: [String]
    let provisionsAllDevices: Bool
    let entitlements: [String: Any]

    var allowsDevelopment: Bool {
        (entitlements["get-task-allow"] as? Bool) == true
    }

    var isExpired: Bool {
        expirationDate <= Date()
    }

    var hasDeviceInstallScope: Bool {
        provisionsAllDevices || !provisionedDevices.isEmpty
    }

    func matches(bundleIdentifier: String) -> Bool {
        guard !bundleIdentifier.isEmpty,
              !bundleIdentifier.contains("*"),
              !bundleIdentifier.hasPrefix("."),
              !bundleIdentifier.hasSuffix(".") else { return false }

        let components = applicationIdentifier.split(separator: ".", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return false }
        let pattern = components[1]

        if pattern == "*" { return true }
        if pattern.hasSuffix(".*") {
            let prefix = String(pattern.dropLast(2))
            return bundleIdentifier.hasPrefix(prefix + ".")
        }
        return pattern == bundleIdentifier
    }

    func metadataReport(for bundleIdentifier: String, now: Date = Date()) -> ProfileMetadataReport {
        let expired = expirationDate <= now
        let bundleMatches = matches(bundleIdentifier: bundleIdentifier)
        return ProfileMetadataReport(
            profileName: name,
            profileUUID: uuid,
            bundleIdentifier: bundleIdentifier,
            teamIdentifiers: teamIdentifiers,
            applicationIdentifier: applicationIdentifier,
            isExpired: expired,
            bundleIdentifierMatches: bundleMatches,
            hasDeviceInstallScope: hasDeviceInstallScope,
            cmsSignatureVerified: false
        )
    }
}

struct ProfileMetadataReport {
    let profileName: String
    let profileUUID: String
    let bundleIdentifier: String
    let teamIdentifiers: [String]
    let applicationIdentifier: String
    let isExpired: Bool
    let bundleIdentifierMatches: Bool
    let hasDeviceInstallScope: Bool
    /// Always false here: this parser only extracts the plist payload.
    let cmsSignatureVerified: Bool

    /// This is a metadata-only result, never a final authorization to sign or install.
    var metadataIsCompatible: Bool {
        !isExpired && bundleIdentifierMatches && !teamIdentifiers.isEmpty
    }
}

enum ProvisioningProfileParseError: LocalizedError, Equatable {
    case payloadNotFound
    case invalidPropertyList
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .payloadNotFound:
            return "Não foi possível localizar o conteúdo plist dentro do perfil."
        case .invalidPropertyList:
            return "O conteúdo do perfil não é um Property List válido."
        case .missingField(let field):
            return "O perfil não contém o campo obrigatório \(field)."
        case .invalidField(let field):
            return "O campo \(field) tem um formato inválido."
        }
    }
}

enum ProvisioningProfileParser {
    static func parse(fileURL: URL) throws -> ProvisioningProfileMetadata {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        return try parse(data)
    }

    static func parse(_ cmsContainer: Data) throws -> ProvisioningProfileMetadata {
        guard let plistData = extractPlistPayload(from: cmsContainer) else {
            throw ProvisioningProfileParseError.payloadNotFound
        }
        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
        } catch {
            throw ProvisioningProfileParseError.invalidPropertyList
        }
        guard let dictionary = object as? [String: Any] else {
            throw ProvisioningProfileParseError.invalidPropertyList
        }

        guard let name = dictionary["Name"] as? String, !name.isEmpty else {
            throw ProvisioningProfileParseError.missingField("Name")
        }
        guard let uuid = dictionary["UUID"] as? String, !uuid.isEmpty else {
            throw ProvisioningProfileParseError.missingField("UUID")
        }
        guard let expirationDate = dictionary["ExpirationDate"] as? Date else {
            throw ProvisioningProfileParseError.missingField("ExpirationDate")
        }
        guard let teams = dictionary["TeamIdentifier"] as? [String], !teams.isEmpty else {
            throw ProvisioningProfileParseError.invalidField("TeamIdentifier")
        }
        guard let entitlements = dictionary["Entitlements"] as? [String: Any] else {
            throw ProvisioningProfileParseError.invalidField("Entitlements")
        }
        guard let applicationIdentifier = entitlements["application-identifier"] as? String,
              !applicationIdentifier.isEmpty else {
            throw ProvisioningProfileParseError.missingField("Entitlements.application-identifier")
        }

        let prefixes = dictionary["ApplicationIdentifierPrefix"] as? [String] ?? []
        let devices = dictionary["ProvisionedDevices"] as? [String] ?? []
        let allDevices = dictionary["ProvisionsAllDevices"] as? Bool ?? false

        return ProvisioningProfileMetadata(
            name: name,
            uuid: uuid,
            teamIdentifiers: teams,
            applicationIdentifierPrefixes: prefixes,
            applicationIdentifier: applicationIdentifier,
            creationDate: dictionary["CreationDate"] as? Date,
            expirationDate: expirationDate,
            provisionedDevices: devices,
            provisionsAllDevices: allDevices,
            entitlements: entitlements
        )
    }

    /// A .mobileprovision is a CMS envelope. This extracts its XML plist payload only;
    /// it deliberately does not claim that the CMS signature is valid.
    private static func extractPlistPayload(from data: Data) -> Data? {
        let opening = Data("<plist".utf8)
        let closing = Data("</plist>".utf8)
        guard let start = data.range(of: opening),
              let end = data.range(of: closing, options: [], in: start.lowerBound..<data.endIndex) else {
            return nil
        }
        return data[start.lowerBound..<end.upperBound]
    }
}
