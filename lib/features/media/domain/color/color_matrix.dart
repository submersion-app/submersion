import 'package:equatable/equatable.dart';

/// A 4x5 colour matrix in the layout `ColorFilter.matrix` takes: rows R, G,
/// B, A; columns r, g, b, a, offset. Offsets are on the 0-255 scale.
///
/// Every display-time colour correction (automatic, by hand, or both) is one
/// of these, so the same value draws a grid tile, a full-screen photo and a
/// playing video, and is applied to pixels when a photo is shared.
class ColorMatrix extends Equatable {
  const ColorMatrix(this.values);

  final List<double> values;

  static const identity = ColorMatrix([
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Per-channel multipliers.
  static ColorMatrix gains(double r, double g, double b) => ColorMatrix([
    r, 0, 0, 0, 0, //
    0, g, 0, 0, 0, //
    0, 0, b, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Rebuilds missing red from green: R' = R + a * G.
  static ColorMatrix redFromGreen(double a) => ColorMatrix([
    1, a, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// [w] in -1..1; positive warms (more red, less blue).
  static ColorMatrix warmth(double w) => gains(1 + 0.25 * w, 1, 1 - 0.25 * w);

  /// [t] in -1..1; positive pulls toward magenta (less green).
  static ColorMatrix tint(double t) => gains(1, 1 - 0.2 * t, 1);

  /// [b] in -1..1; adds up to 64 to each channel.
  static ColorMatrix brightness(double b) {
    final o = 64 * b;
    return ColorMatrix([
      1, 0, 0, 0, o, //
      0, 1, 0, 0, o, //
      0, 0, 1, 0, o, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// [c] in -1..1; scales each channel's distance from mid-grey by 1 + c.
  static ColorMatrix contrast(double c) {
    final k = 1 + c;
    final o = 128 * (1 - k);
    return ColorMatrix([
      k, 0, 0, 0, o, //
      0, k, 0, 0, o, //
      0, 0, k, 0, o, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// [s] in -1..1; -1 is greyscale (Rec. 709 luma), +1 doubles saturation.
  static ColorMatrix saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final k = 1 + s;
    final i = 1 - k;
    return ColorMatrix([
      lr * i + k, lg * i, lb * i, 0, 0, //
      lr * i, lg * i + k, lb * i, 0, 0, //
      lr * i, lg * i, lb * i + k, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }

  static ColorMatrix lerp(ColorMatrix a, ColorMatrix b, double t) =>
      ColorMatrix([
        for (var i = 0; i < 20; i++)
          a.values[i] + (b.values[i] - a.values[i]) * t,
      ]);

  bool get isIdentity {
    for (var i = 0; i < 20; i++) {
      if ((values[i] - identity.values[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  /// The matrix that applies this one first, then [next].
  ColorMatrix then(ColorMatrix next) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += next.values[row * 5 + k] * values[k * 5 + col];
        }
        // The implicit fifth row of [this] is [0, 0, 0, 0, 1].
        if (col == 4) sum += next.values[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return ColorMatrix(out);
  }

  /// Applies the matrix to an opaque pixel, clamped to 0..255.
  (int, int, int) applyToPixel(int r, int g, int b) {
    int channel(int row) {
      final o = row * 5;
      final v =
          values[o] * r +
          values[o + 1] * g +
          values[o + 2] * b +
          values[o + 3] * 255 +
          values[o + 4];
      return v.round().clamp(0, 255);
    }

    return (channel(0), channel(1), channel(2));
  }

  @override
  List<Object?> get props => [values];
}
