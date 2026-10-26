import 'dart:math' as math;

/// How a video's pixel values encode light.
enum SignalTransfer { sdr, pq, hlg }

/// Applies a 4x5 colour [matrix] to one pixel's encoded R'G'B' ([rgb], each
/// 0..1) and returns the encoded result, the way every colour encoder in
/// this package does (issue #3521). This is the reference the native code
/// is tested against.
///
/// SDR: the matrix works on the encoded values, as Flutter's
/// `ColorFilter.matrix` does, offsets divided by 255, clamped.
///
/// HDR (PQ, HLG): the pixel is taken to linear light relative to SDR
/// reference white (PQ 203 cd/m2; HLG the 75% signal level, BT.2408),
/// converted from BT.2020 to BT.709 primaries, encoded with the sRGB curve
/// extended past 0..1, given the matrix unclamped, and taken back the same
/// way. Inside the SDR range that is exactly the SDR result; highlights
/// carry on instead of clipping.
List<double> correctPixel(
  List<double> rgb,
  List<double> matrix,
  SignalTransfer transfer,
) {
  if (transfer == SignalTransfer.sdr) {
    return [for (final v in _applyMatrix(rgb, matrix)) v.clamp(0.0, 1.0)];
  }
  final toLinear = transfer == SignalTransfer.pq
      ? (double e) => pqEotf(e) / pqReferenceWhiteNits
      : (double e) => hlgInverseOetf(e) / _hlgReferenceWhite;
  final fromLinear = transfer == SignalTransfer.pq
      ? (double l) => pqInverseEotf(math.max(0, l) * pqReferenceWhiteNits)
      : (double l) => hlgOetf(math.max(0, l) * _hlgReferenceWhite);

  final linear709 = _mul3(bt2020To709, [for (final e in rgb) toLinear(e)]);
  final encoded = [for (final l in linear709) srgbEncodeExtended(l)];
  final corrected = _applyMatrix(encoded, matrix);
  final back2020 = _mul3(bt709To2020, [
    for (final v in corrected) srgbDecodeExtended(v),
  ]);
  return [for (final l in back2020) fromLinear(l).clamp(0.0, 1.0)];
}

List<double> _applyMatrix(List<double> rgb, List<double> m) => [
  for (var row = 0; row < 3; row++)
    m[row * 5] * rgb[0] +
        m[row * 5 + 1] * rgb[1] +
        m[row * 5 + 2] * rgb[2] +
        m[row * 5 + 3] +
        m[row * 5 + 4] / 255,
];

List<double> _mul3(List<double> m, List<double> v) => [
  for (var r = 0; r < 3; r++)
    m[r * 3] * v[0] + m[r * 3 + 1] * v[1] + m[r * 3 + 2] * v[2],
];

/// SDR reference white for PQ, ITU-R BT.2408.
const pqReferenceWhiteNits = 203.0;

/// Linear BT.709 to linear BT.2020, row-major (ITU-R BT.2087).
const bt709To2020 = <double>[
  0.627403895934699, 0.329283038377884, 0.043313065687417, //
  0.069097289358232, 0.919540395075459, 0.011362315566309, //
  0.016391438875150, 0.088013307877226, 0.895595253247624, //
];

/// Linear BT.2020 to linear BT.709: the exact inverse of [bt709To2020].
final bt2020To709 = _invert3(bt709To2020);

List<double> _invert3(List<double> m) {
  final a = m[0], b = m[1], c = m[2];
  final d = m[3], e = m[4], f = m[5];
  final g = m[6], h = m[7], i = m[8];
  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  return [
    (e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det, //
    (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det, //
    (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det, //
  ];
}

/// The sRGB transfer curve, extended past 0..1 and mirrored for negatives.
double srgbEncodeExtended(double l) {
  final x = l.abs();
  final v = x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
  return l < 0 ? -v : v;
}

/// The inverse of [srgbEncodeExtended].
double srgbDecodeExtended(double v) {
  final x = v.abs();
  final l = x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4);
  return v < 0 ? -l.toDouble() : l.toDouble();
}

const _pqM1 = 2610 / 16384;
const _pqM2 = 2523 / 4096 * 128;
const _pqC1 = 3424 / 4096;
const _pqC2 = 2413 / 4096 * 32;
const _pqC3 = 2392 / 4096 * 32;

/// SMPTE ST 2084: signal 0..1 to luminance in cd/m2.
double pqEotf(double e) {
  final p = math.pow(e.clamp(0.0, 1.0), 1 / _pqM2).toDouble();
  final y = math.pow(math.max(p - _pqC1, 0) / (_pqC2 - _pqC3 * p), 1 / _pqM1);
  return 10000 * y.toDouble();
}

/// SMPTE ST 2084: luminance in cd/m2 to signal 0..1.
double pqInverseEotf(double nits) {
  final y = math.pow((nits / 10000).clamp(0.0, 1.0), _pqM1).toDouble();
  return math.pow((_pqC1 + _pqC2 * y) / (1 + _pqC3 * y), _pqM2).toDouble();
}

const _hlgA = 0.17883277;
const _hlgB = 1 - 4 * _hlgA;
final _hlgC = 0.5 - _hlgA * math.log(4 * _hlgA);

/// BT.2100 HLG OETF: scene light 0..1 to signal 0..1.
double hlgOetf(double l) {
  if (l <= 1 / 12) return math.sqrt(3 * math.max(0, l));
  return _hlgA * math.log(12 * l - _hlgB) + _hlgC;
}

/// BT.2100 HLG inverse OETF: signal 0..1 to scene light 0..1.
double hlgInverseOetf(double e) {
  if (e <= 0.5) return e * e / 3;
  return (math.exp((e - _hlgC) / _hlgA) + _hlgB) / 12;
}

/// HLG's SDR reference white in scene light: the 75% signal level.
final _hlgReferenceWhite = hlgInverseOetf(0.75);
