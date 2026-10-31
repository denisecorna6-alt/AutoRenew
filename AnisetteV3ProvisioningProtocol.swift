import Foundation

/// Messages exchanged by the SideStore Anisette V3 provisioning WebSocket.
/// This type intentionally contains protocol data only; transport and Apple calls
/// are handled by a separate coordinator.
enum AnisetteV3ProvisioningMessage: Decodable, Equatable, Sendable {
    case giveIdentifier
    case giveStartProvisioningData
    case giveEndProvisioningData(cpim: String)
    case provisioningSuccess(adiPB: String)
    case timeout

    private enum CodingKeys: String, CodingKey {
        case result
        case cpim
        case adiPB = "adi_pb"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .result) {
        case "GiveIdentifier":
            self = .giveIdentifier
        case "GiveStartProvisioningData":
            self = .giveStartProvisioningData
        case "GiveEndProvisioningData":
            let cpim = try container.decode(String.self, forKey: .cpim)
            guard !cpim.isEmpty, cpim.utf8.count <= 1_000_000 else {
                throw AnisetteV3ProvisioningProtocolError.invalidPayload
            }
            self = .giveEndProvisioningData(cpim: cpim)
        case "ProvisioningSuccess":
            let adiPB = try container.decode(String.self, forKey: .adiPB)
            guard let decoded = Data(base64Encoded: adiPB),
                  !decoded.isEmpty, decoded.count <= 1_000_000 else {
                throw AnisetteV3ProvisioningProtocolError.invalidPayload
            }
            self = .provisioningSuccess(adiPB: adiPB)
        case "Timeout":
            self = .timeout
        default:
            throw AnisetteV3ProvisioningProtocolError.unknownMessage
        }
    }
}

/// Outbound messages use the exact JSON field names expected by the V3 server.
enum AnisetteV3ProvisioningReply: Encodable, Equatable, Sendable {
    case identifier(Data)
    case spim(String)
    case finish(ptm: String, tk: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .identifier(let value):
            guard value.count == 16 else {
                throw AnisetteV3ProvisioningProtocolError.invalidPayload
            }
            try container.encode(value.base64EncodedString(), forKey: .identifier)
        case .spim(let value):
            guard !value.isEmpty, value.utf8.count <= 1_000_000 else {
                throw AnisetteV3ProvisioningProtocolError.invalidPayload
            }
            try container.encode(value, forKey: .spim)
        case .finish(let ptm, let tk):
            guard !ptm.isEmpty, !tk.isEmpty,
                  ptm.utf8.count <= 1_000_000, tk.utf8.count <= 1_000_000 else {
                throw AnisetteV3ProvisioningProtocolError.invalidPayload
            }
            try container.encode(ptm, forKey: .ptm)
            try container.encode(tk, forKey: .tk)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case spim
        case ptm
        case tk
    }

    func jsonData() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

enum AnisetteV3ProvisioningAction: Equatable, Sendable {
    case sendIdentifier
    case requestStartProvisioning
    case requestFinishProvisioning(cpim: String)
    case completed(adiPB: Data)
}

enum AnisetteV3ProvisioningProtocolError: Error, Equatable, Sendable {
    case unknownMessage
    case invalidPayload
    case timedOut
    case unexpectedMessage
    case alreadyCompleted
}

/// Strict, testable state machine for the documented V3 server message order.
/// It never reports completion until a valid, non-empty ADI blob is received.
struct AnisetteV3ProvisioningStateMachine: Sendable {
    private enum Phase: Sendable {
        case awaitingIdentifier
        case awaitingStart
        case awaitingEnd
        case awaitingSuccess
        case completed
    }

    private var phase: Phase = .awaitingIdentifier

    mutating func receive(_ message: AnisetteV3ProvisioningMessage) throws -> AnisetteV3ProvisioningAction {
        if case .timeout = message {
            throw AnisetteV3ProvisioningProtocolError.timedOut
        }

        switch (phase, message) {
        case (.awaitingIdentifier, .giveIdentifier):
            phase = .awaitingStart
            return .sendIdentifier
        case (.awaitingStart, .giveStartProvisioningData):
            phase = .awaitingEnd
            return .requestStartProvisioning
        case let (.awaitingEnd, .giveEndProvisioningData(cpim)):
            phase = .awaitingSuccess
            return .requestFinishProvisioning(cpim: cpim)
        case let (.awaitingSuccess, .provisioningSuccess(encoded)):
            guard let adiPB = Data(base64Encoded: encoded),
                  !adiPB.isEmpty, adiPB.count <= 1_000_000 else {
                throw AnisetteV3ProvisioningProtocolError.invalidPayload
            }
            phase = .completed
            return .completed(adiPB: adiPB)
        case (.completed, _):
            throw AnisetteV3ProvisioningProtocolError.alreadyCompleted
        default:
            throw AnisetteV3ProvisioningProtocolError.unexpectedMessage
        }
    }

    mutating func receive(json: Data) throws -> AnisetteV3ProvisioningAction {
        let message = try JSONDecoder().decode(AnisetteV3ProvisioningMessage.self, from: json)
        return try receive(message)
    }
}
