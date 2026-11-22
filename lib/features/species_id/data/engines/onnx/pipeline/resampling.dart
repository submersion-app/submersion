import 'dart:math' as math;
import 'dart:typed_data';

/// The ONNX pipeline's one resampling filter: a model of Core Graphics
/// drawing an image with `interpolationQuality = .high`, which is how the
/// Swift pipeline (`VisionPipeline.swift`, `rgba`) draws every detector
/// input and classifier crop. The models' bars were measured on the Core
/// ML engine's pixels, so the ONNX engine draws them the same way. The
/// rules were measured from Core Graphics itself (impulses, edges and
/// noise, each axis on its own) and are pinned by `resampling_test.dart`:
///
/// * Growing an axis: each output pixel's centre maps proportionally into
///   the source, and it blends the two nearest source pixels by a fixed
///   curve of the distance between them, taken in eighths: 0, 1, 2, 4, 8,
///   12, 14, 15 and 16 sixteenths. A straight blend (bilinear) would be
///   2, 4, 6 and so on.
/// * Shrinking an axis: the first and last source pixels map to the first
///   and last output pixels (corners aligned, not centres spaced evenly),
///   and each output pixel is a Keys cubic (a = -0.5) widened by the
///   shrink factor, the edge pixels repeated beyond the image.
///
/// Measured against Core Graphics on 300 photo crops and 99 detector
/// inputs, this leaves under half a level of difference on average, where
/// the area average and bilinear filter it replaces left 1.8. Core
/// Graphics also snaps the phase when shrinking a little (under about 1.5
/// times), which is not modelled: it costs up to about 3 levels on noise
/// and a fraction of one on photos.
///
/// Resamples [source] ([sourceWidth] by [sourceHeight] RGBA) into the
/// rectangle at [left], [top] of [width] by [height] in [out] ([outWidth]
/// by [outHeight] RGBA). Only the output pixels whose centres lie in the
/// rectangle are written, opaque; the rest keep what [out] held.
void resampleRgba(
  Uint8List source,
  int sourceWidth,
  int sourceHeight,
  Uint8List out,
  int outWidth,
  int outHeight, {
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  if (width <= 0 || height <= 0 || sourceWidth <= 0 || sourceHeight <= 0) {
    return;
  }
  final xs = _AxisTaps(sourceWidth, outWidth, left, width);
  final ys = _AxisTaps(sourceHeight, outHeight, top, height);
  if (xs.isEmpty || ys.isEmpty) return;
  // Separable: the axis that leaves the smaller intermediate goes first.
  final rowsFirst = ys.count * sourceWidth <= sourceHeight * xs.count;
  if (rowsFirst) {
    // Each output row from the source rows, then across.
    final mid = Float32List(ys.count * sourceWidth * 3);
    for (var r = 0; r < ys.count; r++) {
      final taps = ys.first[r], n = ys.length[r], w0 = ys.offset[r];
      for (var x = 0; x < sourceWidth; x++) {
        var red = 0.0, green = 0.0, blue = 0.0;
        for (var k = 0; k < n; k++) {
          final i = ((taps + k) * sourceWidth + x) * 4;
          final w = ys.weights[w0 + k];
          red += source[i] * w;
          green += source[i + 1] * w;
          blue += source[i + 2] * w;
        }
        final m = (r * sourceWidth + x) * 3;
        mid[m] = red;
        mid[m + 1] = green;
        mid[m + 2] = blue;
      }
    }
    for (var r = 0; r < ys.count; r++) {
      for (var c = 0; c < xs.count; c++) {
        final taps = xs.first[c], n = xs.length[c], w0 = xs.offset[c];
        var red = 0.0, green = 0.0, blue = 0.0;
        for (var k = 0; k < n; k++) {
          final m = (r * sourceWidth + taps + k) * 3;
          final w = xs.weights[w0 + k];
          red += mid[m] * w;
          green += mid[m + 1] * w;
          blue += mid[m + 2] * w;
        }
        _put(
          out,
          ((ys.start + r) * outWidth + xs.start + c) * 4,
          red,
          green,
          blue,
        );
      }
    }
  } else {
    // Each source row across first, then down.
    final mid = Float32List(sourceHeight * xs.count * 3);
    for (var y = 0; y < sourceHeight; y++) {
      for (var c = 0; c < xs.count; c++) {
        final taps = xs.first[c], n = xs.length[c], w0 = xs.offset[c];
        var red = 0.0, green = 0.0, blue = 0.0;
        for (var k = 0; k < n; k++) {
          final i = (y * sourceWidth + taps + k) * 4;
          final w = xs.weights[w0 + k];
          red += source[i] * w;
          green += source[i + 1] * w;
          blue += source[i + 2] * w;
        }
        final m = (y * xs.count + c) * 3;
        mid[m] = red;
        mid[m + 1] = green;
        mid[m + 2] = blue;
      }
    }
    for (var r = 0; r < ys.count; r++) {
      final taps = ys.first[r], n = ys.length[r], w0 = ys.offset[r];
      for (var c = 0; c < xs.count; c++) {
        var red = 0.0, green = 0.0, blue = 0.0;
        for (var k = 0; k < n; k++) {
          final m = ((taps + k) * xs.count + c) * 3;
          final w = ys.weights[w0 + k];
          red += mid[m] * w;
          green += mid[m + 1] * w;
          blue += mid[m + 2] * w;
        }
        _put(
          out,
          ((ys.start + r) * outWidth + xs.start + c) * 4,
          red,
          green,
          blue,
        );
      }
    }
  }
}

void _put(Uint8List out, int o, double red, double green, double blue) {
  out[o] = _byte(red);
  out[o + 1] = _byte(green);
  out[o + 2] = _byte(blue);
  out[o + 3] = 255;
}

int _byte(double v) => (v + 0.5).floor().clamp(0, 255);

/// Core Graphics' blend of the two nearest pixels when growing, by the
/// distance between them in eighths of a pixel (measured).
const _growingCurve = [
  0.0,
  1 / 16,
  2 / 16,
  4 / 16,
  8 / 16,
  12 / 16,
  14 / 16,
  15 / 16,
  1.0,
];

/// The Keys cubic convolution kernel with a = -0.5 (Catmull-Rom).
double _keys(double x) {
  final t = x.abs();
  if (t < 1) return (1.5 * t - 2.5) * t * t + 1;
  if (t < 2) return ((-0.5 * t + 2.5) * t - 4) * t + 2;
  return 0;
}

/// One axis's taps: for each output pixel from [start] (the first whose
/// centre lies in the target span) for [count] pixels, the first source
/// pixel it reads, how many in a row, and their weights (summing to one).
class _AxisTaps {
  factory _AxisTaps(int n, int outLength, double spanStart, double span) {
    // Output pixels whose centres lie in [spanStart, spanStart + span).
    final start = math.max(0, (spanStart - 0.5).ceil());
    final end = math.min(outLength, (spanStart + span - 0.5).ceil());
    final count = math.max(0, end - start);
    final first = Int32List(count), length = Int32List(count);
    final offset = Int32List(count);
    final weights = <double>[];
    final shrinking = n > span && span > 1;
    final scale = n / span;
    for (var o = 0; o < count; o++) {
      final centre = start + o + 0.5;
      offset[o] = weights.length;
      if (shrinking) {
        final c = (centre - spanStart - 0.5) * (n - 1) / (span - 1);
        final lo = (c - 2 * scale).floor(), hi = (c + 2 * scale).ceil();
        final from = lo.clamp(0, n - 1), to = hi.clamp(0, n - 1);
        final row = List<double>.filled(to - from + 1, 0);
        var total = 0.0;
        for (var i = lo; i <= hi; i++) {
          final w = _keys((i - c) / scale);
          if (w == 0) continue;
          row[i.clamp(0, n - 1) - from] += w;
          total += w;
        }
        first[o] = from;
        length[o] = row.length;
        for (final w in row) {
          weights.add(w / total);
        }
      } else {
        final c = (centre - spanStart) * scale - 0.5;
        final i0 = c.floor();
        // A phase exactly between two eighths goes to the later one, as in
        // Core Graphics; the tolerance keeps one that floating point puts
        // a hair under the half going the same way.
        final t = _growingCurve[((c - i0) * 8 + 0.5 + 1e-9).floor()];
        final a = i0.clamp(0, n - 1), b = (i0 + 1).clamp(0, n - 1);
        first[o] = a;
        if (a == b) {
          length[o] = 1;
          weights.add(1);
        } else {
          length[o] = 2;
          weights
            ..add(1 - t)
            ..add(t);
        }
      }
    }
    return _AxisTaps._(
      start,
      count,
      first,
      length,
      offset,
      Float64List.fromList(weights),
    );
  }

  const _AxisTaps._(
    this.start,
    this.count,
    this.first,
    this.length,
    this.offset,
    this.weights,
  );

  final int start;
  final int count;
  final Int32List first;
  final Int32List length;
  final Int32List offset;
  final Float64List weights;

  bool get isEmpty => count == 0;
}
