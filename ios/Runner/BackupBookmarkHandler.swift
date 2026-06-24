import Flutter
import UIKit
import UniformTypeIdentifiers

/// Dedicated security-scoped bookmark handler for the custom BACKUP folder.
///
/// Deliberately separate from `SecurityScopedBookmarkHandler` (which serves the
/// custom database location). Like `LocalMediaHandler`, it keeps MULTIPLE
/// concurrently active scoped URLs keyed by a session-local ref, rather than a
/// single `activeSecurityScopedURL`. iOS permits many concurrent
/// security-scoped resources, so the database scope and a backup-folder scope
/// coexist -- arming one never displaces the other.
///
/// Channel: `app.submersion/backup_bookmark`
///   - pickFolderWithSecurityScope() -> { path, bookmarkData }
///   - createBookmark(path) -> bookmarkData
///   - resolveBookmark(bookmarkData) -> { ref, path, isStale }   (scope armed)
///   - releaseBookmark(ref) -> nil
///   - releaseAllBookmarks() -> nil
///   - verifyWriteAccess(path) -> Bool
class BackupBookmarkHandler: NSObject, UIDocumentPickerDelegate {

    private let channel: FlutterMethodChannel

    /// Active security-scoped URLs keyed by the ref handed back to Dart.
    private var active: [String: URL] = [:]

    /// Pending result callback while the folder picker is on screen.
    private var pendingPickerResult: FlutterResult?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.submersion/backup_bookmark",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    deinit {
        releaseAll()
    }

    /// Stops accessing every backup URL we hold. Called on app teardown.
    func releaseAll() {
        for (_, url) in active {
            url.stopAccessingSecurityScopedResource()
        }
        active.removeAll()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pickFolderWithSecurityScope":
            pickFolder(result: result)

        case "createBookmark":
            guard let path = stringArg(call, "path") else {
                result(invalidArgs("path"))
                return
            }
            createBookmark(for: path, result: result)

        case "resolveBookmark":
            guard let args = call.arguments as? [String: Any],
                let data = args["bookmarkData"] as? FlutterStandardTypedData
            else {
                result(invalidArgs("bookmarkData"))
                return
            }
            resolveBookmark(data: data.data, result: result)

        case "releaseBookmark":
            guard let ref = stringArg(call, "ref") else {
                result(invalidArgs("ref"))
                return
            }
            if let url = active.removeValue(forKey: ref) {
                url.stopAccessingSecurityScopedResource()
            }
            result(nil)

        case "releaseAllBookmarks":
            releaseAll()
            result(nil)

        case "verifyWriteAccess":
            guard let path = stringArg(call, "path") else {
                result(invalidArgs("path"))
                return
            }
            verifyWriteAccess(path: path, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func stringArg(_ call: FlutterMethodCall, _ name: String) -> String? {
        (call.arguments as? [String: Any])?[name] as? String
    }

    private func invalidArgs(_ name: String) -> FlutterError {
        FlutterError(
            code: "INVALID_ARGS", message: "Missing \(name) argument", details: nil)
    }

    // MARK: - Folder picker

    private func pickFolder(result: @escaping FlutterResult) {
        guard let viewController = UIApplication.shared.windows.first?.rootViewController
        else {
            result(
                FlutterError(
                    code: "NO_VIEW_CONTROLLER",
                    message: "Could not find root view controller", details: nil))
            return
        }
        pendingPickerResult = result

        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        } else {
            picker = UIDocumentPickerViewController(
                documentTypes: ["public.folder"], in: .open)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        viewController.present(picker, animated: true)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
        guard let result = pendingPickerResult else { return }
        pendingPickerResult = nil
        guard let url = urls.first else {
            result(nil)
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            result(
                FlutterError(
                    code: "ACCESS_ERROR",
                    message: "Failed to start accessing security-scoped resource",
                    details: nil))
            return
        }
        // The pick's scope is only needed to mint the bookmark and verify write
        // access. We do NOT keep it active -- runtime access is re-armed later
        // via resolveBookmark (which returns a ref the caller releases).
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let testFileURL = url.appendingPathComponent(".submersion_test")
            do {
                try "test".data(using: .utf8)!.write(to: testFileURL)
                try FileManager.default.removeItem(at: testFileURL)
            } catch {
                result(
                    FlutterError(
                        code: "WRITE_ERROR",
                        message: "Cannot write to selected folder. Please check permissions.",
                        details: error.localizedDescription))
                return
            }

            result([
                "path": url.path,
                "bookmarkData": FlutterStandardTypedData(bytes: bookmarkData),
            ])
        } catch {
            result(
                FlutterError(
                    code: "BOOKMARK_ERROR",
                    message: "Failed to create bookmark: \(error.localizedDescription)",
                    details: nil))
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard let result = pendingPickerResult else { return }
        pendingPickerResult = nil
        result(nil)
    }

    // MARK: - Bookmarks

    private func createBookmark(for path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            result(FlutterStandardTypedData(bytes: data))
        } catch {
            result(
                FlutterError(
                    code: "BOOKMARK_ERROR",
                    message: "Failed to create bookmark: \(error.localizedDescription)",
                    details: nil))
        }
    }

    private func resolveBookmark(data: Data, result: @escaping FlutterResult) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else {
                result(
                    FlutterError(
                        code: "ACCESS_ERROR",
                        message: "Failed to start accessing security-scoped resource",
                        details: nil))
                return
            }
            let ref = UUID().uuidString
            active[ref] = url
            result(["ref": ref, "path": url.path, "isStale": isStale])
        } catch {
            result(
                FlutterError(
                    code: "RESOLVE_ERROR",
                    message: "Failed to resolve bookmark: \(error.localizedDescription)",
                    details: nil))
        }
    }

    private func verifyWriteAccess(path: String, result: @escaping FlutterResult) {
        let url: URL
        var startedHere = false
        if let activeURL = active.values.first(where: { $0.path == path }) {
            url = activeURL
        } else {
            url = URL(fileURLWithPath: path)
            startedHere = url.startAccessingSecurityScopedResource()
        }
        defer {
            if startedHere { url.stopAccessingSecurityScopedResource() }
        }

        let testFileURL = url.appendingPathComponent(".submersion_test")
        do {
            try "test".data(using: .utf8)!.write(to: testFileURL)
            try FileManager.default.removeItem(at: testFileURL)
            result(true)
        } catch {
            result(false)
        }
    }
}
