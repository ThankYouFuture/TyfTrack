import Foundation
import Security

enum Keychain {
    private static let service = "ch.tyf.TyfTrack"

    static func save(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var attrs = query
        attrs[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                TyfLog.append("Keychain.load(\(account)) — échec SecItemCopyMatching, status \(status)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // Legacy personal access token (PAT)
    static func saveToken(_ token: String) { save(token, account: "bexio-api-token") }
    static func loadToken() -> String? { load(account: "bexio-api-token") }
}
