import AVFoundation
import ApplicationServices
import EchoTypeCore
import ServiceManagement
import SwiftUI

/// The settings window: one grouped form. The hotkey applies at once; the rest apply from the
/// next session.
struct SettingsView: View {
  @Bindable var store: SettingsStore
  /// Nil in the overlay demo, which has no controller and so no Test button.
  let controller: DictationController?

  var body: some View {
    Form {
      Section {
        APIKeyRow(controller: controller)
      }
      Section {
        Picker("Hotkey", selection: $store.settings.hotkey) {
          ForEach(EchoTypeCore.Settings.Hotkey.presets, id: \.self) { hotkey in
            Text(verbatim: Self.label(hotkey)).tag(hotkey)
          }
        }
        InputRow(store: store)
        LanguageRow(store: store)
      }
      Section {
        KeytermsRow(store: store)
      }
      Section {
        LaunchAtLoginRow()
      }
      PermissionsSection()
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
///
/// Test saves the key in the field, then runs a five second session through the controller and
/// shows what it heard.
private struct APIKeyRow: View {
  let controller: DictationController?
  @State private var key = ""
  /// What the Keychain holds, so leaving an unchanged field writes nothing. It only advances
  /// when a write succeeds, so a failed one is retried on the next submit or blur.
  @State private var savedKey = ""
  @State private var saveFailed = false
  @State private var lastWrite: Task<Void, Never>?
  @State private var testing = false
  @State private var testOutcome: DictationController.TestOutcome?
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
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
        if let controller {
          Button(testing ? "Testing…" : "Test") {
            Task { await test(controller) }
          }
          .disabled(testing || !controller.isIdle)
        }
      }
      if saveFailed {
        Text("Couldn't save the key")
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
  }

  private func test(_ controller: DictationController) async {
    testing = true
    defer { testing = false }
    testOutcome = nil
    save()
    await lastWrite?.value
    // Testing the key the Keychain still holds would not be testing the one on screen.
    guard !saveFailed else { return }
    testOutcome = await controller.test()
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
private struct PermissionsSection: View {
  @State private var microphone = false
  @State private var deviceControl = false

  var body: some View {
    Section {
      row("Microphone", granted: microphone, pane: "Privacy_Microphone")
      // Still the Accessibility trust check, which macOS 27 names Device Control and Data
      // Access.
      row("Device Control and Data Access", granted: deviceControl, pane: "Privacy_Accessibility")
    }
    .onAppear(perform: refresh)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in refresh() }
  }

  private func row(_ title: String, granted: Bool, pane: String) -> some View {
    LabeledContent(title) {
      HStack {
        Text(granted ? "Granted" : "Not granted")
          .foregroundStyle(granted ? .secondary : Color.red)
        Button("Open") {
          let url = "x-apple.systempreferences:com.apple.preference.security?\(pane)"
          NSWorkspace.shared.open(URL(string: url)!)
        }
      }
    }
  }

  private func refresh() {
    microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    deviceControl = AXIsProcessTrusted()
  }
}
