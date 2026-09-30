import AppKit
import CoreGraphics
import EchoTypeCore
@testable import EchoTypeApp
import Testing

@Suite
@MainActor
struct HotkeyAdapterTests {
  @Test("The macOS adapter preserves every chord modifier")
  func chordModifiers() {
    #expect(NSApp == nil, "Importing EchoTypeApp must not run its application entry point")
    #expect(Settings.ModifierFlags(.maskShift) == .shift)
    #expect(Settings.ModifierFlags(.maskControl) == .control)
    #expect(Settings.ModifierFlags(.maskAlternate) == .option)
    #expect(Settings.ModifierFlags(.maskCommand) == .command)
    #expect(
      Settings.ModifierFlags([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        == [.shift, .control, .option, .command])
  }

  @Test("Caps Lock, Fn and event bookkeeping do not change a hotkey chord")
  func ignoredFlags() {
    let ignored: CGEventFlags = [.maskAlphaShift, .maskSecondaryFn, .maskNumericPad,
      .maskHelp, .maskNonCoalesced]
    #expect(Settings.ModifierFlags(ignored).isEmpty)
    #expect(Settings.Hotkey.optionD.matches(
      keyCode: 0x02, modifiers: Settings.ModifierFlags(ignored.union(.maskAlternate))))
    #expect(!Settings.Hotkey.optionD.matches(
      keyCode: 0x02, modifiers: Settings.ModifierFlags([.maskAlternate, .maskCommand])))
  }
}
