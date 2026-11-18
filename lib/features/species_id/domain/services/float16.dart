/// IEEE 754 half precision, little endian, as the model pack stores its
/// text embeddings and the device-local cache stores crop embeddings.
///
/// Only 16-bit and 32-bit views and shifts under 32 are used, so this runs
/// unchanged where integers are JavaScript numbers.
library;

import 'dart:typed_data';

/// 2^(e - 15) for a normal half's biased exponent `e` (1 to 30).
final List<double> _powerOfTwo = () {
  final table = List<double>.filled(32, 0);
  var value = 1.0;
  for (var e = 15; e < 32; e++) {
    table[e] = value;
    value *= 2;
  }
  value = 0.5;
  for (var e = 14; e >= 0; e--) {
    table[e] = value;
    value /= 2;
  }
  return table;
}();

/// 2^-24: the weight of a subnormal half's lowest mantissa bit.
const double _subnormalUnit = 5.960464477539063e-8;

/// Decodes [littleEndianBytes], two bytes per value.
Float32List decodeFloat16(Uint8List littleEndianBytes) {
  if (littleEndianBytes.length.isOdd) {
    throw ArgumentError.value(
      littleEndianBytes.length,
      'littleEndianBytes',
      'must hold a whole number of 16-bit values',
    );
  }
  final count = littleEndianBytes.length ~/ 2;
  final out = Float32List(count);
  final data = ByteData.sublistView(littleEndianBytes);
  for (var i = 0; i < count; i++) {
    out[i] = _fromHalf(data.getUint16(i * 2, Endian.little));
  }
  return out;
}

/// Encodes [values], rounding each to the nearest half. A magnitude too
/// large for half precision becomes infinity.
Uint8List encodeFloat16(Float32List values) {
  final out = Uint8List(values.length * 2);
  final data = ByteData.sublistView(out);
  final scratch = ByteData(4);
  for (var i = 0; i < values.length; i++) {
    scratch.setFloat32(0, values[i]);
    data.setUint16(i * 2, _toHalf(scratch.getUint32(0)), Endian.little);
  }
  return out;
}

double _fromHalf(int half) {
  final negative = (half & 0x8000) != 0;
  final exponent = (half >> 10) & 0x1f;
  final mantissa = half & 0x3ff;
  final double magnitude;
  if (exponent == 0) {
    magnitude = mantissa * _subnormalUnit;
  } else if (exponent == 31) {
    if (mantissa != 0) return double.nan;
    magnitude = double.infinity;
  } else {
    magnitude = (1 + mantissa / 1024) * _powerOfTwo[exponent];
  }
  return negative ? -magnitude : magnitude;
}

int _toHalf(int float32Bits) {
  final sign = (float32Bits >> 16) & 0x8000;
  final exponent = (float32Bits >> 23) & 0xff;
  final mantissa = float32Bits & 0x7fffff;
  if (exponent == 0xff) {
    return sign | 0x7c00 | (mantissa != 0 ? 0x200 : 0);
  }
  final halfExponent = exponent - 127 + 15;
  if (halfExponent >= 31) return sign | 0x7c00;
  if (halfExponent <= 0) {
    // Too small for a normal half: a subnormal, or zero.
    if (halfExponent < -10) return sign;
    var shifted = (mantissa | 0x800000) >> (1 - halfExponent);
    if ((shifted & 0x1000) != 0) shifted += 0x2000;
    return sign | (shifted >> 13);
  }
  final half = sign | (halfExponent << 10) | (mantissa >> 13);
  // Round to nearest; a carry out of the mantissa raises the exponent, and
  // out of the top exponent gives infinity, both of which are right.
  return (mantissa & 0x1000) != 0 ? half + 1 : half;
}
