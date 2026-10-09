import Foundation

enum KokoroText {
  /// NeMo folds dotted meridiems into AM/PM, but the bundled English lexicon reads
  /// AM as the word "am". Separate letter names only after an explicit valid clock
  /// time. Leave prose, identifiers and ambiguous units to the runtime frontend.
  static func prepare(_ text: String) -> String {
    let source = text as NSString
    let matches = meridiem.matches(in: text, range: NSRange(location: 0, length: source.length))
    let result = NSMutableString(string: text)
    for match in matches.reversed() {
      let letter = source.substring(with: match.range(at: 2)).uppercased()
      let clock = source.substring(with: match.range(at: 1))
      result.replaceCharacters(in: match.range, with: "\(clock)\(letter) M.")
    }
    return result as String
  }

  private static let meridiem = try! NSRegularExpression(
    pattern: #"(?<![\p{L}\p{N}:./_-])((?:0?[1-9]|1[0-2]):[0-5][0-9][ \t]+)([ap])\.m\.(?![\p{L}\p{N}_])"#,
    options: .caseInsensitive)
}
