import Foundation

/// A locally provisioned Anisette V3 identity. The ADI blob and identifier are
/// sensitive device credentials and must only be supplied from protected storage.
struct AnisetteV3ProvisioningState: Sendable {
    let identifier: Data
    let adiPB: Data

    var isUsable: Bool {
        !identifier.isEmpty && !adiPB.isEmpty &&
        identifier.count <= 256 && adiPB.count <= 1_000_000
    }
}

/// Implements the V3 /get_headers exchange for an identity that has already
/// completed the provisioning WebSocket flow. This type does not provision ADI.
struct AnisetteV3HeadersClient: Sendable {
    let serverURL: URL
    let session: URLSession

    init(serverURL: URL, session: URLSession = .shared) {
        self.serverURL = serverURL
        self.session = session
    }

    func fetch(using state: AnisetteV3ProvisioningState) async throws -> AnisetteData {
        guard state.isUsable else { throw RefreshError.anisetteUnavailable }

        let request = try Self.makeRequest(serverURL: serverURL, state: state)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RefreshError.network
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw RefreshError.anisetteUnavailable
        }

        return try Self.decodeResponse(data)
    }

    static func decodeResponse(_ data: Data) throws -> AnisetteData {
        do {
            let payload = try JSONDecoder().decode(Response.self, from: data)
            switch payload {
            case let .headers(machineID, oneTimePassword, routingInfo):
                guard !machineID.isEmpty, !oneTimePassword.isEmpty, !routingInfo.isEmpty else {
                    throw RefreshError.anisetteUnavailable
                }
                return AnisetteData(headers: [
                    "X-Apple-I-MD-M": machineID,
                    "X-Apple-I-MD": oneTimePassword,
                    "X-Apple-I-MD-RINFO": routingInfo
                ])
            case .error(let message):
                if message.contains("-45061") {
                    throw RefreshError.anisetteNeedsProvisioning
                }
                throw RefreshError.anisetteUnavailable
            }
        } catch let error as RefreshError {
            throw error
        } catch {
            throw RefreshError.anisetteUnavailable
        }
    }

    static func makeRequest(
        serverURL: URL,
        state: AnisetteV3ProvisioningState
    ) throws -> URLRequest {
        guard state.isUsable,
              var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw RefreshError.anisetteUnavailable
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = (basePath.isEmpty ? "" : "/" + basePath) + "/v3/get_headers"
        guard let endpoint = components.url else {
            throw RefreshError.anisetteUnavailable
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(
            identifier: state.identifier.base64EncodedString(),
            adiPB: state.adiPB.base64EncodedString()
        ))
        return request
    }

    private struct Request: Encodable {
        let identifier: String
        let adiPB: String

        enum CodingKeys: String, CodingKey {
            case identifier
            case adiPB = "adi_pb"
        }
    }

    private enum Response: Decodable {
        case headers(machineID: String, oneTimePassword: String, routingInfo: String)
        case error(String)

        private enum CodingKeys: String, CodingKey {
            case result
            case message
            case machineID = "X-Apple-I-MD-M"
            case oneTimePassword = "X-Apple-I-MD"
            case routingInfo = "X-Apple-I-MD-RINFO"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let result = try container.decode(String.self, forKey: .result)
            guard result == "Headers" else {
                self = .error(try container.decodeIfPresent(String.self, forKey: .message) ?? "")
                return
            }
            self = .headers(
                machineID: try container.decode(String.self, forKey: .machineID),
                oneTimePassword: try container.decode(String.self, forKey: .oneTimePassword),
                routingInfo: try container.decode(String.self, forKey: .routingInfo)
            )
        }
    }
}
