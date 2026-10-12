import AVFoundation
import ApplicationServices
import EchoTypeCore
import ServiceManagement
import SwiftUI

/// A Settings page.
enum Pane: Hashable {
  case dictation, readAloud, provider(ProviderID), general, keyterms, agents, about

  var title: String {
    switch self {
    case .dictation: "Dictation"
    case .readAloud: "Read Aloud"
    case .provider(let id): Providers[id].name
    case .general: "General"
    case .keyterms: "Keyterms"
    case .agents: "Agents"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .dictation: "mic"
    case .readAloud: "speaker.wave.2"
    case .provider(let id): Providers[id].setup == nil ? "network" : "desktopcomputer"
    case .general: "gearshape"
    case .keyterms: "character.book.closed"
    case .agents: "terminal"
    case .about: "info.circle"
    }
  }

  /// Providers with something to configure: a key or files to install.
  static var providers: [Pane] {
    Providers.all.filter { $0.credential != .none || $0.setup != nil }.map { .provider($0.id) }
  }
}

/// The settings window: a page per concern. The hotkeys apply at once; the rest apply from the
/// next dictation or reading.
struct SettingsView: View {
  @Bindable var store: SettingsStore
  /// Nil in the overlay demo, which has no controller.
  let controller: DictationController?
  @State private var pane: Pane? = .dictation

  var body: some View {
    NavigationSplitView {
      List(selection: $pane) {
        Section { row(.dictation); row(.readAloud) }
        Section { ForEach(Pane.providers, id: \.self, content: row) }
        Section { row(.general); row(.keyterms); row(.agents); row(.about) }
      }
      .toolbar(removing: .sidebarToggle)
      .navigationSplitViewColumnWidth(180)
    } detail: {
      Group {
        switch pane ?? .dictation {
        case .dictation: DictationPage(store: store, controller: controller, pane: $pane)
        case .readAloud: ReadAloudPage(store: store, controller: controller, pane: $pane)
        case .provider(let id): ProviderPage(provider: Providers[id], store: store, controller: controller)
        case .general: GeneralPage()
        case .keyterms: KeytermsPage(store: store)
        case .agents: AgentsPage()
        case .about: AboutPage()
        }
      }
      .formStyle(.grouped)
      .navigationTitle((pane ?? .dictation).title)
    }
  }

  private func row(_ pane: Pane) -> some View {
    Label(pane.title, systemImage: pane.systemImage).tag(pane)
  }
}

// MARK: Features

private struct DictationPage: View {
  @Bindable var store: SettingsStore
  let controller: DictationController?
  @Binding var pane: Pane?
  @State private var readiness: ServiceReadiness?
  @State private var testing = false
  @State private var outcome: DictationController.TestOutcome?
  private var provider: Provider { Providers[store.settings.dictationProvider] }

  var body: some View {
    Form {
      ProviderPicker(selection: $store.settings.dictationProvider)
      Section("Status") {
        CredentialRow(provider: provider, missing: controller?.dictationHasCredential == false, pane: $pane)
        ServiceRow(title: "Transcription", state: readiness?.transcription, provider: provider, pane: $pane)
        if provider.cleanup != nil {
          ServiceRow(title: "Cleanup", state: readiness?.cleanup, provider: provider, pane: $pane)
        }
      }
      Section("Input") {
        Picker("Hotkey", selection: $store.settings.hotkey) {
          ForEach(EchoTypeCore.Settings.Hotkey.presets, id: \.self) { Text(verbatim: $0.label).tag($0) }
        }
        InputRow(store: store)
        Picker("Language", selection: Binding(
          get: { store.settings.language(for: provider) }, set: { store.settings.language = $0 })
        ) {
          ForEach(provider.languages, id: \.self) { Text(verbatim: $0.name).tag($0.tag) }
        }
        Toggle(isOn: $store.settings.sendReplyRequests) {
          Text("Send reply requests")
          Text("Ending with a request like “reply with EchoType” sends the message.")
        }
      }
      if let controller {
        Section {
          LabeledContent("Microphone") {
            Button(testing ? "Testing…" : "Test") {
              testing = true
              Task {
                outcome = await controller.test()
                testing = false
              }
            }
            .disabled(testing || !controller.isIdle || controller.dictationHasCredential == false)
          }
        } footer: {
          switch outcome {
          case .heard(let text): Text(text).textSelection(.enabled)
          case .heardNothing: Text("Nothing was heard.")
          case .failed(let error): Label(error, systemImage: "exclamationmark.triangle.fill")
          case nil: Text("Records five seconds and shows what was heard.")
          }
        }
      }
    }
    .task(id: Followed(settings: store.settings, provider: provider)) {
      readiness = nil
      await provider.readiness.follow(ReadinessRequest(settings: store.settings, provider: provider)) {
        readiness = $0
      }
    }
  }
}

