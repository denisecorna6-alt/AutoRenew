import Foundation

struct AnisetteData: Sendable {
    var headers: [String: String]
    var fetched = Date()

    var isValid: Bool {
        guard let machineData = headers["X-Apple-I-MD"], !machineData.isEmpty else {
            return false
        }
        let age = Date().timeIntervalSince(fetched)
        // Reject clock-skewed/future timestamps as well as expired cache entries.
        return age >= 0 && age < 300
    }
}

protocol AnisetteProvider: Sendable {
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
        let (data, response) = try await InstallerDownloadPolicy.fetchData(for: request, maximumBytes: 1 * 1_024 * 1_024)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw RefreshError.network
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RefreshError.anisetteUnavailable
        }
        let result = AnisetteData(headers: object.compactMapValues { $0 as? String })
        guard result.isValid else { throw RefreshError.anisetteUnavailable }
        return result
    }
}

/// Actor isolation prevents concurrent refresh tasks from racing the metadata cache.
actor AnisetteRouter: AnisetteProvider {
    private var cache: AnisetteData?
    private let providers: [any AnisetteProvider]

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
        if let cached = cache, cached.isValid { return cached }
        for provider in providers {
            if let value = try? await provider.fetch(), value.isValid {
                cache = value
                return value
            }
        }
        throw RefreshError.anisetteUnavailable
    }
}
