import CoreGraphics
import CoreML
import Foundation
import ImageIO
// Imported only where it exists, so the accuracy tool in
// tool/species_pack/vision_cli can compile this file on its own.
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

enum VisionError: Error {
  case notLoaded
  case decodeFailed(String)
  case inferenceFailed(String)
  case badArguments(String)
  case notForeground
  case tooHot

  var code: String {
    switch self {
    case .notLoaded: return "not_loaded"
    case .decodeFailed: return "decode_failed"
    case .inferenceFailed: return "inference_failed"
    case .badArguments: return "bad_arguments"
    case .notForeground: return "not_foreground"
    case .tooHot: return "too_hot"
    }
  }

  var message: String {
    switch self {
    case .notLoaded: return "The models are not loaded"
    case .decodeFailed(let detail): return "Could not read the image: \(detail)"
    case .inferenceFailed(let detail): return detail
    case .badArguments(let name): return "Missing or invalid argument: \(name)"
    case .notForeground: return "The app is not in the foreground"
    case .tooHot: return "The device is too hot"
    }
  }
}

/// How the detector's input is prepared and its output read.
enum DetectorFormat: String {
  /// RF-DETR (the Community Fish Detector): the image resized straight to
  /// the square, 300 boxes with raw scores, no overlap suppression.
  case rfdetr
  /// YOLO (FathomNet's Megalodon): the image letterboxed into the square,
  /// one output of boxes and squashed scores per anchor, overlapping boxes
  /// suppressed.
  case yolo
}

/// How a crop is fitted to the classifier's square input.
enum CropFit: String {
  /// Fitted whole inside the square, the rest filled with the mean colour,
  /// so long fish are not cut.
  case padSquare
  /// Shorter side fitted to the square and the centre kept, as the spike
  /// did; the ends of a long fish are cut off.
  case centreCrop
}

/// Reads typed values from the channel's arguments, naming the bad key.
private struct Arguments {
  let values: [String: Any]

  func string(_ key: String) throws -> String {
    guard let v = values[key] as? String, !v.isEmpty else { throw VisionError.badArguments(key) }
    return v
  }

  func int(_ key: String) throws -> Int {
    guard let v = values[key] as? NSNumber, v.intValue > 0 else { throw VisionError.badArguments(key) }
    return v.intValue
  }

  func double(_ key: String) throws -> Double {
    guard let v = values[key] as? NSNumber, v.doubleValue.isFinite else { throw VisionError.badArguments(key) }
    return v.doubleValue
  }

  func triple(_ key: String) throws -> [Float] {
    guard let v = values[key] as? [NSNumber], v.count == 3 else { throw VisionError.badArguments(key) }
    return v.map { $0.floatValue }
  }
}

/// One detector of a pack (issue #4691): its model and how it is run.
struct DetectorSettings: Equatable {
  let path: String
  let format: DetectorFormat
  let inputSize: Int
  let mean: [Float]
  let std: [Float]
  let scoreThreshold: Float
  let maxBoxes: Int

  init(_ values: [String: Any]) throws {
    let args = Arguments(values: values)
    path = try args.string("path")
    guard let format = DetectorFormat(rawValue: try args.string("format")) else {
      throw VisionError.badArguments("format")
    }
    self.format = format
    inputSize = try args.int("inputSize")
    mean = try args.triple("mean")
    std = try args.triple("std")
    scoreThreshold = Float(try args.double("scoreThreshold"))
    maxBoxes = try args.int("maxBoxes")
  }
}

/// What the model pack says about running its detectors and classifier.
struct VisionModelSettings: Equatable {
  /// One or two, in the pack's order.
  let detectors: [DetectorSettings]
  /// Two detectors' boxes overlapping this much or more are one animal.
  let mergeIoU: Double
  /// At most this many boxes once two detectors' boxes are merged.
  let maxBoxes: Int
  let cropPadding: Double
  let classifierPath: String
  let classifierInputSize: Int
  let classifierMean: [Float]
  let classifierStd: [Float]
  let embeddingSize: Int
  let cropThumbnailSize: Int
  let cropFit: CropFit

