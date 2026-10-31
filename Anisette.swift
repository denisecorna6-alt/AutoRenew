import Foundation

struct AnisetteData: Sendable {
    var headers: [String: String]
    var fetched = Date()

    /// The Apple machine-data header is required and the response is short-lived.
    var isValid: Bool {
        guard let machineData = headers["X-Apple-I-MD"], !machineData.isEmpty else {
            return false
        }
        return Date().timeIntervalSince(fetched) < 300
    }
}

protocol AnisetteProvider: Sendable {
    func fetch() async throws -> AnisetteData
}

struct RemoteAnisetteProvider: AnisetteProvider {
    let url: URL

    func fetch() async throws -> AnisetteData {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw RefreshError.network
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RefreshError.anisetteUnavailable
        }

        let result = AnisetteData(headers: object.compactMapValues { $0 as? String })
        guard result.isValid else {
            throw RefreshError.anisetteUnavailable
        }
        return result
    }
}

/// Tries providers in priority order and caches only validated, short-lived data.
/// Actor isolation prevents concurrent refresh tasks from racing the cache.
actor AnisetteRouter: AnisetteProvider {
    private var cache: AnisetteData?
    private let providers: [any AnisetteProvider]

    init(urls: [String]) {
        providers = urls
            .compactMap(URL.init(string:))
            .map(RemoteAnisetteProvider.init(url:))
    }

    func fetch() async throws -> AnisetteData {
        if let cached = cache, cached.isValid {
            return cached
        }

        for provider in providers {
            if let value = try? await provider.fetch(), value.isValid {
                cache = value
                return value
            }
        }

        throw RefreshError.anisetteUnavailable
    }
}
