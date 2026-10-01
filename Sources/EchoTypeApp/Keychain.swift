import EchoTypeCore
import Foundation
import Security

/// Each provider's API key, as one generic password item under the app's service whose account
/// is the provider's id.
///
/// Every call can block while macOS asks whether EchoType may use the item, so call them off
/// the main actor, where they would otherwise stall the event tap.
enum Keychain {
  private static let service = "com.aidanzealley.echotype"

  private static func query(_ provider: ProviderID) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: provider.rawValue,
    ]
  }

  /// The provider's key, or `nil` if it has no item.
  static func key(for provider: ProviderID) -> String? {
    var query = Self.query(provider)
    query[kSecReturnData] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data,
      let key = String(data: data, encoding: .utf8), !key.isEmpty
    else { return nil }
    return key
  }

  /// Updates the existing item so changing the key does not reset its access rule. A new
  /// item uses the app's default rule until the Keychain grants it access.
  static func save(_ key: String, for provider: ProviderID) -> Bool {
    let query = Self.query(provider)
    let data = Data(key.utf8)
    switch SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary) {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      var item = query
      item[kSecValueData] = data
      return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    default:
      return false
    }
  }

  /// Deletes the provider's item, leaving other providers' keys. Returns whether it is gone.
  static func remove(for provider: ProviderID) -> Bool {
    let status = SecItemDelete(Self.query(provider) as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}
