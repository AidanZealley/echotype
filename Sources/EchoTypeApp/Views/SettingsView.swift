import AVFoundation
import ApplicationServices
import EchoTypeCore
import ServiceManagement
import SwiftUI

/// The settings window: a tab per concern. The hotkeys apply at once; the rest apply from the
/// next dictation or reading.
struct SettingsView: View {
  @Bindable var store: SettingsStore
  /// Nil in the overlay demo, which has no controller and so no Test button.
  let controller: DictationController?

  var body: some View {
    TabView {
      Tab("General", systemImage: "gearshape") {
        GeneralTab(store: store)
      }
      Tab("Keyterms", systemImage: "character.book.closed") {
        KeytermsTab(store: store)
      }
      Tab("Read Aloud", systemImage: "speaker.wave.2") {
        ReadAloudTab(store: store)
      }
      Tab("API Key", systemImage: "key") {
        APIKeyTab(controller: controller)
      }
    }
    .frame(width: 460)
  }
}

private struct GeneralTab: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Form {
      Picker("Hotkey", selection: $store.settings.hotkey) {
        ForEach(EchoTypeCore.Settings.Hotkey.presets, id: \.self) { hotkey in
          Text(verbatim: hotkey.label).tag(hotkey)
        }
      }
      InputRow(store: store)
      LanguageRow(store: store)
      VStack(alignment: .leading) {
        Toggle("Re-transcribe on stop", isOn: $store.settings.batchOnCommit)
        Text("Better punctuation, slower insertion")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      LaunchAtLoginRow()
      PermissionsRow()
        .padding(.top, 12)
    }
    .formStyle(.columns)
    .padding(20)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct ReadAloudTab: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Form {
      Picker("Hotkey", selection: $store.settings.readAloudHotkey) {
        ForEach(EchoTypeCore.Settings.Hotkey.readAloudPresets, id: \.self) { hotkey in
          Text(verbatim: hotkey.label).tag(hotkey)
        }
      }
      Picker("Voice", selection: $store.settings.voice) {
        ForEach(Speech.voices, id: \.self) { voice in
          Text(verbatim: voice.capitalized).tag(voice)
        }
      }
      LabeledContent("Speed") {
        HStack {
          // The endpoint's range.
          Slider(value: $store.settings.speechSpeed, in: 0.7...1.5, step: 0.1)
          Text(store.settings.speechSpeed, format: .number.precision(.fractionLength(1)))
            .monospacedDigit()
            .frame(width: 28, alignment: .trailing)
        }
      }
    }
    .formStyle(.columns)
    .padding(20)
    .fixedSize(horizontal: false, vertical: true)
  }
}

extension EchoTypeCore.Settings.Hotkey {
  /// The label for one of the dictation or read-aloud presets.
  fileprivate var label: String {
    switch self {
    case .controlOptionD: "⌃⌥D"
    case .optionS: "⌥S"
    case .controlOptionS: "⌃⌥S"
    default: "⌥D"
    }
  }
}

