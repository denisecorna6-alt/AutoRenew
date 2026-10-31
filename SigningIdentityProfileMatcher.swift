import CoreFoundation
import CryptoKit
import Foundation
import Security

struct SigningIdentityProfileMatch {
    let certificateName: String
    let certificateSHA256: String
    let matchesProfileDeveloperCertificate: Bool
    let profileMetadataCompatible: Bool
    let cmsSignatureVerified: Bool

    /// A matching certificate is necessary, but not sufficient, for a real signing operation.
    var metadataReady: Bool {
        matchesProfileDeveloperCertificate && profileMetadataCompatible
    }
}

enum SigningIdentityMatchError: LocalizedError {
    case emptyPassword
    case invalidPKCS12
    case missingIdentity
    case missingCertificate
    case missingPrivateKey

    var errorDescription: String? {
        switch self {
        case .emptyPassword: return "Informe a senha do arquivo .p12."
        case .invalidPKCS12: return "O arquivo .p12 não pôde ser aberto com essa senha."
        case .missingIdentity: return "O arquivo .p12 não contém uma identidade de assinatura."
        case .missingCertificate: return "A identidade não contém um certificado X.509."
        case .missingPrivateKey: return "A identidade não contém uma chave privada acessível."
        }
    }
}

enum SigningIdentityProfileMatcher {
    /// Checks that the PKCS#12 identity contains a certificate listed by the profile.
    /// The password is used only for this in-memory import and is never persisted.
    static func inspect(
        pkcs12Data: Data,
        password: String,
        profile: ProvisioningProfileMetadata,
        bundleIdentifier: String,
        now: Date = Date()
    ) throws -> SigningIdentityProfileMatch {
        guard !password.isEmpty else { throw SigningIdentityMatchError.emptyPassword }

        var importedItems: CFArray?
        let status = SecPKCS12Import(
            pkcs12Data as CFData,
            [kSecImportExportPassphrase as String: password] as CFDictionary,
            &importedItems
        )
        guard status == errSecSuccess else {
            throw SigningIdentityMatchError.invalidPKCS12
        }
        guard let first = (importedItems as? [[String: Any]])?.first,
              let identityValue = first[kSecImportItemIdentity as String] else {
            throw SigningIdentityMatchError.missingIdentity
        }
        guard CFGetTypeID(identityValue as CFTypeRef) == SecIdentityGetTypeID() else {
            throw SigningIdentityMatchError.missingIdentity
        }

        let identity = identityValue as! SecIdentity
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let certificate else {
            throw SigningIdentityMatchError.missingCertificate
        }

        var privateKey: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess,
              privateKey != nil else {
            throw SigningIdentityMatchError.missingPrivateKey
        }

        let certificateData = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: certificateData).map { String(format: "%02x", $0) }.joined()
        let subject = SecCertificateCopySubjectSummary(certificate) as String? ?? "Certificado sem nome"
        let profileReport = profile.metadataReport(for: bundleIdentifier, now: now)

        return SigningIdentityProfileMatch(
            certificateName: subject,
            certificateSHA256: digest,
            matchesProfileDeveloperCertificate: profile.developerCertificates.contains(certificateData),
            profileMetadataCompatible: profileReport.metadataIsCompatible,
            cmsSignatureVerified: false
        )
    }
}

