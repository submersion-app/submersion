import AVFoundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

#if os(iOS)
/// One stretch of extra background time, ended exactly once: by the encode
/// finishing or by iOS running out of time. Used on the main thread only.
private final class BackgroundTask {
  private var id = UIBackgroundTaskIdentifier.invalid

  func begin(onExpiry: @escaping () -> Void) {
    id = UIApplication.shared.beginBackgroundTask { [weak self] in
      onExpiry()
      self?.end()
    }
  }

  func end() {
    guard id != .invalid else { return }
    UIApplication.shared.endBackgroundTask(id)
    id = .invalid
  }
}
#endif

public class SubmersionTranscoderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var progressSink: FlutterEventSink?
  // Colour encodes in flight, by progressId, for cancelEncode.
  private let cancelLock = NSLock()
  private var cancelFlags: [String: ColorEncodeCancelFlag] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let methods = FlutterMethodChannel(
      name: "submersion_transcoder/methods", binaryMessenger: messenger)
    let progress = FlutterEventChannel(
      name: "submersion_transcoder/progress", binaryMessenger: messenger)
    let instance = SubmersionTranscoderPlugin()
    registrar.addMethodCallDelegate(instance, channel: methods)
    progress.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "probe":
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(nil)
        return
      }
      // Building an AVAsset and reading track metadata can be slow for large
      // videos; keep it off the platform (main) thread so the UI never blocks.
      DispatchQueue.global(qos: .userInitiated).async {
        let probe = AvfTranscoder.probe(path: path)
        DispatchQueue.main.async { result(probe) }
      }
    case "transcode":
      guard let a = call.arguments as? [String: Any],
        let source = a["source"] as? String,
        let output = a["output"] as? String,
        let maxHeight = a["maxHeight"] as? Int,
        let vk = a["videoBitrateKbps"] as? Int,
        let ak = a["audioBitrateKbps"] as? Int,
        let progressId = a["progressId"] as? String
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "transcode requires: source, output, maxHeight, "
              + "videoBitrateKbps, audioBitrateKbps, progressId",
            details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        do {
          try AvfTranscoder.transcode(
            source: source, output: output,
            maxHeight: maxHeight, videoBitrateKbps: vk, audioBitrateKbps: ak,
            onProgress: { fraction in
              DispatchQueue.main.async {
                self?.progressSink?(
                  ["progressId": progressId, "fraction": fraction])
              }
            })
          DispatchQueue.main.async { result(nil) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "transcode_failed",
                message: error.localizedDescription, details: nil))
          }
        }
      }
    case "encodeWithColor":
      guard let a = call.arguments as? [String: Any],
        let source = a["source"] as? String,
        let output = a["output"] as? String,
        let rawTimeline = a["timeline"] as? [[String: Any]],
        let progressId = a["progressId"] as? String
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "encodeWithColor requires: source, output, timeline, progressId",
            details: nil))
        return
      }
      let keys = rawTimeline.compactMap { entry -> ColorTimelineKey? in
        guard let t = entry["t"] as? NSNumber, let m = entry["m"] as? [NSNumber],
          m.count == 20
        else { return nil }
        return ColorTimelineKey(timeMs: t.doubleValue, matrix: m.map { $0.floatValue })
      }
      let flag = ColorEncodeCancelFlag()
      cancelLock.lock()
      cancelFlags[progressId] = flag
      cancelLock.unlock()
      #if os(iOS)
      // iOS stops video encoding soon after the app leaves the screen; ask for
      // the extra time, and stop cleanly when it runs out. The expiration
      // handler must end the task itself, or iOS terminates the app.
      let background = BackgroundTask()
      background.begin { flag.set() }
      #endif
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        var failure: FlutterError?
        do {
          try ColorEncoder.encode(
            source: source, output: output, keys: keys,
            location: a["location"] as? String,
            onProgress: { fraction in
              DispatchQueue.main.async {
                self?.progressSink?(["progressId": progressId, "fraction": fraction])
              }
            },
            isCancelled: { flag.isSet })
        } catch ColorEncodeError.cancelled {
          failure = FlutterError(code: "cancelled", message: nil, details: nil)
        } catch ColorEncodeError.unsupported(let detail) {
          failure = FlutterError(code: "unsupported", message: detail, details: nil)
        } catch {
          failure = FlutterError(
            code: "transcode_failed", message: error.localizedDescription, details: nil)
        }
        DispatchQueue.main.async {
          self?.cancelLock.lock()
          self?.cancelFlags[progressId] = nil
          self?.cancelLock.unlock()
          #if os(iOS)
          background.end()
          #endif
          result(failure)
        }
      }
    case "cancelEncode":
      if let a = call.arguments as? [String: Any],
        let progressId = a["progressId"] as? String
      {
        cancelLock.lock()
        let flag = cancelFlags[progressId]
        cancelLock.unlock()
        flag?.set()
      }
      result(nil)
    case "extractFrames":
      guard let a = call.arguments as? [String: Any],
        let path = a["path"] as? String,
        let timesMs = a["timesMs"] as? [Int]
      else {
        result(nil)
        return
      }
      let maxDimension = min(max(a["maxDimension"] as? Int ?? 160, 16), 2048)
      let exact = a["exact"] as? Bool ?? false
      // Seeking and decoding frames is slow on long clips; keep it off the
      // platform (main) thread.
      DispatchQueue.global(qos: .utility).async {
        let frames = FrameExtractor.extract(
          path: path, timesMs: timesMs, maxDimension: maxDimension, exact: exact)
        let reply = frames.map { frame -> Any in
          if let data = frame as? Data {
            return FlutterStandardTypedData(bytes: data)
          }
          return NSNull()
        }
        DispatchQueue.main.async { result(reply) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    progressSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    progressSink = nil
    return nil
  }
}
