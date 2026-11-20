import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// The pixel steps of the ONNX pipeline: ports of `rgba`, `tensor`,
/// `fitRect`, the crop in `cropAndEmbed`, `fitted` and `jpeg` in the Swift
/// pipeline (`VisionPipeline.swift`). No Flutter import: the pipeline runs
/// in a worker isolate.

/// RGBA pixels, four bytes each, rows top to bottom.
class RgbaImage {
  const RgbaImage(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;
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
}) {
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
  _resample(
    source,
    out,
    canvas,
    canvas,
    target.left,
    target.top,
    target.width,
    target.height,
  );
  return RgbaImage(canvas, canvas, out);
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
  _resample(image, out, w, h, 0, 0, w.toDouble(), h.toDouble());
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

/// Resamples [source] into the rectangle at [left], [top] of [width] by
/// [height] in [out] (a [outWidth] by [outHeight] RGBA buffer). The one
/// place the pipeline chooses a filter, so the accuracy gate judges one
/// choice: the average of the covered source pixels when shrinking by more
/// than two, bilinear otherwise.
void _resample(
  RgbaImage source,
  Uint8List out,
  int outWidth,
  int outHeight,
  double left,
  double top,
  double width,
  double height,
) {
  if (width <= 0 || height <= 0) return;
  final scaleX = source.width / width, scaleY = source.height / height;
  final average = scaleX > 2 || scaleY > 2;
  final x0 = math.max(0, (left - 0.5).ceil());
  final y0 = math.max(0, (top - 0.5).ceil());
  final x1 = math.min(outWidth, (left + width - 0.5).ceil());
  final y1 = math.min(outHeight, (top + height - 0.5).ceil());
  final src = source.bytes;
  final sw = source.width, sh = source.height;
  for (var oy = y0; oy < y1; oy++) {
    // The output pixel's footprint in source pixels.
    final fy0 = (oy - top) * scaleY, fy1 = fy0 + scaleY;
    for (var ox = x0; ox < x1; ox++) {
      final fx0 = (ox - left) * scaleX, fx1 = fx0 + scaleX;
      final o = (oy * outWidth + ox) * 4;
      if (average) {
        final sx0 = fx0.floor().clamp(0, sw - 1);
        final sy0 = fy0.floor().clamp(0, sh - 1);
        final sx1 = math.max(sx0 + 1, fx1.ceil().clamp(0, sw));
        final sy1 = math.max(sy0 + 1, fy1.ceil().clamp(0, sh));
        var r = 0, g = 0, b = 0;
        for (var sy = sy0; sy < sy1; sy++) {
          var i = (sy * sw + sx0) * 4;
          for (var sx = sx0; sx < sx1; sx++, i += 4) {
            r += src[i];
            g += src[i + 1];
            b += src[i + 2];
          }
        }
        final n = (sx1 - sx0) * (sy1 - sy0);
        out[o] = (r / n).round();
        out[o + 1] = (g / n).round();
        out[o + 2] = (b / n).round();
      } else {
        final cx = ((fx0 + fx1) / 2 - 0.5).clamp(0.0, sw - 1.0);
        final cy = ((fy0 + fy1) / 2 - 0.5).clamp(0.0, sh - 1.0);
        final ax = cx.floor(), ay = cy.floor();
        final bx = math.min(ax + 1, sw - 1), by = math.min(ay + 1, sh - 1);
        final tx = cx - ax, ty = cy - ay;
        for (var c = 0; c < 3; c++) {
          final p00 = src[(ay * sw + ax) * 4 + c];
          final p10 = src[(ay * sw + bx) * 4 + c];
          final p01 = src[(by * sw + ax) * 4 + c];
          final p11 = src[(by * sw + bx) * 4 + c];
          final top0 = p00 + (p10 - p00) * tx;
          final bottom0 = p01 + (p11 - p01) * tx;
          out[o + c] = (top0 + (bottom0 - top0) * ty).round();
        }
      }
      out[o + 3] = 255;
    }
  }
}
