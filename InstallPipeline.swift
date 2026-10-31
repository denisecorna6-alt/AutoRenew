import Foundation
import CryptoKit

struct IPAInspection: Equatable {
    let fileURL: URL
    let fileName: String
    let byteCount: Int
    let sha256: String
}

enum IPAInspectionError: LocalizedError, Equatable {
    case unsupportedExtension
    case fileMissing
    case emptyFile
    case fileTooLarge
    case invalidArchive
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension:
            return "Selecione um arquivo com extensão .ipa."
        case .fileMissing:
            return "O arquivo IPA não está mais disponível."
        case .emptyFile:
            return "O arquivo IPA está vazio."
        case .fileTooLarge:
            return "O IPA excede o limite de 1,5 GB."
        case .invalidArchive:
            return "O arquivo não começa com a assinatura ZIP esperada para um IPA."
        case .unreadable:
            return "Não foi possível ler o arquivo IPA."
        }
    }
}

/// Performs a bounded, streaming preflight before handing an IPA to a signing/install tool.
/// This is deliberately not a code-signature or provisioning-profile validator.
enum IPAInspector {
    static let maximumFileSize = 1_500_000_000
    private static let chunkSize = 1_048_576

    static func inspect(fileURL: URL) throws -> IPAInspection {
        guard fileURL.pathExtension.lowercased() == "ipa" else {
            throw IPAInspectionError.unsupportedExtension
        }

        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IPAInspectionError.fileMissing
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            throw IPAInspectionError.unreadable
        }

        guard let size = (attributes[.size] as? NSNumber)?.intValue else {
            throw IPAInspectionError.unreadable
        }
        guard size > 0 else { throw IPAInspectionError.emptyFile }
        guard size <= maximumFileSize else { throw IPAInspectionError.fileTooLarge }

        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            let header = try handle.read(upToCount: 4) ?? Data()
            guard header.count == 4,
                  header[0] == 0x50, header[1] == 0x4B,
                  header[2] == 0x03, header[3] == 0x04 else {
                throw IPAInspectionError.invalidArchive
            }

            try handle.seek(toOffset: 0)
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            let digest = hasher.finalize()
                .map { String(format: "%02x", $0) }
                .joined()

            return IPAInspection(
                fileURL: fileURL,
                fileName: fileURL.lastPathComponent,
                byteCount: size,
                sha256: digest
            )
        } catch let error as IPAInspectionError {
            throw error
        } catch {
            throw IPAInspectionError.unreadable
        }
    }
}
