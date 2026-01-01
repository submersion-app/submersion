import Cocoa
import FlutterMacOS

/// Handles security-scoped bookmarks for persisting folder access across app restarts.
/// This is required for sandboxed macOS apps to maintain access to user-selected folders.
class SecurityScopedBookmarkHandler: NSObject {

    private let channel: FlutterMethodChannel

    /// Currently active security-scoped URL that we've started accessing
    private var activeSecurityScopedURL: URL?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.submersion/security_scoped_bookmark",
            binaryMessenger: messenger
        )
        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createBookmark":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            createBookmark(for: path, result: result)

        case "resolveBookmark":
            guard let args = call.arguments as? [String: Any],
                  let bookmarkData = args["bookmarkData"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing bookmarkData argument", details: nil))
                return
            }
            resolveBookmark(data: bookmarkData.data, result: result)

        case "startAccessingSecurityScopedResource":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            startAccessing(path: path, result: result)

        case "stopAccessingSecurityScopedResource":
            stopAccessing(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Creates a security-scoped bookmark for the given path.
    /// The bookmark data can be stored and used to regain access after app restart.
    private func createBookmark(for path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)

        do {
            // Create a security-scoped bookmark
            // Using .withSecurityScope allows the bookmark to be resolved across app launches
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Return the bookmark data as bytes
            result(FlutterStandardTypedData(bytes: bookmarkData))
        } catch {
            result(FlutterError(
                code: "BOOKMARK_ERROR",
                message: "Failed to create bookmark: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    /// Resolves a security-scoped bookmark and returns the path.
    /// Also starts accessing the security-scoped resource.
    private func resolveBookmark(data: Data, result: @escaping FlutterResult) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Start accessing the security-scoped resource
            if url.startAccessingSecurityScopedResource() {
                // Stop accessing any previously active URL
                activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
                activeSecurityScopedURL = url

                result([
                    "path": url.path,
                    "isStale": isStale
                ])
            } else {
                result(FlutterError(
                    code: "ACCESS_ERROR",
                    message: "Failed to start accessing security-scoped resource",
                    details: nil
                ))
            }
        } catch {
            result(FlutterError(
                code: "RESOLVE_ERROR",
                message: "Failed to resolve bookmark: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    /// Starts accessing a security-scoped resource at the given path.
    /// This is called after successfully resolving a bookmark.
    private func startAccessing(path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)

        if url.startAccessingSecurityScopedResource() {
            activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = url
            result(true)
        } else {
            result(false)
        }
    }

    /// Stops accessing the currently active security-scoped resource.
    private func stopAccessing(result: @escaping FlutterResult) {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
        result(nil)
    }

    /// Call this when the app is terminating to clean up resources.
    func cleanup() {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
    }
}
