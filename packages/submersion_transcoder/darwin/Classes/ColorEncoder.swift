import AVFoundation
import CoreImage
import CoreMedia
import VideoToolbox
#if os(iOS)
import UIKit
#endif

enum ColorEncodeError: Error {
  case cancelled
  case unsupported(String)
  case failed(String)
}

extension ColorEncodeError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .cancelled: return "Colour encode cancelled"
    case .unsupported(let detail): return "Unsupported on this device: \(detail)"
    case .failed(let detail): return "Colour encode failed: \(detail)"
    }
  }
}

/// A cancel request that any thread may set and the encode polls per frame.
final class ColorEncodeCancelFlag {
  private let lock = NSLock()
  private var value = false

  func set() {
    lock.lock()
    value = true
    lock.unlock()
  }

  var isSet: Bool {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}

/// One key of the colour timeline the app sends: the 4x5 matrix (row-major;
/// offsets on the 0-255 scale) in effect `timeMs` into the clip.
struct ColorTimelineKey {
  let timeMs: Double
  let matrix: [Float]
}

/// Re-encodes a video with a per-frame colour correction (issue #3521).
///
/// Every frame gets the matrix the timeline gives for its presentation time
/// (the player's position at that frame), applied with the one formula the
/// Dart side pins in `color_math.dart`: on the encoded values for SDR, and
/// through an extended sRGB space relative to SDR white for PQ and HLG.
/// Keeps the codec family (H.264 or HEVC; anything else, or 10-bit H.264,
/// becomes HEVC), dimensions, rotation, frame timing, bit depth, HDR colour
/// tags and mastering metadata, every audio track, and the location the
/// Dart side read from the source.
final class ColorEncoder {
  static func encode(
    source: String, output: String, keys: [ColorTimelineKey], location: String?,
    onProgress: @escaping (Double) -> Void,
    isCancelled: @escaping () -> Bool
  ) throws {
    let asset = AVAsset(url: URL(fileURLWithPath: source))
    guard let videoTrack = asset.tracks(withMediaType: .video).first,
      let format = videoTrack.formatDescriptions.first.map({
        $0 as! CMFormatDescription
      })
    else {
      throw ColorEncodeError.failed("no video track in the source")
    }
    let traits = SourceTraits(format: format, track: videoTrack)
    let tmpURL = URL(fileURLWithPath: output + ".tmp")
    try? FileManager.default.removeItem(at: tmpURL)
    func discard() { try? FileManager.default.removeItem(at: tmpURL) }

    let reader: AVAssetReader
    let writer: AVAssetWriter
    do {
      reader = try AVAssetReader(asset: asset)
      writer = try AVAssetWriter(outputURL: tmpURL, fileType: .mp4)
    } catch {
      throw ColorEncodeError.failed(error.localizedDescription)
    }
    writer.shouldOptimizeForNetworkUse = true
    writer.metadata = locationMetadata(location)

    let videoOut = AVAssetReaderTrackOutput(
      track: videoTrack,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: traits.pixelFormat])
    videoOut.alwaysCopiesSampleData = false
    reader.add(videoOut)