  init(_ values: [String: Any]) throws {
    let args = Arguments(values: values)
    guard let list = values["detectors"] as? [[String: Any]], (1...2).contains(list.count) else {
      throw VisionError.badArguments("detectors")
    }
    detectors = try list.map(DetectorSettings.init)
    mergeIoU = try args.double("mergeIoU")
    guard mergeIoU > 0, mergeIoU <= 1 else { throw VisionError.badArguments("mergeIoU") }
    maxBoxes = try args.int("maxBoxes")
    cropPadding = try args.double("cropPadding")
    classifierPath = try args.string("classifierPath")
    classifierInputSize = try args.int("classifierInputSize")
    classifierMean = try args.triple("classifierMean")
    classifierStd = try args.triple("classifierStd")
    embeddingSize = try args.int("embeddingSize")
    cropThumbnailSize = try args.int("cropThumbnailSize")
    // Absent means pad-to-square, which every app before fittings sent.
    if let fit = values["cropFit"] {
      guard let name = fit as? String, let parsed = CropFit(rawValue: name) else {
        throw VisionError.badArguments("cropFit")
      }
      cropFit = parsed
    } else {
      cropFit = .padSquare
    }
  }
}

/// Decodes an image, finds the animals, crops and embeds each one.
/// Used only from the plugin's serial queue.
final class VisionPipeline {
  /// The decoded image's longer side is capped here, so a very large photo
  /// cannot exhaust memory. Boxes are normalised, so nothing downstream
  /// depends on the cap.
  private static let maxImageSide = 4096

  private var settings: VisionModelSettings?
  /// One per detector setting, in the same order.
  private var detectors: [MLModel] = []
  private var classifier: MLModel?

  func load(_ next: VisionModelSettings) throws {
    if next == settings, detectors.count == next.detectors.count, classifier != nil { return }
    unload()
    let config = MLModelConfiguration()
    config.computeUnits = .all
    detectors = try next.detectors.map {
      try MLModel(contentsOf: try Self.compiledModel(at: $0.path), configuration: config)
    }
    classifier = try MLModel(contentsOf: try Self.compiledModel(at: next.classifierPath), configuration: config)
    settings = next
  }

  func unload() {
    detectors = []
    classifier = nil
    settings = nil
  }

  func analyze(_ args: [String: Any]) throws -> [String: Any] {
    guard settings != nil, !detectors.isEmpty, classifier != nil else {
      throw VisionError.notLoaded
    }
    let image = try Self.decode(args)
    let detectStart = Date()
    let runs = try detectEach(in: image)
    let boxes = try combined(runs)
    let detectMs = Date().timeIntervalSince(detectStart) * 1000
    var detections: [[String: Any]] = []
    for box in boxes {
      // No crop to show for it, so no suggestion either.
      guard var detection = try cropAndEmbed(image, x: box.x, y: box.y, w: box.w, h: box.h) else {
        continue
      }
      detection["x"] = box.x
      detection["y"] = box.y
      detection["width"] = box.w
      detection["height"] = box.h
      detection["score"] = Double(box.score)
      detections.append(detection)
    }
    var reply: [String: Any] = [
      "imageWidth": image.width, "imageHeight": image.height, "detections": detections,
      "detectMs": detectMs,
    ]
    // Each detector's own boxes and the merged boxes, before any is
    // cropped, for the accuracy tool's check that the merge matches the one
    // it measured. The app never asks.
    if args["withDetectorBoxes"] as? Bool == true {
      func plain(_ run: [Box]) -> [[String: Any]] {
        run.map { ["x": $0.x, "y": $0.y, "w": $0.w, "h": $0.h, "score": Double($0.score)] }
      }
      reply["detectorBoxes"] = runs.map(plain)
      reply["mergedBoxes"] = plain(boxes)
    }
    return reply
  }

  /// The detectors over an already decoded frame (a video's, issue #4675),
  /// merged when there are two.
  func detectBoxes(in image: CGImage) throws -> [Box] {
    try combined(try detectEach(in: image))
  }

  /// Each detector's boxes, in the pack's order.
  func detectEach(in image: CGImage) throws -> [[Box]] {
    guard let settings = settings, !detectors.isEmpty else { throw VisionError.notLoaded }
    return try zip(settings.detectors, detectors).map { detector, model in
      try detect(image, settings: detector, model: model)
    }
  }

