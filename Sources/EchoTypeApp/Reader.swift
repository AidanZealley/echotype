import EchoTypeCore
import Foundation
import Observation

/// Created without side effects. The coordinator reserves it, then owns and joins `run()`.
@MainActor @Observable final class Reader {
  enum Failure: Error { case nothingSelected, noAPIKey, playback(any Error) }
  enum Source { case selection, text(String) }
  enum Presentation: Equatable { case starting, playing, paused, failed(String), stopped }
  struct Dependencies {
    var selection: (@escaping @MainActor () -> Bool) async -> String?
    var cleanup: () async -> Void
    /// What the provider needs before a reading starts.
    var credential: Credential
    /// The provider's stored key, or nil.
    var key: () async -> String?
    var voice: VoiceService
    var player: any ReadingPlayback
  }
  private let source: Source
  private let settings: Settings
  private let dependencies: Dependencies
  private let onPresentation: @MainActor (Reader) -> Void
  private var stream: (any SpeechStream)?
  private var stopped = false
  private var hasRun = false
  private var playbackStarted = false
  private(set) var presentation: Presentation = .starting
  private(set) var level = 0.0
  let id: UUID
  let startedAt = Date.now
  private(set) var pausedAt: Date?
  private(set) var pausedDuration: TimeInterval = 0

  init(_ source: Source, id: UUID = UUID(), settings: Settings, dependencies: Dependencies,
    onPresentation: @escaping @MainActor (Reader) -> Void = { _ in }
  ) {
    self.id = id
    self.source = source; self.settings = settings
    self.dependencies = dependencies; self.onPresentation = onPresentation
  }

  func receiveLevel(_ level: Double) {
    guard !stopped, presentation == .playing else { return }
    self.level = level; onPresentation(self)
  }
  func stop() {
    guard !stopped else { return }
    stopped = true
    stream?.cancel(); dependencies.player.stop()
    presentation = .stopped; level = 0
    onPresentation(self)
  }
  func togglePause() {
    guard !stopped else { return }
    if let pausedAt {
      pausedDuration += Date.now.timeIntervalSince(pausedAt); self.pausedAt = nil
      if playbackStarted { dependencies.player.resume() }
      presentation = playbackStarted ? .playing : .starting
    } else {
      pausedAt = .now
      if playbackStarted { dependencies.player.pause() }
      presentation = .paused
    }
    level = 0; onPresentation(self)
  }
  private func checkStopped() throws {
    try Task.checkCancellation()
    if stopped { throw CancellationError() }
  }

  /// Returns exactly once, after selection restoration and player/request teardown.
  func run() async -> (any Error)? {
    precondition(!hasRun); hasRun = true
    var failure: (any Error)?
    do {
      try await withTaskCancellationHandler { try await read() } onCancel: {
        Task { @MainActor in self.stop() }
      }
    }
    catch { if !stopped && !Task.isCancelled { failure = error } }
    stream?.cancel(); stream = nil
    dependencies.player.stop()
    await dependencies.cleanup()
    if stopped || Task.isCancelled { failure = nil }
    level = 0
    if let failure { presentation = .failed(String(describing: failure)) }
    else { presentation = .stopped }
    stopped = true
    onPresentation(self)
    return failure
  }

  private func read() async throws {
    try checkStopped()
    let spoken: String
    switch source {
    case .selection:
      let selected = await dependencies.selection { [weak self] in self?.stopped != false }
      try checkStopped()
      guard let selected, !selected.isEmpty else { throw Failure.nothingSelected }
      spoken = selected
    case .text(let text): spoken = text
    }
    let apiKey = await dependencies.key()
    try checkStopped()
    guard dependencies.credential.isSatisfied(by: apiKey) else { throw Failure.noAPIKey }
    let voice = dependencies.voice
    let stream = voice.speak(SpeechRequest(text: voice.capped(spoken), settings: settings, voice: voice, credential: apiKey))
    self.stream = stream
    // Each short chunk waits for playback capacity before the stream is pulled again.
    while let audio = try await stream.next() {
      try checkStopped()
      if !playbackStarted {
        do { try dependencies.player.start(sampleRate: audio.sampleRate) } catch { throw Failure.playback(error) }
        playbackStarted = true
        if pausedAt != nil { dependencies.player.pause() }
        presentation = pausedAt != nil ? .paused : .playing; onPresentation(self)
      }
      try await dependencies.player.schedule(audio.samples)
    }
    try checkStopped()
    if playbackStarted { try await dependencies.player.finished() }
  }
}
