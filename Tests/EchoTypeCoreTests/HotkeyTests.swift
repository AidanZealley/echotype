import EchoTypeCore
import Testing

@Test("The hotkey matches its own key with exactly its own modifiers")
func hotkeyMatchesItsChord() {
  #expect(Settings.Hotkey.optionD.matches(keyCode: 0x02, modifiers: .option))

  let controlOptionD = Settings.Hotkey(keyCode: 0x02, modifiers: [.control, .option])
  #expect(controlOptionD.matches(keyCode: 0x02, modifiers: [.control, .option]))
}

@Test(
  "A press with other modifiers, missing modifiers or another key passes through",
  arguments: [
    (0x02, [.command, .option]),
    (0x02, [.control, .option]),
    (0x02, [.shift, .option]),
    (0x02, []),
    (0x0E, .option),  // Opt+E
  ] as [(UInt16, Settings.ModifierFlags)]
)
func hotkeyRejectsOtherChords(keyCode: UInt16, modifiers: Settings.ModifierFlags) {
  #expect(!Settings.Hotkey.optionD.matches(keyCode: keyCode, modifiers: modifiers))
}
