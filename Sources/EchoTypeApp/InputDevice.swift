import AVFoundation

/// A connected audio input, for the picker. `uid` is the device's `AVCaptureDevice.uniqueID`,
/// which is what `Settings.inputDeviceID` stores and what `AudioCapture` opens by. It survives
/// unplugging and relaunching.
struct InputDevice: Sendable {
  let uid: String
  let name: String

  /// Every connected microphone, built in or external, as `AVCaptureDevice` lists them. It
  /// asks the system about every device, so keep it off the main actor.
  static func all() -> [InputDevice] {
    AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified
    ).devices.map { InputDevice(uid: $0.uniqueID, name: $0.localizedName) }
  }
}
