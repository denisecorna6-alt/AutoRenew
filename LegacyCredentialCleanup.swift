import Foundation
import Security

/// Removes the legacy Apple password item saved by earlier Alpha builds.
/// No credential is read, transmitted, or replaced.
enum LegacyCredentialCleanup {
    static func removePreviouslyStoredApplePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "applePassword"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
