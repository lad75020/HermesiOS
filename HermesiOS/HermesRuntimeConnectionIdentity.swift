import CryptoKit
import Foundation

/// Non-secret identity for runtime tasks. Key rotation must invalidate a live
/// connection even when both the old and new credentials are nonempty.
struct HermesRuntimeConnectionIdentity: Hashable {
    let dashboardURL: String
    let apiURL: String
    let credentialFingerprint: String
    let allowSelfSignedCertificates: Bool

    init(dashboardURL: String, apiSettings: HermesAPISettings) {
        self.dashboardURL = dashboardURL
        apiURL = apiSettings.baseURL
        credentialFingerprint = Self.fingerprint(apiSettings.apiKey)
        allowSelfSignedCertificates = apiSettings.allowSelfSignedCertificates
    }

    static func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Changing either transport or edit scope destroys panel-owned fallback state
/// and cancels its tasks, instead of painting late results in a new profile.
struct HermesToolsScopeIdentity: Hashable {
    let gateway: HermesRuntimeConnectionIdentity
    let profileName: String
    let gatewayPath: String?
    let companionPath: String?
    let companionURL: String
    let companionCredentialFingerprint: String
    let deviceID: String
    let enrollmentEndpoint: String
    let enrollmentFingerprint: String
    let approvedAt: Date?
    let revokedAt: Date?

    init(gateway: HermesRuntimeConnectionIdentity, profileName: String, gatewayPath: String?, companionPath: String?, settings: HermesCompanionSettings, identity: HermesCompanionIdentityState) {
        self.gateway = gateway
        self.profileName = profileName
        self.gatewayPath = gatewayPath
        self.companionPath = companionPath
        companionURL = settings.apiURL
        companionCredentialFingerprint = HermesRuntimeConnectionIdentity.fingerprint(settings.deviceSecret)
        deviceID = identity.deviceID
        enrollmentEndpoint = identity.serverEndpoint
        enrollmentFingerprint = identity.deviceSecretFingerprint
        approvedAt = identity.approvedAt
        revokedAt = identity.revokedAt
    }
}
