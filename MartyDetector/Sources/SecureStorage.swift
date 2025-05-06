import Security
import Foundation

enum SecureStorageError: Error {
    case failedToSetData
    case failedToGetData
}

class SecureStorage: NSObject {
    private let service: String

    init(service: String) {
        self.service = service
    }
    
    func set(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Remove any existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw SecureStorageError.failedToSetData
        }
    } 

    func get(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
        let data = result as? Data,
        let value = String(data: data, encoding: .utf8) {
            return value
        }

        throw SecureStorageError.failedToGetData
    }
}
