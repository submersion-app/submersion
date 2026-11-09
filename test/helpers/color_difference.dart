import 'dart:math' as math;
import 'dart:ui';

/// How different two colours look to a person: CIEDE2000 (Sharma, Wu and
/// Dalal, 2005) on sRGB colours under D65. About 2 is a just noticeable
/// difference. Purple and indigo chart dots, about 20 apart, were hard to
/// tell apart at a glance, so series that must be read apart want more.
double colorDifference(Color a, Color b) => ciede2000(_lab(a), _lab(b));

/// CIEDE2000 between two CIELAB colours given as (L, a, b).
double ciede2000(
  (double, double, double) first,
  (double, double, double) second,
) {
  final (l1, a1, b1) = first;
  final (l2, a2, b2) = second;
  double rad(double degrees) => degrees * math.pi / 180;
  double deg(double radians) => radians * 180 / math.pi;
  double pow7(double v) => math.pow(v, 7).toDouble();

  final cBar =
      (math.sqrt(a1 * a1 + b1 * b1) + math.sqrt(a2 * a2 + b2 * b2)) / 2;
  final g = 0.5 * (1 - math.sqrt(pow7(cBar) / (pow7(cBar) + pow7(25))));
  final a1p = (1 + g) * a1;
  final a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  double hue(double b, double ap) =>
      b == 0 && ap == 0 ? 0 : (deg(math.atan2(b, ap)) + 360) % 360;
  final h1p = hue(b1, a1p);
  final h2p = hue(b2, a2p);

  final dLp = l2 - l1;
  final dCp = c2p - c1p;
  var dhp = h2p - h1p;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else if (dhp > 180) {
    dhp -= 360;
  } else if (dhp < -180) {
    dhp += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dhp / 2));

  final lBarP = (l1 + l2) / 2;
  final cBarP = (c1p + c2p) / 2;
  final double hBarP;
  if (c1p * c2p == 0) {
    hBarP = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarP = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarP = (h1p + h2p + 360) / 2;
  } else {
    hBarP = (h1p + h2p - 360) / 2;
  }
  final t =
      1 -
      0.17 * math.cos(rad(hBarP - 30)) +
      0.24 * math.cos(rad(2 * hBarP)) +
      0.32 * math.cos(rad(3 * hBarP + 6)) -
      0.20 * math.cos(rad(4 * hBarP - 63));
  final dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2));
  final rc = 2 * math.sqrt(pow7(cBarP) / (pow7(cBarP) + pow7(25)));
  final lOffset = math.pow(lBarP - 50, 2);
  final sl = 1 + 0.015 * lOffset / math.sqrt(20 + lOffset);
  final sc = 1 + 0.045 * cBarP;
  final sh = 1 + 0.015 * cBarP * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;

  final l = dLp / sl;
  final c = dCp / sc;
  final h = dHp / sh;
  return math.sqrt(l * l + c * c + h * h + rt * c * h);
}

/// sRGB under D65 to CIELAB.
(double, double, double) _lab(Color color) {
  double linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  final r = linear(color.r);
  final g = linear(color.g);
  final b = linear(color.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double v) =>
      v > 0.008856 ? math.pow(v, 1 / 3).toDouble() : 7.787 * v + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}
