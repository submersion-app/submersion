import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/media/domain/color/color_adjustment.dart';

/// The mean colour of the square of side `2 * radius + 1` around [at] in a
/// straight-RGBA image of [width] x [height], for "Pick white" (issue
/// #3520). Null when [at] is outside the image or the patch is too dark to
/// carry a colour (luma below 0.04), so a tap on black water is refused
/// rather than blowing the gains up.
WhitePoint? averageWhiteAround(
  ByteData rgba,
  int width,
  int height,
  Offset at, {
  int radius = 4,
}) {
  final cx = at.dx.floor(), cy = at.dy.floor();
  if (cx < 0 || cy < 0 || cx >= width || cy >= height) return null;
  var sumR = 0, sumG = 0, sumB = 0, n = 0;
  for (
    var y = math.max(0, cy - radius);
    y <= math.min(height - 1, cy + radius);
    y++
  ) {
    for (
      var x = math.max(0, cx - radius);
      x <= math.min(width - 1, cx + radius);
      x++
    ) {
      final o = (y * width + x) * 4;
      sumR += rgba.getUint8(o);
      sumG += rgba.getUint8(o + 1);
      sumB += rgba.getUint8(o + 2);
      n++;
    }
  }
  final r = sumR / (n * 255), g = sumG / (n * 255), b = sumB / (n * 255);
  if (0.2126 * r + 0.7152 * g + 0.0722 * b < 0.04) return null;
  return WhitePoint(r, g, b);
}

/// Where a tap at [tap] in a box of [boxSize] lands on a frame of
/// [frameSize] drawn there with `BoxFit.contain`, in frame pixels; null on
/// the letterbox.
Offset? tapToFramePixel(
  Offset tap, {
  required Size boxSize,
  required Size frameSize,
}) {
  final scale = math.min(
    boxSize.width / frameSize.width,
    boxSize.height / frameSize.height,
  );
  final left = (boxSize.width - frameSize.width * scale) / 2;
  final top = (boxSize.height - frameSize.height * scale) / 2;
  final x = (tap.dx - left) / scale, y = (tap.dy - top) / scale;
  if (x < 0 || y < 0 || x >= frameSize.width || y >= frameSize.height) {
    return null;
  }
  return Offset(x, y);
}
