import EchoTypeCore
import Foundation

/// Runs one reading: copies the selection, reads the key, caps the text, then streams the
/// `POST /v1/tts` response into a `SpeechPlayer` as it arrives (decision 0018). It starts when
/// created. `stop()` cancels the request and cuts the audio off at once.
@MainActor final class Reader {
  enum Failure: Error {
    case nothingSelected
    case noAPIKey
    /// The audio output could not start.
    case playback(any Error)
  }

  /// About 100ms of 16-bit mono audio, the most gathered before it is scheduled.
  private static let bufferBytes = Speech.sampleRate / 10 * 2

  private let player: SpeechPlayer
  private let inserter: Inserter
  private var task: Task<Void, any Error>?

  /// `onStart` runs once the text is known, just before it is fetched, with whether it was cut
  /// to `Speech.maximumCharacters`. `onLevel` receives the level of the audio as it plays.
  init(
    settings: Settings, inserter: Inserter,
    onStart: @escaping @MainActor (_ wasCut: Bool) -> Void,
    onLevel: @escaping @MainActor (Double) -> Void
  ) {
    self.inserter = inserter
    player = SpeechPlayer(onLevel: onLevel)
    task = Task { try await read(settings, onStart: onStart) }
  }

  /// Returns when the audio has finished or the reading was stopped. Throws why it failed
  /// otherwise.
  func finished() async throws {
    guard let task else { return }
    do {
      try await task.value
    } catch where task.isCancelled {
      // Stopped: the cancelled request's error is not a failure.
    }
  }

  func stop() {
    task?.cancel()
    player.stop()
  }

  private func read(_ settings: Settings, onStart: (Bool) -> Void) async throws {
    try await inserter.waitForRestore()
    let selection = await Pasteboard.copySelection()
    try Task.checkCancellation()
    guard let selection else { throw Failure.nothingSelected }
    let apiKey = await Task.detached { Keychain.apiKey() }.value
    guard let apiKey else { throw Failure.noAPIKey }
    try Task.checkCancellation()
    let (text, wasCut) = Speech.capped(selection)
    onStart(wasCut)

    let request = Speech.request(text: text, settings: settings, apiKey: apiKey)
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else { throw STTError(httpStatus: status) }
    // A stop during the request may land after its response arrived.
    try Task.checkCancellation()

    do { try player.start() } catch { throw Failure.playback(error) }
    defer { player.stop() }
    var decoder = PCMDecoder()
    var chunk = Data(capacity: Self.bufferBytes)
    for try await byte in bytes {
      chunk.append(byte)
      guard chunk.count == Self.bufferBytes else { continue }
      player.schedule(decoder.samples(from: chunk))
      chunk.removeAll(keepingCapacity: true)
    }
    player.schedule(decoder.samples(from: chunk))
    await player.finished()
  }
}
