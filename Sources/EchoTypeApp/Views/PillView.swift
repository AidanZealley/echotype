import SwiftUI

private let supportingTextOpacity = 0.65
private let indicatorOpacity = 0.4

/// The overlay pill: a growing transcript for dictation, or a compact reading status.
struct PillView: View {
  let pill: Pill

  var body: some View {
    let reading = pill.isReading
    VStack(alignment: .leading, spacing: 8) {
      if reading {
        readingLayout
      } else {
        statusRow
        Transcript(pill: pill).font(.system(size: 16))
        hint
      }
    }
    .padding(.horizontal, reading ? 16 : 18)
    .padding(.vertical, reading ? 10 : 12)
    .frame(width: reading ? 280 : 420)
    // Drawn on the glass, beneath the text, and cut off by the pill's outline.
    // Identity per session, so the glow's smoothing starts fresh rather than at the last
    // session's level.
    .background { LevelGlow(pill: pill).id(pill.startedAt).clipShape(.rect(cornerRadius: 22)) }
    .glassEffect(in: .rect(cornerRadius: 22))
    // Room for the glass's own edge and shadow, which the window does not draw.
    .padding(16)
  }

  private var statusRow: some View {
    HStack(spacing: 8) {
      LevelMeter(pill: pill)
      Text(pill.phase.name)
        .foregroundStyle(pill.phase == .selectInput ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary.opacity(supportingTextOpacity)))
      Spacer()
      Elapsed(pill: pill)
    }
    .font(.system(size: 11, weight: .medium))
  }

  private var hint: some View {
    HStack(spacing: 8) {
      if let device = pill.inputDevice {
        Image(systemName: device.isBluetooth ? "headphones" : "mic")
          .accessibilityHidden(true)
        deviceName(device.name)
      }
      Spacer(minLength: 8)
      switch pill.phase {
      case .listening, .paused, .starting, .selectInput:
        if pill.canCommit {
          Text(verbatim: "\(pill.dictationHotkey == .controlOptionD ? "⌃⌥D" : "⌥D") stop · esc cancel").fixedSize()
        } else {
          Text(verbatim: "esc cancel").fixedSize()
        }
      case .transcribing:
        Text(verbatim: "esc cancel").fixedSize()
      default: EmptyView()
      }
    }
    .font(.system(size: 11))
    .foregroundStyle(.primary.opacity(supportingTextOpacity))
  }

  private func deviceName(_ name: String) -> some View {
    ViewThatFits(in: .horizontal) {
      Text(verbatim: name).fixedSize(horizontal: true, vertical: false)
      Text(verbatim: name)
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: 160, alignment: .leading)
        .clipped()
        .mask {
          LinearGradient(
            stops: [.init(color: .white, location: 0.75), .init(color: .clear, location: 1)],
            startPoint: .leading, endPoint: .trailing)
        }
    }
    .frame(maxWidth: 160, alignment: .leading)
  }

  private var readingHint: String {
    "space \(pill.phase == .readingPaused ? "resume" : "pause") · esc stop"
  }

  private var readingTitle: String {
    if case .error = pill.phase { "Error reading" } else { pill.phase.name }
  }

  private var readingLayout: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        LevelMeter(pill: pill)
        Text(readingTitle).fontWeight(.medium)
        Spacer()
        Elapsed(pill: pill)
      }
      if case .error(let message) = pill.phase {
        Text(message)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text(verbatim: readingHint)
          .foregroundStyle(.primary.opacity(supportingTextOpacity))
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .font(.system(size: 11))
  }
}

/// The transcript grows to a height cap, then keeps the newest text visible at the bottom.
private struct Transcript: View {
  let pill: Pill
  private let maximumHeight: CGFloat = 183
  private let fadeHeight: CGFloat = 20
  @State private var overflows = false