private struct ReadAloudPage: View {
  @Bindable var store: SettingsStore
  let controller: DictationController?
  @Binding var pane: Pane?
  @State private var voice: ServiceState?
  private var provider: Provider { Providers[store.settings.readAloudProvider] }
  private var reading: Binding<EchoTypeCore.Settings.Reading> {
    Binding(
      get: { store.settings.readingChoice(for: provider) },
      set: { store.settings.reading[provider.id.rawValue] = $0 })
  }

  var body: some View {
    Form {
      ProviderPicker(selection: $store.settings.readAloudProvider)
      Section("Status") {
        CredentialRow(provider: provider, missing: controller?.readAloudHasCredential == false, pane: $pane)
        ServiceRow(title: "Speech", state: voice, provider: provider, pane: $pane)
      }
      Section("Reading") {
        Picker("Hotkey", selection: $store.settings.readAloudHotkey) {
          ForEach(EchoTypeCore.Settings.Hotkey.readAloudPresets, id: \.self) {
            Text(verbatim: $0.label).tag($0)
          }
        }
        Picker("Voice", selection: reading.voice) {
          ForEach(provider.voice.voices) { Text(verbatim: $0.name).tag($0.id) }
        }
        // A fixed rate has no choice to make and cannot supply a Slider's non-empty range.
        let range = provider.voice.speedRange
        if range.lowerBound < range.upperBound {
          Slider(value: reading.speed, in: range, step: 0.1) {
            Text("Speed")
          } minimumValueLabel: {
            Text(verbatim: speed(range.lowerBound))
          } maximumValueLabel: {
            Text(verbatim: speed(range.upperBound))
          }
        }
      }
    }
    .task(id: Followed(settings: store.settings, provider: provider)) {
      voice = nil
      await provider.readiness.follow(ReadinessRequest(settings: store.settings, provider: provider)) {
        voice = $0.voice
      }
    }
  }

  private func speed(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1))) + "×"
  }
}

/// The feature's provider, with the selected one's summary underneath.
private struct ProviderPicker: View {
  @Binding var selection: ProviderID

  var body: some View {
    Section {
      Picker("Provider", selection: $selection) {
        ForEach(Providers.all) { Text(verbatim: $0.name).tag($0.id) }
      }
    } footer: {
      Text(Providers[selection].summary)
    }
  }
}

/// What a page follows. Changes when the provider, language or voice does, which restarts the
/// following.
private struct Followed: Hashable {
  var provider: ProviderID
  var request: ReadinessRequest

  init(settings: EchoTypeCore.Settings, provider: Provider) {
    self.provider = provider.id
    request = ReadinessRequest(settings: settings, provider: provider)
  }
}

/// Shown only when the provider's key is missing.
private struct CredentialRow: View {
  let provider: Provider
  let missing: Bool
  @Binding var pane: Pane?

  var body: some View {
    if missing {
      LabeledContent {
        Button("Set Up…") { pane = .provider(provider.id) }
      } label: {
        Text("API key")
        Label("Add your \(provider.name) API key.", systemImage: "exclamationmark.triangle.fill")
      }
    }
  }
}

/// One service's status. A provider with setup links to its page until the service is ready.
private struct ServiceRow: View {
  let title: String
  let state: ServiceState?
  let provider: Provider
  @Binding var pane: Pane?

