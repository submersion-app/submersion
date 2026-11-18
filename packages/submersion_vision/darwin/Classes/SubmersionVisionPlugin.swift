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
  private lazy var scanner = VideoScanner(pipeline: pipeline)

  /// Whether the app is in the foreground, where iOS lets it use the GPU.
  /// Written on the main thread, read on the queue between video frames.
  private let activeLock = NSLock()
  private var _active = true
  private var isActive: Bool {
    get { activeLock.lock(); defer { activeLock.unlock() }; return _active }
    set { activeLock.lock(); _active = newValue; activeLock.unlock() }
  }

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
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(enteringForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    instance.isActive = UIApplication.shared.applicationState != .background
    #endif
  }

  @objc private func enteredBackground() { isActive = false }
  @objc private func enteringForeground() { isActive = true }

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
    case "detectVideo":
      run(result) {
        try self.checkVideoAllowed()
        return try self.scanner.detect(args) { self.isActive }
      }
    case "embedMoments":
      run(result) {
        try self.checkVideoAllowed()
        return try self.scanner.embed(args) { self.isActive }
      }
    case "unload":
      run(result) { self.pipeline.unload(); return nil }
    case "memory":
      // On the queue, so the reading comes after the stage it follows.
      run(result) { MemoryReading.current() }
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

  /// A video scan runs only in the foreground (iOS refuses GPU work from
  /// the background) and on a device that is not hot (issue #4675).
  private func checkVideoAllowed() throws {
    if !isActive { throw VisionError.notForeground }
    switch ProcessInfo.processInfo.thermalState {
    case .serious, .critical: throw VisionError.tooHot
    default: break
    }
  }

  private static func availability() -> String {
    #if os(iOS)
    // The floor (MemoryFloor, in MemoryReading.swift) needs an 8 GB device.
    return MemoryFloor.isEligible(physicalMemory: ProcessInfo.processInfo.physicalMemory)
      ? "available" : "deviceNotEligible"
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
