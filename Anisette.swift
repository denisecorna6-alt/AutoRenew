import Foundation

struct AnisetteData {
    var headers: [String: String]
    var fetched = Date()
    var isValid: Bool {
        headers["X-Apple-I-MD"] != nil &&
        Date().timeIntervalSince(fetched) < 300
    }
}

protocol AnisetteProvider {
    func fetch() async throws -> AnisetteData
}

struct RemoteAnisetteProvider: AnisetteProvider {
    let url: URL

    func fetch() async throws -> AnisetteData {
        guard url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              url.fragment == nil else {
            throw RefreshError.anisetteUnavailable
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RefreshError.anisetteUnavailable
        }
        let headers = object.compactMapValues { $0 as? String }
        let result = AnisetteData(headers: headers)
        guard result.isValid else { throw RefreshError.anisetteUnavailable }
        return result
    }
}

/// Tries configured HTTPS providers in priority order and reuses short-lived metadata.
final class AnisetteRouter: AnisetteProvider {
    private static var cache: AnisetteData?
    private let providers: [AnisetteProvider]

    init(urls: [String]) {
        providers = urls.compactMap { raw in
            guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme?.lowercased() == "https",
                  url.host != nil,
                  url.user == nil, url.password == nil,
                  url.fragment == nil else { return nil }
            return RemoteAnisetteProvider(url: url)
        }
    }

    func fetch() async throws -> AnisetteData {
        if let cached = Self.cache, cached.isValid { return cached }
        for provider in providers {
            if let data = try? await provider.fetch(), data.isValid {
                Self.cache = data
                return data
            }
        }
        throw RefreshError.anisetteUnavailable
    }
}
