import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// Built test profiles and files carrying them, for the colour tests: each
/// profile is a minimal ICC profile with only the tags a matrix and curves
/// profile needs, its numbers those of the profile it stands for.

/// Display P3's colorants (D50, as Apple's profile stores them), columns
/// red, green, blue.
const displayP3Colorants = [
  [0.515121, 0.241196, -0.001053],
  [0.291977, 0.692245, 0.041885],
  [0.157104, 0.066574, 0.784073],
];

/// sRGB's colorants (D50, as littleCMS's built-in sRGB profile stores
/// them).
const srgbColorants = [
  [0.436041, 0.222485, 0.01392],
  [0.385113, 0.716905, 0.097067],
  [0.143046, 0.06061, 0.713913],
];

/// Adobe RGB (1998)'s colorants (D50).
const adobeColorants = [
  [0.609741, 0.311111, 0.019470],
  [0.205276, 0.625671, 0.060867],
  [0.149185, 0.063217, 0.744568],
];

/// The sRGB curve as Display P3's profile stores it (`para`, type 3).
const srgbCurveParams = [2.399994, 0.947861, 0.052139, 0.077393, 0.040451];

Uint8List _s15(double v) {
  final b = ByteData(4)..setInt32(0, (v * 65536).round());
  return b.buffer.asUint8List();
}

Uint8List _sig(String s) => Uint8List.fromList(s.codeUnits);

/// An `XYZ ` tag.
Uint8List xyzTag(List<double> xyz) => Uint8List.fromList([
  ..._sig('XYZ '), 0, 0, 0, 0, //
  for (final v in xyz) ..._s15(v),
]);

/// A `para` curve of function [type] (0 to 4; 3, the default, is
/// `(a x + b)^g` from `d`, `c x` below), [params] in the ICC order.
Uint8List paraTag(List<double> params, {int type = 3}) => Uint8List.fromList([
  ..._sig('para'), 0, 0, 0, 0, 0, type, 0, 0, //
  for (final v in params) ..._s15(v),
]);

/// A `curv` of one entry: a plain gamma, in steps of 1/256.
Uint8List gammaTag(int gamma256) => Uint8List.fromList([
  ..._sig('curv'), 0, 0, 0, 0, 0, 0, 0, 1, //
  gamma256 >> 8, gamma256 & 0xff, 0, 0,
]);

/// A `curv` table of 16-bit values from [values] (0 to 1).
Uint8List tableTag(List<double> values) {
  final b = BytesBuilder()
    ..add(_sig('curv'))
    ..add([0, 0, 0, 0]);
  b.add((ByteData(4)..setUint32(0, values.length)).buffer.asUint8List());
  for (final v in values) {
    b.add(
      (ByteData(2)..setUint16(0, (v * 65535).round())).buffer.asUint8List(),
    );
  }
  return b.toBytes();
}

/// A profile of the given [tags] (signature to tag bytes).
Uint8List profile(Map<String, Uint8List> tags) {
  final entries = tags.entries.toList();
  var offset = 128 + 4 + 12 * entries.length;
  final table = BytesBuilder(), data = BytesBuilder();
  for (final e in entries) {
    final padded = (e.value.length + 3) & ~3;
    table
      ..add(_sig(e.key))
      ..add((ByteData(4)..setUint32(0, offset)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, e.value.length)).buffer.asUint8List());
    data
      ..add(e.value)
      ..add(List.filled(padded - e.value.length, 0));
    offset += padded;
  }
  final header = ByteData(128)
    ..setUint32(0, offset)
    ..setUint32(8, 0x04000000);
  final h = header.buffer.asUint8List()
    ..setRange(12, 16, _sig('mntr'))
    ..setRange(16, 20, _sig('RGB '))
    ..setRange(20, 24, _sig('XYZ '))
    ..setRange(36, 40, _sig('acsp'));
  return (BytesBuilder()
        ..add(h)
        ..add((ByteData(4)..setUint32(0, entries.length)).buffer.asUint8List())
        ..add(table.toBytes())
        ..add(data.toBytes()))
      .toBytes();
}

/// A matrix and curves profile: [colorants] (columns red, green, blue) and
/// one curve tag for all three channels.
Uint8List matrixProfile(List<List<double>> colorants, Uint8List curve) =>
    profile({
      'rXYZ': xyzTag(colorants[0]),
      'gXYZ': xyzTag(colorants[1]),
      'bXYZ': xyzTag(colorants[2]),
      'rTRC': curve,
      'gTRC': curve,
      'bTRC': curve,
    });

Uint8List displayP3Profile() =>
    matrixProfile(displayP3Colorants, paraTag(srgbCurveParams));

/// A small JPEG of one colour, carrying [icc] split over [segments] APP2
/// segments when given, with [beforeProfile] (fill bytes or standalone
/// markers) between the start of the image and the profile.
Uint8List jpegWith(
  Uint8List? icc, {
  int segments = 1,
  List<int> rgb = const [200, 100, 50],
  List<int> beforeProfile = const [],
}) {
  final image = img.Image(width: 8, height: 8)
    ..clear(img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
  final jpeg = img.encodeJpg(image, quality: 100);
  if (icc == null) return jpeg;
  final out = BytesBuilder()
    ..add(jpeg.sublist(0, 2))
    ..add(beforeProfile);
  final size = (icc.length / segments).ceil();
  for (var s = 0; s < segments; s++) {
    final chunk = icc.sublist(s * size, ((s + 1) * size).clamp(0, icc.length));
    final length = 2 + 12 + 2 + chunk.length;
    out
      ..add([0xff, 0xe2, length >> 8, length & 0xff])
      ..add([..._sig('ICC_PROFILE'), 0, s + 1, segments])
      ..add(chunk);
  }
  return (out..add(jpeg.sublist(2))).toBytes();
}

/// A small PNG carrying [icc] in an iCCP chunk.
Uint8List pngWith(Uint8List icc) {
  final png = img.encodePng(img.Image(width: 4, height: 4));
  final body = [..._sig('icc'), 0, 0, ...const ZLibEncoder().encodeBytes(icc)];
  final typed = [..._sig('iCCP'), ...body];
  final chunk = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, body.length)).buffer.asUint8List())
    ..add(typed)
    ..add((ByteData(4)..setUint32(0, getCrc32(typed))).buffer.asUint8List());
  // After the signature (8) and IHDR (25).
  return (BytesBuilder()
        ..add(png.sublist(0, 33))
        ..add(chunk.toBytes())
        ..add(png.sublist(33)))
      .toBytes();
}
