import AVFoundation
import CoreMedia

enum AvfTranscodeError: Error {
  case noVideoTrack, readerFailed(String), writerFailed(String)
}

// LocalizedError so the message that reaches Dart (via localizedDescription)
// carries the associated detail; a bare Swift enum's localizedDescription is a
// generic "operation couldn't be completed" string that drops the payload.
extension AvfTranscodeError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .noVideoTrack: return "No video track in the source asset"
    case .readerFailed(let detail): return "AVAssetReader failed: \(detail)"
    case .writerFailed(let detail): return "AVAssetWriter failed: \(detail)"
    }
  }
}

final class AvfTranscoder {
  /// AVAsset-based probe (no ffprobe on Apple). Returns nil for a
  /// non-video / unreadable asset.
  static func probe(path: String) -> [String: Any]? {
    let asset = AVAsset(url: URL(fileURLWithPath: path))
    guard let v = asset.tracks(withMediaType: .video).first else { return nil }
    let size = v.naturalSize.applying(v.preferredTransform)
    let w = Int(abs(size.width)), h = Int(abs(size.height))
    if w == 0 || h == 0 { return nil }
    // Duration can be indefinite -> CMTimeGetSeconds returns NaN/inf, and
    // Int(NaN) traps at runtime. Guard it.
    let rawDuration = CMTimeGetSeconds(asset.duration)
    let durationSec = (rawDuration.isFinite && rawDuration > 0) ? rawDuration : 0
    let durationMs = Int(durationSec * 1000)
    // Overall bitrate: sum of track data rates (bits/s) -> kbps. When that is
    // unknown (0), estimate from file size / duration so the ceiling rule
    // doesn't read a high-bitrate clip as 0 and skip transcoding.
    var bps = asset.tracks.reduce(Float(0)) { $0 + $1.estimatedDataRate }
    if bps <= 0, durationSec > 0,
      let attrs = try? FileManager.default.attributesOfItem(atPath: path),
      let fileSize = attrs[.size] as? Int, fileSize > 0
    {
      bps = Float(fileSize * 8) / Float(durationSec)
    }
    return [
      "width": w, "height": h,
      "durationMs": durationMs,
      "overallBitrateKbps": Int(bps / 1000),
    ]
  }

  /// Reads with AVAssetReader, re-encodes H.264+AAC with AVAssetWriter to
  /// '<output>.tmp', renames on success. Progress is fraction of duration.
  static func transcode(
    source: String, output: String,
    maxHeight: Int, videoBitrateKbps: Int, audioBitrateKbps: Int,
    onProgress: @escaping (Double) -> Void
  ) throws {
    let asset = AVAsset(url: URL(fileURLWithPath: source))
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      throw AvfTranscodeError.noVideoTrack
    }
    let tmpURL = URL(fileURLWithPath: output + ".tmp")
    try? FileManager.default.removeItem(at: tmpURL)

