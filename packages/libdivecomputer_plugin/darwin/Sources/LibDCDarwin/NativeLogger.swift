import Foundation

/// Centralized logger that sends log events back to Flutter via Pigeon
/// while also printing to the system console.
class NativeLogger {
    static var flutterApi: DiveComputerFlutterApi?

    static func d(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] \(message)")
        sendToFlutter(category: category, level: "DEBUG", message: message)
    }

    static func i(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] \(message)")
        sendToFlutter(category: category, level: "INFO", message: message)
    }

    static func w(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] WARNING: \(message)")
        sendToFlutter(category: category, level: "WARN", message: message)
    }

    static func e(_ tag: String, category: String, _ message: String) {
        print("[\(tag)] ERROR: \(message)")
        sendToFlutter(category: category, level: "ERROR", message: message)
    }

    private static func sendToFlutter(category: String, level: String, message: String) {
        guard let api = flutterApi else { return }
        DispatchQueue.main.async {
            api.onLogEvent(category: category, level: level, message: message) { _ in
                // Ignore callback result - don't let logging failures crash the app
            }
        }
    }
}
