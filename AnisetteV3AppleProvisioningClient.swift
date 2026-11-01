import CryptoKit
import Foundation

struct AnisetteV3AppleClientInfo: Sendable {
    let clientInfo: String
    let userAgent: String

    var isValid: Bool {
        !clientInfo.isEmpty && !userAgent.isEmpty &&
        clientInfo.utf8.count <= 2_048 && userAgent.utf8.count <= 512
    }
}

struct AnisetteV3AppleProvisioningURLs: Sendable {
    let start: URL
    let finish: URL
}

struct AnisetteV3AppleFinishData: Equatable, Sendable {
    let ptm: String
    let tk: String
}

/// Performs the Apple GrandSlam plist exchanges used by Anisette V3.
/// URLSession's normal TLS certificate validation remains enabled.
struct AnisetteV3AppleProvisioningClient: Sendable {
    private static let lookupURL = URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookupURLs(
        identifier: Data,
        clientInfo: AnisetteV3AppleClientInfo
    ) async throws -> AnisetteV3AppleProvisioningURLs {
        let request = try Self.makeAppleRequest(
            url: Self.lookupURL,
            method: "GET",
            body: nil,
            identifier: identifier,
            clientInfo: clientInfo
        )
        return try Self.parseProvisioningURLs(await perform(request))
    }

    func startProvisioning(
        at url: URL,
        identifier: Data,
        clientInfo: AnisetteV3AppleClientInfo
    ) async throws -> String {
        let body = try Self.makeProvisioningPlist(cpim: nil)
        let request = try Self.makeAppleRequest(
            url: url,
            method: "POST",
            body: body,
            identifier: identifier,
            clientInfo: clientInfo
        )
        return try Self.parseSPIM(await perform(request))
    }

    func finishProvisioning(
        at url: URL,
        cpim: String,
        identifier: Data,
        clientInfo: AnisetteV3AppleClientInfo
    ) async throws -> AnisetteV3AppleFinishData {
        guard !cpim.isEmpty, cpim.utf8.count <= 1_000_000 else {
            throw RefreshError.anisetteUnavailable
        }
        let body = try Self.makeProvisioningPlist(cpim: cpim)
        let request = try Self.makeAppleRequest(
            url: url,
            method: "POST",
            body: body,
            identifier: identifier,
            clientInfo: clientInfo
        )
        return try Self.parseFinishData(await perform(request))
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw RefreshError.network
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url,
              Self.isAppleHTTPSURL(finalURL),
              !data.isEmpty, data.count <= 2_000_000 else {
            throw RefreshError.anisetteUnavailable
        }
        return data
    }

    static func makeAppleRequest(
        url: URL,
        method: String,
        body: Data?,
        identifier: Data,
        clientInfo: AnisetteV3AppleClientInfo,
        now: Date = Date()
    ) throws -> URLRequest {
        guard identifier.count == 16,
              clientInfo.isValid,
              isAppleHTTPSURL(url),
              method == "GET" || method == "POST" else {
            throw RefreshError.anisetteUnavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(clientInfo.clientInfo, forHTTPHeaderField: "X-Mme-Client-Info")
        request.setValue(clientInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue(localUserID(for: identifier), forHTTPHeaderField: "X-Apple-I-MD-LU")
        request.setValue(deviceID(for: identifier), forHTTPHeaderField: "X-Mme-Device-Id")
        request.setValue(clientTime(now), forHTTPHeaderField: "X-Apple-I-Client-Time")
        request.setValue("UTC", forHTTPHeaderField: "X-Apple-I-TimeZone")
        request.setValue("en_US", forHTTPHeaderField: "X-Apple-Locale")
        request.httpBody = body
        return request
    }

    static func makeProvisioningPlist(cpim: String?) throws -> Data {
        var request: [String: Any] = [:]
        if let cpim {
            guard !cpim.isEmpty, cpim.utf8.count <= 1_000_000 else {
                throw RefreshError.anisetteUnavailable
            }
            request["cpim"] = cpim
        }
        let payload: [String: Any] = [
            "Header": [String: Any](),
            "Request": request
        ]
        do {
            return try PropertyListSerialization.data(
                fromPropertyList: payload,
                format: .xml,
                options: 0
            )
        } catch {
            throw RefreshError.anisetteUnavailable
        }
    }

    static func parseProvisioningURLs(_ data: Data) throws -> AnisetteV3AppleProvisioningURLs {
        let root = try parsePlistDictionary(data)
        guard let urls = root["urls"] as? [String: Any],
              let startString = urls["midStartProvisioning"] as? String,
              let finishString = urls["midFinishProvisioning"] as? String,
              let start = URL(string: startString),
              let finish = URL(string: finishString),
              isAppleHTTPSURL(start), isAppleHTTPSURL(finish) else {
            throw RefreshError.anisetteUnavailable
        }
        return AnisetteV3AppleProvisioningURLs(start: start, finish: finish)
    }

    static func parseSPIM(_ data: Data) throws -> String {
        let response = try parseAppleResponse(data)
        guard let spim = response["spim"] as? String,
              !spim.isEmpty, spim.utf8.count <= 1_000_000 else {
            throw RefreshError.anisetteUnavailable
        }
        return spim
    }

    static func parseFinishData(_ data: Data) throws -> AnisetteV3AppleFinishData {
        let response = try parseAppleResponse(data)
        guard let ptm = response["ptm"] as? String,
              let tk = response["tk"] as? String,
              !ptm.isEmpty, !tk.isEmpty,
              ptm.utf8.count <= 1_000_000, tk.utf8.count <= 1_000_000 else {
            throw RefreshError.anisetteUnavailable
        }
        return AnisetteV3AppleFinishData(ptm: ptm, tk: tk)
    }

    private static func parseAppleResponse(_ data: Data) throws -> [String: Any] {
        let root = try parsePlistDictionary(data)
        guard let response = root["Response"] as? [String: Any] else {
            throw RefreshError.anisetteUnavailable
        }
        return response
    }

    private static func parsePlistDictionary(_ data: Data) throws -> [String: Any] {
        guard !data.isEmpty, data.count <= 2_000_000 else {
            throw RefreshError.anisetteUnavailable
        }
        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let value = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            )
            guard let dictionary = value as? [String: Any] else {
                throw RefreshError.anisetteUnavailable
            }
            return dictionary
        } catch let error as RefreshError {
            throw error
        } catch {
            throw RefreshError.anisetteUnavailable
        }
    }

    private static func isAppleHTTPSURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              components.user == nil, components.password == nil,
              components.fragment == nil else {
            return false
        }
        return host == "apple.com" || host.hasSuffix(".apple.com")
    }

    private static func localUserID(for identifier: Data) -> String {
        SHA256.hash(data: identifier)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func deviceID(for identifier: Data) -> String {
        let hex = identifier.map { String(format: "%02X", $0) }.joined()
        let groups = [8, 4, 4, 4, 12]
        var cursor = hex.startIndex
        return groups.map { count in
            let end = hex.index(cursor, offsetBy: count)
            let part = String(hex[cursor..<end])
            cursor = end
            return part
        }.joined(separator: "-")
    }

    private static func clientTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter.string(from: date)
    }
}
