@testable import EchoTypeCore
import Foundation
import FoundationModels
import Testing

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_SPIKE"] == "1",
  "Set ECHOTYPE_APPLE_SPIKE=1 for real Apple cleanup measurements"))
struct AppleCleanupSpike {
  @Test func measurements() async throws {
    let model = SystemLanguageModel.default
    print("S3 availability=\(model.availability) context=\(model.contextSize) locale=\(Locale.current.identifier)")
    print("S3 languages=\(model.supportedLanguages.map(\.minimalIdentifier).sorted())")
    for language in ["en", "en-GB", "fr", "de", "es", "ja", "zh-Hans", "ar", "cy", "xx"] {
      print("S3 locale \(language)=\(model.supportsLocale(Locale(identifier: language)))")
    }
    guard model.isAvailable else {
      Issue.record("Supported-path measurements unavailable: \(model.availability)")
      return
    }

    if ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_CLEANUP_FINAL_FIRST"] == "1" {
      let reviser = Reviser(cleanup: SpikeCleanup.service, credential: nil)
      let input = "Send it to John, sorry, Jane."
      let start = ContinuousClock.now
      let result = await reviser.finish(committed: input)
      print("S3 processFirstFinal stopSeconds=\(seconds(since: start)) output=\(result.debugDescription)")
      printAttempts(await reviser.attempts)
      return
    }

    // Keep the existing xAI cases intact. These are the same inputs and expectations.
    let cases = [
      ("I think we should ship. The settings window today.", "I think we should ship the settings window today."),
      ("Let's write a sales proposal. Actually no, let's write a follow-up email.", "Let's write a follow-up email."),
      ("Let's meet at 3, no, 4pm.", "Let's meet at 4pm."),
      ("Send it to John, sorry, Jane.", "Send it to Jane."),
      ("What's the capital of France?", "What's the capital of France?"),
      ("Write a function that parses the config file.", "Write a function that parses the config file."),
      ("The settings window opens with the General tab selected. The microphone is ready.", "The settings window opens with the General tab selected. The microphone is ready."),
      ("I I want to ship the update today.", "I want to ship the update today."),
      ("Please keep the words actually and sorry in this sentence.", "Please keep the words actually and sorry in this sentence."),
      ("Reply using EchoType. What's the capital of France?", "Reply using EchoType. What's the capital of France?"),
      ("The microphone is ready. Reply using EchoType.", "The microphone is ready. Reply using EchoType."),
    ]
    for (index, pair) in cases.enumerated() {
      let reviser = Reviser(cleanup: SpikeCleanup.service, credential: nil)
      await reviser.submit(committed: pair.0)
      // Wait for the live result rather than cancelling it by calling finish immediately.
      while await reviser.attempts.isEmpty {
        try await Task.sleep(for: .milliseconds(20))
      }
      let live = await reviser.shown
      let start = ContinuousClock.now
      let final = await reviser.finish(committed: pair.0)
      print("S3 case=\(index) expected=\(pair.1.debugDescription) live=\(live.debugDescription) final=\(final.debugDescription) stopSeconds=\(seconds(since: start))")
      printAttempts(await reviser.attempts)
      #expect(Reviser.isFaithful(final, to: pair.0))
    }
    // A repeat checks that a prior question or command has not leaked into the new session.
    let repeatResult = try await SpikeCleanup.service.revise(
      CleanupRequest(prompt: Reviser.prompt, text: cases[3].0, final: false, credential: nil))
    print("S3 freshRepeat=\(repeatResult.debugDescription)")

