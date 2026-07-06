import Vision
#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif

public class SubmersionOcrPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "submersion_ocr", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(SubmersionOcrPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizeText",
          let args = call.arguments as? [String: Any],
          let imageData = args["image"] as? FlutterStandardTypedData else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let cgImage = Self.cgImage(from: imageData.data) else {
      result(FlutterError(code: "decode_failed", message: "Could not decode image", details: nil))
      return
    }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)

    let request = VNRecognizeTextRequest { req, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        }
        return
      }
      var blocks: [[String: Any]] = []
      for obs in (req.results as? [VNRecognizedTextObservation]) ?? [] {
        guard let candidate = obs.topCandidates(1).first else { continue }
        // Vision boundingBox: normalized, bottom-left origin. Flip Y.
        let bb = obs.boundingBox
        blocks.append([
          "text": candidate.string,
          "left": Double(bb.minX * width),
          "top": Double((1.0 - bb.maxY) * height),
          "width": Double(bb.width * width),
          "height": Double(bb.height * height),
          "confidence": Double(candidate.confidence),
          "imageWidth": Double(width),
          "imageHeight": Double(height),
        ])
      }
      DispatchQueue.main.async {
        result(blocks)
      }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func cgImage(from data: Data) -> CGImage? {
    #if os(iOS)
    return UIImage(data: data)?.cgImage
    #else
    guard let ns = NSImage(data: data) else { return nil }
    var rect = CGRect(origin: .zero, size: ns.size)
    return ns.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    #endif
  }
}
