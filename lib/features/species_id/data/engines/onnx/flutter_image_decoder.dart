import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// A photo decoded for the ONNX engine by Flutter's own decoder, the one the
/// viewer draws with, so the image analysed is the one on screen: EXIF
/// orientation applied and the longer side at most [maxSide], as the Swift
/// pipeline caps it. The decoding runs on Flutter's IO threads, not the UI
/// thread. Throws [VisionEngineException] `decode_failed` for bytes Flutter
/// cannot decode on this platform (HEIC on Windows and Linux, which the
/// viewer cannot show either).
Future<RgbaImage> decodeForAnalysis(
  Uint8List encoded, {
  int maxSide = 4096,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    // Only the longer side is bounded, and never upscaled: the descriptor
    // reports the stored size, which EXIF orientation may turn, so the
    // result is checked again below.
    final wide = descriptor.width >= descriptor.height;
    final longer = math.max(descriptor.width, descriptor.height);
    codec = await descriptor.instantiateCodec(
      targetWidth: longer > maxSide && wide ? maxSide : null,
      targetHeight: longer > maxSide && !wide ? maxSide : null,
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw const VisionEngineException('decode_failed', 'no pixels');
    }
    final decoded = fittedWithin(
      RgbaImage(
        image.width,
        image.height,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
      maxSide,
    );
    // Flutter hands back the stored values whatever the photo's profile;
    // the conversion to sRGB, as the Core ML engine's photos are drawn,
    // rides along to the worker, which applies it off this isolate.
    final colour = srgbConversionOf(encoded);
    return colour == null
        ? decoded
        : RgbaImage(
            decoded.width,
            decoded.height,
            decoded.bytes,
            colour: colour,
          );
  } on VisionEngineException {
    rethrow;
  } on Object catch (e) {
    throw VisionEngineException('decode_failed', '$e');
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
