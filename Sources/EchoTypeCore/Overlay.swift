import CoreGraphics
import Foundation

/// The overlay's two decisions that do not need AppKit to test: how loud the meter reads, and
/// which screen the pill goes on.
public enum Overlay {
  /// Maps a buffer's RMS amplitude, with full scale at 1, onto the level meter's 0 to 1.
  ///
  /// Linear in decibels from -50 dBFS, about a quiet room through a laptop microphone, to
  /// -20 dBFS, loud speech close up. Ordinary speech lands around the middle and room noise
  /// barely lifts the meter off zero.
  public static func level(rms: Float) -> Double {
    let decibels = 20 * log10(Double(rms))
    return min(max((decibels + 50) / 30, 0), 1)
  }

  /// The index of the screen containing the centre of a window, or nil if none does.
  ///
  /// `window` is in Accessibility coordinates: origin at the top left of the primary screen, y
  /// growing downwards. `screens` are `NSScreen` frames: origin at the bottom left of the
  /// primary screen, y growing upwards. `screens[0]` must be the primary screen, as
  /// `NSScreen.screens` guarantees.
  public static func screenIndex(holding window: CGRect, among screens: [CGRect]) -> Int? {
    guard let primary = screens.first else { return nil }
    let centre = CGPoint(x: window.midX, y: primary.height - window.midY)
    return screens.firstIndex { $0.contains(centre) }
  }
}
