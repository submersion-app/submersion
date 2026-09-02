import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// How a stored image blob is bounded.
///
/// Sizing is enforced HERE, in Dart, and never through `ImagePicker`'s
/// `maxWidth` / `maxHeight` / `imageQuality`: those arguments are silently
/// ignored by image_picker_macos, image_picker_windows and image_picker_linux,
/// so a desktop pick would enter the database at full size and ride into every
/// sync changeset as base64.
@immutable
class ImageEncodeSpec {
  const ImageEncodeSpec({
    required this.maxDimension,
    required this.jpegQuality,
    required this.square,
  });

  /// Longest edge of the output, in pixels. A source already within this is
  /// never upscaled.
  final int maxDimension;

  final int jpegQuality;

  /// When true the output is cropped to a square before resizing, so every
  /// avatar render site can assume a 1:1 aspect and never letterbox.
  final bool square;

  /// Profile photo for a diver or buddy: 512x512, roughly 50-80 KB. The
  /// largest avatar in the app draws at radius 50, so 300 physical pixels at
  /// 3x. 512 is deliberate headroom for a future enlarged view, since the
  /// source is discarded at pick time and re-encoding upward is impossible.
  static const avatar = ImageEncodeSpec(
    maxDimension: 512,
    jpegQuality: 85,
    square: true,
  );

  /// Certification card face. Card text must stay readable, so the ceiling is
  /// higher and the source aspect ratio is preserved.
  static const certificationCard = ImageEncodeSpec(
    maxDimension: 2000,
    jpegQuality: 85,
    square: false,
  );
}

/// One encode job, sendable to an isolate.
@immutable
class ImageEncodeRequest {
  const ImageEncodeRequest.fromBytes({
    required this.bytes,
    required this.spec,
    this.cropRect,
    this.declaredName,
    this.maxSourcePixels = defaultMaxSourcePixels,
  });

  /// 80 megapixels. Decoding is what allocates, and nothing caps a desktop
  /// pick, so a source beyond this is refused rather than risking an isolate
  /// out-of-memory that would surface as an unexplained failure.
  static const int defaultMaxSourcePixels = 80 * 1000 * 1000;

  final Uint8List bytes;
  final ImageEncodeSpec spec;

  /// Region of the DECODED, orientation-corrected source to keep, in source
  /// pixels. Null means the largest centered square when [ImageEncodeSpec
  /// .square] is set, or the whole image otherwise.
  final Rect? cropRect;

  /// Filename whose extension picks the decoder. package:image's generic
  /// probe tries every format and the permissive ones accept arbitrary bytes,
  /// so pass this whenever the source name is known.
  final String? declaredName;

  final int maxSourcePixels;
}

/// What [encodeStoredImage] did.
enum ImageEncodeOutcome {
  /// A JPEG was produced and is in [ImageEncodeResult.bytes].
  encoded,

  /// package:image could not decode the source.
  undecodable,

  /// The decoded source exceeded [ImageEncodeRequest.maxSourcePixels].
  tooLarge,
}

@immutable
class ImageEncodeResult {
  const ImageEncodeResult(
    this.outcome, {
    this.bytes,
    this.sizeBytes = 0,
    this.error,
  });

  final ImageEncodeOutcome outcome;

  /// The encoded JPEG, non-null only for [ImageEncodeOutcome.encoded].
  final Uint8List? bytes;

  final int sizeBytes;

  /// Why the source could not be decoded, carried as a String rather than
  /// letting the exception cross the isolate boundary and lose the outcome
  /// the caller switches on.
  final String? error;
}

/// Runs [request] on a background isolate.
Future<ImageEncodeResult> encodeStoredImage(ImageEncodeRequest request) =>
    compute(runImageEncodeRequest, request);

/// The isolate body. Top-level and public so a test can exercise the work
/// itself without paying for an isolate spawn per case.
@visibleForTesting
ImageEncodeResult runImageEncodeRequest(ImageEncodeRequest request) {
  final name = request.declaredName;
  final img.Image? decoded;
  try {
    decoded = name != null && name.contains('.')
        ? img.decodeNamedImage(name, request.bytes)
        : img.decodeImage(request.bytes);
  } on Exception catch (e) {
    return ImageEncodeResult(
      ImageEncodeOutcome.undecodable,
      error: e.toString(),
    );
  }
  if (decoded == null) {
    return const ImageEncodeResult(ImageEncodeOutcome.undecodable);
  }

  if (decoded.width * decoded.height > request.maxSourcePixels) {
    return const ImageEncodeResult(ImageEncodeOutcome.tooLarge);
  }

  // Orientation MUST be resolved before any geometry is applied. The JPEG
  // decoder does no orientation handling, so a portrait phone photo arrives
  // as a sideways buffer carrying exif.orientation = 6. Cropping first would
  // apply a rectangle chosen in the upright preview to a rotated buffer and
  // select the wrong region.
  final upright = img.bakeOrientation(decoded);

  final cropped = _crop(upright, request);

  final longest = cropped.width > cropped.height
      ? cropped.width
      : cropped.height;
  final resized = longest > request.spec.maxDimension
      ? img.copyResize(
          cropped,
          // Width or height only: passing both resizes to exact bounds and
          // distorts the aspect ratio.
          width: cropped.width >= cropped.height
              ? request.spec.maxDimension
              : null,
          height: cropped.height > cropped.width
              ? request.spec.maxDimension
              : null,
        )
      : cropped;

  // Re-encoding drops EXIF, so GPS embedded in a gallery or contact photo
  // cannot ride into a blob that syncs to every device and cloud provider.
  final jpeg = Uint8List.fromList(
    img.encodeJpg(resized, quality: request.spec.jpegQuality),
  );
  return ImageEncodeResult(
    ImageEncodeOutcome.encoded,
    bytes: jpeg,
    sizeBytes: jpeg.length,
  );
}

img.Image _crop(img.Image source, ImageEncodeRequest request) {
  final rect = request.cropRect;
  if (rect != null) {
    final x = rect.left.round().clamp(0, source.width - 1);
    final y = rect.top.round().clamp(0, source.height - 1);
    final w = rect.width.round().clamp(1, source.width - x);
    final h = rect.height.round().clamp(1, source.height - y);
    return img.copyCrop(source, x: x, y: y, width: w, height: h);
  }

  if (!request.spec.square) return source;

  final side = source.width < source.height ? source.width : source.height;
  return img.copyCrop(
    source,
    x: (source.width - side) ~/ 2,
    y: (source.height - side) ~/ 2,
    width: side,
    height: side,
  );
}
