import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/resampling.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// The pixel steps of the ONNX pipeline: ports of `rgba`, `tensor`,
/// `fitRect`, the crop in `cropAndEmbed`, `fitted` and `jpeg` in the Swift
/// pipeline (`VisionPipeline.swift`). No Flutter import: the pipeline runs
/// in a worker isolate.

/// RGBA pixels, four bytes each, rows top to bottom.
class RgbaImage {
  const RgbaImage(this.width, this.height, this.bytes, {this.colour});

  final int width;
  final int height;
  final Uint8List bytes;

  /// The conversion of [bytes] to sRGB when they are in a photo's own
  /// colour space (its embedded profile, which Flutter's decoder does not
  /// apply); null when they are sRGB already or untagged. The pipeline
  /// applies it first ([inSrgb]), in the worker isolate.
  final SrgbConversion? colour;
}

/// [image] in sRGB: converted by its [RgbaImage.colour], or itself when it
/// carries none.
RgbaImage inSrgb(RgbaImage image) {
  final colour = image.colour;
  if (colour == null) return image;
  return RgbaImage(image.width, image.height, toSrgbBytes(image.bytes, colour));
}

/// A crop in whole pixels of an image.
typedef CropRect = ({int x, int y, int width, int height});

/// [source] resampled into [target] of a [canvas]-pixel square, over
/// [fill] (0 to 1 RGB) where given and black elsewhere. A pixel whose
/// centre lies in [target] takes the source; the rest keep the fill.
RgbaImage drawInto(
  RgbaImage source,
  PixelRect target, {
  required int canvas,
  List<double>? fill,
}) => CanvasDrawer(source).draw(target, canvas: canvas, fill: fill);

/// Draws one image into several canvases as [drawInto] does, sharing the
/// work of draws that resample an axis alike ([Resampler]): the detectors'
/// square and letterbox from one photo or frame.
class CanvasDrawer {
  CanvasDrawer(RgbaImage source)
    : _resampler = Resampler(source.bytes, source.width, source.height);

  final Resampler _resampler;

  RgbaImage draw(PixelRect target, {required int canvas, List<double>? fill}) {
    final out = Uint8List(canvas * canvas * 4);
    if (fill != null) {
      final r = (fill[0] * 255).round(), g = (fill[1] * 255).round();
      final b = (fill[2] * 255).round();
      for (var i = 0; i < out.length; i += 4) {
        out[i] = r;
        out[i + 1] = g;
        out[i + 2] = b;
        out[i + 3] = 255;
      }
    }
    _resampler.draw(
      out,
      canvas,
      canvas,
      left: target.left,
      top: target.top,
      width: target.width,
      height: target.height,
    );
    return RgbaImage(canvas, canvas, out);
  }
}

/// A `[1, 3, size, size]` tensor of a square image: R, G and B planes, each
/// value `(v / 255 - mean) / std`.
Float32List toTensor(
  RgbaImage square, {
  required List<double> mean,
  required List<double> std,
}) {
  final plane = square.width * square.height;
  final out = Float32List(3 * plane);
  final bytes = square.bytes;
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      out[c * plane + i] = (bytes[i * 4 + c] / 255 - mean[c]) / std[c];
    }
  }
  return out;
}

/// Where a crop of [width] by [height] is drawn in the [size]-pixel square:
/// inside it for pad to square, covering it for centre crop. Centred either
/// way; the canvas clips what falls outside.
PixelRect fitRect(int width, int height, int size, CropFit fit) {
  final sx = size / width, sy = size / height;
  final scale = fit == CropFit.padSquare ? math.min(sx, sy) : math.max(sx, sy);
  final w = width * scale, h = height * scale;
  return (left: (size - w) / 2, top: (size - h) / 2, width: w, height: h);
}

/// The box at normalised [x], [y], [w], [h] of an image, widened by
/// [padding] of its size on each side, clamped to the image and taken out
/// to whole pixels; null when under 2 pixels either way.
CropRect? paddedCrop({
  required int imageWidth,
  required int imageHeight,
  required double x,
  required double y,
  required double w,
  required double h,
  required double padding,
}) {
  final bx = x * imageWidth, by = y * imageHeight;
  final bw = w * imageWidth, bh = h * imageHeight;
  final padX = bw * padding, padY = bh * padding;
  final left = math.max(0.0, bx - padX), top = math.max(0.0, by - padY);
  final right = math.min(imageWidth.toDouble(), bx + bw + padX);
  final bottom = math.min(imageHeight.toDouble(), by + bh + padY);
  final x0 = left.floor(), y0 = top.floor();
  final x1 = right.ceil(), y1 = bottom.ceil();
  if (x1 - x0 < 2 || y1 - y0 < 2) return null;
  return (x: x0, y: y0, width: x1 - x0, height: y1 - y0);
}

/// The pixels of [image] inside [rect].
RgbaImage cropOf(RgbaImage image, CropRect rect) {
  final out = Uint8List(rect.width * rect.height * 4);
  final rowBytes = rect.width * 4;
  for (var row = 0; row < rect.height; row++) {
    final from = ((rect.y + row) * image.width + rect.x) * 4;
    out.setRange(row * rowBytes, (row + 1) * rowBytes, image.bytes, from);
  }
  return RgbaImage(rect.width, rect.height, out);
}

/// [image] shrunk so its longer side is at most [side]; the same image when
/// it already fits.
RgbaImage fittedWithin(RgbaImage image, int side) {
  final longer = math.max(image.width, image.height);
  if (longer <= side) return image;
  final scale = side / longer;
  final w = math.max(1, (image.width * scale).round());
  final h = math.max(1, (image.height * scale).round());
  final out = Uint8List(w * h * 4);
  resampleRgba(
    image.bytes,
    image.width,
    image.height,
    out,
    w,
    h,
    left: 0,
    top: 0,
    width: w.toDouble(),
    height: h.toDouble(),
  );
  return RgbaImage(w, h, out);
}

/// A JPEG of [image] at quality 85, as the Swift pipeline writes crops.
Uint8List jpegOf(RgbaImage image) => img.encodeJpg(
  img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.bytes.buffer,
    bytesOffset: image.bytes.offsetInBytes,
    numChannels: 4,
  ),
  quality: 85,
);
