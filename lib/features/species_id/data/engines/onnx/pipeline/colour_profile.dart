import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A photo's colours brought into sRGB from its embedded ICC profile.
///
/// The Core ML engine's photos are decoded by ImageIO and drawn into an
/// sRGB context, so a Display P3 or Adobe RGB photo reaches its models in
/// sRGB. Flutter's decoder ignores embedded profiles, so without this the
/// ONNX engine would see such a photo's raw values (on the photos measured,
/// a Display P3 photo's red came out 9 levels higher). This reads matrix
/// and curves profiles (Display P3, Adobe RGB, ProPhoto and the like) the
/// way littleCMS does, relative colorimetric; a profile of lookup tables
/// only, or one this cannot read, is left alone, as an untagged photo is.
/// No Flutter import: the conversion runs in the worker isolate.
class SrgbConversion {
  const SrgbConversion._(this.decode, this.matrix);

  /// For each channel, its 256 values' linear light (red, then green, then
  /// blue).
  final Float64List decode;

  /// Linear source RGB to linear sRGB, row by row.
  final Float64List matrix;
}

/// The conversion for the profile embedded in [encoded] (a JPEG's APP2
/// `ICC_PROFILE` segments or a PNG's iCCP chunk); null when there is none,
/// when it describes sRGB already, or when it cannot be read.
SrgbConversion? srgbConversionOf(Uint8List encoded) {
  try {
    final icc = _embeddedProfile(encoded);
    if (icc == null) {
      return null;
    }
    final conversion = _readProfile(icc);
    if (conversion == null || _isSrgb(conversion)) {
      return null;
    }
    return conversion;
  } on Object {
    // A malformed profile is treated as no profile, as decoders do.
    return null;
  }
}

/// [rgba] (four bytes a pixel) converted to sRGB by [conversion], as a new
/// list; alpha is kept.
///
/// In fixed point, as littleCMS converts 8-bit matrix profiles: each
/// channel value's share of each linear output is looked up in whole
/// 1/256ths of an encode-table step, so a pixel costs nine table reads and
/// integer sums, about three times faster than the same sums in floating
/// point over a 12 MP photo, and within a level of them (a rounding edge,
/// well under 1% of values).
Uint8List toSrgbBytes(Uint8List rgba, SrgbConversion conversion) {
  final s = _shares(conversion);
  final encode = _encodeTable;
  final out = Uint8List(rgba.length);
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final r = rgba[i], g = 256 + rgba[i + 1], b = 512 + rgba[i + 2];
    out[i] = encode[_step(s[r] + s[g] + s[b])];
    out[i + 1] = encode[_step(s[768 + r] + s[768 + g] + s[768 + b])];
    out[i + 2] = encode[_step(s[1536 + r] + s[1536 + g] + s[1536 + b])];
    out[i + 3] = rgba[i + 3];
  }
  return out;
}

const _encodeSteps = 65535;

/// The shares: for output channel k, input channel c and value v, at
/// `(k * 3 + c) * 256 + v`, the value's linear light times the matrix
/// entry, in 1/256ths of an encode-table step.
Int32List _shares(SrgbConversion c) {
  final s = Int32List(9 * 256);
  for (var k = 0; k < 3; k++) {
    for (var ch = 0; ch < 3; ch++) {
      final m = c.matrix[k * 3 + ch] * _encodeSteps * 256;
      for (var v = 0; v < 256; v++) {
        s[(k * 3 + ch) * 256 + v] = (m * c.decode[ch * 256 + v]).round();
      }
    }
  }
  return s;
}

/// A sum of shares as an encode-table index, rounded and clamped.
int _step(int shares) {
  final step = (shares + 128) >> 8;
  return step < 0 ? 0 : (step > _encodeSteps ? _encodeSteps : step);
}

/// Linear light to an 8-bit sRGB value, in 65,536 steps: fine enough near
/// black, where the curve is steepest, to round as a direct calculation
/// would.
final Uint8List _encodeTable = () {
  final t = Uint8List(_encodeSteps + 1);
  for (var i = 0; i <= _encodeSteps; i++) {
    final l = i / _encodeSteps;
    final v = l <= 0.0031308 ? 12.92 * l : 1.055 * math.pow(l, 1 / 2.4) - 0.055;
    t[i] = (v * 255 + 0.5).floor().clamp(0, 255);
  }
  return t;
}();

