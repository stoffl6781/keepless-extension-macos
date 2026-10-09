//
//  SafariWebExtensionHandler.swift
//  Keepless Extension
//
//  Native Touch ID for the Safari extension (lib/biometrics.js, browser.runtime.sendNativeMessage).
//
//  DECISION: Safari gives the extension a new origin on every launch, so WebAuthn passkeys break after a
//  restart. Instead a random 32-byte secret lives in the data protection keychain behind .biometryCurrentSet:
//  the system releases it only after Touch ID, and changing the enrolled fingerprints invalidates it.
//  The extension seals the master password with this secret; the password itself never reaches the keychain.
//
//  Never log message contents or replies: they carry the secret.
//

import Foundation
import LocalAuthentication
import SafariServices
import Security

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private static let service = "app.keepless.Keepless.touchid"
    private static let secretLength = 32

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any] ?? [:]

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: handle(message)]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func handle(_ message: [String: Any]) -> [String: Any] {
        guard let action = message["action"] as? String else { return ["error": "BAD_REQUEST"] }
        // keyId comes from the extension (crypto.randomUUID); anything else is refused
        guard let keyId = message["keyId"] as? String, UUID(uuidString: keyId) != nil else {
            return ["error": "BAD_REQUEST"]
        }

        switch action {
        case "biometrics.create":
            return create(keyId)
        case "biometrics.read":
            let reason = (message["reason"] as? String).flatMap { $0.isEmpty ? nil : String($0.prefix(120)) }
            return read(keyId, reason: reason ?? "Keepless entsperren")
        case "biometrics.delete":
            delete(keyId)
            return ["ok": true]
        default:
            return ["error": "UNKNOWN_ACTION"]
        }
    }

    private func create(_ keyId: String) -> [String: Any] {
        guard LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return ["error": "UNAVAILABLE"]
        }
        var secret = Data(count: Self.secretLength)
        let random = secret.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Self.secretLength, $0.baseAddress!)
        }
        guard random == errSecSuccess else { return ["error": "KEYCHAIN_\(random)"] }

        var acError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &acError
        ) else {
            return ["error": "UNAVAILABLE"]
        }

        delete(keyId)
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: keyId,
            kSecValueData: secret,
            kSecAttrAccessControl: access,
            kSecUseDataProtectionKeychain: true,
        ] as CFDictionary, nil)
        return status == errSecSuccess ? ["ok": true] : ["error": errorCode(status)]
    }

    private func read(_ keyId: String, reason: String) -> [String: Any] {
        let context = LAContext()
        context.localizedReason = reason
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: keyId,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
            kSecUseDataProtectionKeychain: true,
        ] as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, data.count == Self.secretLength else {
            return ["error": status == errSecSuccess ? "BAD_SECRET" : errorCode(status)]
        }
        return ["secret": data.base64EncodedString()]
    }

    private func delete(_ keyId: String) {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: keyId,
            kSecUseDataProtectionKeychain: true,
        ] as CFDictionary)
    }

    private func errorCode(_ status: OSStatus) -> String {
        switch status {
        case errSecUserCanceled: return "CANCELLED"
        case errSecItemNotFound: return "NOT_FOUND"
        case errSecAuthFailed: return "AUTH_FAILED"
        default: return "KEYCHAIN_\(status)"
        }
    }
}