  /// One detector's boxes as they are, as every one-detector pack has
  /// always had them; two detectors' merged.
  private func combined(_ runs: [[Box]]) throws -> [Box] {
    guard let settings = settings else { throw VisionError.notLoaded }
    if runs.count == 1 { return runs[0] }
    return Self.merge(runs, iou: settings.mergeIoU, limit: settings.maxBoxes)
  }

  /// The box at normalised [x, y, w, h] of [image], padded, cropped and
  /// embedded: `{pixelWidth, pixelHeight, crop, embedding}`, or nil when
  /// the crop is too small to read. Shared by photos and video moments.
  func cropAndEmbed(_ image: CGImage, x: Double, y: Double, w: Double, h: Double) throws -> [String: Any]? {
    guard let settings = settings, let classifier = classifier else { throw VisionError.notLoaded }
    let width = image.width
    let height = image.height
    // Pixel box of the detection, then padded for the crop.
    let bx = x * Double(width), by = y * Double(height)
    let bw = w * Double(width), bh = h * Double(height)
    let padX = bw * settings.cropPadding, padY = bh * settings.cropPadding
    let cropRect = CGRect(
      x: max(0, bx - padX), y: max(0, by - padY),
      width: min(Double(width), bx + bw + padX) - max(0, bx - padX),
      height: min(Double(height), by + bh + padY) - max(0, by - padY)
    ).integral
    guard cropRect.width >= 2, cropRect.height >= 2, let crop = image.cropping(to: cropRect),
          let jpeg = Self.jpeg(Self.fitted(crop, within: settings.cropThumbnailSize)) else {
      return nil
    }
    let embedStart = Date()
    let embedding = try embed(crop, settings: settings, model: classifier)
    // Read by the accuracy tool (tool/species_pack); the app ignores it.
    let embedMs = Date().timeIntervalSince(embedStart) * 1000
    return [
      "pixelWidth": Int(bw.rounded()), "pixelHeight": Int(bh.rounded()),
      "crop": FlutterStandardTypedData(bytes: jpeg),
      "embedding": FlutterStandardTypedData(float32: embedding.withUnsafeBufferPointer { Data(buffer: $0) }),
      "embedMs": embedMs,
    ]
  }

  // MARK: Detection

  struct Box {
    let x: Double, y: Double, w: Double, h: Double
    let score: Float
  }

  /// Several detectors' boxes as one set, as the accuracy scorer merged
  /// them (tool/species_pack/boxes.py `merge`): all boxes pooled in run
  /// order, best score first (equal scores keep pool order, as Python's
  /// stable sort does), each dropped if it overlaps a kept box by [iou] or
  /// more, at most [limit].
  static func merge(_ runs: [[Box]], iou: Double, limit: Int) -> [Box] {
    let pooled = runs.flatMap { $0 }
    let order = pooled.indices.sorted { a, b in
      pooled[a].score != pooled[b].score ? pooled[a].score > pooled[b].score : a < b
    }
    var kept: [Box] = []
    for i in order {
      let box = pooled[i]
      if kept.allSatisfy({ overlap(box, $0) < iou }) { kept.append(box) }
      if kept.count == limit { break }
    }
    return kept
  }

  /// Intersection over union of two boxes, computed as boxes.py `iou`
  /// does, so a merge decided at the threshold goes the same way.
  static func overlap(_ a: Box, _ b: Box) -> Double {
    let ix = max(0, min(a.x + a.w, b.x + b.w) - max(a.x, b.x))
    let iy = max(0, min(a.y + a.h, b.y + b.h) - max(a.y, b.y))
    let inter = ix * iy
    let union = a.w * a.h + b.w * b.h - inter
    return union > 0 ? inter / union : 0
  }

