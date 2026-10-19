import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// Reads still frames out of a video at chosen times, for the app's
/// per-moment colour correction (issue #3520). Read-only: the video is
/// opened as an AVAsset and never written.
enum FrameExtractor {
  /// JPEG data for each of [timesMs], fitted inside [maxDimension] square,
  /// or NSNull for a time that could not be read. Synchronous; call it off
  /// the main thread.
  static func extract(path: String, timesMs: [Int], maxDimension: Int) -> [Any] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let generator = AVAssetImageGenerator(asset: asset)
    // Upright frames, as the player shows them.
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
    // Colour does not need the exact frame; a nearby keyframe is far faster.
    let tolerance = CMTime(value: 500, timescale: 1000)
    generator.requestedTimeToleranceBefore = tolerance
    generator.requestedTimeToleranceAfter = tolerance

    return timesMs.map { ms -> Any in
      let time = CMTime(value: CMTimeValue(ms), timescale: 1000)
      guard let image = try? generator.copyCGImage(at: time, actualTime: nil),
        let jpeg = jpegData(image)
      else { return NSNull() }
      return jpeg
    }
  }

  private static func jpegData(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, "public.jpeg" as CFString, 1, nil)
    else { return nil }
    let options = [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
    CGImageDestinationAddImage(destination, image, options)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }
}
