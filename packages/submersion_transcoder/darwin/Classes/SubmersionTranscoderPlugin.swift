import AVFoundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

public class SubmersionTranscoderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var progressSink: FlutterEventSink?

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
          FlutterError(code: "bad_args", message: "transcode args", details: nil))
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