    let videoIn = AVAssetWriterInput(
      mediaType: .video, outputSettings: traits.writerSettings)
    videoIn.expectsMediaDataInRealTime = false
    videoIn.transform = videoTrack.preferredTransform
    guard writer.canAdd(videoIn) else {
      throw ColorEncodeError.unsupported(
        "cannot encode \(traits.codec.rawValue) at \(traits.width)x\(traits.height)")
    }
    writer.add(videoIn)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoIn,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: traits.pixelFormat,
        kCVPixelBufferWidthKey as String: traits.width,
        kCVPixelBufferHeightKey as String: traits.height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      ])

    let audio = try addAudioTracks(of: asset, reader: reader, writer: writer)
    // Built before reading starts, so a kernel that cannot compile leaves
    // nothing to clean up.
    let kernel = try ColorKernel(transfer: traits.transfer)

    guard reader.startReading() else {
      discard()
      throw classify(reader.error, stage: "reader start")
    }
    guard writer.startWriting() else {
      discard()
      throw classify(writer.error, stage: "writer start")
    }
    guard let first = videoOut.copyNextSampleBuffer() else {
      reader.cancelReading()
      writer.cancelWriting()
      discard()
      throw ColorEncodeError.failed("the source has no video frames")
    }
    let firstPts = CMSampleBufferGetPresentationTimeStamp(first)
    writer.startSession(atSourceTime: firstPts)

    let timeline = Timeline(keys: keys)
    let durationSec = max(0.001, CMTimeGetSeconds(asset.duration))
    let group = DispatchGroup()
    let videoQueue = DispatchQueue(label: "color.encode.video")
    var renderError: Error?

    group.enter()
    var pending: CMSampleBuffer? = first
    videoIn.requestMediaDataWhenReady(on: videoQueue) {
      while videoIn.isReadyForMoreMediaData {
        guard !isCancelled(), writer.status == .writing, reader.status == .reading
            || pending != nil,
          let sample = pending ?? videoOut.copyNextSampleBuffer()
        else {
          videoIn.markAsFinished()
          group.leave()
          return
        }
        pending = nil
        let pts = CMSampleBufferGetPresentationTimeStamp(sample)
        // Presentation time, as the player's position reads it, which is
        // what the app's timeline is sampled against.
        let ms = CMTimeGetSeconds(pts) * 1000
        do {
          guard let pool = adaptor.pixelBufferPool,
            let src = CMSampleBufferGetImageBuffer(sample)
          else { throw ColorEncodeError.failed("no pixel buffer") }
          let dst = try kernel.render(
            src, matrix: timeline.matrix(atMs: ms), pool: pool)
          if !adaptor.append(dst, withPresentationTime: pts) {
            throw ColorEncodeError.failed(
              writer.error?.localizedDescription ?? "append failed")
          }
        } catch {
          renderError = error
          videoIn.markAsFinished()
          group.leave()
          return
        }
        onProgress(min(1.0, (ms / 1000) / durationSec))
      }
    }
    for (input, out) in audio {
      group.enter()
      let queue = DispatchQueue(label: "color.encode.audio")
      input.requestMediaDataWhenReady(on: queue) {
        while input.isReadyForMoreMediaData {
          guard !isCancelled(), writer.status == .writing, reader.status == .reading,
            let sample = out.copyNextSampleBuffer(), input.append(sample)
          else {
            input.markAsFinished()
            group.leave()
            return
          }
        }
      }
    }
    // A writer that fails while an input is not ready stops calling that
    // input's block, which would then never leave the group: watch for that
    // (and for a cancel no pump is awake to see) instead of waiting blind.
    var abandoned = false
    while group.wait(timeout: .now() + 0.5) == .timedOut {
      if writer.status == .failed || reader.status == .failed || isCancelled() {
        abandoned = true
        reader.cancelReading()
        writer.cancelWriting()
        break
      }
    }

    if isCancelled() {
      reader.cancelReading()
      writer.cancelWriting()
      discard()
      throw ColorEncodeError.cancelled
    }
    if let renderError = renderError {
      reader.cancelReading()
      writer.cancelWriting()
      discard()
      throw renderError as? ColorEncodeError
        ?? ColorEncodeError.failed(renderError.localizedDescription)
    }
    if reader.status == .failed {
      writer.cancelWriting()
      discard()
      throw classify(reader.error, stage: "reading")
    }
    if abandoned {
      discard()
      throw classify(writer.error, stage: "writing")
    }
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    guard writer.status == .completed else {
      discard()
      throw classify(writer.error, stage: "finishing")
    }
    onProgress(1.0)
    let outputURL = URL(fileURLWithPath: output)
    do {
      try? FileManager.default.removeItem(at: outputURL)
      try FileManager.default.moveItem(at: tmpURL, to: outputURL)
    } catch {
      discard()
      throw ColorEncodeError.failed("finalize: \(error.localizedDescription)")
    }
  }

  /// Codes for a device that cannot do this source, as opposed to a fault.
  private static let unsupportedCodes: Set<Int> = [
    AVError.Code.encoderNotFound.rawValue,
    AVError.Code.decoderNotFound.rawValue,
    AVError.Code.encoderTemporarilyUnavailable.rawValue,
    AVError.Code.decoderTemporarilyUnavailable.rawValue,
    AVError.Code.fileFormatNotRecognized.rawValue,
    AVError.Code.operationNotSupportedForAsset.rawValue,
  ]

  private static func classify(_ error: Error?, stage: String) -> ColorEncodeError {
    let ns = error as NSError?
    let detail = "\(stage): \(ns?.localizedDescription ?? "unknown")"
    if let code = ns?.code, ns?.domain == AVFoundationErrorDomain,
      unsupportedCodes.contains(code)
    {
      return .unsupported(detail)
    }
    return .failed(detail)
  }

  /// Every audio track, copied as it is where MP4 can hold it, otherwise
  /// re-encoded as AAC at its own rate and channel count. A track that can
  /// be written neither way makes the encode unsupported: the copy keeps
  /// every audio track or is not made.
  private static func addAudioTracks(
    of asset: AVAsset, reader: AVAssetReader, writer: AVAssetWriter
  ) throws -> [(AVAssetWriterInput, AVAssetReaderTrackOutput)] {
    var pairs: [(AVAssetWriterInput, AVAssetReaderTrackOutput)] = []
    for track in asset.tracks(withMediaType: .audio) {
      let hint = track.formatDescriptions.first.map { $0 as! CMFormatDescription }
      let copy = AVAssetWriterInput(
        mediaType: .audio, outputSettings: nil, sourceFormatHint: hint)
      copy.expectsMediaDataInRealTime = false
      if writer.canAdd(copy) {
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        if reader.canAdd(out) {
          reader.add(out)
          writer.add(copy)
          pairs.append((copy, out))
          continue
        }
      }
      let asbd = hint.flatMap {
        CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
      }
      let rate = asbd.map { Int($0.mSampleRate) } ?? 48000
      let channels = asbd.map { Int($0.mChannelsPerFrame) } ?? 2
      let out = AVAssetReaderTrackOutput(
        track: track,
        outputSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: rate,
          AVNumberOfChannelsKey: channels,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsBigEndianKey: false,
          AVLinearPCMIsNonInterleaved: false,
        ])
      let aac = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: rate,
          AVNumberOfChannelsKey: channels,
          AVEncoderBitRateKey: 96_000 * max(1, channels),
        ])
      aac.expectsMediaDataInRealTime = false
      guard reader.canAdd(out), writer.canAdd(aac) else {
        throw ColorEncodeError.unsupported(
          "an audio track (\(rate) Hz, \(channels) channels) cannot be written to MP4")
      }
      reader.add(out)
      writer.add(aac)
      pairs.append((aac, out))
    }
    return pairs
  }

  /// The location, as ISO 6709, in the forms MP4 readers look for. The
  /// recording date is written by the Dart side into the movie header,
  /// which AVAssetWriter always stamps with the moment of writing.
  private static func locationMetadata(_ location: String?) -> [AVMetadataItem] {
    guard let location = location, !location.isEmpty else { return [] }
    return [AVMetadataIdentifier.commonIdentifierLocation, .quickTimeMetadataLocationISO6709]
      .map { id in
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = location as NSString
        return item
      }
  }
}

