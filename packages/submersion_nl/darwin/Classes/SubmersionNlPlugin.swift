import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Foundation Models behind the `submersion_nl` channel. Every use of
/// the framework sits behind an availability check, so the plugin builds and
/// runs on the current deployment targets and reports `deviceNotEligible`
/// where the framework is absent.
public class SubmersionNlPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let instance = SubmersionNlPlugin()
    let channel = FlutterMethodChannel(name: "submersion_nl", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(name: "submersion_nl/download", binaryMessenger: messenger)
    events.setStreamHandler(instance)
  }

  // Apple downloads the model itself; the download stream is empty here.
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    events(FlutterEndOfEventStream)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }

  private var instructions: String = ""
  private var vocabulary: [String: Any] = [:]
  private var sessionBox: AnyObject?

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "availability":
      result(availability(localeTag: args["locale"] as? String ?? "en"))
    case "prepare":
      instructions = args["instructions"] as? String ?? ""
      vocabulary = args["vocabulary"] as? [String: Any] ?? [:]
      prepare()
      result(nil)
    case "compile":
      guard let sentence = args["sentence"] as? String else {
        result(FlutterError(code: "decoding_failure", message: "missing sentence", details: nil))
        return
      }
      compile(sentence: sentence, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func availability(localeTag: String) -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let model = SystemLanguageModel.default
      switch model.availability {
      case .available:
        return model.supportsLocale(Locale(identifier: localeTag)) ? "available" : "unsupportedLocale"
      case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible: return "deviceNotEligible"
        case .appleIntelligenceNotEnabled: return "notEnabled"
        case .modelNotReady: return "modelNotReady"
        @unknown default: return "modelNotReady"
        }
      @unknown default:
        return "modelNotReady"
      }
    }
    #endif
    return "deviceNotEligible"
  }

  private func prepare() {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let session = LanguageModelSession(instructions: instructions)
      session.prewarm()
      sessionBox = session
    }
    #endif
  }

  private func compile(sentence: String, result: @escaping FlutterResult) {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      Task {
        do {
          if sessionBox == nil { prepare() }
          guard let session = sessionBox as? LanguageModelSession else {
            result(FlutterError(code: "model_not_ready", message: nil, details: nil))
            return
          }
          let schema = try GenerationSchema(root: Self.querySchema(vocabulary), dependencies: [])
          let response = try await session.respond(to: sentence, schema: schema)
          result(response.content.jsonString)
        } catch {
          result(Self.mapError(error))
        }
      }
      return
    }
    #endif
    result(FlutterError(code: "model_not_ready", message: "FoundationModels unavailable", details: nil))
  }

  #if canImport(FoundationModels)
  /// Builds the schema v1 shape from the vocabulary Dart shipped, so the enum
  /// lists are owned in one place and the model cannot emit a field or op the
  /// compiler does not know. `value` is a string: a property has one type, and
  /// the Dart side unquotes numbers, lists and booleans.
  @available(iOS 26.0, macOS 26.0, *)
  private static func querySchema(_ vocab: [String: Any]) -> DynamicGenerationSchema {
    func strings(_ key: String) -> [String] { vocab[key] as? [String] ?? [] }
    let clause = DynamicGenerationSchema(
      name: "Clause",
      properties: [
        .init(name: "field", schema: DynamicGenerationSchema(name: "Field", anyOf: strings("fields"))),
        .init(name: "op", schema: DynamicGenerationSchema(name: "Op", anyOf: strings("ops"))),
        .init(name: "value", schema: DynamicGenerationSchema(type: String.self)),
        .init(name: "unit", schema: DynamicGenerationSchema(name: "Unit", anyOf: strings("units") + ["none"])),
        .init(name: "text", schema: DynamicGenerationSchema(type: String.self)),
      ])
    let mention = DynamicGenerationSchema(
      name: "Mention",
      properties: [
        .init(name: "kind", schema: DynamicGenerationSchema(name: "Kind", anyOf: strings("mentionKinds"))),
        .init(name: "text", schema: DynamicGenerationSchema(type: String.self)),
      ])
    let time = DynamicGenerationSchema(
      name: "Time",
      properties: [.init(name: "text", schema: DynamicGenerationSchema(type: String.self))])
    return DynamicGenerationSchema(
      name: "ParsedQuery",
      properties: [
        .init(name: "schemaVersion", schema: DynamicGenerationSchema(type: Int.self)),
        .init(name: "subject", schema: DynamicGenerationSchema(name: "Subject", anyOf: strings("subjects"))),
        .init(name: "clauses", schema: DynamicGenerationSchema(arrayOf: clause)),
        .init(name: "mentions", schema: DynamicGenerationSchema(arrayOf: mention)),
        .init(name: "time", schema: time, isOptional: true),
        .init(name: "unplaced", schema: DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(type: String.self))),
      ])
  }

  /// Maps by case name so both the 26.x GenerationError and the 27.x
  /// LanguageModelError families land on the documented channel codes.
  @available(iOS 26.0, macOS 26.0, *)
  private static func mapError(_ error: Error) -> FlutterError {
    let text = String(describing: error)
    let code: String
    if text.contains("exceededContextWindowSize") { code = "context_exceeded" }
    else if text.contains("unsupportedLanguageOrLocale") { code = "unsupported_locale" }
    else if text.contains("guardrailViolation") { code = "guardrail" }
    else if text.contains("refusal") { code = "refusal" }
    else if text.contains("decodingFailure") || text.contains("unsupportedGuide") { code = "decoding_failure" }
    else if text.contains("assetsUnavailable") { code = "model_not_ready" }
    else if text.contains("rateLimited") { code = "quota_exceeded" }
    else { code = "unknown" }
    return FlutterError(code: code, message: error.localizedDescription, details: nil)
  }
  #endif
}
