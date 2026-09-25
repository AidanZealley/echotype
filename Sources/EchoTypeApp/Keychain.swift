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

  /// Replaces any item with a new one holding `key`. Recreating rather than updating means
  /// the app always owns the item: one seeded by hand carries an access list that makes the
  /// app prompt on every read, and an update would keep that list. Returns whether the new
  /// item was written; if the old one cannot be deleted, nothing is added.
  static func save(_ key: String) -> Bool {
    guard clear() else { return false }
    let item: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: "xai",
      kSecValueData: Data(key.utf8),
    ]
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
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
