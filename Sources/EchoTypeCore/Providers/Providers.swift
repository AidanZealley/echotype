/// Every provider, in the order Settings lists them. The first is the default.
public enum Providers {
  public static let all: [Provider] = [.xAI]

  /// The registered provider with `id`, or the default for an id no provider has.
  public static subscript(id: ProviderID) -> Provider {
    all.first { $0.id == id } ?? all[0]
  }
}
