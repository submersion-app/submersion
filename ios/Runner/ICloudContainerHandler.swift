import Flutter
import UIKit

/// Thread-safe atomic flag for one-shot operations.
private class AtomicFlag {
    private var value = false
    private let lock = NSLock()

    /// Atomically sets the flag to true if it was false.
    /// Returns true if the flag was successfully set (was false), false if already set.
    func setIfFalse() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if value { return false }
        value = true
        return true
    }
}

/// Handles iCloud container discovery and download requests.
class ICloudContainerHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.submersion/icloud_container",
            binaryMessenger: messenger
        )
        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getICloudContainerPath":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            let identifier = args["identifier"] as? String
            getContainerPath(identifier: identifier, result: result)

        case "downloadIfNeeded":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            downloadIfNeeded(path: path, result: result)

        case "writeFile":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing write arguments", details: nil))
                return
            }
            writeFile(path: path, data: data.data, result: result)

        case "moveFile":
            guard let args = call.arguments as? [String: Any],
                  let sourcePath = args["sourcePath"] as? String,
                  let destinationPath = args["destinationPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing move arguments", details: nil))
                return
            }
            moveFile(sourcePath: sourcePath, destinationPath: destinationPath, result: result)

        case "refreshFolder":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            refreshFolder(path: path, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getContainerPath(identifier: String?, result: @escaping FlutterResult) {
        // Thread-safe flag to ensure result is only called once
        let responded = AtomicFlag()

        DispatchQueue.global(qos: .userInitiated).async {
            let url = FileManager.default.url(forUbiquityContainerIdentifier: identifier)

            // Only respond if we haven't timed out
            guard responded.setIfFalse() else { return }

            guard let containerURL = url else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            let documentsURL = containerURL.appendingPathComponent("Documents")
            DispatchQueue.main.async { result(documentsURL.path) }
        }

        // Timeout after 10 seconds - url(forUbiquityContainerIdentifier:) can hang indefinitely
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 10) {
            // Only respond if the main work hasn't completed yet
            guard responded.setIfFalse() else { return }
            DispatchQueue.main.async {
                result(FlutterError(code: "TIMEOUT", message: "iCloud container lookup timed out", details: nil))
            }
        }
    }

    private func downloadIfNeeded(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            let fileManager = FileManager.default

            guard fileManager.isUbiquitousItem(at: url) else {
                DispatchQueue.main.async { result(true) }
                return
            }

            if self.isDownloaded(url: url) {
                DispatchQueue.main.async { result(true) }
                return
            }

            do {
                try fileManager.startDownloadingUbiquitousItem(at: url)
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "DOWNLOAD_ERROR", message: "Failed to start download", details: error.localizedDescription))
                }
                return
            }

            let timeout = Date().addingTimeInterval(12)
            while Date() < timeout {
                if self.isDownloaded(url: url) {
                    DispatchQueue.main.async { result(true) }
                    return
                }
                Thread.sleep(forTimeInterval: 0.2)
            }

            DispatchQueue.main.async { result(false) }
        }
    }

    /// Check if running in the iOS Simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func writeFile(path: String, data: Data, result: @escaping FlutterResult) {
        // In the simulator, iCloud Mobile Documents path blocks indefinitely
        // Return an error immediately to avoid wasting time
        if isSimulator && path.contains("Mobile Documents") {
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "SIMULATOR_UNSUPPORTED",
                    message: "iCloud sync is not supported in the iOS Simulator. Please test on a physical device.",
                    details: nil
                ))
            }
            return
        }

        // Thread-safe flag to ensure result is only called once
        let responded = AtomicFlag()

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            let fileManager = FileManager.default

            // Ensure parent directory exists
            let parentDir = url.deletingLastPathComponent()
            do {
                var isDir: ObjCBool = false
                if !fileManager.fileExists(atPath: parentDir.path, isDirectory: &isDir) {
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }
            } catch {
                guard responded.setIfFalse() else { return }
                DispatchQueue.main.async {
                    result(FlutterError(code: "DIR_ERROR", message: "Failed to create parent directory: \(parentDir.path)", details: error.localizedDescription))
                }
                return
            }

            // Write directly without NSFileCoordinator to avoid blocking
            // Don't use .atomic - it creates a temp file and renames, which can
            // trigger internal iCloud coordination and block
            do {
                try data.write(to: url, options: [])

                guard responded.setIfFalse() else { return }
                DispatchQueue.main.async { result(true) }
            } catch {
                guard responded.setIfFalse() else { return }
                DispatchQueue.main.async {
                    result(FlutterError(code: "WRITE_ERROR", message: "Failed to write file at: \(path)", details: error.localizedDescription))
                }
            }
        }

        // Timeout after 20 seconds
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 20) {
            guard responded.setIfFalse() else { return }
            DispatchQueue.main.async {
                result(FlutterError(code: "TIMEOUT", message: "iCloud write timed out after 20s", details: "Path: \(path)"))
            }
        }
    }

    private func moveFile(sourcePath: String, destinationPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = URL(fileURLWithPath: destinationPath)
            let fileManager = FileManager.default
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                do {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                } catch {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    try? fileManager.removeItem(at: sourceURL)
                }
                DispatchQueue.main.async { result(true) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MOVE_ERROR", message: "Failed to move iCloud file", details: error.localizedDescription))
                }
            }
        }
    }

    /// Refreshes an iCloud folder by triggering downloads for all items.
    /// This ensures iOS sees the latest files synced from other devices.
    private func refreshFolder(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let folderURL = URL(fileURLWithPath: path)
            let fileManager = FileManager.default

            // First, trigger download of the folder itself
            if fileManager.isUbiquitousItem(at: folderURL) {
                do {
                    try fileManager.startDownloadingUbiquitousItem(at: folderURL)
                } catch {
                    // Ignore errors - folder might already be downloaded
                }
            }

            // Wait a moment for folder metadata to sync
            Thread.sleep(forTimeInterval: 0.5)

            // Enumerate folder contents and trigger download of each item
            guard let enumerator = fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
                options: [.skipsHiddenFiles]
            ) else {
                DispatchQueue.main.async { result(true) }
                return
            }

            var downloadCount = 0
            for case let fileURL as URL in enumerator {
                if fileManager.isUbiquitousItem(at: fileURL) {
                    do {
                        let values = try fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                        if values.ubiquitousItemDownloadingStatus != .current {
                            try fileManager.startDownloadingUbiquitousItem(at: fileURL)
                            downloadCount += 1
                        }
                    } catch {
                        // Continue with other files
                    }
                }
            }

            // If we triggered any downloads, wait a bit for them to start
            if downloadCount > 0 {
                Thread.sleep(forTimeInterval: 1.0)
            }

            DispatchQueue.main.async { result(true) }
        }
    }

    private func isDownloaded(url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey
            ])
            if values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
                return true
            }
            if values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.downloaded {
                return true
            }
        } catch {
            return false
        }
        return false
    }
}
