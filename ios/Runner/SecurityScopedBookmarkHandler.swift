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
        let documentPicker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        } else {
            documentPicker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        }

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

    /// Call this when the app is terminating to clean up resources.
    func cleanup() {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
    }
}
