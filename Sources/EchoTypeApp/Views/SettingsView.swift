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
          .navigationTitle("EchoType Settings")
      }
      Tab("Keyterms", systemImage: "character.book.closed") {
        KeytermsTab(store: store)
          .navigationTitle("EchoType Settings")
      }
      Tab("Read Aloud", systemImage: "speaker.wave.2") {
        ReadAloudTab(store: store)
          .navigationTitle("EchoType Settings")
      }
      Tab("Agents", systemImage: "terminal") {
        AgentsTab()
          .navigationTitle("EchoType Settings")
      }
      Tab("Provider", systemImage: "network") {
        ProviderTab(store: store, controller: controller)
          .navigationTitle("EchoType Settings")
      }
      Tab("Updates", systemImage: "arrow.triangle.2.circlepath") {
        UpdatesTab()
          .navigationTitle("EchoType Settings")
      }
    }
    .frame(width: 460)
  }
}

/// Commands and optional agent instructions to copy. EchoType never edits another tool's config
/// or runs its CLI. The commands name the running app, so they stay right if it moves.
private struct AgentsTab: View {
  private static let agentInstructions = """
    ## EchoType

    When asked to reply, respond, or read an answer with or using EchoType:

    1. Prepare the full written answer at its normal level of detail.
    2. Before sending it, find and call the `speak` tool on the EchoType MCP server once. Speak a separate short summary, unless asked to hear the whole answer.
    3. Send the full written answer without shortening it for speech.

    EchoType is an MCP server, not a desktop app.
    """

