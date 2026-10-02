import AVFoundation
import EchoTypeCore
import Foundation

/// A deliberately test-only bounded alternative to pausing AVSpeechSynthesizer's callbacks.
/// Only one short utterance is submitted. The next starts after its PCM has been pulled.
@MainActor
final class AppleSpikeSpeechStream: NSObject, SpeechStream, AVSpeechSynthesizerDelegate {
  static let segmentCharacters = 250
  private let synthesizer = AVSpeechSynthesizer()
  private let voice: AVSpeechSynthesisVoice
  private let rate: Float
  private let segmentLimit: Int
  private var remaining: String
  private var audio: [Float] = []
  private var offset = 0
  private var utteranceFinished = true
  private var cancelled = false
  private var failure: (any Error)?
  private var waiter: CheckedContinuation<SpeechAudio?, any Error>?
  private(set) var sampleRate = 0
  private(set) var peakSamples = 0
  private(set) var peakRetainedSamples = 0
  private(set) var submittedScalars = 0
  var hasPendingPull: Bool { waiter != nil }
  var isSynthesizing: Bool { synthesizer.isSpeaking }
  private(set) var totalSamples = 0
  private(set) var callbacks = 0
  private(set) var segments = 0
  private(set) var segmentSamples: [Int] = []
  private(set) var zeroFrameSampleOffsets: [Int] = []
  private(set) var segmentScalars: [Int] = []
  private(set) var submittedRates: [Float] = []
  private var currentSegmentSamples = 0
  private(set) var firstBufferSeconds: Double?
  private(set) var formats: Set<String> = []
  private(set) var maximumCallbackFrames = 0
  private(set) var callbackOnMain = false
  private let started = ProcessInfo.processInfo.systemUptime

  init(text: String, voice: AVSpeechSynthesisVoice, rate: Float, segmentLimit: Int = segmentCharacters) {
    precondition(segmentLimit > 0)
    self.segmentLimit = segmentLimit
    remaining = text
    self.voice = voice
    self.rate = rate
    super.init()
    synthesizer.delegate = self
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    // A zero-frame write callback can occur between parts of one utterance on this SDK.
    // Finish only on the delegate event, after previously queued PCM callbacks are copied.
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.cancelled else { return }
      self.segmentSamples.append(self.currentSegmentSamples)
      self.utteranceFinished = true
      self.deliver()
    }
  }

  func next() async throws -> SpeechAudio? {
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        precondition(waiter == nil, "SpeechStream has one consumer")
        waiter = continuation
        deliver()
      }
    } onCancel: { self.cancel() }
  }

  nonisolated func cancel() {
    Task { @MainActor in
      guard !self.cancelled else { return }
      self.cancelled = true
      self.remaining = ""
      self.audio.removeAll()
      self.offset = 0
      self.synthesizer.stopSpeaking(at: .immediate)
      self.deliver()
    }
  }

  private func deliver() {
    guard let waiter else { return }
    if cancelled || failure != nil {
      self.waiter = nil
      waiter.resume(throwing: failure ?? CancellationError())
    } else if offset < audio.count {
      let end = min(offset + sampleRate / 10, audio.count)
      let chunk = SpeechAudio(sampleRate: sampleRate, samples: Array(audio[offset..<end]))
      offset = end
      self.waiter = nil
      waiter.resume(returning: chunk)
    } else if utteranceFinished {
      audio.removeAll(keepingCapacity: true)
      offset = 0
      if remaining.isEmpty {
        self.waiter = nil
        waiter.resume(returning: nil)
      } else { startSegment() }
    }
  }

  private func startSegment() {
    let scalars = remaining.unicodeScalars
    var end = scalars.index(scalars.startIndex, offsetBy: min(segmentLimit, scalars.count))
    // Keep complete sentences together when they fit the hard bound. A sentence longer
    // than the bound still needs a word break so a paused reader cannot buffer endlessly.
    if end != scalars.endIndex {
      let hardEnd = end
      var sentenceEnd: String.Index?
      remaining.enumerateSubstrings(in: remaining.startIndex..<remaining.endIndex, options: .bySentences) { _, _, range, stop in
        if range.upperBound <= hardEnd { sentenceEnd = range.upperBound }
        else { stop = true }
      }
      if let sentenceEnd { end = sentenceEnd }
      else if let space = scalars[..<end].lastIndex(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) {
        end = scalars.index(after: space)
      }
    }
    let segment = String(scalars[..<end])
    submittedScalars += segment.unicodeScalars.count
    let utterance = AVSpeechUtterance(string: segment)
    remaining = String(scalars[end...])
    utterance.voice = voice
    utterance.rate = rate
    submittedRates.append(utterance.rate)
    segmentScalars.append(segment.unicodeScalars.count)
    currentSegmentSamples = 0
    utteranceFinished = false
    segments += 1
    synthesizer.write(utterance) { [weak self] buffer in
      guard let pcm = buffer as? AVAudioPCMBuffer else { return }
      let frames = Int(pcm.frameLength)
      let frequency = Int(pcm.format.sampleRate)
      let channels = Int(pcm.format.channelCount)
      let format = "channels=\(channels) sampleRate=\(frequency) commonFormat=\(pcm.format.commonFormat.rawValue) interleaved=\(pcm.format.isInterleaved)"
      let main = Thread.isMainThread
      var samples = [Float](repeating: 0, count: frames)
      var unsupported = false
      if frames > 0 {
        if let data = pcm.floatChannelData {
          for frame in 0..<frames {
            for channel in 0..<channels {
              let value = pcm.format.isInterleaved ? data[0][frame * channels + channel] : data[channel][frame]
              samples[frame] += value / Float(channels)
            }
          }
        } else { unsupported = true }
      }
      let converted = samples
      let failed = unsupported
      // FIFO delivery preserves callback ordering without blocking Apple's callback thread.
      DispatchQueue.main.async { [weak self] in
        guard let self, !self.cancelled else { return }
        self.callbacks += 1
        self.callbackOnMain = self.callbackOnMain || main
        self.formats.insert(format)
        self.maximumCallbackFrames = max(self.maximumCallbackFrames, frames)
        if failed { self.failure = ProviderError.failed("Unsupported synthesis PCM format") }
        if frames == 0 {
          self.zeroFrameSampleOffsets.append(self.totalSamples)
        }
        else {
          if self.sampleRate == 0 { self.sampleRate = frequency }
          if self.sampleRate != frequency { self.failure = ProviderError.failed("Synthesis rate changed") }
          if self.firstBufferSeconds == nil { self.firstBufferSeconds = ProcessInfo.processInfo.systemUptime - self.started }
          self.audio.append(contentsOf: converted)
          self.totalSamples += frames
          self.currentSegmentSamples += frames
          self.peakSamples = max(self.peakSamples, self.audio.count - self.offset)
          self.peakRetainedSamples = max(self.peakRetainedSamples, self.audio.count)
        }
        self.deliver()
      }
    }
  }
}