/// sRGB's colorants (D50), columns red, green and blue, as littleCMS's
/// built-in sRGB profile has them.
const _srgbColorants = [
  0.436041, 0.385113, 0.143046, //
  0.222485, 0.716905, 0.06061,
  0.01392, 0.097067, 0.713913,
];

bool _isSrgb(SrgbConversion c) {
  // Every channel's ramp and the grey ramp coming back within a level is
  // sRGB, give or take the profile's rounding: no conversion. The four
  // ramps go through as one strip of pixels.
  final ramps = Uint8List(4 * 256 * 4);
  for (var v = 0; v < 256; v++) {
    for (var ramp = 0; ramp < 4; ramp++) {
      final p = (ramp * 256 + v) * 4;
      for (var k = 0; k < 3; k++) {
        ramps[p + k] = ramp == 3 || ramp == k ? v : 0;
      }
      ramps[p + 3] = 255;
    }
  }
  final out = toSrgbBytes(ramps, c);
  for (var i = 0; i < ramps.length; i += 4) {
    for (var k = 0; k < 3; k++) {
      if ((out[i + k] - ramps[i + k]).abs() > 1) return false;
    }
  }
  return true;
}

// MARK: Finding the profile

Uint8List? _embeddedProfile(Uint8List b) {
  if (b.length > 4 && b[0] == 0xff && b[1] == 0xd8) return _jpegProfile(b);
  const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (b.length > 8 && Iterable<int>.generate(8).every((i) => b[i] == png[i])) {
    return _pngProfile(b);
  }
  return null;
}

const _iccMarker = 'ICC_PROFILE';

Uint8List? _jpegProfile(Uint8List b) {
  final chunks = <int, Uint8List>{};
  var count = 0;
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xff) {
    final marker = b[i + 1];
    if (marker == 0xff) {
      i++; // fill byte
      continue;
    }
    if (marker == 0xda || marker == 0xd9) break; // image data or the end
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      i += 2;
      continue;
    }
    final length = (b[i + 2] << 8) | b[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > b.length) {
      return null;
    }
    if (marker == 0xe2 &&
        length >= 16 &&
        _startsWith(b, i + 4, _iccMarker) &&
        b[i + 4 + 11] == 0) {
      chunks[b[i + 16]] = Uint8List.sublistView(b, i + 18, end);
      count = b[i + 17];
    }
    i = end;
  }
  if (chunks.isEmpty || count == 0) {
    return null;
  }
  final joined = BytesBuilder(copy: false);
  for (var s = 1; s <= count; s++) {
    final chunk = chunks[s];
    if (chunk == null) {
      return null;
    }
    joined.add(chunk);
  }
  return joined.toBytes();
}

Uint8List? _pngProfile(Uint8List b) {
  var i = 8;
  while (i + 8 <= b.length) {
    final length = ByteData.sublistView(b, i, i + 4).getUint32(0);
    final type = String.fromCharCodes(b, i + 4, i + 8);
    final start = i + 8, end = start + length;
    if (end > b.length) {
      return null;
    }
    if (type == 'iCCP') {
      var n = start;
      while (n < end && b[n] != 0) {
        n++;
      }
      if (n + 2 > end || b[n + 1] != 0) return null; // zlib only
      return const ZLibDecoder().decodeBytes(
        Uint8List.sublistView(b, n + 2, end),
      );
    }
    if (type == 'IDAT' || type == 'IEND') {
      return null;
    }
    i = end + 4; // the CRC
  }
  return null;
}

bool _startsWith(Uint8List b, int at, String s) {
  if (at + s.length > b.length) return false;
  for (var k = 0; k < s.length; k++) {
    if (b[at + k] != s.codeUnitAt(k)) return false;
  }
  return true;
}

// MARK: Reading a matrix and curves profile

