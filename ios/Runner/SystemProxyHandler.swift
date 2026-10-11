import CFNetwork
import UIKit
import Flutter

/// Tells Dart which proxy the OS would use for a URL (issue #3217).
///
/// Methods (channel: app.submersion/system_proxy):
///   - resolve({url}) -> Dictionary
///       {kind: "none"}
///       {kind: "fixed", type: "http"|"socks5", host, port, bypass, viaPac}
///       {kind: "unavailable", reason: "pacFailed", detail}
///
/// PAC scripts are evaluated with CFNetwork on a background thread's run
/// loop, capped at 5 seconds. Parsing and fallback live Dart-side in
/// ChannelSystemProxyResolver, where they are unit-testable.
class SystemProxyHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.submersion/system_proxy",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "resolve" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let args = call.arguments as? [String: Any],
              let text = args["url"] as? String,
              let url = URL(string: text)
        else {
            result(FlutterError(code: "bad_args", message: "url required", details: nil))
            return
        }
        // A dedicated thread: PAC evaluation spins its run loop.
        Thread.detachNewThread {
            let answer = SystemProxyHandler.resolve(url: url)
            DispatchQueue.main.async { result(answer) }
        }
    }

    static func resolve(url: URL) -> [String: Any] {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            return ["kind": "none"]
        }
        let dict = settings as NSDictionary
        var bypass = (dict["ExceptionsList"] as? [String]) ?? []
        // Dart routes each request by this list, so "Exclude simple hostnames"
        // travels as the `<local>` entry the Dart side already reads.
        if (dict["ExcludeSimpleHostnames"] as? NSNumber)?.boolValue == true {
            bypass.append("<local>")
        }
        let proxies = CFNetworkCopyProxiesForURL(url as CFURL, settings)
            .takeRetainedValue() as? [[String: Any]] ?? []
        return firstUsable(proxies, url: url, bypass: bypass, viaPac: false)
    }

    private static let typeNone = kCFProxyTypeNone as String
    private static let typeHTTP = kCFProxyTypeHTTP as String
    private static let typeHTTPS = kCFProxyTypeHTTPS as String
    private static let typeSOCKS = kCFProxyTypeSOCKS as String
    private static let typePacURL = kCFProxyTypeAutoConfigurationURL as String
    private static let typePacScript = kCFProxyTypeAutoConfigurationJavaScript as String

    private static func firstUsable(
        _ proxies: [[String: Any]], url: URL, bypass: [String], viaPac: Bool
    ) -> [String: Any] {
        for proxy in proxies {
            guard let type = proxy[kCFProxyTypeKey as String] as? String else { continue }
            switch type {
            case typeNone:
                return ["kind": "none", "viaPac": viaPac]
            case typeHTTP, typeHTTPS, typeSOCKS:
                guard let host = proxy[kCFProxyHostNameKey as String] as? String,
                      let port = (proxy[kCFProxyPortNumberKey as String] as? NSNumber)?.intValue
                else { continue }
                return [
                    "kind": "fixed",
                    "type": type == typeSOCKS ? "socks5" : "http",
                    "host": host, "port": port, "bypass": bypass, "viaPac": viaPac,
                ]
            case typePacURL:
                guard let pac = proxy[kCFProxyAutoConfigurationURLKey as String] as? URL
                else { continue }
                let pacURL = pac as CFURL
                return runPac(url: url, bypass: bypass) { callback, context in
                    CFNetworkExecuteProxyAutoConfigurationURL(
                        pacURL, url as CFURL, callback, context
                    )
                }
            case typePacScript:
                guard let script = proxy[kCFProxyAutoConfigurationJavaScriptKey as String] as? String
                else { continue }
                return runPac(url: url, bypass: bypass) { callback, context in
                    CFNetworkExecuteProxyAutoConfigurationScript(
                        script as CFString, url as CFURL, callback, context
                    )
                }
            default:
                continue
            }
        }
        return ["kind": "none"]
    }

    private final class PacBox {
        var proxies: [[String: Any]]?
        var error: String?
        var done = false
    }

    private static func runPac(
        url: URL, bypass: [String],
        start: (CFProxyAutoConfigurationResultCallback,
                UnsafeMutablePointer<CFStreamClientContext>) -> CFRunLoopSource
    ) -> [String: Any] {
        let box = PacBox()
        var context = CFStreamClientContext(
            version: 0, info: Unmanaged.passUnretained(box).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: CFProxyAutoConfigurationResultCallback = { info, proxies, error in
            let box = Unmanaged<PacBox>.fromOpaque(info).takeUnretainedValue()
            if let error = error {
                box.error = CFErrorCopyDescription(error) as String
            } else {
                box.proxies = proxies as? [[String: Any]]
            }
            box.done = true
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        let source = start(callback, &context)
        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .defaultMode)
        let deadline = Date().addingTimeInterval(5)
        while !box.done && Date() < deadline {
            _ = CFRunLoopRunInMode(.defaultMode, deadline.timeIntervalSinceNow, true)
        }
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        // Invalidate, not just remove: a PAC fetch still in flight after the
        // timeout must never call back into `box` once this frame is gone.
        CFRunLoopSourceInvalidate(source)
        if !box.done {
            return ["kind": "unavailable", "reason": "pacFailed",
                    "detail": "Timed out evaluating the proxy auto-configuration script"]
        }
        if let error = box.error {
            return ["kind": "unavailable", "reason": "pacFailed", "detail": error]
        }
        return firstUsable(box.proxies ?? [], url: url, bypass: bypass, viaPac: true)
    }
}
