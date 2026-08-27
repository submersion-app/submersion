import Foundation

/// Centralized logger that sends log events back to Flutter via Pigeon
/// while also printing to the system console.
class NativeLogger {
    static var flutterApi: DiveComputerFlutterApi?

    // All log output is funneled through this single serial queue so a log call
    // never blocks its caller. The CoreBluetooth delegate queue logs every GATT
    // notification during a download -- hundreds per second under the OSTC
    // fire-hose -- and doing the synchronous print there throttled that queue,
    // which made iOS drop notifications and corrupt the download (issue #394).
    // One serial queue keeps log lines in order while moving the print and the
    // Flutter hand-off off the hot path.
    private static let queue = DispatchQueue(label: "app.submersion.native-logger",
                                             qos: .utility)

    // The message is an @autoclosure so its construction is deferred to the
    // logger queue. Hot-path callers (the per-notification BLE log builds a hex
    // dump) would otherwise format the string on the CoreBluetooth delegate
    // queue before the call even returns, which is exactly the work we are
    // trying to keep off that queue (issue #394).
    static func d(_ tag: String, category: String, _ message: @autoclosure @escaping () -> String) {
        log(tag: tag, category: category, level: "DEBUG", message: message)
    }

    static func i(_ tag: String, category: String, _ message: @autoclosure @escaping () -> String) {
        log(tag: tag, category: category, level: "INFO", message: message)
    }

    static func w(_ tag: String, category: String, _ message: @autoclosure @escaping () -> String) {
        log(tag: tag, category: category, level: "WARN", message: message)
    }

    static func e(_ tag: String, category: String, _ message: @autoclosure @escaping () -> String) {
        log(tag: tag, category: category, level: "ERROR", message: message)
    }

    private static func log(tag: String, category: String, level: String,
                            message: @escaping () -> String) {
        queue.async {
            let prefix: String
            switch level {
            case "WARN": prefix = "WARNING: "
            case "ERROR": prefix = "ERROR: "
            default: prefix = ""
            }
            // Evaluate the message once, here on the logger queue, and reuse it
            // for both the console print and the Flutter log event.
            let text = message()
            print("[\(tag)] \(prefix)\(text)")
            guard let api = flutterApi else { return }
            DispatchQueue.main.async {
                api.onLogEvent(category: category, level: level, message: text) { _ in
                    // Ignore callback result - don't let logging failures crash the app
                }
            }
        }
    }
}