/// A saved key is shown masked, never in an editable field. Save, Replace and Remove are
/// explicit, and every Keychain call runs off the main actor with the buttons disabled until it
/// finishes, so two writes cannot race.
///
/// Test runs a five second session through the controller with the saved key and shows what it
/// heard.
private struct APIKeyTab: View {
  let controller: DictationController?
  /// What the Keychain holds. Nil when there is no key.
  @State private var savedKey: String?
  @State private var loaded = false
  @State private var draft = ""
  /// Replace was clicked, so the field shows even though a key is saved.
  @State private var replacing = false
  @State private var revealed = false
  /// The width the key has to fill, which sets how many bullets the masked key shows.
  @State private var keyWidth: CGFloat = 0
  @State private var confirmingRemove = false
  @State private var writing = false
  @State private var writeError: String?
  @State private var testing = false
  @State private var testOutcome: DictationController.TestOutcome?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("xAI API key")
      if !loaded {
        ProgressView().controlSize(.small)
      } else if let savedKey, !replacing {
        saved(savedKey)
      } else {
        entry
      }
      messages
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .fixedSize(horizontal: false, vertical: true)
    .task {
      savedKey = await Task.detached { Keychain.apiKey() }.value
      loaded = true
    }
    .confirmationDialog("Remove the API key?", isPresented: $confirmingRemove) {
      Button("Remove", role: .destructive) { Task { await remove() } }
    } message: {
      Text("Dictation won't work until you add another.")
    }
  }

  private func saved(_ key: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(verbatim: revealed ? key : Self.masked(key, width: keyWidth))
          .font(.body.monospaced())
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .onGeometryChange(for: CGFloat.self, of: \.size.width) { keyWidth = $0 }
        Button(revealed ? "Hide key" : "Show key", systemImage: revealed ? "eye.slash" : "eye") {
          revealed.toggle()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help(revealed ? "Hide key" : "Show key")
      }
      HStack {
        Spacer()
        if let controller {
          Button(testing ? "Testing…" : "Test") {
            Task { await test(controller) }
          }
          .disabled(testing || writing || !controller.isIdle)
        }
        Button("Replace") {
          draft = ""
          replacing = true
        }
        Button("Remove", role: .destructive) { confirmingRemove = true }
      }
      .disabled(writing || testing)
    }
  }

  /// Wraps rather than scrolling sideways, so the whole key is visible while pasting it. That
  /// means it is not masked, which a secure field would need.
  private var entry: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("xAI API key", text: $draft, prompt: Text(verbatim: "xai-…"), axis: .vertical)
        .labelsHidden()
        .font(.body.monospaced())
        .lineLimit(2...4)
        .onSubmit { Task { await save() } }
      HStack {
        Spacer()
        if replacing {
          Button("Cancel") {
            replacing = false
            writeError = nil
          }
        }
        Button("Save") { Task { await save() } }
          .keyboardShortcut(.defaultAction)
          .disabled(writing || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  @ViewBuilder private var messages: some View {
    if let writeError {
      Text(writeError)
        .font(.caption)
        .foregroundStyle(.red)
    }
    switch testOutcome {
    case .heard(let text):
      Text(text)
        .font(.caption)
        .textSelection(.enabled)
    case .heardNothing:
      Text("Nothing was heard")
        .font(.caption)
        .foregroundStyle(.secondary)
    case .failed(let error):
      Text(error)
        .font(.caption)
        .foregroundStyle(.red)
    case nil:
      EmptyView()
    }
  }

  /// `xai-••••…••••a3F9`: enough to tell keys apart without showing one. The bullets fill one
  /// line of `width`, up to the key's own length.
  private static func masked(_ key: String, width: CGFloat) -> String {
    let prefix = key.firstIndex(of: "-").map { key[...$0] } ?? ""
    let hidden = key.count - prefix.count - 4
    let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    let fitting = Int(width / ("•" as NSString).size(withAttributes: [.font: font]).width)
    let bullets = String(repeating: "•", count: max(8, min(hidden, fitting - prefix.count - 4)))
    guard hidden >= 4 else { return bullets }
    return "\(prefix)\(bullets)\(key.suffix(4))"
  }

  private func test(_ controller: DictationController) async {
    testing = true
    defer { testing = false }
    testOutcome = nil
    testOutcome = await controller.test()
  }

  private func save() async {
    let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, !writing else { return }
    guard await write("Couldn't save the key", { Keychain.save(key) }) else { return }
    savedKey = key
    draft = ""
    replacing = false
    revealed = false
  }

  private func remove() async {
    guard await write("Couldn't remove the key", Keychain.clear) else { return }
    savedKey = nil
    revealed = false
  }

  /// Runs a Keychain write off the main actor and reports a failure under the key.
  private func write(_ failure: String, _ operation: @escaping @Sendable () -> Bool) async -> Bool {
    writing = true
    defer { writing = false }
    let succeeded = await Task.detached(operation: operation).value
    writeError = succeeded ? nil : failure
    if succeeded { testOutcome = nil }
    return succeeded
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
    LabeledContent("Language") {
      TextField("Language", text: $text, prompt: Text(verbatim: EchoTypeCore.Settings().language))
        .labelsHidden()
        .frame(width: 80)
        .onChange(of: text) {
          let tag = text.trimmingCharacters(in: .whitespaces)
          store.settings.language = tag.isEmpty ? EchoTypeCore.Settings().language : tag
        }
    }
  }
}

/// One term per line. The editor holds its own text while the user types; writing the parsed
/// list back into it would eat the newline being typed.
private struct KeytermsTab: View {
  let store: SettingsStore
  @State private var text: String

  init(store: SettingsStore) {
    self.store = store
    _text = State(initialValue: store.settings.keyterms.joined(separator: "\n"))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Names and jargon to spell your way, one per line")
        Spacer()
        Text(verbatim: "\(store.settings.keyterms.count) of \(STTConnection.maximumKeyterms)")
          .monospacedDigit()
      }
      .foregroundStyle(.secondary)
      TextEditor(text: $text)
        .font(.body)
        .scrollContentBackground(.hidden)
        // The text view already insets each line by a few points horizontally.
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
        .frame(height: 260)
        .onChange(of: text) {
          store.settings.keyterms = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        }
    }
    .padding(20)
  }
}

