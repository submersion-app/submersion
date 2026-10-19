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
  static func extract(
    path: String, timesMs: [Int], maxDimension: Int, exact: Bool = false
  ) -> [Any] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let generator = AVAssetImageGenerator(asset: asset)
    // Upright frames, as the player shows them.
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
    // Colour statistics do not need the exact frame and a nearby keyframe
    // is far faster; a white-point pick needs the paused frame itself.
    // Exact still allows a little before the time: a clip that played to the
    // end is paused at the asset's duration, which can lie past the last
    // video frame (audio running longer), and no frame starts after it.
    let tolerance = CMTime(value: 500, timescale: 1000)
    generator.requestedTimeToleranceBefore =
      exact ? CMTime(value: 100, timescale: 1000) : tolerance
    generator.requestedTimeToleranceAfter = exact ? CMTime.zero : tolerance

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
