import Flutter
import UIKit
import UniformTypeIdentifiers

/// Handles security-scoped bookmarks for persisting folder access across app restarts.
/// This is required for iOS apps to maintain access to user-selected folders in iCloud Drive
/// or other document providers.
///
/// iOS uses a slightly different API than macOS:
/// - Bookmark creation uses `.minimalBookmark` instead of `.withSecurityScope`
/// - Resolution doesn't require special options (security scope is implicit)
/// - We must capture the security-scoped URL directly from the document picker
class SecurityScopedBookmarkHandler: NSObject, UIDocumentPickerDelegate {

    private let channel: FlutterMethodChannel

    /// Currently active security-scoped URL that we've started accessing
    private var activeSecurityScopedURL: URL?

    /// Pending result callback for folder picker
    private var pendingPickerResult: FlutterResult?

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

        case "pickFolderWithSecurityScope":
            pickFolderWithSecurityScope(result: result)

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

    /// Picks a folder using UIDocumentPickerViewController and immediately captures
    /// the security-scoped URL, creates a bookmark, and starts accessing.
    ///
    /// Returns a map with:
    /// - path: The folder path
    /// - bookmarkData: The bookmark data for persistent access
    private func pickFolderWithSecurityScope(result: @escaping FlutterResult) {
        guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not find root view controller", details: nil))
            return
        }

        // Store the result callback for later
        pendingPickerResult = result

