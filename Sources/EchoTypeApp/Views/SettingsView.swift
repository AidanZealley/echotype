import EchoTypeCore
import SwiftUI

/// The settings window: one grouped form. The hotkey applies at once; the rest apply from the
/// next session.
struct SettingsView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Form {
      Section {
        APIKeyRow()
      }
      Section {
        Picker("Hotkey", selection: $store.settings.hotkey) {
          ForEach(EchoTypeCore.Settings.Hotkey.presets, id: \.self) { hotkey in
            Text(verbatim: Self.label(hotkey)).tag(hotkey)
          }
        }
        LanguageRow(store: store)
      }
      Section {
        KeytermsRow(store: store)
      }
    }
    .formStyle(.grouped)
    .frame(width: 460)
    .fixedSize(horizontal: false, vertical: true)
  }

  private static func label(_ hotkey: EchoTypeCore.Settings.Hotkey) -> String {
    hotkey == .controlOptionD ? "⌃⌥D" : "⌥D"
  }
}

/// The key is saved when the field is submitted or loses focus, and an emptied field clears
/// it. Every Keychain call runs off the main actor, one at a time and in order.
private struct APIKeyRow: View {
  @State private var key = ""
  /// What the Keychain holds, so leaving an unchanged field writes nothing. It only advances
  /// when a write succeeds, so a failed one is retried on the next submit or blur.
  @State private var savedKey = ""
  @State private var saveFailed = false
  @State private var lastWrite: Task<Void, Never>?
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading) {
      SecureField("xAI API key", text: $key)
        .focused($focused)
        .onSubmit(save)
        .onChange(of: focused) { if !focused { save() } }
        .onDisappear(perform: save)
        .task {
          let stored = await Task.detached { Keychain.apiKey() }.value ?? ""
          // A slow read, or one held up by a prompt, must not replace what the user typed.
          guard key.isEmpty else { return }
          key = stored
          savedKey = stored
        }
      if saveFailed {
        Text("Couldn't save the key")
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }

  private func save() {
    let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard key != savedKey else { return }
    lastWrite = Task { [lastWrite] in
      await lastWrite?.value
      let saved = await Task.detached {
        key.isEmpty ? Keychain.clear() : Keychain.save(key)
      }.value
      if saved { savedKey = key }
      saveFailed = !saved
    }
  }
}

/// Holds its own text so clearing the field to type a new tag does not snap back to the
/// default. A blank field stores the default.
private struct LanguageRow: View {
  let store: SettingsStore
  @State private var text: String

  init(store: SettingsStore) {
    self.store = store
    _text = State(initialValue: store.settings.language)
  }

  var body: some View {
    TextField("Language", text: $text, prompt: Text(verbatim: EchoTypeCore.Settings().language))
      .onChange(of: text) {
        let tag = text.trimmingCharacters(in: .whitespaces)
        store.settings.language = tag.isEmpty ? EchoTypeCore.Settings().language : tag
      }
  }
}

/// One term per line. The editor holds its own text while the user types; writing the parsed
/// list back into it would eat the newline being typed.
private struct KeytermsRow: View {
  let store: SettingsStore
  @State private var text: String

  init(store: SettingsStore) {
    self.store = store
    _text = State(initialValue: store.settings.keyterms.joined(separator: "\n"))
  }

  var body: some View {
    VStack(alignment: .leading) {
      LabeledContent("Keyterms") {
        Text(verbatim: "\(store.settings.keyterms.count) of \(STTConnection.maximumKeyterms)")
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      TextEditor(text: $text)
        .font(.body)
        .frame(height: 140)
        .onChange(of: text) {
          store.settings.keyterms = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        }
    }
  }
}
