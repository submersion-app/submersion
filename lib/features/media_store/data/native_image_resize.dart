import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/media_store/data/image_resize_job.dart';

/// A source decoded and scaled by [NativeImageDecoder], as straight RGBA.
@immutable
class DecodedRgba {
  const DecodedRgba({
    required Uint8List this.rgba,
    required this.width,
    required this.height,
  }) : underCeiling = false;

  /// The source was already within the request's ceiling and the request
  /// asked for such a source to be left alone. Nothing was decoded.
  const DecodedRgba.underCeiling()
    : rgba = null,
      width = 0,
      height = 0,
      underCeiling = true;

  final Uint8List? rgba;
  final int width;
  final int height;
  final bool underCeiling;
}

/// Decodes a request's source to pixels no larger than its ceiling. Throws
/// when it cannot read the source.
typedef NativeImageDecoder =
    Future<DecodedRgba> Function(ImageResizeRequest request);

/// [resizeToJpegFile] with the decode done by Flutter's own codecs
/// (issue #3337).
///
/// The Dart decoder behind [resizeToJpegFile] is slow and holds the whole
/// full-resolution bitmap in memory: about 96 MB for a 24 MP photo, to make
/// a 512px thumbnail. The engine decodes off the UI thread with the
/// platform's codecs and scales as it goes, so only the small result ever
/// reaches Dart. It also reads formats the Dart library cannot, HEIC on
/// Apple platforms among them.
///
/// Flutter cannot encode JPEG, so the small result is still encoded by the
/// Dart library, on a background isolate. And the Dart decoder stays as the
/// [fallback] for whatever the engine rejects (TIFF, for one), so the set of
/// readable formats only grows.
Future<ImageResizeResult> resizeToJpegFileNative(
  ImageResizeRequest request, {
  NativeImageDecoder decode = decodeWithFlutterCodec,
  Future<ImageResizeResult> Function(ImageResizeRequest request) fallback =
      resizeToJpegFile,
}) async {
  final DecodedRgba decoded;
  try {
    decoded = await decode(request);
  } on Object {
    // Whatever the engine made of it, the Dart decoder gets its turn and
    // its verdict is the one reported.
    return fallback(request);
  }
  if (decoded.underCeiling) {
    return const ImageResizeResult(ImageResizeOutcome.underCeiling);
  }
  final sizeBytes = await compute(
    _encodeRgbaToJpegFile,
    _RgbaEncodeJob(
      rgba: decoded.rgba!,
      width: decoded.width,
      height: decoded.height,
      maxDimension: request.maxDimension,
      jpegQuality: request.jpegQuality,
      destinationPath: request.destinationPath,
    ),
  );
  return ImageResizeResult(ImageResizeOutcome.written, sizeBytes: sizeBytes);
}

/// The production [NativeImageDecoder]: the engine's image codecs.
Future<DecodedRgba> decodeWithFlutterCodec(ImageResizeRequest request) async {
  final path = request.sourcePath;
  // From the path where there is one, so the encoded original is never
  // copied onto the Dart heap.
  final buffer = path != null
      ? await ui.ImmutableBuffer.fromFilePath(path)
      : await ui.ImmutableBuffer.fromUint8List(request.sourceBytes!);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    final longest = width > height ? width : height;
    if (request.skipWhenUnderCeiling && longest <= request.maxDimension) {
      return const DecodedRgba.underCeiling();
    }
    // One dimension only: the codec keeps the aspect ratio for the other.
    // Neither for a source already small enough, which is never enlarged.
    final shrink = longest > request.maxDimension;
    codec = await descriptor.instantiateCodec(
      targetWidth: shrink && width >= height ? request.maxDimension : null,
      targetHeight: shrink && height > width ? request.maxDimension : null,
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) {
      throw StateError('the decoded image has no pixel data');
    }
    return DecodedRgba(
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      height: image.height,
    );
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

@immutable
class _RgbaEncodeJob {
  const _RgbaEncodeJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.maxDimension,
    required this.jpegQuality,
    required this.destinationPath,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final int maxDimension;
  final int jpegQuality;
  final String destinationPath;
}

/// The isolate body: JPEG-encodes already-small pixels and writes the file.
/// Returns the file's length.
int _encodeRgbaToJpegFile(_RgbaEncodeJob job) {
  var image = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.rgba.buffer,
    bytesOffset: job.rgba.offsetInBytes,
    numChannels: 4,
  );
  // The ceiling was asked of the codec on the dimensions the file declares.
  // A photo stored rotated declares them one way round and decodes the
  // other, and can come back over the ceiling on its long edge. Cheap to
  // put right here, since the image is already small.
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > job.maxDimension) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? job.maxDimension : null,
      height: image.height > image.width ? job.maxDimension : null,
    );
  }
  final jpeg = img.encodeJpg(image, quality: job.jpegQuality);
  File(job.destinationPath).writeAsBytesSync(jpeg, flush: true);
  return jpeg.length;
}
