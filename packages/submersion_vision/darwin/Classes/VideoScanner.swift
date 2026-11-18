import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

/// The two passes over a video (issue #4675). Pass 1 decodes part of the
/// video in order at a small size and runs only the detector on a few
/// frames a second. Pass 2 fetches chosen moments at full size and crops
/// and embeds them. Tracking and naming are done in Dart.
///
/// Used only from the plugin's serial queue, like [VisionPipeline].
final class VideoScanner {
  /// Pass 1's frames are decoded with the longer side at most this: the
  /// detector's input is 640 pixels, so nothing larger helps it.
  private static let detectSide: CGFloat = 960

  /// Pass 2's frames are capped like a photo's.
  private static let embedSide: CGFloat = 4096

  private let pipeline: VisionPipeline
  private lazy var context = CIContext(options: [.cacheIntermediates: false])

  init(pipeline: VisionPipeline) {
    self.pipeline = pipeline
  }

  /// `{width, height, durationMs, frames: [{ms, boxes: [{x, y, width,
  /// height, score}]}]}`. Throws `notForeground` when [stillWanted] turns
  /// false (the app left the foreground) and `decodeFailed` when the reader
  /// fails: a chunk cut short is never returned as if it were whole.
  func detect(_ args: [String: Any], stillWanted: () -> Bool) throws -> [String: Any] {
    guard let path = args["path"] as? String,
          let startMs = (args["startMs"] as? NSNumber)?.intValue,
          let endMs = (args["endMs"] as? NSNumber)?.intValue,
          let interval = (args["sampleIntervalMs"] as? NSNumber)?.intValue, interval > 0 else {
      throw VisionError.badArguments("path, startMs, endMs or sampleIntervalMs")
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw VisionError.decodeFailed("no video track")
    }
    // An indefinite or invalid length would trap the conversion below.
    let seconds = CMTimeGetSeconds(asset.duration)
    guard asset.duration.isNumeric, seconds.isFinite, seconds >= 0 else {
      throw VisionError.decodeFailed("no readable length")
    }
    let durationMs = Int((seconds * 1000).rounded())
    let natural = track.naturalSize
    let shown = natural.applying(track.preferredTransform)
    let orientation = Self.orientation(of: track.preferredTransform)
    var reply: [String: Any] = [
      "width": Int(abs(shown.width).rounded()),
      "height": Int(abs(shown.height).rounded()),
      "durationMs": durationMs,
    ]
    let end = min(endMs, durationMs)
    guard end > startMs, natural.width > 0, natural.height > 0 else {
      reply["frames"] = []
      return reply
    }

    let scale = min(1, Self.detectSide / max(natural.width, natural.height))
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: Int((natural.width * scale).rounded()),
      kCVPixelBufferHeightKey as String: Int((natural.height * scale).rounded()),
    ])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    reader.timeRange = CMTimeRange(
      start: CMTime(value: CMTimeValue(startMs), timescale: 1000),
      end: CMTime(value: CMTimeValue(end), timescale: 1000)
    )
    guard reader.startReading() else {
      throw VisionError.decodeFailed(reader.error?.localizedDescription ?? "unreadable")
    }
    defer { reader.cancelReading() }

    var frames: [[String: Any]] = []
    var next = startMs
    reading: while next < end, stillWanted() {
      let step: Step = try autoreleasepool {
        guard let sample = output.copyNextSampleBuffer() else { return .end }
        // A marker buffer may carry no usable time; converting it would trap.
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        guard time.isNumeric else { return .skip }
        let ms = Int((CMTimeGetSeconds(time) * 1000).rounded())
        // Frames between the sampled times are decoded but not looked at.
        guard ms >= next, let pixels = CMSampleBufferGetImageBuffer(sample) else { return .skip }
        while next <= ms { next += interval }
        guard let image = frameImage(pixels, orientation: orientation) else { return .skip }
        let boxes = try pipeline.detectBoxes(in: image)
        return .frame([
          "ms": ms,
          "boxes": boxes.map { box -> [String: Any] in
            ["x": box.x, "y": box.y, "width": box.w, "height": box.h, "score": Double(box.score)]
          },
        ])
      }
      switch step {
      case .frame(let frame): frames.append(frame)
      case .skip: continue
      case .end: break reading
      }
    }
    // A chunk cut short is not a chunk scanned: the caller must not mark
    // its time as done. The reader also stops early when decoding fails
    // (or iOS suspends the decoder before the app is marked inactive).
    if next < end, !stillWanted() { throw VisionError.notForeground }
    // Short of the end, only a reader that completed has read all there
    // is: the last frame starts before the last sampled time, or the video
    // track ends before the asset's length. Any other stop is a failure.
    if reader.status == .failed || (next < end && reader.status != .completed) {
      throw VisionError.decodeFailed(reader.error?.localizedDescription ?? "reader stopped early")
    }
    reply["frames"] = frames
    return reply
  }

  /// One entry per moment: NSNull, or `{pixelWidth, pixelHeight, crop,
  /// embedding}`. Stops when [stillWanted] turns false, and throws when no
  /// frame at all could be read, so the caller does not count the chunk.
  func embed(_ args: [String: Any], stillWanted: () -> Bool) throws -> [Any] {
    guard let path = args["path"] as? String, let moments = args["moments"] as? [[String: Any]] else {
      throw VisionError.badArguments("path or moments")
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let generator = AVAssetImageGenerator(asset: asset)
    // Upright, as the player shows it, so the boxes from pass 1 fit.
    generator.appliesPreferredTrackTransform = true
    // A moment's time is its frame's, rounded to the millisecond: a time
    // rounded down by under a millisecond must still reach that frame (and
    // not the one before it, or none before the first).
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 1000)
    generator.maximumSize = CGSize(width: Self.embedSide, height: Self.embedSide)
    var unread = 0
    let crops = try moments.map { moment -> Any in
      if !stillWanted() { throw VisionError.notForeground }
      return try autoreleasepool {
        guard let ms = (moment["ms"] as? NSNumber)?.intValue,
              let x = (moment["x"] as? NSNumber)?.doubleValue,
              let y = (moment["y"] as? NSNumber)?.doubleValue,
              let w = (moment["width"] as? NSNumber)?.doubleValue,
              let h = (moment["height"] as? NSNumber)?.doubleValue else {
          return NSNull()
        }
        guard let image = try? generator.copyCGImage(
          at: CMTime(value: CMTimeValue(ms), timescale: 1000), actualTime: nil) else {
          unread += 1
          return NSNull()
        }
        // Nil for a crop too small to read: that fish is simply not named.
        return try pipeline.cropAndEmbed(image, x: x, y: y, w: w, h: h) ?? NSNull()
      }
    }
    if !moments.isEmpty, unread == moments.count {
      throw VisionError.decodeFailed("no frame could be read")
    }
    return crops
  }

  private enum Step {
    case frame([String: Any])
    case skip
    case end
  }

  /// The decoded frame upright, as the player displays it, at most
  /// [detectSide] on its longer side whatever size the decoder returned.
  private func frameImage(_ pixels: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CGImage? {
    var image = CIImage(cvPixelBuffer: pixels).oriented(orientation)
    let longer = max(image.extent.width, image.extent.height)
    if longer > Self.detectSide {
      let s = Self.detectSide / longer
      image = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
    }
    return context.createCGImage(image, from: image.extent.integral)
  }

  /// The rotation and mirroring a video track's transform asks for, as the
  /// orientation that turns its decoded frames the way the player shows
  /// them (and pass 2 crops them). A mirrored transform is a rotation after
  /// a horizontal flip: undoing the flip gives the rotation.
  private static func orientation(of t: CGAffineTransform) -> CGImagePropertyOrientation {
    let mirrored = t.a * t.d - t.b * t.c < 0
    let (a, b) = mirrored ? (-t.a, -t.b) : (t.a, t.b)
    let degrees = Int((atan2(Double(b), Double(a)) * 180 / .pi).rounded())
    switch ((degrees + 360) % 360, mirrored) {
    case (90, false): return .right
    case (180, false): return .down
    case (270, false): return .left
    case (0, true): return .upMirrored
    case (90, true): return .rightMirrored
    case (180, true): return .downMirrored
    case (270, true): return .leftMirrored
    default: return .up
    }
  }
}
