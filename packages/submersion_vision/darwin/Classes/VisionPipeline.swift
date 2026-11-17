import CoreGraphics
import CoreML
import Foundation
import ImageIO
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

/// What the model pack says about running its two models.
struct VisionModelSettings: Equatable {
  let detectorPath: String
  let classifierPath: String
  let detectorInputSize: Int
  let detectorMean: [Float]
  let detectorStd: [Float]
  let scoreThreshold: Float
  let maxBoxes: Int
  let cropPadding: Double
  let classifierInputSize: Int
  let classifierMean: [Float]
  let classifierStd: [Float]
  let embeddingSize: Int
  let cropThumbnailSize: Int

  init(_ args: [String: Any]) throws {
    func string(_ key: String) throws -> String {
      guard let v = args[key] as? String, !v.isEmpty else { throw VisionError.badArguments(key) }
      return v
    }
    func int(_ key: String) throws -> Int {
      guard let v = args[key] as? NSNumber, v.intValue > 0 else { throw VisionError.badArguments(key) }
      return v.intValue
    }
    func double(_ key: String) throws -> Double {
      guard let v = args[key] as? NSNumber else { throw VisionError.badArguments(key) }
      return v.doubleValue
    }
    func triple(_ key: String) throws -> [Float] {
      guard let v = args[key] as? [NSNumber], v.count == 3 else { throw VisionError.badArguments(key) }
      return v.map { $0.floatValue }
    }
    detectorPath = try string("detectorPath")
    classifierPath = try string("classifierPath")
    detectorInputSize = try int("detectorInputSize")
    detectorMean = try triple("detectorMean")
    detectorStd = try triple("detectorStd")
    scoreThreshold = Float(try double("scoreThreshold"))
    maxBoxes = try int("maxBoxes")
    cropPadding = try double("cropPadding")
    classifierInputSize = try int("classifierInputSize")
    classifierMean = try triple("classifierMean")
    classifierStd = try triple("classifierStd")
    embeddingSize = try int("embeddingSize")
    cropThumbnailSize = try int("cropThumbnailSize")
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
  private var detector: MLModel?
  private var classifier: MLModel?

  func load(_ next: VisionModelSettings) throws {
    if next == settings, detector != nil, classifier != nil { return }
    unload()
    let config = MLModelConfiguration()
    config.computeUnits = .all
    detector = try MLModel(contentsOf: try Self.compiledModel(at: next.detectorPath), configuration: config)
    classifier = try MLModel(contentsOf: try Self.compiledModel(at: next.classifierPath), configuration: config)
    settings = next
  }

  func unload() {
    detector = nil
    classifier = nil
    settings = nil
  }

  func analyze(_ args: [String: Any]) throws -> [String: Any] {
    guard let settings = settings, let detector = detector, classifier != nil else {
      throw VisionError.notLoaded
    }
    let image = try Self.decode(args)
    let boxes = try detect(image, settings: settings, model: detector)
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
    return ["imageWidth": image.width, "imageHeight": image.height, "detections": detections]
  }

  /// The detector over an already decoded frame (a video's, issue #4675).
  func detectBoxes(in image: CGImage) throws -> [Box] {
    guard let settings = settings, let detector = detector else { throw VisionError.notLoaded }
    return try detect(image, settings: settings, model: detector)
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
    let embedding = try embed(crop, settings: settings, model: classifier)
    return [
      "pixelWidth": Int(bw.rounded()), "pixelHeight": Int(bh.rounded()),
      "crop": FlutterStandardTypedData(bytes: jpeg),
      "embedding": FlutterStandardTypedData(float32: embedding.withUnsafeBufferPointer { Data(buffer: $0) }),
    ]
  }

  // MARK: Detection

  struct Box {
    let x: Double, y: Double, w: Double, h: Double
    let score: Float
  }

  private func detect(_ image: CGImage, settings: VisionModelSettings, model: MLModel) throws -> [Box] {
    let size = settings.detectorInputSize
    // Resized straight to the square input, no letterbox, as the detector
    // was trained.
    guard let pixels = Self.rgba(image, into: CGRect(x: 0, y: 0, width: size, height: size), canvas: size, fill: nil) else {
      throw VisionError.decodeFailed("could not draw the image")
    }
    let input = try Self.tensor(pixels, size: size, mean: settings.detectorMean, std: settings.detectorStd)
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

  // MARK: Embedding

  private func embed(_ crop: CGImage, settings: VisionModelSettings, model: MLModel) throws -> [Float] {
    let size = settings.classifierInputSize
    // The crop is fitted inside the square, the rest filled with the mean
    // colour, so long fish are not cut.
    let scale = min(Double(size) / Double(crop.width), Double(size) / Double(crop.height))
    let w = Double(crop.width) * scale, h = Double(crop.height) * scale
    let rect = CGRect(x: (Double(size) - w) / 2, y: (Double(size) - h) / 2, width: w, height: h)
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
