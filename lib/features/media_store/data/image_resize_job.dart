import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Decode / resize / re-encode, on a background isolate.
///
/// [ThumbnailGenerator] and [ImageCompressor] both used to run
/// `img.decodeImage` + `img.copyResize` + `img.encodeJpg` inline. Those are
/// pure Dart, so they ran on whichever isolate called them -- and every caller
/// is the media store's upload worker, which lives on the UI isolate. A single
/// 24 MP frame is seconds of uninterrupted CPU there, and the worker drains
/// its queue in a loop, so a backlog froze the app for as long as it took to
/// clear. That is the Windows hang in #1175: a store-backed grid tile
/// constructs the store runtime, the runtime kicks `worker.drain()`, and the
/// drain starts decoding.
///
/// Desktop is the worst case and the platform the bug was reported on: a
/// gallery photo arrives from photo_manager already sized and JPEG-encoded, so
/// mobile often skips the decode entirely, while a local-file original never
/// does.
///
/// Following the codebase's existing convention (`ExifExtractor`,
/// `PhotoPickerServiceDesktop`), the hop is `compute` with a single sendable
/// argument. Prefer [ImageResizeRequest.fromFile]: reading the source inside
/// the isolate keeps multi-megabyte originals off the message channel
/// altogether. The result is written straight to [destinationPath] for the
/// same reason -- only a small record comes back.
@immutable
class ImageResizeRequest {
  /// Reads the source inside the isolate. Preferred: no bytes cross the
  /// message channel.
  const ImageResizeRequest.fromFile({
    required this.sourcePath,
    required this.destinationPath,
    required this.maxDimension,
    required this.jpegQuality,
    this.declaredName,
    this.skipWhenUnderCeiling = false,
  }) : sourceBytes = null;

  /// For callers that already hold the bytes and have no file to point at
  /// (a resolver that returned `BytesData`). The bytes are copied to the
  /// isolate, which is still far cheaper than decoding them here.
  const ImageResizeRequest.fromBytes({
    required Uint8List bytes,
    required this.destinationPath,
    required this.maxDimension,
    required this.jpegQuality,
    this.declaredName,
    this.skipWhenUnderCeiling = false,
  }) : sourcePath = null,
       sourceBytes = bytes;

  final String? sourcePath;
  final Uint8List? sourceBytes;

  /// Where the JPEG lands. Written only on [ImageResizeOutcome.written], so a
  /// caller that staged a path can leave it untouched otherwise.
  final String destinationPath;

  /// Longest edge of the output, in pixels.
  final int maxDimension;

  final int jpegQuality;

  /// Filename whose extension picks the decoder. Decoding by declared
  /// extension matters: package:image's generic probe tries every format and
  /// the permissive ones (TGA) accept arbitrary bytes.
  final String? declaredName;

  /// When true, a source already within [maxDimension] reports
  /// [ImageResizeOutcome.underCeiling] instead of being re-encoded, so the
  /// caller can upload the untouched original rather than a lossy round-trip.
  /// Thumbnails want the opposite: a small source is still copied out, because
  /// the point is to strip EXIF, not to shrink.
  final bool skipWhenUnderCeiling;
}

/// What [resizeToJpegFile] did.
enum ImageResizeOutcome {
  /// A JPEG was written to `destinationPath`.
  written,

  /// package:image could not decode the source (HEIC on desktop, a video, a
  /// truncated file).
  undecodable,

  /// The source was already within `maxDimension` and
  /// `skipWhenUnderCeiling` was set. Nothing was written.
  underCeiling,
}

@immutable
class ImageResizeResult {
  const ImageResizeResult(this.outcome, {this.sizeBytes = 0, this.error});

  final ImageResizeOutcome outcome;

  /// Length of the written JPEG; 0 for the other outcomes.
  final int sizeBytes;

  /// Why the source could not be decoded, when the decoder said so out loud.
  ///
  /// Carried back as a STRING rather than by letting the exception escape the
  /// isolate. package:image throws for a malformed source of a known
  /// extension (`decodeNamedImage` on a truncated JPEG raises "Start Of Image
  /// marker not found") and returns null for one it merely does not
  /// recognise; both are the same fact to a caller, so the job normalises
  /// them into [ImageResizeOutcome.undecodable] and keeps the detail here for
  /// the log.
  final String? error;
}

/// Runs [request] on a background isolate.
Future<ImageResizeResult> resizeToJpegFile(ImageResizeRequest request) =>
    compute(runImageResizeRequest, request);

/// The isolate body. Top-level and public so a test can exercise the work
/// itself without paying for an isolate spawn per case.
@visibleForTesting
ImageResizeResult runImageResizeRequest(ImageResizeRequest request) {
  final path = request.sourcePath;
  final bytes = path != null
      ? File(path).readAsBytesSync()
      : request.sourceBytes!;

  final name = request.declaredName;
  final img.Image? decoded;
  try {
    decoded = name != null && name.contains('.')
        ? img.decodeNamedImage(name, bytes)
        : img.decodeImage(bytes);
  } on Exception catch (e) {
    // A malformed source of a known extension throws instead of returning
    // null. Left to escape, it would cross the isolate boundary and reach the
    // caller as a bare exception, losing the outcome the caller switches on.
    return ImageResizeResult(
      ImageResizeOutcome.undecodable,
      error: e.toString(),
    );
  }
  if (decoded == null) {
    return const ImageResizeResult(ImageResizeOutcome.undecodable);
  }

  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (request.skipWhenUnderCeiling && longest <= request.maxDimension) {
    return const ImageResizeResult(ImageResizeOutcome.underCeiling);
  }

  // Width only: passing both dimensions resizes to exact bounds and distorts
  // the aspect ratio.
  final resized = longest > request.maxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? request.maxDimension : null,
          height: decoded.height > decoded.width ? request.maxDimension : null,
        )
      : decoded;

  final jpeg = img.encodeJpg(resized, quality: request.jpegQuality);
  File(request.destinationPath).writeAsBytesSync(jpeg, flush: true);
  return ImageResizeResult(ImageResizeOutcome.written, sizeBytes: jpeg.length);
}