  var body: some View {
    Group {
      if case .error(let message) = pill.phase {
        Text(message).foregroundStyle(.red).lineHeight(.multiple(factor: 1.5)).lineLimit(2)
      } else {
        TailLayout(maximumHeight: maximumHeight) {
          text.lineHeight(.multiple(factor: 1.5))
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: Bool.self) { $0.size.height > maximumHeight } action: {
              overflows = $0
            }
        }
        .clipped()
        // Fade only when text exceeds the cap; shorter transcripts stay fully opaque.
        .mask(alignment: .bottom) {
          if overflows {
            LinearGradient(
              stops: [
                .init(color: .white.opacity(0.1), location: 0),
                .init(color: .white, location: fadeHeight / maximumHeight),
                .init(color: .white, location: 1),
              ],
              startPoint: .top, endPoint: .bottom
            )
            .frame(height: maximumHeight)
          } else {
            Rectangle()
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var text: Text {
    if pill.settled.isEmpty && pill.provisional.isEmpty { return Text(verbatim: " ") }
    let gap = pill.settled.isEmpty || pill.provisional.isEmpty ? "" : " "
    return Text("\(pill.settled)\(gap)\(Text(pill.provisional).foregroundStyle(.primary.opacity(supportingTextOpacity)))")
  }
}

/// Measures one text view and anchors its bottom when it exceeds the visible height.
private struct TailLayout: Layout {
  let maximumHeight: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let content = subviews[0].sizeThatFits(.init(width: proposal.width, height: nil))
    return CGSize(width: content.width, height: min(content.height, maximumHeight))
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let height = subviews[0].sizeThatFits(.init(width: bounds.width, height: nil)).height
    subviews[0].place(
      at: CGPoint(x: bounds.minX, y: bounds.maxY), anchor: .bottomLeading,
      proposal: .init(width: bounds.width, height: height))
  }
}

extension Pill.Phase {
  /// One word for the phase, shown in the pill's top strip.
  fileprivate var name: String {
    switch self {
    case .starting: "Starting"
    case .selectInput: "Select an input"
    case .listening: "Listening"
    case .paused: "Paused"
    case .transcribing: "Transcribing"
    case .inserting: "Inserting"
    case .reading: "Reading"
    case .readingPaused: "Paused"
    case .error: "Error transcribing"
    }
  }
}

/// Small vertical bars that rise with the level, the microphone's or, while reading, the
/// playback's. Flat and faint while the microphone opens, dimmed while paused, a spinner while
/// transcribing.
private struct LevelMeter: View {
  let pill: Pill

  /// Each bar's share of the level, so the bars move together at different heights.
  private static let weights = [0.55, 0.85, 1, 0.7, 0.45]

  var body: some View {
    switch pill.phase {
    case .transcribing, .inserting:
      ProgressView()
        .controlSize(.mini)
        .tint(Color.primary.opacity(indicatorOpacity))
        .scaleEffect(1.15)
        .frame(height: 14)
    case .error:
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
        .frame(height: 14)
    case .starting, .selectInput, .listening, .paused, .reading, .readingPaused:
      HStack(alignment: .center, spacing: 1.5) {
        ForEach(Self.weights.indices, id: \.self) { index in
          Capsule()
            .frame(width: 2, height: 2.5 + 11.5 * min(1, pill.level * Self.weights[index]))
        }
      }
      .frame(height: 14)
      .foregroundStyle(Color.primary.opacity(
        pill.phase == .starting ? indicatorOpacity * 0.7 : indicatorOpacity))
      .opacity(pill.phase == .paused ? 0.35 : pill.phase == .readingPaused ? 0.8 : 1)
      .animation(.easeOut(duration: 0.12), value: pill.level)
    }
  }
}

/// Minutes and seconds since the session started, excluding reading pauses. Amber from four
/// minutes as dictation's five minute cap approaches, dimmed while paused.
private struct Elapsed: View {
  let pill: Pill

  var body: some View {
    TimelineView(.periodic(from: pill.startedAt, by: 1)) { context in
      let seconds = max(0, Int(
        (pill.pausedAt ?? context.date).timeIntervalSince(pill.startedAt) - pill.pausedDuration))
      Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
        .monospacedDigit()
        .foregroundStyle(seconds >= 4 * 60 ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary.opacity(supportingTextOpacity)))
    }
    .opacity(pill.phase == .paused ? 0.4 : pill.phase == .readingPaused ? 0.8 : 1)
  }
}

/// A blurred blue wave hanging from the pill's top edge, as deep as the level. Its ripples roll
/// while listening or reading, but it flattens to a faint line when the voice is quiet, so it
/// moves only in proportion to the voice, the user's or the one reading. Faint and grey while
/// the microphone opens, dimmed and still while paused, gone once the session is committed or
/// fails.
private struct LevelGlow: View {
  let pill: Pill
  /// The approximate height of the pill with one transcript line.
  private static let referenceHeight: CGFloat = 96

  /// Recent levels, oldest first, averaged so the wave swells rather than jitters.
  @State private var history = Array(repeating: 0.0, count: 4)

  var body: some View {
    TimelineView(.animation(paused: pill.phase != .listening && pill.phase != .selectInput && pill.phase != .reading)) { timeline in
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
    case .listening, .selectInput, .reading: 0.4
    case .paused, .readingPaused: 0.15
    case .transcribing, .inserting, .error: 0
    }
  }

  /// Keep the wave at its one-line depth as the transcript grows.
  private func depth(_ level: Double) -> CGFloat {
    Self.referenceHeight * (0.08 + 0.62 * level)
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
      path.addLine(to: CGPoint(x: x, y: depth(level * ripple)))
    }
    path.addLine(to: CGPoint(x: size.width, y: 0))
    path.closeSubpath()
    context.fill(
      path,
      with: .linearGradient(
        Gradient(colors: [colour, colour.opacity(0.6)]), startPoint: .zero,
        endPoint: CGPoint(x: 0, y: Self.referenceHeight)))
  }
}
