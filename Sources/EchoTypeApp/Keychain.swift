import Foundation
import Security

/// Reads the xAI API key. There is no write path: until the settings milestone adds one, the
/// item is seeded by hand with `security add-generic-password -s com.aidanzealley.echotype`.
enum Keychain {
  /// The key, or `nil` if there is no item. Any account name under the service will do, so
  /// the reader does not depend on how the item was seeded.
  ///
  /// Blocks while macOS asks whether EchoType may read the item, so call it off the main actor,
  /// where it would otherwise stall the event tap.
  static func apiKey() -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: "com.aidanzealley.echotype",
      kSecReturnData: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data,
      let key = String(data: data, encoding: .utf8), !key.isEmpty
    else { return nil }
    return key
  }
}
