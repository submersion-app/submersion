import Cocoa
import FlutterMacOS

/// Dedicated security-scoped bookmark handler for the custom BACKUP folder
/// (macOS). See `ios/Runner/BackupBookmarkHandler.swift` for the rationale: a
/// separate, multi-slot handler so a backup-folder scope never displaces the
/// database-location scope held by `SecurityScopedBookmarkHandler`.
///
/// macOS requires `.withSecurityScope` at BOTH bookmark creation and
/// resolution (unlike iOS's `.minimalBookmark` + `[]`). The folder itself is
/// chosen via file_picker on the Dart side, so there is no native picker here.
///
/// Channel: `app.submersion/backup_bookmark`
///   - createBookmark(path) -> bookmarkData
///   - resolveBookmark(bookmarkData) -> { ref, path, isStale }   (scope armed)
///   - releaseBookmark(ref) -> nil
///   - releaseAllBookmarks() -> nil
///   - verifyWriteAccess(path) -> Bool
class BackupBookmarkHandler: NSObject {

    private let channel: FlutterMethodChannel

    /// Active security-scoped URLs keyed by the ref handed back to Dart.
    private var active: [String: URL] = [:]

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

    private func createBookmark(for path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)
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
                options: .withSecurityScope,
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
