import AppKit
import FlutterMacOS
import Foundation
import QuickLookThumbnailing

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
        releaseAllActiveBookmarks()
    }

    /// Defensive cleanup: balances any startAccessingSecurityScopedResource()
    /// calls whose matching releaseBookmark never came in (Dart-side bug,
    /// missed teardown, etc.). On normal app exit the OS would reclaim these
    /// anyway, but draining the dictionary keeps long-lived sandbox accounting
    /// clean if the handler is ever recreated mid-process.
    ///
    /// Internal rather than private so `applicationWillTerminate` can call it
    /// too: `deinit` does not run when the process terminates, and the app
    /// delegate holds this handler for the whole session.
    ///
    /// **Contract: the caller must have exclusive access to `active`.** That is
    /// the real requirement; being on the main thread is just the ordinary way
    /// to satisfy it, since `active` is main-thread-owned (see
    /// `resolveBookmark`, which hops back to main purely to mutate it).
    ///
    /// The two callers satisfy it in different ways, which is why the contract
    /// is stated as exclusivity rather than as "call this on main":
    ///   * `applicationWillTerminate` runs on the main thread.
    ///   * `deinit` may run on any thread, and does not need to be on main:
    ///     it runs only once the reference count reaches zero, so no other
    ///     reference exists and nothing can be concurrently inside a method
    ///     that touches `active`. Exclusivity holds by construction.
    ///
    /// A third caller on some other queue would break it. Not enforced with
    /// `dispatchPrecondition`, which would be wrong twice over: it would reject
    /// the legitimate `deinit` case, and it traps in release builds, so it
    /// would trade a theoretical race for a definite crash on the path the user
    /// takes to quit.
    func releaseAllActiveBookmarks() {
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
        case "readBookmarkBytes":
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
            readBookmarkBytes(blob: blob.data, result: result)
        case "generateVideoThumbnail":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            // Clamp at the channel boundary (mirrors the Dart caller's
            // 1...4096): a zero/negative size would make an invalid QuickLook
            // request, and an absurd one would provoke a huge render.
            let maxDim = min(max((args["maxDimension"] as? Int) ?? 512, 1), 4096)
            let blob = (args["bookmarkBlob"] as? FlutterStandardTypedData)?.data
            let path = args["path"] as? String
            generateVideoThumbnail(
                path: path, bookmarkBlob: blob, maxDimension: maxDim,
                result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Generates a poster frame via QuickLook. On the sandbox, resolves the
    /// security-scoped bookmark and brackets access; falls back to the raw
    /// path when no bookmark is supplied (unsandboxed dev builds). Returns nil
    /// on any failure so the Dart side keeps the placeholder.
    private func generateVideoThumbnail(
        path: String?, bookmarkBlob: Data?, maxDimension: Int,
        result: @escaping FlutterResult
    ) {
        // QuickLook's own call is already asynchronous, but the bookmark
        // resolution ahead of it is not, and resolving a bookmark touches the
        // volume it points at. One video tile per unreachable share was enough
        // to block the platform thread before the generator was ever reached.
        DispatchQueue.global(qos: .userInitiated).async {
            var url: URL?
            var scoped = false
            if let blob = bookmarkBlob {
                var stale = false
                url = try? URL(
                    resolvingBookmarkData: blob,
                    options: [.withSecurityScope],
                    relativeTo: nil, bookmarkDataIsStale: &stale)
                if let u = url { scoped = u.startAccessingSecurityScopedResource() }
            } else if let p = path {
                url = URL(fileURLWithPath: p)
            }
            guard let fileURL = url else {
                DispatchQueue.main.async { result(nil) }
                return
            }

            let size = CGSize(width: maxDimension, height: maxDimension)
            let request = QLThumbnailGenerator.Request(
                fileAt: fileURL, size: size, scale: 1.0,
                representationTypes: .thumbnail)

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                rep, _ in
                defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
                guard let cg = rep?.cgImage else {
                    DispatchQueue.main.async { result(nil) }
                    return
                }
                let bitmap = NSBitmapImageRep(cgImage: cg)
                let jpeg = bitmap.representation(
                    using: .jpeg, properties: [.compressionFactor: 0.8])
                DispatchQueue.main.async {
                    if let data = jpeg {
                        result(FlutterStandardTypedData(bytes: data))
                    } else {
                        result(nil)
                    }
                }
            }
        }
    }

    /// Mints a security-scoped bookmark.
    ///
    /// Off the platform thread: bookmarking a file on an unreachable share
    /// blocks in the same way reading one does.
    private func createBookmark(filePath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: filePath)
            do {
                let data = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: data))
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "BOOKMARK_FAILED",
                            message:
                                "Could not create bookmark: \(error.localizedDescription)",
                            details: nil
                        ))
                }
            }
        }
    }

    /// Resolves a bookmark and starts security-scoped access.
    ///
    /// Off the platform thread for the same reason as readBookmarkBytes:
    /// resolving a bookmark touches the volume it points at, so a dead mount
    /// blocks here too. `active` is main-thread-owned state and is mutated back
    /// on main, which also keeps the ref's registration ordered ahead of the
    /// Dart side ever seeing it.
    private func resolveBookmark(blob: Data, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: blob,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    DispatchQueue.main.async {
                        result(
                            FlutterError(
                                code: "ACCESS_DENIED",
                                message: "Security-scoped resource access denied",
                                details: nil
                            ))
                    }
                    return
                }
                let ref = UUID().uuidString
                let isStale = stale
                DispatchQueue.main.async {
                    guard let self else {
                        // The handler went away mid-resolve, so nothing will
                        // ever release this scope. Balance it here.
                        url.stopAccessingSecurityScopedResource()
                        result(
                            FlutterError(
                                code: "RESOLVE_FAILED",
                                message: "Handler released before the bookmark resolved",
                                details: nil
                            ))
                        return
                    }
                    self.active[ref] = url
                    result([
                        "bookmarkRef": ref,
                        "filePath": url.path,
                        "stale": isStale,
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "RESOLVE_FAILED",
                            message:
                                "Could not resolve bookmark: \(error.localizedDescription)",
                            details: nil
                        ))
                }
            }
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

    /// Reads the bookmarked file's bytes.
    ///
    /// Runs off the platform thread. `Data(contentsOf:)` is a synchronous
    /// whole-file read, and on a sandboxed build this is the ordinary path for
    /// every local media item, grid thumbnails included. Against a network
    /// share or an evicted iCloud Drive file it blocks until the mount's own
    /// timeout, and on macOS the platform thread IS the main thread: the thread
    /// that paints frames, and the thread that must run
    /// applicationShouldTerminate and deliver its reply. Blocking it froze the
    /// Media section outright and left the process alive after its window had
    /// already closed.
    private func readBookmarkBytes(blob: Data, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: blob,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    DispatchQueue.main.async {
                        result(
                            FlutterError(
                                code: "ACCESS_DENIED",
                                message: "Security-scoped resource access denied",
                                details: nil
                            ))
                    }
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: data))
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "READ_FAILED",
                            message:
                                "Could not read bookmark bytes: \(error.localizedDescription)",
                            details: nil
                        ))
                }
            }
        }
    }
}
