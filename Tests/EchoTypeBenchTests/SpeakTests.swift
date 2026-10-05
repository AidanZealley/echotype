import EchoTypeCore
import Testing

@testable import EchoTypeBench

@Test("The player holds 500 ms: a chunk waits for room, and a late chunk is a gap")
func playerQueueAndGaps() {
  var player = PlayerModel()
  // The first chunk starts playback at once. The next two fit beside it, then a 0.1 s chunk
  // pulled at once has to wait until the queue has drained to 0.4 s.
  #expect(player.schedule(seconds: 0.1, pulledAt: 0) == 0)
  for _ in 0..<4 { _ = player.schedule(seconds: 0.1, pulledAt: 0) }
  #expect(abs(player.schedule(seconds: 0.1, pulledAt: 0) - 0.1) < 1e-9)
  #expect(player.gaps == 0)

  // Six chunks queued run out at 0.6 s; the next arrives at 0.8 s.
  _ = player.schedule(seconds: 0.1, pulledAt: 0.8)
  #expect(player.gaps == 1)
  #expect(abs(player.gapSeconds - 0.2) < 1e-9)
}

@Test("Pausing stretches the queue instead of leaving a gap, unless it had already run dry")
func pauseIsNotAGap() {
  var player = PlayerModel()
  _ = player.schedule(seconds: 0.1, pulledAt: 0)
  player.pause(at: 0.05, for: 5)
  _ = player.schedule(seconds: 0.1, pulledAt: 5.05)
  #expect(player.gaps == 0)

  player.pause(at: 5.5, for: 5)  // The queue ran out at 5.2.
  #expect(player.gaps == 1)
  #expect(abs(player.gapSeconds - 0.3) < 1e-9)
}

@Test("The speech contract flags a long chunk, a changed rate and an empty stream")
func speechContract() {
  var check = SpeechContractCheck()
  check.observe(SpeechAudio(sampleRate: 24_000, samples: Array(repeating: 0, count: 2_400)))
  #expect(check.violations.isEmpty)
  check.observe(SpeechAudio(sampleRate: 16_000, samples: Array(repeating: 0, count: 1_600)))
  #expect(check.violations.count == 1)
  check.observe(SpeechAudio(sampleRate: 16_000, samples: Array(repeating: 0, count: 1_700)))
  #expect(check.violations.count == 2)

  var empty = SpeechContractCheck()
  empty.streamEnded(spoken: "Hello")
  empty.cancellationTook(seconds: 1.5)
  #expect(empty.violations.count == 2)
}

@Test("A listening page labels every run's reading once per passage and skips what no run read")
func listeningPageMapsEveryRunOnce() {
  let passages = [
    Reading(id: "one", text: "One.", checks: [], tags: []), Reading(id: "two", text: "Two.", checks: [], tags: []),
    Reading(id: "three", text: "Three.", checks: [], tags: []),
  ]
  let runs = ["a", "b", "c"].map { ListeningRun(id: $0, provider: "apple", voice: $0) }
  var generator = SystemRandomNumberGenerator()
  let page = listeningPage(passages, runs: runs, hasAudio: { run, id in id != "three" && !(run.id == "c" && id == "two") }, using: &generator)

  #expect(page.map(\.id) == ["one", "two"])
  #expect(Set(page[0].readings.map(\.run.id)) == ["a", "b", "c"])
  #expect(page[0].readings.map(\.label) == ["A", "B", "C"])
  #expect(Set(page[1].readings.map(\.run.id)) == ["a", "b"])
  #expect(page[1].readings.map(\.audio) == ["two-A.wav", "two-B.wav"])
}