        // Create document picker for folders
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])

        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet

        viewController.present(documentPicker, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let result = pendingPickerResult else { return }
        pendingPickerResult = nil

        guard let url = urls.first else {
            result(nil) // User cancelled or no selection
            return
        }

        // CRITICAL: Start accessing the security-scoped resource IMMEDIATELY
        // This is the actual security-scoped URL from the picker
        guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(
                code: "ACCESS_ERROR",
                message: "Failed to start accessing security-scoped resource",
                details: nil
            ))
            return
        }

        // Stop accessing any previously active URL
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = url

        // Create bookmark while we have security-scoped access
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Verify we can write to the folder
            let testFileURL = url.appendingPathComponent(".submersion_test")
            let testData = "test".data(using: .utf8)!

            do {
                try testData.write(to: testFileURL)
                try FileManager.default.removeItem(at: testFileURL)
            } catch {
                // Can't write - stop accessing and report error
                url.stopAccessingSecurityScopedResource()
                activeSecurityScopedURL = nil
                result(FlutterError(
                    code: "WRITE_ERROR",
                    message: "Cannot write to selected folder. Please check permissions.",
                    details: error.localizedDescription
                ))
                return
            }

            // Success! Return path and bookmark data
            result([
                "path": url.path,
                "bookmarkData": FlutterStandardTypedData(bytes: bookmarkData)
            ])
        } catch {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
            result(FlutterError(
                code: "BOOKMARK_ERROR",
                message: "Failed to create bookmark: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard let result = pendingPickerResult else { return }
        pendingPickerResult = nil
        result(nil) // User cancelled
    }

    // MARK: - Bookmark Methods

    /// Creates a security-scoped bookmark for the given path.
    /// Note: This only works if we already have security-scoped access to this path.
    private func createBookmark(for path: String, result: @escaping FlutterResult) {
        // Check if this is our currently active security-scoped URL
        if let activeURL = activeSecurityScopedURL, activeURL.path == path {
            do {
                let bookmarkData = try activeURL.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                result(FlutterStandardTypedData(bytes: bookmarkData))
            } catch {
                result(FlutterError(
                    code: "BOOKMARK_ERROR",
                    message: "Failed to create bookmark: \(error.localizedDescription)",
                    details: nil
                ))
            }
            return
        }

        // Try with a new URL (may fail without security scope)
        let url = URL(fileURLWithPath: path)
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
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
                options: [],
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
    /// Uses the active security-scoped URL if the path matches.
    private func verifyWriteAccess(path: String, result: @escaping FlutterResult) {
        let url: URL
        var didStartAccessing = false

        // Use active security-scoped URL if available and matches
        if let activeURL = activeSecurityScopedURL, activeURL.path == path {
            url = activeURL
        } else {
            url = URL(fileURLWithPath: path)
            didStartAccessing = url.startAccessingSecurityScopedResource()
        }

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

    /// Replies owed for downloads still under way, by path, each with its own id so its
    /// deadline can answer it alone. Touched only on the main thread.
    private var downloadWaiters: [String: [(id: UUID, result: FlutterResult)]] = [:]

    /// Paths with a coordinated read under way. A second request for the same path waits on
    /// that read instead of starting another: a read blocked on an evicted file cannot be
    /// interrupted, so fresh reads would only pile up behind it. Main thread only.
    private var downloadsInFlight: Set<String> = []

    /// Asks iCloud for the contents of the file at `path`, and replies true once they are on
    /// this device, or false when the download fails or `timeoutSeconds` pass. Each caller
    /// is answered exactly once, on the main thread, by its own deadline at the latest, even
    /// while the read itself is still blocked.
    ///
    /// A coordinated read is what makes the system fetch a ubiquitous item before handing it
    /// over, and it works for an item reached through a bookmark or a picker, where
    /// startDownloadingUbiquitousItem alone may be refused. It blocks until the item is here,
    /// so it runs off the main thread.
    private func downloadICloudItem(path: String, timeoutSeconds: Int, result: @escaping FlutterResult) {
        let id = UUID()
        downloadWaiters[path, default: []].append((id: id, result: result))
        let deadline = DispatchTime.now() + .seconds(max(timeoutSeconds, 1))
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            self?.answerDownloadWaiter(path: path, id: id, downloaded: false)
        }
        guard !downloadsInFlight.contains(path) else { return }
        downloadsInFlight.insert(path)

        let url = URL(fileURLWithPath: path)
        // Harmless when refused or when the item is already here. Where it is allowed, it
        // starts the transfer before the coordinated read below waits on it. The item's own
        // URL is the documented argument; the placeholder's URL is tried only if that is
        // refused, for systems that still leave `.name.icloud` in its place.
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            let placeholder = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).icloud")
            try? FileManager.default.startDownloadingUbiquitousItem(at: placeholder)
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        let queue = DispatchQueue.global(qos: .userInitiated)
        // A read still waiting for coordination when this fires returns with a cancellation
        // error. One already inside the accessor runs on, and the waiters' own deadlines
        // answer for it.
        queue.asyncAfter(deadline: deadline) {
            coordinator.cancel()
        }
        queue.async {
            var coordinationError: NSError?
            var downloaded = false
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
                // Reading a byte is what makes an evicted file's contents arrive, whether or
                // not the coordination fetched them already, so the status is read after it.
                // An evicted file still exists by name, so presence alone proves nothing, and
                // neither does an unknown status: only an explicit answer that the contents
                // are local counts.
                let readable = Self.readsFirstByte(of: readURL)
                let status = self.iCloudDownloadStatus(path: readURL.path)
                downloaded = readable && (status == "downloaded" || status == "notUbiquitous")
            }
            let succeeded = coordinationError == nil && downloaded
            DispatchQueue.main.async {
                self.downloadsInFlight.remove(path)
                self.answerAllDownloadWaiters(path: path, downloaded: succeeded)
            }
        }
    }

    /// Answers one caller of `downloadICloudItem`, if it has not been answered yet.
    private func answerDownloadWaiter(path: String, id: UUID, downloaded: Bool) {
        guard var waiters = downloadWaiters[path],
              let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        downloadWaiters[path] = waiters.isEmpty ? nil : waiters
        waiter.result(downloaded)
    }

    /// Answers every caller still waiting on the download of `path`.
    private func answerAllDownloadWaiters(path: String, downloaded: Bool) {
        let waiters = downloadWaiters.removeValue(forKey: path) ?? []
        waiters.forEach { $0.result(downloaded) }
    }

    /// True when the first byte of the file at `url` can be read.
    private static func readsFirstByte(of url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 1))?.isEmpty == false
    }

    /// Call this when the app is terminating to clean up resources.
    func cleanup() {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
    }
}