  private var app: String {
    let path = Bundle.main.executablePath ?? "/Applications/EchoType.app/Contents/MacOS/EchoTypeApp"
    return path.contains(" ") ? "'\(path)'" : path
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Connect an agent to EchoType so it can read replies aloud. Run the command once in a terminal, then start a new agent session.")
        .font(.caption)
        .foregroundStyle(.secondary)
      command("Claude Code", "claude mcp add --scope user echotype -- \(app) --mcp", remove: "claude mcp remove echotype")
      command("Codex", "codex mcp add echotype -- \(app) --mcp", remove: "codex mcp remove echotype")
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Optional agent instructions")
          Spacer()
          Button("Copy", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.agentInstructions, forType: .string)
          }
        }
        Text("Paste into your agent's instructions, such as AGENTS.md.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(verbatim: Self.agentInstructions)
          .font(.caption)
          .textSelection(.enabled)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 6))
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func command(_ name: String, _ add: String, remove: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(name)
        Spacer()
        Button("Copy", systemImage: "doc.on.doc") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(add, forType: .string)
        }
      }
      Text(verbatim: add)
        .font(.caption.monospaced())
        .textSelection(.enabled)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
      Text(verbatim: "Already connected? Run \(remove) first.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct UpdatesTab: View {
  private let releases = URL(string: "https://github.com/AidanZealley/echotype/releases/latest")!

  var body: some View {
    Form {
      LabeledContent("Installed version") {
        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
      }
      Link("View latest release on GitHub", destination: releases)
      Text("Compare the version on GitHub with this one. To update, quit EchoType, download the DMG, and replace EchoType.app in Applications.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .formStyle(.columns)
    .padding(20)
    .fixedSize(horizontal: false, vertical: true)
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
      Picker("Language", selection: $store.settings.language) {
        ForEach(EchoTypeCore.Settings.Language.all, id: \.self) { language in
          Text(verbatim: language.name).tag(language.tag)
        }
      }
      VStack(alignment: .leading) {
        Toggle("Send reply requests", isOn: $store.settings.sendReplyRequests)
        Text("Ending with a request like “reply with EchoType” sends the message")
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

  private var provider: Provider { Providers[store.settings.provider] }
  private var reading: Binding<EchoTypeCore.Settings.Reading> {
    Binding(
      get: { store.settings.readingChoice(for: provider.voice) },
      set: { store.settings.reading[provider.id.rawValue] = $0 })
  }

  var body: some View {
    Form {
      Picker("Hotkey", selection: $store.settings.readAloudHotkey) {
        ForEach(EchoTypeCore.Settings.Hotkey.readAloudPresets, id: \.self) { hotkey in
          Text(verbatim: hotkey.label).tag(hotkey)
        }
      }
      Picker("Voice", selection: reading.voice) {
        ForEach(provider.voice.voices) { voice in
          Text(verbatim: voice.name).tag(voice.id)
        }
      }
      LabeledContent("Speed") {
        HStack {
          Slider(value: reading.speed, in: provider.voice.speedRange, step: 0.1)
          Text(reading.wrappedValue.speed, format: .number.precision(.fractionLength(1)))
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

private struct ProviderTab: View {
  @Bindable var store: SettingsStore
  let controller: DictationController?
  /// The selected provider's readiness for the current settings, followed while this tab is
  /// open. Nil until the first check answers, and for a provider that declares no readiness.
  @State private var readiness: ServiceReadiness?

  private var provider: Provider { Providers[store.settings.provider] }

  /// Changes when the provider, language or voice does, which restarts the following.
  private struct ReadinessID: Hashable {
    var provider: ProviderID
    var language: String
    var voice: String
  }

  private var readinessID: ReadinessID {
    let request = ReadinessRequest(settings: store.settings, voice: provider.voice)
    return ReadinessID(provider: provider.id, language: request.language, voice: request.voice)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Provider", selection: $store.settings.provider) {
        ForEach(Providers.all) { provider in
          Text(verbatim: provider.name).tag(provider.id)
        }
      }
      Text(verbatim: provider.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 8) {
        // These two services are required by the Provider contract.
        feature("Live transcription", available: true, state: readiness?.transcription)
        feature("Read aloud", available: true, state: readiness?.voice)
        feature("Cleanup", available: provider.cleanup != nil, state: readiness?.cleanup)
      }
      ProviderControls(provider: provider, controller: controller)
        // Each provider gets its own key draft, reveal state and async results.
        .id(provider.id)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .fixedSize(horizontal: false, vertical: true)
    .task(id: readinessID) {
      readiness = nil
      guard let source = provider.readiness else { return }
      await source.follow(ReadinessRequest(settings: store.settings, voice: provider.voice)) {
        readiness = $0
      }
    }
  }

  /// A supported service that is not ready shows the provider's reason beside its mark.
  private func feature(_ title: String, available: Bool, state: ServiceState?) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Label {
        Text(title)
      } icon: {
        Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
          .foregroundStyle(available ? Color.green : Color.secondary)
      }
      if let state, let reason = state.reason {
        Text(verbatim: reason)
          .font(.caption)
          .foregroundStyle(state == .unavailable(reason) ? Color.red : Color.secondary)
      }
    }
  }
}

/// The selected provider's key. A saved key is shown masked, never in an editable field. Save,
/// Replace and Remove are explicit, and every Keychain call runs off the main actor with the
/// buttons disabled until it finishes, so two writes cannot race.
///
/// Test runs a five second session through the controller with the saved key and shows what it
/// heard.
private struct ProviderControls: View {
  let provider: Provider
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

  private var placeholder: String {
    if case .apiKey(let placeholder) = provider.credential { placeholder } else { "" }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if case .apiKey = provider.credential {
        Text(verbatim: "\(provider.name) API key")
        if !loaded {
          ProgressView().controlSize(.small)
        } else if let savedKey, !replacing {
          saved(savedKey)
        } else {
          entry
        }
      }
      if let controller {
        HStack {
          Spacer()
          Button(testing ? "Testing…" : "Test") {
            Task { await test(controller) }
          }
          .disabled(testing || writing || !loaded || !controller.isIdle
            || !provider.credential.isSatisfied(by: savedKey))
        }
      }
      messages
    }
    .task {
      if case .apiKey = provider.credential {
        let id = provider.id
        let key = await Task.detached { Keychain.key(for: id) }.value
        guard !Task.isCancelled else { return }
        savedKey = key
      }
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
      TextField("\(provider.name) API key", text: $draft, prompt: Text(verbatim: placeholder), axis: .vertical)
        .labelsHidden()
        .font(.body.monospaced())
        .lineLimit(2...4)
        .onSubmit { Task { await save() } }
        .disabled(writing || testing)
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
          .disabled(writing || testing || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

  /// `key-••••…••••a3F9`: enough to tell keys apart without showing one. The bullets fill one
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
    let id = provider.id
    guard await write("Couldn't save the key", { Keychain.save(key, for: id) }) else { return }
    savedKey = key
    await controller?.refreshAPIKeyStatus(clearError: true)
    draft = ""
    replacing = false
    revealed = false
  }

  private func remove() async {
    let id = provider.id
    guard await write("Couldn't remove the key", { Keychain.remove(for: id) }) else { return }
    savedKey = nil
    await controller?.refreshAPIKeyStatus(clearError: true)
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

/// The editor holds its own text while the user types, so adding a separator does not rewrite
/// the text around the cursor.
private struct KeytermsTab: View {
  let store: SettingsStore
  @State private var text: String

  init(store: SettingsStore) {
    self.store = store
    _text = State(initialValue: store.settings.keyterms.joined(separator: ", "))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Separate with commas")
        Spacer()
        Text(verbatim: "\(store.settings.keyterms.count) of \(Providers[store.settings.provider].transcription.keytermLimit - 1) keyterms used")
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
        .frame(height: 120)
        .onChange(of: text) {
          store.settings.keyterms = text.split { $0 == "," || $0.isNewline }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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

extension Readiness {
  /// Reports the answer for `request` now, which starts any setup it needs, and again each time
  /// `changes` yields. Runs until cancelled, which drops the stream; an answer that arrives after
  /// cancellation is ignored.
  @MainActor func follow(
    _ request: ReadinessRequest, update: @MainActor (ServiceReadiness) -> Void
  ) async {
    let changes = changes()
    func report() async {
      let answer = await check(request)
      if !Task.isCancelled { update(answer) }
    }
    await report()
    for await _ in changes { await report() }
  }
}
