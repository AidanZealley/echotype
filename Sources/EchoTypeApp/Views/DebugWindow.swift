import AppKit
import EchoTypeCore
import SwiftUI

/// The debug window: the last dictation's commits, revision requests and the words the
/// inserted text lost or re-punctuated. It only renders `controller.lastTrace`, so a dictation
/// ending updates it without ordering it front or taking focus.
struct DebugWindow: View {
  static let id = "debug"
  let controller: DictationController

  var body: some View {
    if let trace = controller.lastTrace {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(trace.summary)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
          MarkedText(trace: trace)
          if !trace.revisions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              ForEach(Array(trace.revisions.enumerated()), id: \.offset) { _, revision in
                RevisionRow(revision: revision, startedAt: trace.startedAt)
              }
            }
          }
          Button("Copy as JSON") { copy(trace) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    } else {
      Text("No dictation yet")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func copy(_ trace: DictationTrace) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(trace) else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(String(decoding: data, as: UTF8.self), forType: .string)
  }
}

/// One revision request: when it started, live or final, its size, latency and result. Expands
/// to the window sent and the reply.
private struct RevisionRow: View {
  let revision: DictationTrace.Revision
  let startedAt: Date

  var body: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 8) {
        LabeledText(label: "Window", text: revision.window)
        LabeledText(label: "Reply", text: revision.reply ?? "No reply")
      }
      .padding(.vertical, 4)
    } label: {
      let words = revision.window.split(whereSeparator: \.isWhitespace).count
      Text(
        "\(seconds(revision.at.timeIntervalSince(startedAt)))  \(revision.isFinal ? "final" : "live")  "
          + "\(words) words  \(seconds(revision.duration))  \(revision.result.label)"
      )
      .monospacedDigit()
    }
  }
}

private struct LabeledText: View {
  let label: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Text(text).textSelection(.enabled)
    }
  }
}

/// The streamed words marked against the inserted text, as one selectable paragraph. SwiftUI's
/// `Text` has no hover for part of a paragraph, so this is a text view, which shows each run's
/// tooltip: the streamed form of a changed word, and the time since the previous commit at a
/// commit mark.
private struct MarkedText: NSViewRepresentable {
  let trace: DictationTrace

  func makeNSView(context: Context) -> NSTextView {
    // TextKit 1, because `sizeThatFits` measures with the layout manager.
    let view = NSTextView(usingTextLayoutManager: false)
    view.isEditable = false
    view.isSelectable = true
    view.drawsBackground = false
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    return view
  }

  func updateNSView(_ view: NSTextView, context: Context) {
    view.textStorage?.setAttributedString(text)
  }

  /// The paragraph's height at the proposed width.
  func sizeThatFits(_ proposal: ProposedViewSize, nsView view: NSTextView, context: Context)
    -> CGSize?
  {
    guard let width = proposal.width, let container = view.textContainer,
      let layout = view.layoutManager
    else { return nil }
    container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
    layout.ensureLayout(for: container)
    return CGSize(width: width, height: ceil(layout.usedRect(for: container).height))
  }

  private var text: NSAttributedString {
    let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let result = NSMutableAttributedString()
    func append(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) {
      result.append(NSAttributedString(
        string: string,
        attributes: [.font: font, .foregroundColor: NSColor.labelColor].merging(attributes) { $1 }))
    }
    let marks = trace.marks
    if marks.isEmpty { append("No words", [.foregroundColor: NSColor.secondaryLabelColor]) }
    for (index, mark) in marks.enumerated() {
      if index > 0 { append(" ") }
      if let commit = mark.commit {
        let gap = trace.commits[commit].at.timeIntervalSince(trace.commits[commit - 1].at)
        append("|", [.foregroundColor: NSColor.tertiaryLabelColor, .toolTip: seconds(gap)])
        append(" ")
      }
      switch mark.kind {
      case .kept:
        append(mark.word)
      case .deleted:
        append(mark.word, [
          .foregroundColor: NSColor.systemRed,
          .strikethroughStyle: NSUnderlineStyle.single.rawValue,
        ])
      case .changed(let inserted):
        append(inserted, [.foregroundColor: NSColor.systemOrange, .toolTip: mark.word])
      }
    }
    return result
  }
}

/// Seconds to one decimal place, for request times and commit gaps.
private func seconds(_ interval: TimeInterval) -> String {
  interval.formatted(.number.precision(.fractionLength(1))) + "s"
}

extension DictationTrace {
  /// For example `42s · 138 words · 9 commits · 11 requests: 7 accepted, 2 rejected, 1 failed`,
  /// followed by the outcome when nothing was inserted or the session failed.
  fileprivate var summary: String {
    let duration = Duration.seconds((endedAt ?? startedAt).timeIntervalSince(startedAt))
    var parts = [
      duration.formatted(.units(allowed: [.minutes, .seconds], width: .narrow)),
      "\(marks.count) words",
      "\(commits.count) commits",
      cleanUp ? requestCounts : "cleanup off",
    ]
    switch outcome {
    case .inserted: break
    case .nothing: parts.append("empty")
    case .cancelled: parts.append("cancelled")
    case .failed(let error): parts.append("failed: \(error)")
    }
    return parts.joined(separator: " · ")
  }

  /// The request count, then the count of each result kind that occurred, in `ResultKind` order.
  private var requestCounts: String {
    let counts = Dictionary(grouping: revisions, by: \.result.kind).mapValues(\.count)
    let breakdown = ResultKind.allCases.compactMap { kind in
      counts[kind].map { "\($0) \(kind.rawValue)" }
    }
    let total = "\(revisions.count) requests"
    return breakdown.isEmpty ? total : total + ": " + breakdown.joined(separator: ", ")
  }
}

/// A revision result without its detail, named as the window shows it.
private enum ResultKind: String, CaseIterable {
  case accepted, unchanged, rejected
  case replyRequestRemoved = "reply request removed"
  case empty, failed, cancelled, superseded
}

extension DictationTrace.Result {
  fileprivate var kind: ResultKind {
    switch self {
    case .accepted: .accepted
    case .unchanged: .unchanged
    case .rejected: .rejected
    case .replyRequestRemoved: .replyRequestRemoved
    case .empty: .empty
    case .failed: .failed
    case .cancelled: .cancelled
    case .superseded: .superseded
    }
  }

  /// The result with its detail, for a request row.
  fileprivate var label: String {
    switch self {
    case .rejected(let word): "rejected at \"\(word)\""
    case .failed(let error): "failed: \(error)"
    default: kind.rawValue
    }
  }
}
