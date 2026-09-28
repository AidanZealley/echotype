import AVFoundation
import CoreAudio

/// A microphone in the picker or the one actually opened for a session. Its UID survives
/// unplugging and relaunching, and is what `Settings.inputDeviceID` stores.
struct InputDevice: Equatable, Sendable {
  let uid: String
  let name: String
  let isBluetooth: Bool

  init(uid: String, name: String, isBluetooth: Bool) {
    self.uid = uid
    self.name = name
    self.isBluetooth = isBluetooth
  }

  init(_ device: AVCaptureDevice) {
    let transport = device.transportType
    self.init(
      uid: device.uniqueID, name: device.localizedName,
      isBluetooth: transport == Int32(bitPattern: kAudioDeviceTransportTypeBluetooth)
        || transport == Int32(bitPattern: kAudioDeviceTransportTypeBluetoothLE))
  }

  /// Every connected microphone, built in or external, as `AVCaptureDevice` lists them. It
  /// asks the system about every device, so keep it off the main actor.
  static func all() -> [InputDevice] {
    AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified
    ).devices.map(InputDevice.init)
  }
}