SrgbConversion? _readProfile(Uint8List icc) {
  if (icc.length < 132) {
    return null;
  }
  final data = ByteData.sublistView(icc);
  if (!_startsWith(icc, 16, 'RGB ') || !_startsWith(icc, 20, 'XYZ ')) {
    return null;
  }
  final tags = <String, int>{};
  final count = data.getUint32(128);
  if (132 + count * 12 > icc.length) {
    return null;
  }
  for (var t = 0; t < count; t++) {
    final at = 132 + t * 12;
    final offset = data.getUint32(at + 4), size = data.getUint32(at + 8);
    if (offset + size > icc.length) {
      return null;
    }
    tags[String.fromCharCodes(icc, at, at + 4)] = offset;
  }
  final colorants = <List<double>>[];
  for (final tag in ['rXYZ', 'gXYZ', 'bXYZ']) {
    final at = tags[tag];
    if (at == null || at + 20 > icc.length || !_startsWith(icc, at, 'XYZ ')) {
      return null;
    }
    colorants.add([
      for (var k = 0; k < 3; k++) data.getInt32(at + 8 + 4 * k) / 65536,
    ]);
  }
  final decode = Float64List(3 * 256);
  for (var ch = 0; ch < 3; ch++) {
    final at = tags[['rTRC', 'gTRC', 'bTRC'][ch]];
    if (at == null) {
      return null;
    }
    final curve = _curve(icc, data, at);
    if (curve == null) {
      return null;
    }
    for (var v = 0; v < 256; v++) {
      decode[ch * 256 + v] = curve(v / 255);
    }
  }
  // Source linear RGB to XYZ (columns are the colorants), then XYZ to
  // linear sRGB.
  final source = [
    for (var row = 0; row < 3; row++)
      for (var col = 0; col < 3; col++) colorants[col][row],
  ];
  final toSrgb = _inverse(_srgbColorants);
  if (toSrgb == null) {
    return null;
  }
  return SrgbConversion._(
    decode,
    Float64List.fromList(_multiply(toSrgb, source)),
  );
}

/// A `curv` or `para` tag's curve, input and output 0 to 1.
double Function(double)? _curve(Uint8List icc, ByteData data, int at) {
  if (at + 12 > icc.length) {
    return null;
  }
  if (_startsWith(icc, at, 'curv')) {
    final n = data.getUint32(at + 8);
    if (at + 12 + 2 * n > icc.length) {
      return null;
    }
    if (n == 0) return (x) => x;
    if (n == 1) {
      final gamma = data.getUint16(at + 12) / 256;
      return (x) => math.pow(x, gamma).toDouble();
    }
    final table = [
      for (var k = 0; k < n; k++) data.getUint16(at + 12 + 2 * k) / 65535,
    ];
    return (x) {
      final pos = x * (n - 1);
      final lo = pos.floor().clamp(0, n - 1), hi = (lo + 1).clamp(0, n - 1);
      return table[lo] + (table[hi] - table[lo]) * (pos - lo);
    };
  }
  if (_startsWith(icc, at, 'para')) {
    final type = data.getUint16(at + 8);
    const counts = [1, 3, 4, 5, 7];
    if (type >= counts.length || at + 12 + 4 * counts[type] > icc.length) {
      return null;
    }
    final p = [
      for (var k = 0; k < counts[type]; k++)
        data.getInt32(at + 12 + 4 * k) / 65536,
    ];
    final g = p[0];
    double power(double base) => base <= 0 ? 0 : math.pow(base, g).toDouble();
    return switch (type) {
      0 => (x) => power(x),
      1 => (x) => x >= -p[2] / p[1] ? power(p[1] * x + p[2]) : 0,
      2 => (x) => x >= -p[2] / p[1] ? power(p[1] * x + p[2]) + p[3] : p[3],
      3 => (x) => x >= p[4] ? power(p[1] * x + p[2]) : p[3] * x,
      _ => (x) => x >= p[4] ? power(p[1] * x + p[2]) + p[5] : p[3] * x + p[6],
    };
  }
  return null;
}

List<double>? _inverse(List<double> m) {
  final a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5];
  final g = m[6], h = m[7], i = m[8];
  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  if (det.abs() < 1e-12) {
    return null;
  }
  return [
    (e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det, //
    (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det,
    (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det,
  ];
}

List<double> _multiply(List<double> x, List<double> y) => [
  for (var row = 0; row < 3; row++)
    for (var col = 0; col < 3; col++)
      x[row * 3] * y[col] +
          x[row * 3 + 1] * y[3 + col] +
          x[row * 3 + 2] * y[6 + col],
];
