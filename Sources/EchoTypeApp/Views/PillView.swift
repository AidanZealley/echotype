import SwiftUI

/// The overlay pill. Renders one `Pill` and nothing else: a slim strip with the level meter,
/// the phase and elapsed time above a larger transcript, the hint at the foot, and the level
/// glowing inside the pill from its top edge.
struct PillView: View {
  let pill: Pill

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        LevelMeter(pill: pill)
        Text(pill.phase.name).foregroundStyle(.secondary)
        Spacer()
        Elapsed(pill: pill)
      }
      .font(.system(size: 11, weight: .medium))
      Transcript(pill: pill).font(.system(size: 16))
      Text(verbatim: "⌥D stop · esc cancel")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .frame(width: 420)
    // Drawn on the glass, beneath the text, and cut off by the pill's outline.
    // Identity per session, so the glow's smoothing starts fresh rather than at the last
    // session's level.
    .background { LevelGlow(pill: pill).id(pill.startedAt).clipShape(.rect(cornerRadius: 22)) }
    .glassEffect(in: .rect(cornerRadius: 22))
    // Room for the glass's own edge and shadow, which the window does not draw.
    .padding(16)
  }
}

extension Pill.Phase {
  /// One word for the phase, shown in the pill's top strip.
  fileprivate var name: String {
    switch self {
    case .starting: "Starting"
    case .listening: "Listening"
    case .paused: "Paused"
    case .transcribing: "Transcribing"
    case .error: "Error"
    }
  }
}

/// Small vertical bars that rise with the input level. Flat and faint while the microphone
/// opens, dimmed while paused, a spinner while transcribing.
private struct LevelMeter: View {
  let pill: Pill

  /// Each bar's share of the level, so the bars move together at different heights.
  private static let weights = [0.55, 0.85, 1, 0.7, 0.45]

  var body: some View {
    switch pill.phase {
    case .transcribing:
      ProgressView().controlSize(.mini).frame(width: 18, height: 14)
    case .error:
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
        .frame(width: 18, height: 14)
    case .starting, .listening, .paused:
      HStack(alignment: .center, spacing: 1.5) {
        ForEach(Self.weights.indices, id: \.self) { index in
          Capsule()
            .frame(width: 2, height: 2.5 + 11.5 * min(1, pill.level * Self.weights[index]))
        }
      }
      .frame(width: 18, height: 14)
      .foregroundStyle(pill.phase == .starting ? .tertiary : .primary)
      .opacity(pill.phase == .paused ? 0.35 : 1)
      .animation(.easeOut(duration: 0.12), value: pill.level)
    }
  }
}

/// Settled text solid and provisional text dimmed, at most two lines, losing its beginning
/// rather than the words just spoken. An error replaces it in red, also at most two lines but
/// losing its end, because its start says what failed. With no text yet it keeps one empty
/// line, since the strip above already names the phase.
private struct Transcript: View {
  let pill: Pill

  var body: some View {
    Group {
      if case .error(let message) = pill.phase {
        Text(message).foregroundStyle(.red).lineLimit(2)
      } else {
        TailLayout {
          text.fixedSize(horizontal: false, vertical: true)
          Text(verbatim: "A\nA").hidden()
        }
        .clipped()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var text: some View {
    if pill.settled.isEmpty && pill.provisional.isEmpty {
      Text(verbatim: " ")
    } else {
      let gap = pill.settled.isEmpty || pill.provisional.isEmpty ? "" : " "
      Text("\(pill.settled)\(gap)\(Text(pill.provisional).foregroundStyle(.secondary))")
    }
  }
}

/// Shows the bottom of its first subview, no taller than its second, so overflow falls off the
/// top. The second subview only sets that height; hide it. Clip the result.
private struct TailLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let unbounded = ProposedViewSize(width: proposal.width, height: nil)
    let content = subviews[0].sizeThatFits(unbounded)
    let limit = subviews[1].sizeThatFits(unbounded)
    return CGSize(width: content.width, height: min(content.height, limit.height))
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let unbounded = ProposedViewSize(width: bounds.width, height: nil)
    let height = subviews[0].sizeThatFits(unbounded).height
    subviews[0].place(
      at: CGPoint(x: bounds.minX, y: bounds.maxY), anchor: .bottomLeading,
      proposal: ProposedViewSize(width: bounds.width, height: height))
    subviews[1].place(at: bounds.origin, proposal: .zero)
  }
}

/// Minutes and seconds since the session started, amber from eight minutes as the ten minute
/// cap approaches, dimmed while paused.
private struct Elapsed: View {
  let pill: Pill

  var body: some View {
    TimelineView(.periodic(from: pill.startedAt, by: 1)) { context in
      let seconds = max(0, Int(context.date.timeIntervalSince(pill.startedAt)))
      Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
        .monospacedDigit()
        .foregroundStyle(seconds >= 8 * 60 ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
    }
    .opacity(pill.phase == .paused ? 0.4 : 1)
  }
}

/// A blurred blue wave hanging from the pill's top edge, as deep as the input level. Its
/// ripples roll while listening, but it flattens to a faint line when the voice is quiet, so
/// it moves only in proportion to the voice. Faint and grey while the microphone opens,
/// dimmed and still while paused, gone once the session is committed or fails.
private struct LevelGlow: View {
  let pill: Pill

  /// Recent levels, oldest first, averaged so the wave swells rather than jitters.
  @State private var history = Array(repeating: 0.0, count: 4)

  var body: some View {
    TimelineView(.animation(paused: pill.phase != .listening)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      Canvas { context, size in
        let colour: Color = pill.phase == .starting ? .gray : .blue
        drawWave(in: &context, size: size, colour: colour, time: time)
      }
    }
    .blur(radius: 12)
    .opacity(opacity)
    .onChange(of: pill.level) { _, level in
      history.removeFirst()
      history.append(min(1, max(0, level)))
    }
  }

  private var opacity: Double {
    switch pill.phase {
    case .starting: 0.25
    case .listening: 0.4
    case .paused: 0.15
    case .transcribing, .error: 0
    }
  }

  /// How far the glow reaches into the pill at full level, and at silence, so a live session
  /// always shows a faint line.
  private func depth(_ level: Double, in size: CGSize) -> CGFloat {
    size.height * (0.08 + 0.62 * level)
  }

  private func drawWave(
    in context: inout GraphicsContext, size: CGSize, colour: Color, time: Double
  ) {
    let level = history.reduce(0, +) / Double(history.count)
    var path = Path()
    path.move(to: .zero)
    for x in stride(from: 0, through: size.width, by: 4) {
      let phase = x / size.width * .pi * 2
      let ripple =
        0.5 + 0.3 * sin(phase * 1.5 + time * 1.3) + 0.2 * sin(phase * 2.7 - time * 0.9)
      path.addLine(to: CGPoint(x: x, y: depth(level * ripple, in: size)))
    }
    path.addLine(to: CGPoint(x: size.width, y: 0))
    path.closeSubpath()
    context.fill(
      path,
      with: .linearGradient(
        Gradient(colors: [colour, colour.opacity(0.6)]), startPoint: .zero,
        endPoint: CGPoint(x: 0, y: size.height)))
  }
}