  var body: some View {
    LabeledContent {
      if let fix = state?.fix {
        Button("Open…") { NSWorkspace.shared.open(fix) }
      } else if provider.setup != nil, let state, state.status != .ready {
        Button("Set Up…") { pane = .provider(provider.id) }
      } else {
        switch state?.status {
        case .ready: Text("Ready")
        case .waiting, nil: ProgressView().controlSize(.small)
        case .unavailable: Text("Unavailable")
        }
      }
    } label: {
      Text(title)
      if let message = state?.message {
        if state?.status == .unavailable {
          Label(message, systemImage: "exclamationmark.triangle.fill")
        } else {
          Text(message)
        }
      }
    }
  }
}

// MARK: Providers

/// A provider's key and setup, whichever it has.
private struct ProviderPage: View {
  let provider: Provider
  let store: SettingsStore
  let controller: DictationController?

  var body: some View {
    Form {
      Section {
        if case .apiKey = provider.credential {
          APIKeyRow(provider: provider, settings: store.settings, controller: controller)
            .id(provider.id)
        }
      } footer: {
        Text(provider.summary)
      }
      if let state = store.setups[provider.id] {
        SetupSections(state: state)
          .task(id: provider.id) {
            await state.follow(ReadinessRequest(settings: store.settings, provider: provider))
          }
      }
    }
  }
}

/// The provider's key. A saved key is shown masked, never in an editable field. Every Keychain
/// call runs off the main actor with the buttons disabled until it finishes, so two writes
/// cannot race.
private struct APIKeyRow: View {
  let provider: Provider
  let settings: EchoTypeCore.Settings
  let controller: DictationController?
  /// What the Keychain holds. Nil when there is no key.
  @State private var savedKey: String?
  @State private var loaded = false
  @State private var draft = ""
  /// Replace was clicked, so the field shows even though a key is saved.
  @State private var replacing = false
  @State private var confirmingRemove = false
  @State private var writing = false
  @State private var writeError: String?

  var body: some View {
    Group {
      if !loaded {
        LabeledContent("API key") { ProgressView().controlSize(.small) }
      } else if let savedKey, !replacing {
        LabeledContent("API key", value: Self.masked(savedKey))
        LabeledContent {
          HStack {
            Button("Replace") { draft = ""; replacing = true }
            Button("Remove…") { confirmingRemove = true }
          }
        } label: {
          if let writeError { Label(writeError, systemImage: "exclamationmark.triangle.fill") }
        }
        .disabled(writing)
      } else {
        TextField("API key", text: $draft, prompt: Text(verbatim: placeholder))
          .onSubmit { Task { await save() } }
          .disabled(writing)
        LabeledContent {
          HStack {
            if replacing { Button("Cancel") { replacing = false; writeError = nil } }
            Button("Save") { Task { await save() } }
              .disabled(writing || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        } label: {
          if let writeError { Label(writeError, systemImage: "exclamationmark.triangle.fill") }
        }
      }
    }
    .task {
      let id = provider.id
      savedKey = await Task.detached { Keychain.key(for: id) }.value
      loaded = true
    }
    .confirmationDialog("Remove the API key?", isPresented: $confirmingRemove) {
      Button("Remove", role: .destructive) { Task { await remove() } }
    } message: {
      let affected = [
        settings.dictationProvider == provider.id ? "Dictation" : nil,
        settings.readAloudProvider == provider.id ? "Read Aloud" : nil,
      ].compactMap { $0 }
      Text(
        affected.isEmpty
          ? "This removes the saved key for \(provider.name)."
          : "\(affected.joined(separator: " and ")) will need a new \(provider.name) API key.")
    }
  }

  private var placeholder: String {
    if case .apiKey(let placeholder) = provider.credential { placeholder } else { "" }
  }

  /// `key-••••••••a3F9`: enough to tell keys apart without showing one.
  private static func masked(_ key: String) -> String {
    let prefix = key.firstIndex(of: "-").map { String(key[...$0]) } ?? ""
    guard key.count - prefix.count > 8 else { return String(repeating: "•", count: 8) }
    return prefix + String(repeating: "•", count: 8) + key.suffix(4)
  }

  private func save() async {
    let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, !writing else { return }
    let id = provider.id
    guard await write("Couldn't save the key.", { Keychain.save(key, for: id) }) else { return }
    savedKey = key
    await controller?.refreshCredentialStatus(clearError: true)
    draft = ""
    replacing = false
  }

  private func remove() async {
    let id = provider.id
    guard await write("Couldn't remove the key.", { Keychain.remove(for: id) }) else { return }
    savedKey = nil
    await controller?.refreshCredentialStatus(clearError: true)
  }

  private func write(_ failure: String, _ operation: @escaping @Sendable () -> Bool) async -> Bool {
    writing = true
    defer { writing = false }
    let succeeded = await Task.detached(operation: operation).value
    writeError = succeeded ? nil : failure
    return succeeded
  }
}

// MARK: App

private struct GeneralPage: View {
  var body: some View {
    Form {
      Section("Startup") { LaunchAtLoginRow() }
      Section("Permissions") { PermissionRows() }
    }
  }
}

private struct KeytermsPage: View {
  @Bindable var store: SettingsStore

  var body: some View {
    let limit = Providers[store.settings.dictationProvider].transcription.keytermLimit
    Form {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          LabeledContent {
            Text("\(store.settings.keyterms.count) of \(limit)").monospacedDigit()
          } label: {
            Text("Vocabulary")
            Text("Names and terms that dictation should spell exactly as you write them.")
          }
          KeytermField(terms: $store.settings.keyterms)
        }
      }
    }
    // A click outside the field ends editing, which macOS does not do on its own.
    .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
  }
}