  private func detect(_ image: CGImage, settings: DetectorSettings, model: MLModel) throws -> [Box] {
    if settings.format == .yolo {
      return try detectYolo(image, settings: settings, model: model)
    }
    let size = settings.inputSize
    // Resized straight to the square input, no letterbox, as the detector
    // was trained.
    guard let pixels = Self.rgba(image, into: CGRect(x: 0, y: 0, width: size, height: size), canvas: size, fill: nil) else {
      throw VisionError.decodeFailed("could not draw the image")
    }
    let input = try Self.tensor(pixels, size: size, mean: settings.mean, std: settings.std)
    let output = try model.prediction(from: try Self.features(model, input))

    var boxArray: MLMultiArray?
    var scoreArray: MLMultiArray?
    for name in output.featureNames {
      guard let array = output.featureValue(for: name)?.multiArrayValue else { continue }
      let shape = array.shape.map { $0.intValue }
      if shape.count == 3, shape[2] == 4 { boxArray = array }
      else if shape.count == 3 { scoreArray = array }
    }
    guard let boxesOut = boxArray, let scoresOut = scoreArray else {
      throw VisionError.inferenceFailed("detector outputs not found")
    }
    let queries = boxesOut.shape[1].intValue
    let classes = scoresOut.shape[2].intValue
    let boxValues = Self.floats(boxesOut)
    let scoreValues = Self.floats(scoresOut)
    // A model whose two outputs disagree would read past the end below.
    guard classes > 0, scoresOut.shape[1].intValue == queries,
          boxValues.count >= queries * 4, scoreValues.count >= queries * classes else {
      throw VisionError.inferenceFailed("detector outputs do not match")
    }

    var found: [Box] = []
    for q in 0..<queries {
      var best: Float = -.infinity
      for c in 0..<classes { best = max(best, scoreValues[q * classes + c]) }
      let score = 1 / (1 + exp(-best))
      guard score >= settings.scoreThreshold else { continue }
      let cx = Double(boxValues[q * 4]), cy = Double(boxValues[q * 4 + 1])
      let w = Double(boxValues[q * 4 + 2]), h = Double(boxValues[q * 4 + 3])
      let x0 = min(max(cx - w / 2, 0), 1), y0 = min(max(cy - h / 2, 0), 1)
      let x1 = min(max(cx + w / 2, 0), 1), y1 = min(max(cy + h / 2, 0), 1)
      guard x1 > x0, y1 > y0 else { continue }
      found.append(Box(x: x0, y: y0, w: x1 - x0, h: y1 - y0, score: score))
    }
    found.sort { $0.score > $1.score }
    return Array(found.prefix(settings.maxBoxes))
  }

  /// Grey 114, as YOLO models are trained with.
  private static let letterboxFill: [Float] = [114 / 255, 114 / 255, 114 / 255]
  private static let yoloSuppressIoU = 0.7

  private func detectYolo(_ image: CGImage, settings: DetectorSettings, model: MLModel) throws -> [Box] {
    let size = settings.inputSize
    let rect = Self.letterboxRect(width: image.width, height: image.height, size: size)
    guard let pixels = Self.rgba(image, into: rect, canvas: size, fill: Self.letterboxFill) else {
      throw VisionError.decodeFailed("could not draw the image")
    }
    let input = try Self.tensor(pixels, size: size, mean: settings.mean, std: settings.std)
    let output = try model.prediction(from: try Self.features(model, input))
    guard let array = output.featureNames.lazy.compactMap({ output.featureValue(for: $0)?.multiArrayValue })
      .first(where: { $0.shape.count == 3 }) else {
      throw VisionError.inferenceFailed("detector output not found")
    }
    // [1, 4 + classes, anchors]: centre and size in input pixels, then
    // scores already squashed to 0 to 1.
    let channels = array.shape[1].intValue, anchors = array.shape[2].intValue
    let values = Self.floats(array)
    guard channels >= 5, values.count >= channels * anchors else {
      throw VisionError.inferenceFailed("detector output has an unexpected shape")
    }
    let sx = rect.width / Double(image.width), sy = rect.height / Double(image.height)
    var found: [Box] = []
    for a in 0..<anchors {
      var score: Float = 0
      for c in 4..<channels { score = max(score, values[c * anchors + a]) }
      guard score >= settings.scoreThreshold else { continue }
      let cx = Double(values[a]), cy = Double(values[anchors + a])
      let w = Double(values[2 * anchors + a]), h = Double(values[3 * anchors + a])
      // Out of the letterbox, into the image's 0 to 1.
      let x0 = min(max((cx - w / 2 - rect.minX) / sx / Double(image.width), 0), 1)
      let y0 = min(max((cy - h / 2 - rect.minY) / sy / Double(image.height), 0), 1)
      let x1 = min(max((cx + w / 2 - rect.minX) / sx / Double(image.width), 0), 1)
      let y1 = min(max((cy + h / 2 - rect.minY) / sy / Double(image.height), 0), 1)
      guard x1 > x0, y1 > y0 else { continue }
      found.append(Box(x: x0, y: y0, w: x1 - x0, h: y1 - y0, score: score))
    }
    return Self.suppress(found, iou: Self.yoloSuppressIoU, limit: settings.maxBoxes)
  }

