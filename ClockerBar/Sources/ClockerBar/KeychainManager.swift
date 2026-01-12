import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .itemNotFound:
            return "Item not found in Keychain"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        }
    }
}

struct KeychainManager {
    private static let service = "com.clocker.menubar"
    
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try update(key: key, value: value)
            return
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    static func update(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func hasCredentials() -> Bool {
        get(key: "apiKey") != nil &&
        get(key: "companyDomain") != nil &&
        get(key: "employeeId") != nil
    }
    
    static func getConfig() -> BambooHRConfig? {
        guard let apiKey = get(key: "apiKey"),
              let companyDomain = get(key: "companyDomain"),
              let employeeId = get(key: "employeeId") else {
            return nil
        }
        
        return BambooHRConfig(
            apiKey: apiKey,
            companyDomain: companyDomain,
            employeeId: employeeId
        )
    }
    
    static func saveConfig(_ config: BambooHRConfig) throws {
        try save(key: "apiKey", value: config.apiKey)
        try save(key: "companyDomain", value: config.companyDomain)
        try save(key: "employeeId", value: config.employeeId)
    }
}
