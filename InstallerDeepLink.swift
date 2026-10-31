import Foundation

/// Parses the install-link handoff supported by AutoRenew Installer.
/// The link intentionally downloads an IPA only; it never installs or signs it.
enum InstallerDeepLink {
    enum LinkError: LocalizedError, Equatable {
        case unsupportedLink
        case missingDownloadURL
        case unsafeDownloadURL

        var errorDescription: String? {
            switch self {
            case .unsupportedLink:
                return "Link AutoRenew Installer não reconhecido."
            case .missingDownloadURL:
                return "O link não contém um endereço de download."
            case .unsafeDownloadURL:
                return "O link precisa apontar para um arquivo .ipa por HTTPS, sem usuário, senha ou fragmento."
            }
        }
    }

    static func parse(_ incomingURL: URL) throws -> URL {
        guard let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "autorenewinstaller",
              components.host?.lowercased() == "install",
              components.path.isEmpty,
              components.fragment == nil else {
            throw LinkError.unsupportedLink
        }

        let items = components.queryItems ?? []
        guard items.count == 1,
              items[0].name == "url",
              let rawValue = items[0].value,
              !rawValue.isEmpty,
              let target = URL(string: rawValue),
              let targetComponents = URLComponents(url: target, resolvingAgainstBaseURL: false) else {
            throw LinkError.missingDownloadURL
        }

        guard targetComponents.scheme?.lowercased() == "https",
              let host = targetComponents.host, !host.isEmpty,
              targetComponents.user == nil,
              targetComponents.password == nil,
              targetComponents.fragment == nil,
              target.pathExtension.lowercased() == "ipa" else {
            throw LinkError.unsafeDownloadURL
        }

        return target
    }
}