  /// Where an image goes in a letterboxed square, as ultralytics places it:
  /// scaled to fit and rounded to whole pixels, centred.
  static func letterboxRect(width: Int, height: Int, size: Int) -> CGRect {
    let r = min(Double(size) / Double(width), Double(size) / Double(height))
    let w = (Double(width) * r).rounded(), h = (Double(height) * r).rounded()
    let left = ((Double(size) - w) / 2 - 0.1).rounded(), top = ((Double(size) - h) / 2 - 0.1).rounded()
    return CGRect(x: left, y: top, width: w, height: h)
  }

  /// The best boxes, dropping any that overlaps a better one by [iou] or
  /// more, at most [limit].
  private static func suppress(_ boxes: [Box], iou: Double, limit: Int) -> [Box] {
    var kept: [Box] = []
    for box in boxes.sorted(by: { $0.score > $1.score }) {
      if !kept.contains(where: { overlap(box, $0) >= iou }) { kept.append(box) }
      if kept.count == limit { break }
    }
    return kept
  }

  // MARK: Embedding

  private func embed(_ crop: CGImage, settings: VisionModelSettings, model: MLModel) throws -> [Float] {
    let size = settings.classifierInputSize
    let rect = Self.fitRect(width: crop.width, height: crop.height, size: size, fit: settings.cropFit)
    guard let pixels = Self.rgba(crop, into: rect, canvas: size, fill: settings.classifierMean) else {
      throw VisionError.decodeFailed("could not draw the crop")
    }
    let input = try Self.tensor(pixels, size: size, mean: settings.classifierMean, std: settings.classifierStd)
    let output = try model.prediction(from: try Self.features(model, input))
    guard let name = output.featureNames.first,
          let array = output.featureValue(for: name)?.multiArrayValue else {
      throw VisionError.inferenceFailed("classifier output not found")
    }
    let values = Self.floats(array)
    guard values.count == settings.embeddingSize else {
      throw VisionError.inferenceFailed("embedding has \(values.count) values, expected \(settings.embeddingSize)")
    }
    return values
  }

  // MARK: Helpers

  /// Where a crop of [width] by [height] is drawn in the [size]-pixel
  /// square: inside it for pad-to-square, covering it for centre crop.
  /// Centred either way; the canvas clips what falls outside.
  static func fitRect(width: Int, height: Int, size: Int, fit: CropFit) -> CGRect {
    let sx = Double(size) / Double(width), sy = Double(size) / Double(height)
    let scale = fit == .padSquare ? min(sx, sy) : max(sx, sy)
    let w = Double(width) * scale, h = Double(height) * scale
    return CGRect(x: (Double(size) - w) / 2, y: (Double(size) - h) / 2, width: w, height: h)
  }

  /// A compiled model directory, compiling a model package once beside it.
  /// The package is deleted once compiled: keeping both would double the
  /// space the model takes on the device.
  private static func compiledModel(at path: String) throws -> URL {
    let url = URL(fileURLWithPath: path)
    if url.pathExtension == "mlmodelc" { return url }
    let target = url.deletingPathExtension().appendingPathExtension("mlmodelc")
    let fm = FileManager.default
    if fm.fileExists(atPath: target.path) { return target }
    let compiled = try MLModel.compileModel(at: url)
    try? fm.removeItem(at: target)
    try fm.moveItem(at: compiled, to: target)
    try? fm.removeItem(at: url)
    return target
  }

