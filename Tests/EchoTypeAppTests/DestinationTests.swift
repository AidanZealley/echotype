import AppKit
@testable import EchoTypeApp
import Testing

@Suite @MainActor struct DestinationTests {
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