/// The input device. A chosen device that is not connected stays selected, so unplugging it
/// never resets the choice; dictation uses the system default until it is back. Only the UID is
/// stored, so that is all a disconnected choice can show.
private struct InputRow: View {
  @Bindable var store: SettingsStore
  @State private var devices: [InputDevice] = []

  var body: some View {
    Picker("Input", selection: $store.settings.inputDeviceID) {
      Text("System default").tag(String?.none)
      ForEach(devices, id: \.uid) { device in
        Text(verbatim: device.name).tag(String?.some(device.uid))
      }
      if let uid = store.settings.inputDeviceID, !devices.contains(where: { $0.uid == uid }) {
        Text("\(uid) (not connected)").tag(String?.some(uid))
      }
    }
    // Listed each time the window appears.
    .task { devices = await Task.detached { InputDevice.all() }.value }
  }
}

/// Mirrors `SMAppService.mainApp`, read when the window appears and whenever the app becomes
/// active, so approving in Login Items shows the change. Nothing is stored, because the user can
/// change it in System Settings too. Every call to the service runs off the main actor, and the
/// toggle is disabled while a register or unregister is in flight so two cannot race.
private struct LaunchAtLoginRow: View {
  /// Nil until first read.
  @State private var status: SMAppService.Status?
  @State private var error: String?
  @State private var pending = false

  var body: some View {
    VStack(alignment: .leading) {
      Toggle(
        "Launch at login",
        isOn: Binding(
          get: { status == .enabled || status == .requiresApproval },
          set: { enabled in Task { await set(enabled) } }
        )
      )
      .disabled(status == nil || pending)
      if status == .requiresApproval {
        HStack {
          Text("Allow EchoType in Login Items")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
        }
      }
      if let error {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .task { await refresh() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in Task { await refresh() } }
  }

  private func refresh() async {
    status = await Task.detached { SMAppService.mainApp.status }.value
  }

  private func set(_ enabled: Bool) async {
    pending = true
    defer { pending = false }
    let (status, error) = await Task.detached { () -> (SMAppService.Status, String?) in
      let service = SMAppService.mainApp
      do {
        if enabled { try service.register() } else { try service.unregister() }
        return (service.status, nil)
      } catch {
        return (service.status, error.localizedDescription)
      }
    }.value
    self.status = status
    self.error = error
  }
}

/// Whether each permission is granted, read when the window appears and whenever the app
/// becomes active, so coming back from System Settings shows the change. The rows never ask for
/// a permission: the first dictation asks for the microphone, and launch asks for the other.
private struct PermissionsRow: View {
  @State private var microphone = false
  @State private var deviceControl = false

  var body: some View {
    LabeledContent("Permissions") {
      Grid(alignment: .leading, verticalSpacing: 8) {
        row("Microphone", granted: microphone, pane: "Privacy_Microphone")
        // Still the Accessibility trust check, which macOS 27 names Device Control and Data
        // Access.
        row("Device Control and Data Access", granted: deviceControl, pane: "Privacy_Accessibility")
      }
    }
    .onAppear(perform: refresh)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in refresh() }
  }

  private func row(_ title: String, granted: Bool, pane: String) -> some View {
    GridRow(alignment: .firstTextBaseline) {
      VStack(alignment: .leading) {
        Text(title)
        Text(granted ? "Granted" : "Not granted")
          .font(.caption)
          .foregroundStyle(granted ? .secondary : Color.red)
      }
      Button("Open") {
        let url = "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        NSWorkspace.shared.open(URL(string: url)!)
      }
    }
  }

  private func refresh() {
    microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    deviceControl = AXIsProcessTrusted()
  }
}
