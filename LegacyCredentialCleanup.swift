import Foundation
import Security

enum LegacyCredentialCleanup {
    static func run() {
        // Match only the exact account key used by the previous Alpha password field.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "applePassword"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