  private static func decode(_ args: [String: Any]) throws -> CGImage {
    let source: CGImageSource?
    if let path = args["path"] as? String {
      source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
    } else if let bytes = args["bytes"] as? FlutterStandardTypedData {
      source = CGImageSourceCreateWithData(bytes.data as CFData, nil)
    } else {
      throw VisionError.badArguments("path or bytes")
    }
    guard let src = source else { throw VisionError.decodeFailed("unreadable") }
    // The thumbnail API applies EXIF orientation and bounds the size.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxImageSide,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
      throw VisionError.decodeFailed("no image")
    }
    return image
  }

  /// RGBA bytes of [image] drawn into [rect] of a [canvas]-pixel square,
  /// over [fill] (normalised 0 to 1 RGB) where given. Origin top-left.
  private static func rgba(_ image: CGImage, into rect: CGRect, canvas: Int, fill: [Float]?) -> [UInt8]? {
    var bytes = [UInt8](repeating: 0, count: canvas * canvas * 4)
    let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(
        data: buffer.baseAddress, width: canvas, height: canvas, bitsPerComponent: 8,
        bytesPerRow: canvas * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      ) else { return false }
      context.interpolationQuality = .high
      if let fill = fill {
        context.setFillColor(red: CGFloat(fill[0]), green: CGFloat(fill[1]), blue: CGFloat(fill[2]), alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
      }
      // Core Graphics puts the origin bottom-left; flip so rect is top-left.
      let flipped = CGRect(x: rect.minX, y: CGFloat(canvas) - rect.maxY, width: rect.width, height: rect.height)
      context.draw(image, in: flipped)
      return true
    }
    return drawn ? bytes : nil
  }

  /// A `[1, 3, size, size]` float tensor, `(value / 255 - mean) / std`.
  private static func tensor(_ rgba: [UInt8], size: Int, mean: [Float], std: [Float]) throws -> MLMultiArray {
    let array = try MLMultiArray(shape: [1, 3, NSNumber(value: size), NSNumber(value: size)], dataType: .float32)
    let plane = size * size
    let out = array.dataPointer.bindMemory(to: Float.self, capacity: 3 * plane)
    for i in 0..<plane {
      for c in 0..<3 {
        out[c * plane + i] = (Float(rgba[i * 4 + c]) / 255 - mean[c]) / std[c]
      }
    }
    return array
  }

  private static func features(_ model: MLModel, _ input: MLMultiArray) throws -> MLFeatureProvider {
    guard let name = model.modelDescription.inputDescriptionsByName.keys.first else {
      throw VisionError.inferenceFailed("model has no input")
    }
    return try MLDictionaryFeatureProvider(dictionary: [name: MLFeatureValue(multiArray: input)])
  }

  /// Every value of [array] as Float in row-major order, whatever its
  /// storage type and layout. Core ML may hand back padded (strided)
  /// outputs, which are read element by element.
  private static func floats(_ array: MLMultiArray) -> [Float] {
    let count = array.count
    let shape = array.shape.map { $0.intValue }
    let strides = array.strides.map { $0.intValue }
    var contiguous = true
    var expected = 1
    for d in stride(from: shape.count - 1, through: 0, by: -1) {
      if shape[d] > 1 && strides[d] != expected { contiguous = false }
      expected *= shape[d]
    }
    if contiguous {
      switch array.dataType {
      case .float32:
        let p = array.dataPointer.bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: p, count: count))
      case .double:
        let p = array.dataPointer.bindMemory(to: Double.self, capacity: count)
        return (0..<count).map { Float(p[$0]) }
      default:
        break
      }
    }
    var values = [Float]()
    values.reserveCapacity(count)
    var index = [Int](repeating: 0, count: shape.count)
    for _ in 0..<count {
      values.append(array[index.map { NSNumber(value: $0) }].floatValue)
      var d = shape.count - 1
      while d >= 0 {
        index[d] += 1
        if index[d] < shape[d] { break }
        index[d] = 0
        d -= 1
      }
    }
    return values
  }

  private static func fitted(_ image: CGImage, within side: Int) -> CGImage {
    let longer = max(image.width, image.height)
    guard longer > side else { return image }
    let scale = Double(side) / Double(longer)
    let w = max(1, Int((Double(image.width) * scale).rounded()))
    let h = max(1, Int((Double(image.height) * scale).rounded()))
    guard let context = CGContext(
      data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return image }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return context.makeImage() ?? image
  }

  private static func jpeg(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }
}
