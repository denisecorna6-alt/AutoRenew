import Foundation

enum InstallerDownloadError: LocalizedError, Equatable {
    case insecureURL
    case badHTTPResponse
    case invalidFileSize
    case invalidFilename

    var errorDescription: String? {
        switch self {
        case .insecureURL:
            return "O download não terminou em uma URL HTTPS segura."
        case .badHTTPResponse:
            return "O servidor não confirmou o download com HTTP 2xx."
        case .invalidFileSize:
            return "O arquivo está vazio ou excede o limite de 1,5 GB."
        case .invalidFilename:
            return "O servidor não forneceu um nome de arquivo .ipa válido."
        }
    }
}

enum InstallerDownloadPolicy {
    static let maximumFileSize = 1_500_000_000

    static func validatedReleaseFilename(
        sourceURL: URL,
        response: URLResponse?,
        assetName: String,
        fileSize: Int
    ) throws -> String {
        guard sourceURL.scheme?.lowercased() == "https",
              sourceURL.host != nil,
              sourceURL.user == nil,
              sourceURL.password == nil,
              let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let finalURL = response.url,
              finalURL.scheme?.lowercased() == "https",
              finalURL.host != nil,
              finalURL.user == nil,
              finalURL.password == nil else {
            throw InstallerDownloadError.insecureURL
        }
        guard fileSize > 0, fileSize <= maximumFileSize else {
            throw InstallerDownloadError.invalidFileSize
        }
        let filename = URL(fileURLWithPath: assetName).lastPathComponent
        guard filename.lowercased().hasSuffix(".ipa"),
              filename != ".ipa",
              !filename.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw InstallerDownloadError.invalidFilename
        }
        return filename
    }

    static func uniqueDestination(in directory: URL, filename: String, fileManager: FileManager = .default) -> URL {
        let original = directory.appendingPathComponent(filename, isDirectory: false)
        guard fileManager.fileExists(atPath: original.path) else { return original }
        let stem = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        return directory.appendingPathComponent("\(stem)-\(UUID().uuidString).\(ext)", isDirectory: false)
    }
}