/// What the encode keeps from the source's video track.
private struct SourceTraits {
  let codec: AVVideoCodecType
  let transfer: Float  // 0 sdr, 1 pq, 2 hlg
  let tenBit: Bool
  let width: Int
  let height: Int
  let pixelFormat: OSType
  let writerSettings: [String: Any]

  init(format: CMFormatDescription, track: AVAssetTrack) {
    let ext = (CMFormatDescriptionGetExtensions(format) as? [String: Any]) ?? [:]
    let transferName = ext[kCMFormatDescriptionExtension_TransferFunction as String]
      as? String
    if transferName == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) {
      transfer = 1
    } else if transferName == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
      transfer = 2
    } else {
      transfer = 0
    }
    let bits = (ext[kCMFormatDescriptionExtension_BitsPerComponent as String] as? NSNumber)?
      .intValue
    tenBit = (bits ?? 8) > 8 || transfer != 0 || SourceTraits.hevcLumaBits(ext) > 8
    let isH264 = CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_H264
    // VideoToolbox has no 10-bit H.264 encoder; such a clip becomes HEVC.
    codec = isH264 && !tenBit ? .h264 : .hevc
    let dims = CMVideoFormatDescriptionGetDimensions(format)
    width = Int(dims.width)
    height = Int(dims.height)
    pixelFormat =
      tenBit
      ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
      : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

    let hdr = transfer != 0
    let colour: [String: Any] = [
      AVVideoColorPrimariesKey:
        ext[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String
        ?? (hdr ? AVVideoColorPrimaries_ITU_R_2020 : AVVideoColorPrimaries_ITU_R_709_2),
      AVVideoTransferFunctionKey: transferName ?? AVVideoTransferFunction_ITU_R_709_2,
      AVVideoYCbCrMatrixKey:
        ext[kCMFormatDescriptionExtension_YCbCrMatrix as String] as? String
        ?? (hdr ? AVVideoYCbCrMatrix_ITU_R_2020 : AVVideoYCbCrMatrix_ITU_R_709_2),
    ]
    let rate = Double(track.estimatedDataRate)
    var compression: [String: Any] = [
      AVVideoAverageBitRateKey: Int(min(max(rate, 4_000_000), 100_000_000)),
      AVVideoProfileLevelKey: codec == .h264
        ? AVVideoProfileLevelH264HighAutoLevel
        : (tenBit
          ? kVTProfileLevel_HEVC_Main10_AutoLevel as String
          : kVTProfileLevel_HEVC_Main_AutoLevel as String),
    ]
    if track.nominalFrameRate > 0 {
      compression[AVVideoExpectedSourceFrameRateKey] = track.nominalFrameRate
    }
    if let mastering = ext[kCMFormatDescriptionExtension_MasteringDisplayColorVolume as String] {
      compression[kVTCompressionPropertyKey_MasteringDisplayColorVolume as String] = mastering
    }
    if let light = ext[kCMFormatDescriptionExtension_ContentLightLevelInfo as String] {
      compression[kVTCompressionPropertyKey_ContentLightLevelInfo as String] = light
    }
    writerSettings = [
      AVVideoCodecKey: codec,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoColorPropertiesKey: colour,
      AVVideoCompressionPropertiesKey: compression,
    ]
  }
}

