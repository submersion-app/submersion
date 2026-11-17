import Foundation
#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif

/// The `submersion_vision` channel. Every call runs on one serial background
/// queue, so models are never loaded and used at the same time, and the
/// reply goes back on the main thread.
public class SubmersionVisionPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "app.submersion.vision", qos: .userInitiated)
  private let pipeline = VisionPipeline()

  /// Devices with less memory than this cannot hold the embedding model.
  /// Phones sold as 6 GB report about 5.5 GiB.
  private static let minimumMemoryBytes: UInt64 = 5 * 1024 * 1024 * 1024

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "submersion_vision", binaryMessenger: messenger)
    let instance = SubmersionVisionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    #if os(iOS)
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(memoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification,
      object: nil
    )
    #endif
  }

  @objc private func memoryWarning() {
    queue.async { [pipeline] in pipeline.unload() }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "availability":
      result(Self.availability())
    case "load":
      run(result) {
        try self.pipeline.load(VisionModelSettings(args))
        return nil
      }
    case "analyze":
      run(result) { try self.pipeline.analyze(args) }
    case "unload":
      run(result) { self.pipeline.unload(); return nil }
    case "excludeFromBackup":
      run(result) {
        guard let path = args["path"] as? String else {
          throw VisionError.badArguments("path")
        }
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return nil
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func availability() -> String {
    #if os(iOS)
    return ProcessInfo.processInfo.physicalMemory < minimumMemoryBytes
      ? "deviceNotEligible" : "available"
    #else
    return "available"
    #endif
  }

  private func run(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    queue.async {
      let reply: Any?
      do {
        reply = try autoreleasepool { try work() }
      } catch let error as VisionError {
        reply = FlutterError(code: error.code, message: error.message, details: nil)
      } catch {
        reply = FlutterError(
          code: "inference_failed", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(reply) }
    }
  }
}

enum VisionError: Error {
  case notLoaded
  case decodeFailed(String)
  case inferenceFailed(String)
  case badArguments(String)

  var code: String {
    switch self {
    case .notLoaded: return "not_loaded"
    case .decodeFailed: return "decode_failed"
    case .inferenceFailed: return "inference_failed"
    case .badArguments: return "bad_arguments"
    }
  }

  var message: String {
    switch self {
    case .notLoaded: return "The models are not loaded"
    case .decodeFailed(let detail): return "Could not read the image: \(detail)"
    case .inferenceFailed(let detail): return detail
    case .badArguments(let name): return "Missing or invalid argument: \(name)"
    }
  }
}
