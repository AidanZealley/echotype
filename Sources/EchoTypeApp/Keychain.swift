import Foundation
import Security

/// The xAI API key, as one generic password item under the app's service.
///
/// Every call can block while macOS asks whether EchoType may use the item, so call them off
/// the main actor, where they would otherwise stall the event tap.
enum Keychain {
  private static let service = "com.aidanzealley.echotype"

  /// The key, or `nil` if there is no item. Any account name under the service will do, so
  /// an item seeded by hand with `security add-generic-password` still reads.
  static func apiKey() -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecReturnData: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data,
      let key = String(data: data, encoding: .utf8), !key.isEmpty
    else { return nil }
    return key
  }

  /// Updates the existing item so changing the key does not reset its access rule. A new
  /// item uses the app's default rule until the Keychain grants it access.
  static func save(_ key: String) -> Bool {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
    ]
    let data = Data(key.utf8)
    switch SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary) {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      var item = query
      item[kSecAttrAccount] = "xai"
      item[kSecValueData] = data
      return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    default:
      return false
    }
  }

  /// Deletes every item under the service. Returns whether none is left.
  static func clear() -> Bool {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
    ]
    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}
