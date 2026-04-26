import FlutterMacOS
import Foundation

/// Handles security-scoped bookmark creation and resolution for the
/// Media Source Extension feature.
///
/// Methods (channel: com.submersion.app/local_media):
///   - createBookmark(filePath: String) -> bookmarkBlob: FlutterStandardTypedData
///       Creates a security-scoped bookmark for [filePath] and returns the
///       raw bookmark blob. The Dart side stores this in flutter_secure_storage
///       and provides it back on resolveBookmark.
///
///   - resolveBookmark(bookmarkBlob: FlutterStandardTypedData) -> Dictionary
///       Resolves a stored bookmark blob, starts security-scoped resource
///       access, and returns:
///         - bookmarkRef: a session-local key to release the resource later
///         - filePath: the resolved file path
///         - stale: whether the bookmark needs to be re-created
///
///   - releaseBookmark(bookmarkRef: String) -> Void
///       Stops the security-scoped resource access for the given session ref.
///
///   - releaseAllBookmarks() -> Void
///       Stops security-scoped access for every URL currently held by this
///       handler. Intended for logout / app-teardown flows where the Dart
///       side wants to drop every outstanding resolve at once.
class LocalMediaHandler: NSObject {
    private let channel: FlutterMethodChannel
    /// Active security-scoped URLs that callers must release. Keyed by a
    /// session-local UUID returned to the Dart side.
    private var active: [String: URL] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.submersion.app/local_media",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    deinit {
        // Defensive cleanup: balance any startAccessingSecurityScopedResource()
        // calls whose matching releaseBookmark never came in (Dart-side bug,
        // missed teardown, etc.). On normal app exit the OS would reclaim
        // these anyway, but draining the dictionary keeps long-lived sandbox
        // accounting clean if the handler is ever recreated mid-process.
        for (_, url) in active {
            url.stopAccessingSecurityScopedResource()
        }
        active.removeAll()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createBookmark":
            guard let args = call.arguments as? [String: Any],
                let path = args["filePath"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "filePath required",
                        details: nil
                    ))
                return
            }
            createBookmark(filePath: path, result: result)
        case "resolveBookmark":
            guard let args = call.arguments as? [String: Any],
                let blob = args["bookmarkBlob"] as? FlutterStandardTypedData
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "bookmarkBlob required",
                        details: nil
                    ))
                return
            }
            resolveBookmark(blob: blob.data, result: result)
        case "releaseBookmark":
            guard let args = call.arguments as? [String: Any],
                let key = args["bookmarkRef"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "bookmarkRef required",
                        details: nil
                    ))
                return
            }
            releaseBookmark(key: key, result: result)
        case "releaseAllBookmarks":
            releaseAllBookmarks(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createBookmark(filePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            result(FlutterStandardTypedData(bytes: data))
        } catch {
            result(
                FlutterError(
                    code: "BOOKMARK_FAILED",
                    message: "Could not create bookmark: \(error.localizedDescription)",
                    details: nil
                ))
        }
    }

    private func resolveBookmark(blob: Data, result: @escaping FlutterResult) {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: blob,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard url.startAccessingSecurityScopedResource() else {
                result(
                    FlutterError(
                        code: "ACCESS_DENIED",
                        message: "Security-scoped resource access denied",
                        details: nil
                    ))
                return
            }
            let ref = UUID().uuidString
            active[ref] = url
            result([
                "bookmarkRef": ref,
                "filePath": url.path,
                "stale": stale,
            ])
        } catch {
            result(
                FlutterError(
                    code: "RESOLVE_FAILED",
                    message: "Could not resolve bookmark: \(error.localizedDescription)",
                    details: nil
                ))
        }
    }

    private func releaseBookmark(key: String, result: @escaping FlutterResult) {
        if let url = active.removeValue(forKey: key) {
            url.stopAccessingSecurityScopedResource()
        }
        result(nil)
    }

    private func releaseAllBookmarks(result: @escaping FlutterResult) {
        for (_, url) in active {
            url.stopAccessingSecurityScopedResource()
        }
        active.removeAll()
        result(nil)
    }
}
