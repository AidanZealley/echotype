import AppKit
@testable import EchoTypeApp
import Testing

@Suite @MainActor struct DestinationTests {
  @Test func accessibilityActivationLeavesTimeForElectronAndRetriesPerApp() {
    var activation = DestinationFocus.AccessibilityActivation()
    func request(_ pid: pid_t, at now: TimeInterval) -> Bool {
      activation.shouldRequest(for: pid, at: now)
    }
    #expect(request(1, at: 10))
    // Both samples in capture and subsequent half-second probes must leave the
    // pending activation alone. Switching apps must not reset its waiting period.
    #expect(!request(1, at: 10))
    #expect(request(2, at: 10.5))
    for now in stride(from: 10.5, through: 12.5, by: 0.5) {
      #expect(!request(1, at: now))
    }
    #expect(request(1, at: 13))
    #expect(!request(2, at: 13))
    #expect(request(2, at: 13.5))
  }

  @Test func unsupportedEnabledCapabilityDoesNotHideDisabledOrFailedTargets() {
    #expect(DestinationFocus.acceptsEnabledAttribute((.attributeUnsupported, nil)))
    #expect(DestinationFocus.acceptsEnabledAttribute((.success, kCFBooleanTrue)))
    #expect(!DestinationFocus.acceptsEnabledAttribute((.success, kCFBooleanFalse)))
    #expect(!DestinationFocus.acceptsEnabledAttribute((.success, nil)))
    #expect(!DestinationFocus.acceptsEnabledAttribute((.success, "true" as CFString)))
    for error in [AXError.noValue, .cannotComplete, .invalidUIElement, .apiDisabled,
      .notImplemented] {
      #expect(!DestinationFocus.acceptsEnabledAttribute((error, kCFBooleanTrue)))
    }
  }

  private func destination(window: pid_t = 2, target: pid_t = 3) -> Destination {
    Destination(application: AXUIElementCreateApplication(1),
      window: AXUIElementCreateApplication(window), target: AXUIElementCreateApplication(target),
      pid: 1)
  }

  @Test func retainedIdentityMatchesAcrossLookups() {
    let focus = DestinationFocus(lookup: { destination() })
    #expect(focus.verify(focus.capture()) == .matching)
  }

  @Test func sameWindowDifferentTargetIsChanged() {
    let original = destination()
    let focus = DestinationFocus(lookup: { destination(target: 4) })
    #expect(focus.verify(original) == .changed)
    #expect(DestinationFocus(lookup: { destination(window: 4) }).verify(original) == .changed)
  }

  @Test func focusChangingDuringCaptureIsUnavailable() {
    var calls = 0
    let focus = DestinationFocus(lookup: {
      calls += 1
      return destination(target: calls == 1 ? 3 : 4)
    })
    #expect(focus.capture() == nil)
    #expect(DestinationFocus(lookup: { nil }).verify(destination()) == .unavailable)
  }
}
