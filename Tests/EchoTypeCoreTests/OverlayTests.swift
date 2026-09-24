import CoreGraphics
import EchoTypeCore
import Testing

@Test("Room noise barely moves the meter and ordinary speech moves it visibly")
func levelSeparatesSpeechFromNoise() {
  #expect(Overlay.level(rms: 0) == 0)
  #expect(Overlay.level(rms: 0.003) < 0.05)  // about -50 dBFS
  #expect(Overlay.level(rms: 0.03) > 0.5)  // about -30 dBFS
  #expect(Overlay.level(rms: 1) == 1)
}

@Test("The pill goes on the screen holding the window's centre, in flipped coordinates")
func screenHoldingWindow() {
  // A 1440x900 primary screen with a 1920x1080 screen above it.
  let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
  let above = CGRect(x: 0, y: 900, width: 1920, height: 1080)
  let screens = [primary, above]

  // Accessibility's y runs down from the primary's top, so a window above it has negative y.
  func screen(x: CGFloat, y: CGFloat) -> Int? {
    Overlay.screenIndex(holding: CGRect(x: x, y: y, width: 600, height: 400), among: screens)
  }
  #expect(screen(x: 100, y: -800) == 1)
  #expect(screen(x: 100, y: 300) == 0)
  #expect(screen(x: 5000, y: 300) == nil)
}
