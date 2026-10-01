import AppKit
import EchoTypeCore
@testable import EchoTypeApp
import Testing

@Suite(.timeLimit(.minutes(1))) @MainActor struct ClipboardTests {
  @MainActor final class Board {
    var count = 0
    var items: [NSPasteboardItem] = []
    var text = "original"
    var events: [(CGKeyCode, CGEventFlags)] = []
    var writes: [String] = []
    var restores = 0
    var onWait: (Duration) async -> Void = { _ in }
    var onSave: () -> Void = {}

    init(empty: Bool = false) {
      if !empty {
        let item = NSPasteboardItem()
        item.setString("original", forType: .string)
        item.setData(Data([1, 2]), forType: .html)
        items = [item]
      }
    }

    var access: Clipboard.Access {
      .init(count: { self.count }, save: { self.onSave(); return self.items },
        restore: { self.restores += 1; self.items = $0; self.count += 1 },
        read: { self.text },
        write: { self.text = $0; self.writes.append($0); self.count += 1 },
        post: { key, flags in
          self.events.append((key, flags))
          if key == 8 { self.text = "selection"; self.count += 1 }
        }, wait: { await self.onWait($0) })
    }
  }

  @Test func destinationLossAndCancellationSkipEveryWrite() async {
    for check in [DestinationVerification.changed, .unavailable] {
      let board = Board()
      let result = await Clipboard(access: board.access).insert("text", destination: nil, sends: true,
        verify: { _ in check }, cancelled: { false })
      #expect(result.insertion == .skipped(check == .changed ? .changed : .unavailable))
      #expect(board.writes.isEmpty && board.events.isEmpty)
    }
    let board = Board()
    var cancelled = false
    board.onSave = { cancelled = true }
    let result = await Clipboard(access: board.access).insert("text", destination: nil, sends: true,
      verify: { _ in .matching }, cancelled: { cancelled })
    #expect(result.insertion == .cancelled)
    #expect(board.writes.isEmpty && board.events.isEmpty)
  }

  @Test func returnRevalidationNeverRepeatsPaste() async {
    let board = Board()
    var check = DestinationVerification.matching
    board.onWait = { _ in check = .changed }
    let result = await Clipboard(access: board.access).insert("text", destination: nil, sends: true,
      verify: { _ in check }, cancelled: { false })
    #expect(result == .init(insertion: .attempted, sending: .skipped(.changed)))
    #expect(board.events.map(\.0) == [9])
    #expect(board.events.first?.1 == .maskCommand)
    #expect(board.restores == 1)
    #expect(board.items.first?.data(forType: .html) == Data([1, 2]))
  }

  @Test func transactionIgnoresCancellationAfterWriteAndPreservesExternalWriter() async {
    let board = Board()
    var cancelled = false
    board.onWait = { _ in cancelled = true; board.count += 1 }
    let result = await Clipboard(access: board.access).insert("text", destination: nil, sends: true,
      verify: { _ in .matching }, cancelled: { cancelled })
    #expect(result == .init(insertion: .attempted, sending: .attempted))
    #expect(board.events.map(\.0) == [9, 36])
    #expect(board.events.last?.1 == [])
    #expect(board.restores == 0)
  }

  @Test func externalWriteDuringFinalVerificationInvalidatesSavedSnapshot() async {
    let board = Board()
    var verifications = 0
    let result = await Clipboard(access: board.access).insert("text", destination: nil, sends: false,
      verify: { _ in
        verifications += 1
        if verifications == 1 {
          board.text = "external"
          board.count += 1
        }
        return .matching
      }, cancelled: { false })
    #expect(result == .init(insertion: .attempted, sending: .notRequested))
    #expect(board.writes == ["text"])
    #expect(board.events.map(\.0) == [9])
    #expect(board.restores == 0)
    #expect(board.text == "text")
  }

  @Test func emptyOriginalLeavesTranscriptAndEmptyResultDoesNothing() async {
    let board = Board(empty: true)
    let clipboard = Clipboard(access: board.access)
    _ = await clipboard.insert("text", destination: nil, sends: false,
      verify: { _ in .matching }, cancelled: { false })
    _ = await clipboard.insert("", destination: nil, sends: true,
      verify: { _ in .matching }, cancelled: { false })
    #expect(board.writes == ["text"])
    #expect(board.restores == 0)
    #expect(board.events.map(\.0) == [9])
  }

  @Test func stoppedCopyFinishesBeforeInsertionAndExplicitCopy() async {
    let board = Board()
    let (waiting, signal) = AsyncStream<Void>.makeStream()
    let (release, resume) = AsyncStream<Void>.makeStream()
    defer { signal.finish(); resume.finish() }
    var first = true
    board.onWait = { _ in
      if first {
        first = false
        signal.yield(())
        for await _ in release { break }
      }
    }
    let clipboard = Clipboard(access: board.access)
    var cancelled = false
    let copy = Task { await clipboard.copySelection(cancelled: { cancelled }) }
    for await _ in waiting { break }
    cancelled = true
    let insert = Task.immediate {
      await clipboard.insert("dictation", destination: nil, sends: false,
        verify: { _ in .matching }, cancelled: { false })
    }
    let explicit = Task.immediate { await clipboard.copy("recovery") }
    #expect(board.writes.isEmpty)
    resume.yield(())
    #expect(await copy.value == "selection")
    #expect(await insert.value.insertion == .attempted)
    await explicit.value
    await clipboard.waitForCleanup()
    #expect(board.events.map(\.0) == [8, 9])
    #expect(board.writes == ["dictation", "recovery"])
    #expect(board.restores == 2)
    #expect(board.text == "recovery")
  }

  @Test func secondWriteDuringCopyInvalidatesRestoration() async {
    let board = Board()
    var waits = 0
    board.onWait = { _ in
      waits += 1
      if waits == 2 { board.text = "external"; board.count += 1 }
    }
    _ = await Clipboard(access: board.access).copySelection(cancelled: { false })
    #expect(board.restores == 0)
    #expect(board.text == "external")
  }
}
