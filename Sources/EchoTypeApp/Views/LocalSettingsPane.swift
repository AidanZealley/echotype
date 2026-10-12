import EchoTypeCore
import SwiftUI

struct LocalSettingsPane: View {
  let store: SettingsStore
  @State private var managing = false
  private var installation: LocalInstallation { store.localInstallation }

  var body: some View {
    Form {
      Section {
        Text(
          "English models run on this Mac and work offline after setup. First preparation can take a minute while macOS compiles the models."
        )
        .foregroundStyle(.secondary)
      }
      ForEach(ProviderFeature.allCases) { feature in
        LocalFeatureSection(feature: feature, installation: installation)
      }
      Section("Storage") {
        LabeledContent("On disk", value: size(installation.files.reduce(0) { $0 + $1.bytes }))
        Button("Manage files…") { managing = true }
        if let message = installation.message { Text(message).textSelection(.enabled) }
      }
      LocalNotices()
    }
    .settingsForm()
    .task { await installation.follow() }
    .sheet(isPresented: $managing) { LocalFilesSheet(installation: installation) }
  }
}

/// Requirements and the explicit action stay together on both the feature and provider pages.
struct LocalFeatureSection: View {
  let feature: ProviderFeature
  @Bindable var installation: LocalInstallation
  private var setup: LocalSetup { Provider.local.localSetup! }

  var body: some View {
    let requirements = setup.requirements([feature])
    let installed = requirements.allSatisfy(\.installed)
    let total = requirements.reduce(Int64(0)) { $0 + $1.missingBytes }
    let status =
      feature == .dictation ? installation.readiness?.transcription : installation.readiness?.voice
    let cleanup = feature == .dictation ? installation.readiness?.cleanup : nil
    let ready = status?.status == .ready && (cleanup == nil || cleanup?.status == .ready)
    let running = installation.requested.contains(feature)
    Section(feature.title + " models") {
      LabeledContent(
        "Status",
        value: running ? "Setting up" : ready ? "Ready" : installed ? "Installed" : "Needs download"
      )
      ForEach(requirements) { requirement in
        VStack(alignment: .leading, spacing: 6) {
          LabeledContent(
            requirement.name,
            value: requirement.installed
              ? "Installed · " + size(requirement.bytes)
              : requirement.missingBytes == 0
                ? "Retained download" : size(requirement.missingBytes) + " download")
          HStack {
            Text(requirement.purpose).foregroundStyle(.secondary)
            Spacer()
            Link("Source · " + requirement.license, destination: requirement.source)
          }
        }
      }
      LabeledContent("Total download", value: size(total))
      if let available = setup.availableBytes() {
        LabeledContent("Available disk space", value: size(available))
        Text("Up to " + size(total) + " of temporary storage is needed before verification.")
          .foregroundStyle(.secondary)
        if available < total {
          Text("Free " + size(total - available) + " on this disk, then retry.").foregroundStyle(
            .red)
        }
      }
      Text(
        "Works offline after setup. This action downloads and prepares only " + feature.title + "."
      )
      .foregroundStyle(.secondary)
      if let message = status?.message { Text(message).foregroundStyle(.secondary) }
      if let message = cleanup?.message { Text("Cleanup: " + message).foregroundStyle(.secondary) }
      if let message = installation.messages[feature] { Text(message).textSelection(.enabled) }
      HStack {
        Spacer()
        if running {
          ProgressView().controlSize(.small)
          Button("Cancel") { installation.cancel(feature) }
        } else if !ready {
          Button(installed ? "Prepare / Retry" : "Download") { installation.start([feature]) }
            .disabled(setup.availableBytes().map { $0 < total } == true)
        }
      }
    }
  }
}

struct LocalNotices: View {
  var body: some View {
    Section("Sources and licences") {
      Text(
        "Model files retain their upstream licences. EchoType bundles eSpeak NG pronunciation data and its notices."
      )
      .foregroundStyle(.secondary)
      ForEach(Provider.local.localSetup!.requirements(Set(ProviderFeature.allCases))) {
        requirement in
        Link(requirement.name + " · " + requirement.license, destination: requirement.source)
      }
      Link(
        "eSpeak NG · GPLv3",
        destination: URL(string: "https://github.com/espeak-ng/espeak-ng/blob/master/COPYING")!)
      if let notices = Bundle.main.resourceURL?.appending(path: "Licenses") {
        Button("Open bundled notices") { NSWorkspace.shared.open(notices) }
      }
    }
  }
}

private struct LocalFilesSheet: View {
  @Bindable var installation: LocalInstallation
  @Environment(\.dismiss) private var dismiss
  @State private var selected: Set<URL> = []
  @State private var confirming = false
  @State private var removing = false

  private var selectedFiles: [LocalFile] {
    installation.files.filter { file in
      selected.contains(file.id) || selected.contains { file.id.path.hasPrefix($0.path + "/") }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Manage local files").font(.title2)
      Text(
        "Remove EchoType's installed models, generated files or retained downloads. Settings, API keys and other apps' real cache folders are kept."
      )
      .font(.callout).foregroundStyle(.secondary)
      HStack {
        ForEach(ProviderFeature.allCases) { feature in
          Button("Remove " + feature.title + " models…") {
            selected = Set(installation.files.filter { $0.features.contains(feature) }.map(\.id))
            confirming = true
          }.disabled(
            removing || !installation.files.contains { $0.features.contains(feature) }
              || Provider.local.localSetup?.removalBlock(
                installation.files.filter { $0.features.contains(feature) }) != nil
          )
        }
        Button("Remove all local models…") {
          selected = Set(installation.files.map(\.id))
          confirming = true
        }
        .disabled(
          removing || installation.files.isEmpty
            || Provider.local.localSetup?.removalBlock(installation.files) != nil)
      }.controlSize(.small)
      List(installation.files, selection: $selected) { file in
        VStack(alignment: .leading) {
          HStack {
            Text(file.name)
            Spacer()
            Text(size(file.bytes))
          }
          Text(file.category).font(.caption).foregroundStyle(.secondary)
        }.tag(file.id)
      }.frame(minHeight: 220)
      if installation.files.isEmpty {
        Text("No local model files are stored.").foregroundStyle(.secondary)
      }
      if let reason = Provider.local.localSetup?.removalBlock(selectedFiles), !selected.isEmpty {
        Text(reason).font(.caption).foregroundStyle(.secondary)
      }
      if let message = installation.message { Text(message).font(.caption).textSelection(.enabled) }
      HStack {
        Button("Refresh") { Task { await installation.refreshFiles() } }.disabled(removing)
        Spacer()
        Button("Remove selected…", role: .destructive) { confirming = true }
          .disabled(
            selected.isEmpty || removing
              || Provider.local.localSetup?.removalBlock(selectedFiles) != nil)
        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).disabled(removing)
      }
    }.padding(24).frame(width: 670, height: 490)
      .confirmationDialog("Remove the selected files?", isPresented: $confirming) {
        Button("Remove files", role: .destructive) {
          let files = selectedFiles
          removing = true
          Task {
            await installation.remove(files)
            selected = []
            removing = false
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        let affected = Set(selectedFiles.flatMap(\.features)).map(\.title).sorted().joined(
          separator: " and ")
        Text(
          "Affected features: \(affected.isEmpty ? "Retained downloads only" : affected). This removes \(size(selectedFiles.reduce(0) { $0 + $1.bytes })). Removing installed models makes their feature unavailable until setup runs again. Active operations and preparation protect their files."
        )
      }
  }
}

private func size(_ bytes: Int64) -> String {
  ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