extension SourceTraits {
  /// The luma bit depth an HEVC track's configuration record (`hvcC`)
  /// declares, or 8 when there is none: AVFoundation often leaves
  /// BitsPerComponent out for 10-bit SDR HEVC.
  static func hevcLumaBits(_ ext: [String: Any]) -> Int {
    let atoms =
      ext[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String]
      as? [String: Any]
    guard let hvcC = atoms?["hvcC"] as? Data, hvcC.count > 17 else { return 8 }
    // bitDepthLumaMinus8 sits in the low three bits of byte 17.
    return 8 + Int(hvcC[hvcC.startIndex + 17] & 0x07)
  }
}

/// The timeline, interpolated the way `ColorTimeline.matrixAt` does.
private struct Timeline {
  let keys: [ColorTimelineKey]

  init(keys: [ColorTimelineKey]) {
    self.keys = keys.sorted { $0.timeMs < $1.timeMs }
  }

  func matrix(atMs t: Double) -> [Float] {
    guard let firstKey = keys.first, let lastKey = keys.last else {
      return [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
    }
    if t <= firstKey.timeMs { return firstKey.matrix }
    if t >= lastKey.timeMs { return lastKey.matrix }
    // The first key at or after t, by binary search: asked per frame.
    var low = 1
    var high = keys.count - 1
    while low < high {
      let mid = (low + high) / 2
      if keys[mid].timeMs < t { low = mid + 1 } else { high = mid }
    }
    let lo = keys[low - 1], hi = keys[low]
    let f = Float((t - lo.timeMs) / (hi.timeMs - lo.timeMs))
    return (0..<20).map { lo.matrix[$0] + (hi.matrix[$0] - lo.matrix[$0]) * f }
  }
}

/// Applies the colour formula on the GPU, from a source YCbCr buffer into a
/// pooled one of the same format. Colour management is off throughout, so
/// the kernel sees the encoded R'G'B' that Core Image gets from the buffer's
/// own YCbCr matrix, and its result is converted back the same way.
private final class ColorKernel {
  private let kernel: CIColorKernel
  private let context: CIContext
  private let transfer: Float

