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
            return "O arquivo está vazio ou excede o limite permitido."
        case .invalidFilename:
            return "O servidor não forneceu um nome de arquivo .ipa válido."
        }
    }
}

enum InstallerDownloadPolicy {
    static let maximumFileSize = 1_500_000_000
    static let maximumCatalogSize = 5 * 1_024 * 1_024
    private static let ioChunkSize = 64 * 1_024

    private static func isSafeHTTPS(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme?.lowercased() == "https"
            && url.host != nil
            && url.user == nil
            && url.password == nil
    }

    private static func validateResponse(for request: URLRequest, response: URLResponse) throws {
        guard isSafeHTTPS(request.url), isSafeHTTPS(response.url) else {
            throw InstallerDownloadError.insecureURL
        }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw InstallerDownloadError.badHTTPResponse
        }
    }

    private static func validateExpectedSize(_ response: URLResponse, maximumBytes: Int) throws {
        guard maximumBytes > 0 else { throw InstallerDownloadError.invalidFileSize }
        if response.expectedContentLength > Int64(maximumBytes) {
            throw InstallerDownloadError.invalidFileSize
        }
        if let rawLength = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Length"),
           let declaredLength = Int64(rawLength),
           declaredLength > Int64(maximumBytes) {
            throw InstallerDownloadError.invalidFileSize
        }
    }

    /// Reads a response incrementally and refuses oversized bodies before they can exhaust memory.
    static func fetchData(
        for request: URLRequest,
        maximumBytes: Int = maximumCatalogSize
    ) async throws -> (data: Data, response: URLResponse) {
        guard isSafeHTTPS(request.url) else { throw InstallerDownloadError.insecureURL }
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try validateResponse(for: request, response: response)
        try validateExpectedSize(response, maximumBytes: maximumBytes)

        var data = Data()
        data.reserveCapacity(min(maximumBytes, 64 * 1_024))
        for try await byte in bytes {
            data.append(byte)
            if data.count > maximumBytes {
                throw InstallerDownloadError.invalidFileSize
            }
        }
        guard !data.isEmpty else { throw InstallerDownloadError.invalidFileSize }
        return (data, response)
    }

    /// Streams a download to a temporary file and enforces the size limit while receiving it.
    /// The caller owns the returned file and must move or delete it.
    static func download(
        for request: URLRequest,
        maximumBytes: Int = maximumFileSize
    ) async throws -> (temporaryURL: URL, response: URLResponse) {
        guard isSafeHTTPS(request.url), maximumBytes > 0 else {
            throw InstallerDownloadError.insecureURL
        }
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try validateResponse(for: request, response: response)
        try validateExpectedSize(response, maximumBytes: maximumBytes)

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("download")
        guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }

        var received = 0
        var buffer = Data()
        buffer.reserveCapacity(ioChunkSize)
        do {
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= ioChunkSize {
                    received += buffer.count
                    guard received <= maximumBytes else {
                        throw InstallerDownloadError.invalidFileSize
                    }
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                }
            }

            received += buffer.count
            guard received > 0, received <= maximumBytes else {
                throw InstallerDownloadError.invalidFileSize
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()
            return (temporaryURL, response)
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    static func validatedReleaseFilename(
        sourceURL: URL,
        response: URLResponse?,
        assetName: String,
        fileSize: Int
    ) throws -> String {
        guard isSafeHTTPS(sourceURL), let response else {
            throw InstallerDownloadError.insecureURL
        }
        try validateResponse(for: URLRequest(url: sourceURL), response: response)
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
