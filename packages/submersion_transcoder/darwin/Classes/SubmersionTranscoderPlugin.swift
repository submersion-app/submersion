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