    let reader = try AVAssetReader(asset: asset)
    let writer = try AVAssetWriter(outputURL: tmpURL, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true // faststart

    // Output dimensions: scale to maxHeight, preserve aspect, never upscale,
    // even dimensions. Rotation is preserved via the writer input transform.
    let t = videoTrack.preferredTransform
    let natural = videoTrack.naturalSize.applying(t)
    let srcH = abs(natural.height), srcW = abs(natural.width)
    let outH = min(CGFloat(maxHeight), srcH)
    let scale = srcH == 0 ? 1 : outH / srcH
    let evenH = (Int(outH.rounded()) / 2) * 2
    let evenW = (Int((srcW * scale).rounded()) / 2) * 2

    let videoOut = AVAssetReaderTrackOutput(
      track: videoTrack,
      outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      ])
    reader.add(videoOut)
    let videoIn = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: evenW,
        AVVideoHeightKey: evenH,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: videoBitrateKbps * 1000,
        ],
      ])
    videoIn.expectsMediaDataInRealTime = false
    videoIn.transform = t // honor rotation
    writer.add(videoIn)

    // Audio (optional).
    var audioOut: AVAssetReaderTrackOutput?
    var audioIn: AVAssetWriterInput?
    if let audioTrack = asset.tracks(withMediaType: .audio).first {
      // The reader must decode PCM at exactly the rate/channel count the AAC
      // writer expects. If we leave the reader at the source's native format
      // (e.g. 48 kHz from a phone), the writer input -- pinned to 44.1 kHz
      // stereo -- gets mismatched buffers, append() starts returning false,
      // and the whole transcode fails back to uploading the original. The
      // reader resamples/remixes to these settings for us.
      let audioSampleRate = 44100
      let audioChannels = 2
      let ao = AVAssetReaderTrackOutput(
        track: audioTrack,
        outputSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: audioSampleRate,
          AVNumberOfChannelsKey: audioChannels,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsBigEndianKey: false,
          AVLinearPCMIsNonInterleaved: false,
        ])
      reader.add(ao)
      audioOut = ao
      let ai = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVNumberOfChannelsKey: audioChannels,
          AVSampleRateKey: audioSampleRate,
          AVEncoderBitRateKey: audioBitrateKbps * 1000,
        ])
      ai.expectsMediaDataInRealTime = false
      writer.add(ai)
      audioIn = ai
    }

    guard reader.startReading() else {
      // Contract: never leave a "<output>.tmp" behind on failure.
      try? FileManager.default.removeItem(at: tmpURL)
      throw AvfTranscodeError.readerFailed(
        "start: \(reader.error?.localizedDescription ?? "unknown")")
    }
    guard writer.startWriting() else {
      // startWriting() already failed (status == .failed), so there is no
      // active session to cancel; just remove any partial "<output>.tmp".
      try? FileManager.default.removeItem(at: tmpURL)
      throw AvfTranscodeError.writerFailed(
        "writer: \(writer.error?.localizedDescription ?? "unknown")")
    }
    writer.startSession(atSourceTime: .zero)

    let durationSec = CMTimeGetSeconds(asset.duration)
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "avf.transcode")

    func pump(
      _ input: AVAssetWriterInput, _ out: AVAssetReaderTrackOutput,
      reportProgress: Bool
    ) {
      group.enter()
      input.requestMediaDataWhenReady(on: queue) {
        while input.isReadyForMoreMediaData {
          // Any terminal condition -- writer error, reader error, or
          // end-of-samples -- must finish the input and leave the group, or
          // requestMediaDataWhenReady stops calling back and group.wait()
          // deadlocks.
          guard writer.status == .writing, reader.status == .reading,
            let sample = out.copyNextSampleBuffer()
          else {
            input.markAsFinished()
            group.leave()
            return
          }
          if reportProgress, durationSec > 0 {
            let pts = CMTimeGetSeconds(
              CMSampleBufferGetPresentationTimeStamp(sample))
            onProgress(min(1.0, pts / durationSec))
          }
          // A false return means the writer failed; stop pumping so the group
          // completes and writer.status surfaces the error below (ignoring it
          // would silently drop samples until finishWriting).
          if !input.append(sample) {
            input.markAsFinished()
            group.leave()
            return
          }
        }
      }
    }

    pump(videoIn, videoOut, reportProgress: true)
    if let ai = audioIn, let ao = audioOut {
      pump(ai, ao, reportProgress: false)
    }

    group.wait()
    if reader.status == .failed {
      // The writer is mid-session here; cancel it and remove the temp so we
      // never leave a "<output>.tmp" behind (TranscodeEngine contract).
      writer.cancelWriting()
      try? FileManager.default.removeItem(at: tmpURL)
      throw AvfTranscodeError.readerFailed(
        reader.error?.localizedDescription ?? "unknown")
    }
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    guard writer.status == .completed else {
      try? FileManager.default.removeItem(at: tmpURL)
      throw AvfTranscodeError.writerFailed(
        writer.error?.localizedDescription ?? "writer incomplete")
    }
    onProgress(1.0)
    // Finalize atomically. moveItem throws if the destination exists, so
    // remove any stale output first; on any failure, delete the .tmp so we
    // never leave debris (contract: never leave a "<output>.tmp") and rethrow
    // a descriptive error that reaches Dart via localizedDescription.
    let outputURL = URL(fileURLWithPath: output)
    do {
      try? FileManager.default.removeItem(at: outputURL)
      try FileManager.default.moveItem(at: tmpURL, to: outputURL)
    } catch {
      try? FileManager.default.removeItem(at: tmpURL)
      throw AvfTranscodeError.writerFailed(
        "finalize: \(error.localizedDescription)")
    }
  }
}
