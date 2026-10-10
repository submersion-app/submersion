import 'dart:math' as math;

/// WCAG 2.x contrast ratio between two ARGB colours, alpha ignored: 1 for
/// identical, 21 for black on white. The same sums as Flutter's
/// `Color.computeLuminance`, kept here so the palette stays pure Dart.
double figureContrast(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(int argb) {
  double linear(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0);
}