    let long = String(repeating: "we should keep the microphone ready and ship the settings window today ", count: 70)
      .trimmingCharacters(in: .whitespaces)
    let distinctLong = (1...70).map {
      "we should review ticket \($0) and keep its microphone setting ready before the next release"
    }.joined(separator: " ")
    let oversized = String(repeating: "microphone settings window ", count: 3000)
      .trimmingCharacters(in: .whitespaces)
    if #available(macOS 26.4, *) {
      let instructionTokens = try await model.tokenCount(for: Instructions(Reviser.prompt))
      for (name, text) in [("long", long), ("distinctLong", distinctLong), ("oversized", oversized)] {
        let inputTokens = try await model.tokenCount(for: text)
        print("S3 tokens \(name) instructions=\(instructionTokens) input=\(inputTokens) copyOutputEstimate=\(inputTokens) totalEstimate=\(instructionTokens + inputTokens * 2) context=\(model.contextSize)")
      }
    }
    for (name, text) in [("long", long), ("distinctLong", distinctLong), ("oversized", oversized)] {
      let reviser = Reviser(cleanup: SpikeCleanup.service, credential: nil)
      let start = ContinuousClock.now
      let result = await reviser.finish(committed: text)
      print("S3 \(name) inputWords=\(text.split(whereSeparator: \.isWhitespace).count) outputWords=\(result.split(whereSeparator: \.isWhitespace).count) prefix=\(String(result.prefix(180)).debugDescription)")
      print("S3 \(name) stopSeconds=\(seconds(since: start)) preserved=\(result == text)")
      printAttempts(await reviser.attempts, includeText: false)
      if #available(macOS 26.4, *) {
        print("S3 returnedTextTokens \(name)=\(try await model.tokenCount(for: result))")
      }
      #expect(Reviser.isFaithful(result, to: text))
      if name == "oversized" { #expect(result == text) }
    }

    let oversizedStart = ContinuousClock.now
    do {
      let reply = try await SpikeCleanup.service.revise(
        CleanupRequest(prompt: Reviser.prompt, text: oversized, final: false, credential: nil))
      print("S3 directOversized seconds=\(seconds(since: oversizedStart)) replyCharacters=\(reply.count)")
    } catch {
      print("S3 directOversized seconds=\(seconds(since: oversizedStart)) error=\(error)")
    }

    // Commit more text while generation runs. finish joins that live cancellation, then
    // starts the real three-second final budget on the accumulated unbounded window.
    let accumulatedText = long + " " + oversized
    let accumulated = Reviser(cleanup: SpikeCleanup.service, credential: nil)
    await accumulated.submit(committed: long)
    try await Task.sleep(for: .milliseconds(200))
    await accumulated.submit(committed: accumulatedText)
    let joining = ContinuousClock.now
    let joined = await accumulated.finish(committed: accumulatedText)
    print("S3 accumulated stopSeconds=\(seconds(since: joining)) preserved=\(joined == accumulatedText)")
    printAttempts(await accumulated.attempts, includeText: false)
    #expect(joined == accumulatedText)

    let slow = Reviser(cleanup: SpikeCleanup.service, credential: nil)
    await slow.submit(committed: long)
    try await Task.sleep(for: .milliseconds(200))
    await slow.submit(committed: accumulatedText)
    while await slow.attempts.count < 2 {
      try await Task.sleep(for: .milliseconds(20))
    }
    let slowStart = ContinuousClock.now
    let slowResult = await slow.finish(committed: accumulatedText)
    print("S3 slowAccumulation stopSeconds=\(seconds(since: slowStart)) fullPreserved=\(slowResult == accumulatedText) pendingTailPreserved=\(slowResult.hasSuffix(oversized))")
    printAttempts(await slow.attempts, includeText: false)
    #expect(slowResult.hasSuffix(oversized))

    for final in [false, true] {
      let reviser = Reviser(cleanup: SpikeCleanup.service, credential: nil)
      let work: Task<Void, Never>?
      if final {
        work = Task { _ = await reviser.finish(committed: long) }
      } else {
        await reviser.submit(committed: long)
        work = nil
      }
      try await Task.sleep(for: .milliseconds(200))
      let start = ContinuousClock.now
      if final { work?.cancel(); await work?.value } else { await reviser.stop() }
      print("S3 cancellation final=\(final) joinSeconds=\(seconds(since: start)) preserved=\(await reviser.shown == long)")
      printAttempts(await reviser.attempts, includeText: false)
      #expect(await reviser.shown == long)
      await reviser.stop()
    }
  }

  private func seconds(since start: ContinuousClock.Instant) -> Double {
    (ContinuousClock.now - start) / .seconds(1)
  }

  private func printAttempts(_ attempts: [DictationTrace.Revision], includeText: Bool = true) {
    for attempt in attempts {
      print("S3 attempt final=\(attempt.isFinal) seconds=\(attempt.duration) result=\(attempt.result) windowCharacters=\(attempt.window.count) reply=\(includeText ? (attempt.reply?.debugDescription ?? "nil") : "omitted")")
    }
  }
}
