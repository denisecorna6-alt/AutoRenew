import Foundation

struct AnisetteData {
    var headers: [String: String]
    var fetched = Date()
    var isValid: Bool { headers["X-Apple-I-MD"] != nil && Date().timeIntervalSince(fetched) < 300 }
}

protocol AnisetteProvider { func fetch() async throws -> AnisetteData }

struct RemoteAnisetteProvider: AnisetteProvider {
    let url: URL
    func fetch() async throws -> AnisetteData {
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RefreshError.anisetteUnavailable }
        return AnisetteData(headers: obj.compactMapValues { $0 as? String })
    }
}

/// Tenta cada provider em ordem; reutiliza cache válido.
final class AnisetteRouter: AnisetteProvider {
    private static var cache: AnisetteData?
    private let providers: [AnisetteProvider]
    init(urls: [String]) { providers = urls.compactMap { URL(string: $0) }.map { RemoteAnisetteProvider(url: $0) } }

    func fetch() async throws -> AnisetteData {
        if let c = Self.cache, c.isValid { return c }
        for p in providers {
            if let d = try? await p.fetch(), d.isValid { Self.cache = d; return d }
        }
        throw RefreshError.anisetteUnavailable
    }
}
