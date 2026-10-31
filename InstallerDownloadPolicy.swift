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

    static func exceedsStreamingLimit(bytesWritten: Int64, expectedBytes: Int64) -> Bool {
        let maximum = Int64(maximumFileSize)
        return bytesWritten > maximum || (expectedBytes > 0 && expectedBytes > maximum)
    }

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

private final class BoundedIPADownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let maximumBytes = Int64(InstallerDownloadPolicy.maximumFileSize)
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var session: URLSession?
    private var downloadedURL: URL?
    private var downloadResponse: URLResponse?
    private var terminalError: Error?

    func download(_ request: URLRequest) async throws -> (URL, URLResponse) {
        guard let source = request.url,
              source.scheme?.lowercased() == "https",
              source.host != nil,
              source.user == nil,
              source.password == nil else {
            throw InstallerDownloadError.insecureURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 1_800
            let delegateQueue = OperationQueue()
            delegateQueue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
            self.session = session
            session.downloadTask(with: request).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            terminalError = InstallerDownloadError.badHTTPResponse
            downloadTask.cancel()
            return
        }
        if InstallerDownloadPolicy.exceedsStreamingLimit(
            bytesWritten: totalBytesWritten,
            expectedBytes: totalBytesExpectedToWrite
        ) {
            terminalError = InstallerDownloadError.invalidFileSize
            downloadTask.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let target = request.url,
              target.scheme?.lowercased() == "https",
              target.host != nil,
              target.user == nil,
              target.password == nil else {
            terminalError = InstallerDownloadError.insecureURL
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard terminalError == nil,
              let response = downloadTask.response,
              let finalURL = response.url,
              finalURL.scheme?.lowercased() == "https",
              finalURL.host != nil,
              finalURL.user == nil,
              finalURL.password == nil else {
            if terminalError == nil { terminalError = InstallerDownloadError.insecureURL }
            return
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            terminalError = InstallerDownloadError.badHTTPResponse
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard size > 0, size <= maximumBytes else {
                terminalError = InstallerDownloadError.invalidFileSize
                return
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("ipa")
            try FileManager.default.moveItem(at: location, to: destination)
            downloadedURL = destination
            downloadResponse = response
        } catch {
            terminalError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let continuation = self.continuation
        self.continuation = nil
        let failure = terminalError ?? error
        let url = downloadedURL
        let response = downloadResponse
        self.session = nil
        session.finishTasksAndInvalidate()

        if let failure {
            if let url { try? FileManager.default.removeItem(at: url) }
            continuation?.resume(throwing: failure)
        } else if let url, let response {
            continuation?.resume(returning: (url, response))
        } else {
            continuation?.resume(throwing: InstallerDownloadError.badHTTPResponse)
        }
    }
}

enum BoundedIPADownloader {
    static func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        try await BoundedIPADownloadDelegate().download(request)
    }
}
