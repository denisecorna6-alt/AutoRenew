import Combine
import CoreFoundation
import CryptoKit
import Foundation
import Security

struct SigningIdentityRecord: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let fileName: String
    let sha256: String
    let importedAt: Date
}

@MainActor
final class SigningIdentityVault: ObservableObject {
    @Published private(set) var records: [SigningIdentityRecord] = []

    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var directory = base.appendingPathComponent("SigningIdentities", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory
    }()

    private var indexURL: URL { directory.appendingPathComponent("identities.json") }

    init() {
        if let data = try? Data(contentsOf: indexURL),
           let saved = try? JSONDecoder().decode([SigningIdentityRecord].self, from: data) {
            records = saved.filter {
                $0.fileName == "\($0.id.uuidString).p12" &&
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent($0.fileName).path
                )
            }
        }
    }

    func importIdentity(from sourceURL: URL, password: String) throws {
        guard !password.isEmpty else { throw VaultError.passwordRequired }
        guard sourceURL.pathExtension.lowercased() == "p12" else { throw VaultError.unsupportedFile }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize > 0, fileSize <= 20_000_000 else { throw VaultError.invalidFileSize }

        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard !data.isEmpty, data.count <= 20_000_000 else {
            throw VaultError.invalidFileSize
        }
        var importedItems: CFArray?
        let status = SecPKCS12Import(
            data as CFData,
            [kSecImportExportPassphrase as String: password] as CFDictionary,
            &importedItems
        )
        guard status == errSecSuccess,
              let first = (importedItems as? [[String: Any]])?.first,
              let identityValue = first[kSecImportItemIdentity as String] else {
            if status == errSecAuthFailed { throw VaultError.wrongPassword }
            throw VaultError.invalidIdentity
        }
        // Security.framework returns this dictionary value as a CF object. Check its
        // runtime type before bridging it to SecIdentity (a CF type).
        guard CFGetTypeID(identityValue as CFTypeRef) == SecIdentityGetTypeID() else {
            throw VaultError.invalidIdentity
        }
        let identity = identityValue as! SecIdentity

        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let certificate else { throw VaultError.invalidIdentity }

        let displayName = SecCertificateCopySubjectSummary(certificate) as String? ?? "Certificado Apple"
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard !records.contains(where: { $0.sha256 == digest }) else { throw VaultError.duplicate }

        let id = UUID()
        let fileName = "\(id.uuidString).p12"
        let destination = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedDestination = destination
            try protectedDestination.setResourceValues(values)
            records.append(SigningIdentityRecord(
                id: id,
                displayName: displayName,
                fileName: fileName,
                sha256: digest,
                importedAt: Date()
            ))
            try persistIndex()
        } catch {
            records.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func remove(_ record: SigningIdentityRecord) {
        guard record.fileName == "\(record.id.uuidString).p12" else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(record.fileName))
        records.removeAll { $0.id == record.id }
        try? persistIndex()
    }

    private func persistIndex() throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: indexURL, options: [.atomic, .completeFileProtection])
    }
}

enum VaultError: LocalizedError {
    case passwordRequired
    case unsupportedFile
    case invalidFileSize
    case wrongPassword
    case invalidIdentity
    case duplicate

    var errorDescription: String? {
        switch self {
        case .passwordRequired: return "Digite a senha do arquivo .p12 para validar a chave privada."
        case .unsupportedFile: return "Selecione um arquivo .p12."
        case .invalidFileSize: return "O arquivo está vazio ou excede o limite de 20 MB."
        case .wrongPassword: return "A senha do .p12 está incorreta ou o arquivo está danificado."
        case .invalidIdentity: return "O arquivo não contém uma identidade válida com certificado e chave privada."
        case .duplicate: return "Este certificado já foi importado."
        }
    }
}