  // Linear BT.709 to BT.2020 (ITU-R BT.2087) and its exact inverse, as in
  // color_math.dart.
  private static let to2020: [Double] = [
    0.627403895934699, 0.329283038377884, 0.043313065687417,
    0.069097289358232, 0.919540395075459, 0.011362315566309,
    0.016391438875150, 0.088013307877226, 0.895595253247624,
  ]

  private static let to709: [Double] = {
    let m = to2020
    let a: Double = m[0], b: Double = m[1], c: Double = m[2]
    let d: Double = m[3], e: Double = m[4], f: Double = m[5]
    let g: Double = m[6], h: Double = m[7], i: Double = m[8]
    let c0: Double = e * i - f * h
    let c1: Double = d * i - f * g
    let c2: Double = d * h - e * g
    let det: Double = a * c0 - b * c1 + c * c2
    var inv: [Double] = []
    inv.append(c0 / det)
    inv.append((c * h - b * i) / det)
    inv.append((b * f - c * e) / det)
    inv.append(-c1 / det)
    inv.append((a * i - c * g) / det)
    inv.append((c * d - a * f) / det)
    inv.append(c2 / det)
    inv.append((b * g - a * h) / det)
    inv.append((a * e - b * d) / det)
    return inv
  }()

  private static let source = """
    float srgbEnc(float l) {
      float x = abs(l);
      float v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
      return l < 0.0 ? -v : v;
    }
    float srgbDec(float v) {
      float x = abs(v);
      float l = x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
      return v < 0.0 ? -l : l;
    }
    float pqEotf(float e) {
      float p = pow(clamp(e, 0.0, 1.0), 1.0 / 78.84375);
      return 10000.0 * pow(max(p - 0.8359375, 0.0) / (18.8515625 - 18.6875 * p),
        1.0 / 0.1593017578125);
    }
    float pqInv(float nits) {
      float y = pow(clamp(nits / 10000.0, 0.0, 1.0), 0.1593017578125);
      return pow((0.8359375 + 18.8515625 * y) / (1.0 + 18.6875 * y), 78.84375);
    }
    float hlgInv(float e) {
      return e <= 0.5 ? e * e / 3.0
        : (exp((e - 0.559910729529562) / 0.17883277) + 0.28466892) / 12.0;
    }
    float hlgOetf(float l) {
      return l <= 1.0 / 12.0 ? sqrt(3.0 * max(l, 0.0))
        : 0.17883277 * log(12.0 * l - 0.28466892) + 0.559910729529562;
    }
    kernel vec4 correct(__sample s, vec4 r0, vec4 r1, vec4 r2, float mode,
        vec3 a0, vec3 a1, vec3 a2, vec3 b0, vec3 b1, vec3 b2) {
      vec3 c = s.rgb;
      if (mode < 0.5) {
        vec3 o = vec3(dot(r0.xyz, c) + r0.w, dot(r1.xyz, c) + r1.w,
          dot(r2.xyz, c) + r2.w);
        return vec4(clamp(o, 0.0, 1.0), s.a);
      }
      float white = mode < 1.5 ? 203.0 : 0.26496256042100724;
      vec3 lin = mode < 1.5
        ? vec3(pqEotf(c.r), pqEotf(c.g), pqEotf(c.b)) / white
        : vec3(hlgInv(c.r), hlgInv(c.g), hlgInv(c.b)) / white;
      vec3 l709 = vec3(dot(a0, lin), dot(a1, lin), dot(a2, lin));
      vec3 e = vec3(srgbEnc(l709.r), srgbEnc(l709.g), srgbEnc(l709.b));
      vec3 k = vec3(dot(r0.xyz, e) + r0.w, dot(r1.xyz, e) + r1.w,
        dot(r2.xyz, e) + r2.w);
      vec3 d = vec3(srgbDec(k.r), srgbDec(k.g), srgbDec(k.b));
      vec3 l2020 = max(vec3(dot(b0, d), dot(b1, d), dot(b2, d)), 0.0) * white;
      vec3 back = mode < 1.5
        ? vec3(pqInv(l2020.r), pqInv(l2020.g), pqInv(l2020.b))
        : vec3(hlgOetf(l2020.r), hlgOetf(l2020.g), hlgOetf(l2020.b));
      return vec4(clamp(back, 0.0, 1.0), s.a);
    }
    """

