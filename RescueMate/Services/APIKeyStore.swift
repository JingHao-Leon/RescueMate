import Foundation
import Security

/// 高德 REST（Web服务）Key 的存取。
/// Key 只保存在系统钥匙串（每位用户自己的 Key，用各自的免费额度），源码里不写入任何真实 Key。
enum APIKeyStore {
    private static let service = "com.rescuemate.amap"
    private static let account = "amap-restapi-key"

    static func save(_ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var attributes = base
        attributes[kSecValueData as String] = key.data(using: .utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key.isEmpty ? nil : key
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var hasKey: Bool { load() != nil }
}

/// Key 的读取优先级：用户在 App 里粘贴的 Key（钥匙串）> 随包分发的 Key（Info.plist，由运营方通过 xcconfig 注入）。
enum AMapConfig {
    static var bundledAPIKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AMAP_API_KEY") as? String else { return nil }
        return value.isEmpty ? nil : value
    }

    static func currentKey() -> String? {
        APIKeyStore.load() ?? bundledAPIKey
    }

    /// 高德 Key 是 32 位十六进制字符串，粘贴时先做个格式校验。
    static func isValidKeyFormat(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 32 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return key.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    static let consoleURL = URL(string: "https://console.amap.com/dev/key/app")!
    static let guideURL = URL(string: "https://lbs.amap.com/api/webservice/create-project/get-key")!
}
