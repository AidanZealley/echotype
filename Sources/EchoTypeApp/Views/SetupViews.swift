import EchoTypeCore
import SwiftUI

/// A provider's install controls: a section per feature, then its storage.
struct SetupSections: View {
  @Bindable var state: SetupState
  @State private var managing = false

  var body: some View {
    ForEach(ProviderFeature.allCases) { feature in
      FeatureSetupSection(feature: feature, state: state)
    }
    Section("Storage") {
      LabeledContent("On disk", value: size(state.files.reduce(0) { $0 + $1.bytes }))
      LabeledContent("Files") { Button("Manage Files…") { managing = true } }
      LabeledContent("Licences") {
        Menu("Sources") {
          ForEach(state.controls.requirements(Set(ProviderFeature.allCases))) { requirement in
            Link("\(requirement.name), \(requirement.license)", destination: requirement.source)
          }
          if let notices = Bundle.main.resourceURL?.appending(path: "Licenses") {
            Divider()
            Button("Bundled Notices") { NSWorkspace.shared.open(notices) }
          }
        }
        .fixedSize()
      }
      if let message = state.message { Label(message, systemImage: "exclamationmark.triangle.fill") }
    }
    .sheet(isPresented: $managing) { FilesSheet(state: state) }
  }
}

/// One feature's models, its status and its one action.
private struct FeatureSetupSection: View {
  let feature: ProviderFeature
  @Bindable var state: SetupState
  @State private var confirmingRemove = false

  var body: some View {
    let requirements = state.controls.requirements([feature])
    let installed = requirements.allSatisfy(\.installed)
    let missing = requirements.reduce(Int64(0)) { $0 + $1.missingBytes }
    let lacking = state.controls.availableBytes().map { missing - $0 } ?? 0
    let services = services
    let ready = services.allSatisfy { $0?.status == .ready }
    let queued = state.queue.contains(feature)
    let waitingFor = queued && state.queue.first != feature ? state.queue.first : nil
    let files = state.files.filter { $0.features.contains(feature) }
    Section(feature.title) {
      ForEach(requirements) { requirement in
        LabeledContent {
          Text(size(requirement.bytes))
        } label: {
          Text(requirement.name)
          Text(requirement.purpose)
        }
      }
      LabeledContent {
        if queued {
          Button("Cancel") { state.cancel(feature) }
        } else if ready {
          Button("Remove…") { confirmingRemove = true }
            .disabled(state.controls.removalBlock(files) != nil)
        } else if installed {
          Button("Retry") { state.start(feature) }
        } else {
          Button("Download") { state.start(feature) }.disabled(lacking > 0)
        }
      } label: {
        Text("Status")
        if let waitingFor {
          Text("Waiting for \(waitingFor.title) setup.")
        } else if queued {
          Text(state.controls.progress(feature) == nil ? "Loading." : "Downloading.")
        } else if let message = state.messages[feature] {
          Label(message, systemImage: "exclamationmark.triangle.fill")
        } else if ready {
          Text("Ready.")
        } else if let failure = services.compactMap({ $0 }).first(where: { $0.status == .unavailable }), installed {
          Label(failure.message ?? "Couldn't load.", systemImage: "exclamationmark.triangle.fill")
        } else if installed {
          Text("Installed.")
        } else if lacking > 0 {
          Label("Free \(size(lacking)) on this disk to download.", systemImage: "exclamationmark.triangle.fill")
        } else {
          Text("Needs a \(size(missing)) download.")
        }
      }
      if queued, waitingFor == nil, let progress = state.controls.progress(feature) {
        ProgressView(value: progress)
      }
    }
    .confirmationDialog("Remove the \(feature.title) models?", isPresented: $confirmingRemove) {
      Button("Remove", role: .destructive) { Task { await state.remove(files) } }
    } message: {
      Text("\(feature.title) won't work until you download them again.")
    }
  }

  private var services: [ServiceState?] {
    feature == .dictation
      ? [state.readiness?.transcription, state.readiness?.cleanup]
      : [state.readiness?.voice]
  }
}

/// Every file the provider stores, for removing any of them.
private struct FilesSheet: View {
  @Bindable var state: SetupState
  @Environment(\.dismiss) private var dismiss
  @State private var selection: Set<URL> = []
  @State private var confirming = false

  private var selected: [InstalledFile] { state.files.filter { selection.contains($0.id) } }

  var body: some View {
    Table(state.files, selection: $selection) {
      TableColumn("Name", value: \.name)
      TableColumn("Kind", value: \.category)
      TableColumn("Size") { Text(size($0.bytes)) }.width(80)
    }
    .frame(minWidth: 560, minHeight: 300)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
      ToolbarItem(placement: .destructiveAction) {
        Button("Remove…") { confirming = true }
          .disabled(selection.isEmpty || state.controls.removalBlock(selected) != nil)
          .help(state.controls.removalBlock(selected) ?? "")
      }
    }
    .task { await state.refreshFiles() }
    .confirmationDialog("Remove \(selected.count) files?", isPresented: $confirming) {
      Button("Remove", role: .destructive) {
        let files = selected
        Task {
          await state.remove(files)
          selection = []
        }
      }
    } message: {
      let affected = Set(selected.flatMap(\.features)).map(\.title).sorted()
      Text(
        affected.isEmpty
          ? "This frees \(size(selected.reduce(0) { $0 + $1.bytes }))."
          : "\(affected.joined(separator: " and ")) won't work until you download its models again.")
    }
  }
}

private func size(_ bytes: Int64) -> String {
  ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