/// Looks and acts like one input: each term is a removable chip, Return adds what was typed and
/// Backspace in the empty field removes the last term. Clicking anywhere in it starts typing.
private struct KeytermField: View {
  @Binding var terms: [String]
  @State private var draft = ""
  @State private var editing = false
  @State private var focus = TermInput.Focus()

  var body: some View {
    FlowLayout(spacing: 6) {
      ForEach(terms, id: \.self) { term in
        HStack(spacing: 4) {
          Text(term)
          Button("Remove \(term)", systemImage: "xmark") { terms.removeAll { $0 == term } }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .imageScale(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: .capsule)
      }
      TermInput(text: $draft, editing: $editing, focus: focus, onSubmit: add) {
        if !terms.isEmpty { terms.removeLast() }
      }
      .frame(minWidth: 80)
    }
    .padding(6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
    .onTapGesture { focus.start() }
    .overlay {
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(editing ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: editing ? 2 : 1)
    }
  }

  private func add() {
    let term = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    draft = ""
    guard !term.isEmpty, !terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame })
    else { return }
    terms.append(term)
  }
}

/// A borderless text field that reports Return and Backspace when empty, and stops editing on
/// Escape. SwiftUI's key handling never sees Backspace, because AppKit's field editor takes it
/// first.
private struct TermInput: NSViewRepresentable {
  /// Lets the surrounding view start editing the field.
  final class Focus {
    weak var field: NSTextField?
    func start() { field?.window?.makeFirstResponder(field) }
  }

  @Binding var text: String
  @Binding var editing: Bool
  let focus: Focus
  let onSubmit: () -> Void
  let onDeleteEmpty: () -> Void

  /// Reports focus as soon as it is clicked, before any typing.
  final class Field: NSTextField {
    var onFocus: () -> Void = {}
    override func becomeFirstResponder() -> Bool {
      let became = super.becomeFirstResponder()
      if became { onFocus() }
      return became
    }
  }

  func makeNSView(context: Context) -> NSTextField {
    let field = Field()
    field.onFocus = { [coordinator = context.coordinator] in coordinator.input.editing = true }
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.delegate = context.coordinator
    focus.field = field
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    context.coordinator.input = self
    if field.stringValue != text { field.stringValue = text }
  }

  func makeCoordinator() -> Coordinator { Coordinator(input: self) }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    var input: TermInput
    init(input: TermInput) { self.input = input }

    func controlTextDidChange(_ notification: Notification) {
      input.text = (notification.object as? NSTextField)?.stringValue ?? ""
    }

