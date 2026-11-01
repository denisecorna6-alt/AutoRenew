import Foundation

/// Retrieves the public client metadata required to form Apple GrandSlam requests.
struct AnisetteV3ServerClientInfoClient: Sendable {
    let serverURL: URL
    let session: URLSession

    init(serverURL: URL, session: URLSession = .shared) {
        self.serverURL = serverURL
        self.session = session
    }

    func fetch() async throws -> AnisetteV3AppleClientInfo {
        let request = try Self.makeRequest(serverURL: serverURL)
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
              finalURL.scheme?.lowercased() == "https",
              finalURL.host?.lowercased() == serverURL.host?.lowercased(),
              !data.isEmpty, data.count <= 64_000 else {
            throw RefreshError.anisetteUnavailable
        }
        return try Self.parse(data)
    }

    static func makeRequest(serverURL: URL) throws -> URLRequest {
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw RefreshError.anisetteUnavailable
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = (basePath.isEmpty ? "" : "/" + basePath) + "/v3/client_info"
        guard let endpoint = components.url else {
            throw RefreshError.anisetteUnavailable
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func parse(_ data: Data) throws -> AnisetteV3AppleClientInfo {
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            let info = AnisetteV3AppleClientInfo(
                clientInfo: payload.clientInfo,
                userAgent: payload.userAgent
            )
            guard info.isValid else { throw RefreshError.anisetteUnavailable }
            return info
        } catch let error as RefreshError {
            throw error
        } catch {
            throw RefreshError.anisetteUnavailable
        }
    }

    private struct Payload: Decodable {
        let clientInfo: String
        let userAgent: String

        enum CodingKeys: String, CodingKey {
            case clientInfo = "client_info"
            case userAgent = "user_agent"
        }
    }
}

/// Runs the complete remote V3 provisioning conversation.
/// Apple requests are sent directly to Apple; only the V3 protocol messages
/// required by the upstream flow are exchanged with the configured Anisette server.
struct AnisetteV3Provisioner: Sendable {
    let serverURL: URL
    let session: URLSession
    let vault: AnisetteV3StateVault

    init(
        serverURL: URL,
        session: URLSession = .shared,
        vault: AnisetteV3StateVault = AnisetteV3StateVault()
    ) {
        self.serverURL = serverURL
        self.session = session
        self.vault = vault
    }

    /// Provisions only when no ADI blob is stored. Does not fetch headers or sign apps.
    func provisionIfNeeded() async throws {
        if try await vault.loadProvisioningState() != nil { return }

        let identifier = try await vault.loadOrCreateIdentifier()
        let clientInfo = try await AnisetteV3ServerClientInfoClient(
            serverURL: serverURL,
            session: session
        ).fetch()
        let appleClient = AnisetteV3AppleProvisioningClient(session: session)
        let appleURLs = try await appleClient.lookupURLs(
            identifier: identifier,
            clientInfo: clientInfo
        )

        let webSocketURL = try Self.makeWebSocketURL(serverURL: serverURL)
        var socketRequest = URLRequest(url: webSocketURL)
        socketRequest.timeoutInterval = 20
        let socket = session.webSocketTask(with: socketRequest)
        socket.maximumMessageSize = 2_000_000
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        var machine = AnisetteV3ProvisioningStateMachine()
        for _ in 0..<8 {
            let incoming = try await Self.receiveText(from: socket)
            let action = try machine.receive(json: incoming)
            switch action {
            case .sendIdentifier:
                try await Self.send(
                    .identifier(identifier),
                    through: socket
                )
            case .requestStartProvisioning:
                let spim = try await appleClient.startProvisioning(
                    at: appleURLs.start,
                    identifier: identifier,
                    clientInfo: clientInfo
                )
                try await Self.send(.spim(spim), through: socket)
            case .requestFinishProvisioning(let cpim):
                let finish = try await appleClient.finishProvisioning(
                    at: appleURLs.finish,
                    cpim: cpim,
                    identifier: identifier,
                    clientInfo: clientInfo
                )
                try await Self.send(
                    .finish(ptm: finish.ptm, tk: finish.tk),
                    through: socket
                )
            case .completed(let adiPB):
                try await vault.saveProvisionedState(
                    identifier: identifier,
                    adiPB: adiPB
                )
                return
            }
        }
        throw RefreshError.anisetteUnavailable
    }

    static func makeWebSocketURL(serverURL: URL) throws -> URL {
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw RefreshError.anisetteUnavailable
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.scheme = "wss"
        components.path = (basePath.isEmpty ? "" : "/" + basePath) + "/v3/provisioning_session"
        guard let url = components.url else {
            throw RefreshError.anisetteUnavailable
        }
        return url
    }

    private static func send(
        _ reply: AnisetteV3ProvisioningReply,
        through socket: URLSessionWebSocketTask
    ) async throws {
        do {
            let data = try reply.jsonData()
            let message = String(decoding: data, as: UTF8.self)
            try await socket.send(.string(message))
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RefreshError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw RefreshError.network
        }
    }

    private static func receiveText(
        from socket: URLSessionWebSocketTask
    ) async throws -> Data {
        do {
            return try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    let message = try await socket.receive()
                    guard case .string(let text) = message,
                          !text.isEmpty, text.utf8.count <= 2_000_000 else {
                        throw RefreshError.anisetteUnavailable
                    }
                    return Data(text.utf8)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    throw RefreshError.network
                }
                guard let first = try await group.next() else {
                    throw RefreshError.network
                }
                group.cancelAll()
                return first
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RefreshError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw RefreshError.network
        }
    }
}
