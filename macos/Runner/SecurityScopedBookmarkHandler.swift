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

        case "verifyWriteAccess":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            verifyWriteAccess(path: path, result: result)

        case "iCloudDownloadStatus":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            result(iCloudDownloadStatus(path: path))

        case "downloadICloudItem":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            let timeoutSeconds = args["timeoutSeconds"] as? Int ?? 60
            downloadICloudItem(path: path, timeoutSeconds: timeoutSeconds, result: result)

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

    /// Verifies write access to a folder by creating and deleting a test file.
    /// This must be done from native code while security-scoped access is active.
    private func verifyWriteAccess(path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)

        // First, ensure we have security-scoped access
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        defer {
            // Only stop accessing if we started it here
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Try to create a test file
        let testFileURL = url.appendingPathComponent(".submersion_test")
        let testData = "test".data(using: .utf8)!

        do {
            try testData.write(to: testFileURL)
            try FileManager.default.removeItem(at: testFileURL)
            result(true)
        } catch {
            result(false)
        }
    }

    // MARK: - iCloud

    /// Reports whether the file at `path` is in iCloud and whether its contents are on this
    /// device: "notUbiquitous", "downloaded" or "notDownloaded". Nil when the resource values
    /// cannot be read, which Dart treats as unknown. Never starts a download.
    ///
    /// Needed because macOS Sonoma and later evict an iCloud file in place: it keeps its name
    /// and loses its contents, so from Dart it looks present until a read fails (issue #2177).
    private func iCloudDownloadStatus(path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(
            forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        ) else {
            return nil
        }
        guard values.isUbiquitousItem == true else { return "notUbiquitous" }
        let status = values.ubiquitousItemDownloadingStatus
        if status == .notDownloaded { return "notDownloaded" }
        if status == .current || status == .downloaded { return "downloaded" }
        return nil
    }

    /// Asks iCloud for the contents of the file at `path`, and replies true once they are on
    /// this device, or false when the download fails or `timeoutSeconds` pass. Replies exactly
    /// once, on the main thread.
    ///
    /// A coordinated read is what makes the system fetch a ubiquitous item before handing it
    /// over, and it works for an item reached through a bookmark or a picker, where
    /// startDownloadingUbiquitousItem alone may be refused. It blocks until the item is here,
    /// so it runs off the main thread, and cancelling the coordinator is what bounds it.
    private func downloadICloudItem(path: String, timeoutSeconds: Int, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)
        // Harmless when refused or when the item is already here. Where it is allowed, it
        // starts the transfer before the coordinated read below waits on it.
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        let queue = DispatchQueue.global(qos: .userInitiated)
        // A read still waiting when this fires returns with a cancellation error; one that has
        // already finished is unaffected.
        queue.asyncAfter(deadline: .now() + .seconds(max(timeoutSeconds, 1))) {
            coordinator.cancel()
        }
        queue.async {
            var coordinationError: NSError?
            var downloaded = false
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
                // An evicted file still exists by name, so presence alone proves nothing.
                downloaded = FileManager.default.fileExists(atPath: readURL.path)
                    && self.iCloudDownloadStatus(path: readURL.path) != "notDownloaded"
            }
            let succeeded = coordinationError == nil && downloaded
            DispatchQueue.main.async {
                result(succeeded)
            }
        }
    }

    /// Call this when the app is terminating to clean up resources.
    func cleanup() {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
    }
}
