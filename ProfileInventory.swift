import CryptoKit
import Foundation

struct ImportedProfile: Codable, Identifiable, Hashable {
    var id: String
    var originalFileName: String
    var storedFileName: String
    var byteCount: Int
    var sha256: String
    var importedAt: Date

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

enum ProfileImportError: LocalizedError, Equatable {
    case unsupportedFile
    case fileTooLarge
    case emptyFile
    case duplicate
    case unreadable
    case storage

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: return "Selecione um arquivo .mobileprovision."
        case .fileTooLarge: return "O arquivo excede o limite de 25 MB."
        case .emptyFile: return "O arquivo selecionado está vazio."
        case .duplicate: return "Este arquivo já foi importado (mesmo SHA-256)."
        case .unreadable: return "Não foi possível ler o arquivo selecionado."
        case .storage: return "Não foi possível guardar uma cópia local do perfil."
        }
    }
}

enum ProfileImporter {
    static let maximumFileSize = 25 * 1_024 * 1_024

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func importProfile(from sourceURL: URL, into directory: URL) throws -> ImportedProfile {
        guard sourceURL.pathExtension.lowercased() == "mobileprovision" else {
            throw ProfileImportError.unsupportedFile
        }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        guard let fileSize = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw ProfileImportError.unreadable
        }
        guard fileSize <= maximumFileSize else {
            throw ProfileImportError.fileTooLarge
        }
        guard let data = try? Data(contentsOf: sourceURL, options: .mappedIfSafe) else {
            throw ProfileImportError.unreadable
        }
        // Recheck the bytes actually read: the source could change after the metadata check.
        guard data.count <= maximumFileSize else {
            throw ProfileImportError.fileTooLarge
        }
        guard !data.isEmpty else {
            throw ProfileImportError.emptyFile
        }

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            var directoryValues = URLResourceValues()
            directoryValues.isExcludedFromBackup = true
            try directory.setResourceValues(directoryValues)
            let id = UUID().uuidString
            let storedName = "\(id).mobileprovision"
            let destination = directory.appendingPathComponent(storedName, isDirectory: false)
            do {
                try data.write(to: destination, options: [.atomic, .completeFileProtection])
                var fileValues = URLResourceValues()
                fileValues.isExcludedFromBackup = true
                try destination.setResourceValues(fileValues)
                return ImportedProfile(
                    id: id,
                    originalFileName: sourceURL.lastPathComponent,
                    storedFileName: storedName,
                    byteCount: data.count,
                    sha256: sha256(data),
                    importedAt: Date()
                )
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        } catch {
            throw ProfileImportError.storage
        }
    }
}
