import Foundation

/// The distributed notification that hands text to the running app to read aloud. The
/// `--mcp` process posts it and the app observes it. The poster must post with
/// `deliverImmediately`, for example
/// `postNotificationName(_:object:userInfo:options: [.deliverImmediately])`, or the system may
/// hold the notification back while the app is inactive, which a menu bar app normally is.
public enum SpeakNotification {
  public static let name = Notification.Name("com.aidanzealley.echotype.speak")
  /// The user-info key holding the text, a `String`.
  public static let textKey = "text"
}
