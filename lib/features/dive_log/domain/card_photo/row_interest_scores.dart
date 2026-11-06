import 'dart:math' as math;
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';

/// One interest score per row of a small straight-RGBA image, top to bottom,
/// for choosing which strip of a photo a dive card shows.
///
/// The image is blurred 3x3 first, so isolated bright specks (backscatter)
/// drop out while a real subject survives. Each pixel then scores its local
/// brightness change (texture, outlines) plus its distance from the photo's
/// mean colour (a strobe-lit subject against water), capped so a few
/// extreme pixels cannot decide. Very dark pixels score nothing. A row's
/// score is its pixels' mean.
///
/// Null when [rgba] does not hold [width] x [height] pixels, or when too few
/// pixels are bright enough to say anything.
List<double>? rowInterestScores(Uint8List rgba, int width, int height) {
  final count = width * height;
  if (width < 1 || height < 1 || rgba.length != count * 4) return null;

  final r = Float64List(count);
  final g = Float64List(count);
  final b = Float64List(count);
  for (var i = 0; i < count; i++) {
    r[i] = rgba[i * 4] / 255;
    g[i] = rgba[i * 4 + 1] / 255;
    b[i] = rgba[i * 4 + 2] / 255;
  }
  final br = _blur3(r, width, height);
  final bg = _blur3(g, width, height);
  final bb = _blur3(b, width, height);

  final luma = Float64List(count);
  var usable = 0;
  var sumR = 0.0;
  var sumG = 0.0;
  var sumB = 0.0;
  for (var i = 0; i < count; i++) {
    final l = 0.2126 * br[i] + 0.7152 * bg[i] + 0.0722 * bb[i];
    luma[i] = l;
    if (l >= CardPhotoTuning.minLuma) {
      usable++;
      sumR += br[i];
      sumG += bg[i];
      sumB += bb[i];
    }
  }
  if (usable < count * CardPhotoTuning.minUsableShare) return null;
  final meanR = sumR / usable;
  final meanG = sumG / usable;
  final meanB = sumB / usable;

  final rows = List<double>.filled(height, 0);
  for (var y = 0; y < height; y++) {
    final up = math.max(y - 1, 0);
    final down = math.min(y + 1, height - 1);
    var rowSum = 0.0;
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      if (luma[i] < CardPhotoTuning.minLuma) continue;
      final left = math.max(x - 1, 0);
      final right = math.min(x + 1, width - 1);
      final dx = luma[y * width + right] - luma[y * width + left];
      final dy = luma[down * width + x] - luma[up * width + x];
      final detail = dx.abs() + dy.abs();
      final dr = br[i] - meanR;
      final dg = bg[i] - meanG;
      final db = bb[i] - meanB;
      final colour = math.sqrt(dr * dr + dg * dg + db * db) / math.sqrt(3);
      final score =
          CardPhotoTuning.detailWeight * detail +
          CardPhotoTuning.colourWeight * colour;
      rowSum += math.min(score, CardPhotoTuning.pixelScoreCap);
    }
    rows[y] = rowSum / width;
  }
  return rows;
}

/// A 3x3 box blur of one channel, edges clamped.
Float64List _blur3(Float64List src, int width, int height) {
  final out = Float64List(src.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var sum = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = (y + dy).clamp(0, height - 1);
        for (var dx = -1; dx <= 1; dx++) {
          final xx = (x + dx).clamp(0, width - 1);
          sum += src[yy * width + xx];
        }
      }
      out[y * width + x] = sum / 9;
    }
  }
  return out;
}
