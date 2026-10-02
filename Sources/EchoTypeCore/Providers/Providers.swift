/// Every provider, in the order Settings lists them. The first is the default.
public enum Providers {
  public static let all: [Provider] = [.xAI, .apple]

  /// The registered provider with `id`, or the default for an id no provider has.
  public static subscript(id: ProviderID) -> Provider {
    all.first { $0.id == id } ?? all[0]
  }
  /// Upgrade the reading fields stored before providers were selectable.
  static func migratedReading(voice: String?, speed: Double?) -> [String: Settings.Reading] {
    let provider = Provider.xAI
    let choice = Settings.Reading(voice: voice ?? "", speed: speed ?? 1)
    return [provider.id.rawValue: choice.validated(for: provider.voice)]
  }
}
