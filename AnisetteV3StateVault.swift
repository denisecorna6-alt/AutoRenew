import Foundation
import Security

/// A validated, serializable representation of the sensitive Anisette V3 state.
/// Never log or expose this value outside the Keychain boundary.
struct AnisetteV3StoredState: Codable, Sendable {
    let identifier: Data
    let adiPB: Data?

    init(identifier: Data, adiPB: Data? = nil) throws {
        guard identifier.count == 16,
              adiPB == nil || (!(adiPB?.isEmpty ?? true) && (adiPB?.count ?? 0) <= 1_000_000) else {
            throw AnisetteV3StateVaultError.invalidState
        }
        self.identifier = identifier
        self.adiPB = adiPB
    }

    var provisioningState: AnisetteV3ProvisioningState? {
        guard let adiPB else { return nil }
        return AnisetteV3ProvisioningState(identifier: identifier, adiPB: adiPB)
    }
}

enum AnisetteV3StateVaultError: Error, Equatable, Sendable {
    case invalidState
    case keychainStatus(OSStatus)
}

/// Stores the Anisette V3 identifier and ADI blob as one device-only Keychain item.
/// The ADI blob is never written to AppStore.store.json, files, logs, or iCloud Keychain.
actor AnisetteV3StateVault {
    private let service: String
    private let account = "provisioning-state"

    init(service: String = "app.autorenew.anisette-v3") {
        self.service = service
    }

    /// Returns the stable 16-byte identifier, creating and persisting one if needed.
    /// This does not provision with Apple and does not imply that ADI is available.
    func loadOrCreateIdentifier() throws -> Data {
        if let stored = try readStoredState() {
            return stored.identifier
        }

        var identifier = Data(count: 16)
        let status = identifier.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw AnisetteV3StateVaultError.keychainStatus(status)
        }

        let stored = try AnisetteV3StoredState(identifier: identifier)
        try write(stored)
        return stored.identifier
    }

    /// Returns nil until the full Apple provisioning flow has produced an ADI blob.
    func loadProvisioningState() throws -> AnisetteV3ProvisioningState? {
        try readStoredState()?.provisioningState
    }

    /// Persists only a complete, validated provisioned state.
    func saveProvisionedState(identifier: Data, adiPB: Data) throws {
        let stored = try AnisetteV3StoredState(identifier: identifier, adiPB: adiPB)
        try write(stored)
    }

    /// Keeps the stable identifier but clears only the ADI blob after the server
    /// explicitly reports that the existing provisioning is no longer valid.
    func clearProvisionedState() throws {
        guard let stored = try readStoredState(), stored.adiPB != nil else { return }
        try write(AnisetteV3StoredState(identifier: stored.identifier))
    }

    /// Removes the local provisioning identity. The next call creates a new identifier.
    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AnisetteV3StateVaultError.keychainStatus(status)
        }
    }

    private func readStoredState() throws -> AnisetteV3StoredState? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AnisetteV3StateVaultError.keychainStatus(status)
        }
        do {
            let stored = try PropertyListDecoder().decode(AnisetteV3StoredState.self, from: data)
            // Re-run validation even when decoding an older or corrupted Keychain value.
            return try AnisetteV3StoredState(identifier: stored.identifier, adiPB: stored.adiPB)
        } catch let error as AnisetteV3StateVaultError {
            throw error
        } catch {
            throw AnisetteV3StateVaultError.invalidState
        }
    }

    private func write(_ stored: AnisetteV3StoredState) throws {
        let data = try PropertyListEncoder().encode(stored)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw AnisetteV3StateVaultError.keychainStatus(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard retryStatus == errSecSuccess else {
                throw AnisetteV3StateVaultError.keychainStatus(retryStatus)
            }
        } else if addStatus != errSecSuccess {
            throw AnisetteV3StateVaultError.keychainStatus(addStatus)
        }
    }
}