  init(transfer: Float) throws {
    guard let kernel = CIColorKernel(source: ColorKernel.source) else {
      throw ColorEncodeError.failed("the colour kernel did not compile")
    }
    self.kernel = kernel
    self.transfer = transfer
    context = CIContext(options: [
      .workingColorSpace: NSNull(),
      .outputColorSpace: NSNull(),
      .workingFormat: CIFormat.RGBAh,
      .cacheIntermediates: false,
    ])
  }

  private static func rows(_ m: [Double]) -> [CIVector] {
    var out: [CIVector] = []
    for r in 0..<3 {
      let x = CGFloat(m[r * 3])
      let y = CGFloat(m[r * 3 + 1])
      let z = CGFloat(m[r * 3 + 2])
      out.append(CIVector(x: x, y: y, z: z))
    }
    return out
  }

  func render(_ src: CVPixelBuffer, matrix m: [Float], pool: CVPixelBufferPool) throws
    -> CVPixelBuffer
  {
    var out: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
    guard let dst = out else { throw ColorEncodeError.failed("no output buffer") }
    CVBufferPropagateAttachments(src, dst)
    let image = CIImage(cvPixelBuffer: src, options: [.colorSpace: NSNull()])
    var args: [Any] = [image]
    for i in 0..<3 {
      let offset: Float = m[i * 5 + 3] + m[i * 5 + 4] / 255
      args.append(
        CIVector(
          x: CGFloat(m[i * 5]), y: CGFloat(m[i * 5 + 1]), z: CGFloat(m[i * 5 + 2]),
          w: CGFloat(offset)))
    }
    args.append(transfer)
    args.append(contentsOf: ColorKernel.rows(ColorKernel.to709) as [Any])
    args.append(contentsOf: ColorKernel.rows(ColorKernel.to2020) as [Any])
    guard let corrected = kernel.apply(extent: image.extent, arguments: args) else {
      throw ColorEncodeError.failed("the colour kernel did not apply")
    }
    context.render(corrected, to: dst, bounds: image.extent, colorSpace: nil)
    return dst
  }
}