    func controlTextDidEndEditing(_ notification: Notification) { input.editing = false }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
      switch selector {
      case #selector(NSResponder.insertNewline(_:)):
        input.onSubmit()
        return true
      case #selector(NSResponder.cancelOperation(_:)):
        control.window?.makeFirstResponder(nil)
        return true
      case #selector(NSResponder.deleteBackward(_:)) where textView.string.isEmpty:
        input.onDeleteEmpty()
        return true
      default:
        return false
      }
    }
  }
}

/// Places views in rows, starting a new row when the next one would not fit.
private struct FlowLayout: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(subviews, width: proposal.width ?? .infinity)
    return CGSize(width: proposal.width ?? rows.width, height: rows.height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for (subview, origin) in zip(subviews, arrange(subviews, width: bounds.width).origins) {
      subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
    }
  }

  /// Each view's origin, centred vertically in its row.
  private func arrange(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], width: CGFloat, height: CGFloat) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    var origins: [CGPoint] = []
    var row: Range<Int> = 0..<0
    var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
    func endRow() {
      for index in row { origins[index].y = y + (rowHeight - sizes[index].height) / 2 }
    }
    for (index, size) in sizes.enumerated() {
      if x > 0, x + size.width > width {
        endRow()
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
        row = index..<index
      }
      origins.append(CGPoint(x: x, y: y))
      row = row.lowerBound..<(index + 1)
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      widest = max(widest, x - spacing)
    }
    endRow()
    return (origins, widest, y + rowHeight)
  }
}

/// Commands and optional agent instructions to copy. EchoType never edits another tool's config
/// or runs its CLI. The commands name the running app, so they stay right if it moves.
private struct AgentsPage: View {
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
    Form {
      Section {
        command("Claude Code", "claude mcp add --scope user echotype -- \(app) --mcp")
        command("Codex", "codex mcp add echotype -- \(app) --mcp")
      } header: {
        Text("Connect an agent")
      } footer: {
        Text("Run a command once in a terminal, then start a new agent session. If the agent is already connected, remove EchoType from it first.")
      }
      Section {
        LabeledContent("Agent instructions") { copy(Self.agentInstructions) }
      } footer: {
        Text("Optional. Paste them into your agent's instructions, such as AGENTS.md.")
      }
    }
  }

  private func command(_ name: String, _ text: String) -> some View {
    LabeledContent {
      copy(text)
    } label: {
      Text(name)
      Text(verbatim: text).textSelection(.enabled)
    }
  }

  private func copy(_ text: String) -> some View {
    Button("Copy") {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    }
  }
}

private struct AboutPage: View {
  var body: some View {
    Form {
      Section {
        LabeledContent(
          "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Link("Latest release", destination: URL(string: "https://github.com/AidanZealley/echotype/releases/latest")!)
        Link("Source code", destination: URL(string: "https://github.com/AidanZealley/echotype")!)
        Link("Report an issue", destination: URL(string: "https://github.com/AidanZealley/echotype/issues")!)
      } footer: {
        Text("To update, quit EchoType and replace it in Applications with the latest release.")
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
    Toggle(isOn: Binding(
      get: { status == .enabled || status == .requiresApproval },
      set: { enabled in Task { await set(enabled) } })
    ) {
      Text("Launch at login")
      if let error {
        Label(error, systemImage: "exclamationmark.triangle.fill")
      } else if status == .requiresApproval {
        Text("Allow EchoType in System Settings > General > Login Items.")
      }
    }
    .disabled(status == nil || pending)
    .task { await refresh() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      Task { await refresh() }
    }
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
private struct PermissionRows: View {
  @State private var microphone = false
  @State private var deviceControl = false

  var body: some View {
    Group {
      row("Microphone", granted: microphone, pane: "Privacy_Microphone")
      row("Device Control and Data Access", granted: deviceControl, pane: "Privacy_Accessibility")
    }
    .onAppear(perform: refresh)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      refresh()
    }
  }

  private func row(_ title: String, granted: Bool, pane: String) -> some View {
    LabeledContent(title) {
      if granted {
        Label("Granted", systemImage: "checkmark.circle.fill")
      } else {
        Button("Open System Settings…") {
          NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
        }
      }
    }
  }

  private func refresh() {
    microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    deviceControl = AXIsProcessTrusted()
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

extension Readiness {
  /// Reports the answer for `request` now without starting setup, and again each time
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
