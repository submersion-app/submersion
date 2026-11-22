import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';

import 'icc_test_profiles.dart';

/// Expected values are littleCMS's (Pillow's ImageCms) conversions of the
/// same colours with the same profiles to sRGB, which ImageIO matches on
/// the photos measured (the Core ML engine's pixels).
void main() {
  List<int> converted(SrgbConversion c, List<int> rgb) {
    final out = toSrgbBytes(Uint8List.fromList([...rgb, 255]), c);
    expect(out[3], 255, reason: 'alpha kept');
    return out.sublist(0, 3);
  }

  void expectNear(List<int> got, List<int> want) {
    for (var i = 0; i < 3; i++) {
      expect(
        (got[i] - want[i]).abs(),
        lessThanOrEqualTo(1),
        reason: 'got $got, want $want',
      );
    }
  }

  group('srgbConversionOf', () {
    test('reads Display P3 from a JPEG and converts as littleCMS does', () {
      final c = srgbConversionOf(jpegWith(displayP3Profile()))!;
      expectNear(converted(c, [200, 100, 50]), [215, 93, 31]);
      expectNear(converted(c, [30, 160, 220]), [0, 163, 226]);
      expectNear(converted(c, [128, 128, 128]), [128, 128, 128]);
      expectNear(converted(c, [10, 5, 2]), [11, 5, 2]);
    });

    test('joins a profile split over several APP2 segments', () {
      final c = srgbConversionOf(jpegWith(displayP3Profile(), segments: 3))!;
      expectNear(converted(c, [200, 100, 50]), [215, 93, 31]);
    });

    test('reads a PNG profile, compressed in its iCCP chunk', () {
      final c = srgbConversionOf(pngWith(displayP3Profile()))!;
      expectNear(converted(c, [30, 160, 220]), [0, 163, 226]);
    });

    test('reads a plain gamma curve (Adobe RGB)', () {
      final icc = matrixProfile(adobeColorants, gammaTag(563));
      final c = srgbConversionOf(jpegWith(icc))!;
      expectNear(converted(c, [200, 100, 50]), [227, 100, 42]);
      expectNear(converted(c, [30, 160, 220]), [0, 161, 223]);
      expectNear(converted(c, [128, 128, 128]), [129, 129, 129]);
    });

    test('reads a curve table, interpolating between its entries', () {
      final icc = matrixProfile(
        displayP3Colorants,
        tableTag([0, 0.1, 0.3, 0.6, 1]),
      );
      final c = srgbConversionOf(jpegWith(icc))!;
      expectNear(converted(c, [200, 100, 50]), [225, 122, 67]);
      expectNear(converted(c, [64, 64, 64]), [89, 89, 89]);
    });

    test('reads every parametric curve type as littleCMS does', () {
      // Display P3's colorants with a curve of each `para` type but 3
      // (Display P3's own, above); littleCMS's values.
      for (final (type, params, want) in [
        (
          0,
          [2.2],
          [
            [216, 92, 24],
            [0, 164, 227],
            [3, 1, 0],
          ],
        ),
        (
          1,
          [2.2, 0.95, 0.05],
          [
            [219, 101, 41],
            [0, 169, 228],
            [16, 9, 6],
          ],
        ),
        (
          2,
          [2.2, 0.95, 0.05, 0.02],
          [
            [221, 108, 58],
            [0, 173, 231],
            [44, 42, 41],
          ],
        ),
        (
          4,
          [2.4, 0.947867, 0.052133, 0.077399, 0.04045, 0.002, 0.001],
          [
            [215, 93, 34],
            [0, 163, 226],
            [14, 8, 5],
          ],
        ),
      ]) {
        final icc = matrixProfile(
          displayP3Colorants,
          paraTag(params, type: type),
        );
        final c = srgbConversionOf(jpegWith(icc))!;
        expectNear(converted(c, [200, 100, 50]), want[0]);
        expectNear(converted(c, [30, 160, 220]), want[1]);
        expectNear(converted(c, [10, 5, 2]), want[2]);
      }
    });

    test('finds the profile past fill bytes and standalone markers', () {
      // A standalone marker (TEM) and a fill byte before the APP2 segment.
      final c = srgbConversionOf(
        jpegWith(displayP3Profile(), beforeProfile: const [0xff, 0x01, 0xff]),
      )!;
      expectNear(converted(c, [200, 100, 50]), [215, 93, 31]);
    });

    test('gives nothing for sRGB, which needs no conversion', () {
      final icc = matrixProfile(srgbColorants, paraTag(srgbCurveParams));
      expect(srgbConversionOf(jpegWith(icc)), isNull);
    });

    test('gives nothing for a photo with no profile', () {
      expect(srgbConversionOf(jpegWith(null)), isNull);
    });

    test('gives nothing for a profile of lookup tables only', () {
      final icc = profile({
        'A2B0': Uint8List.fromList('mAB \x00\x00\x00\x00'.codeUnits),
      });
      expect(srgbConversionOf(jpegWith(icc)), isNull);
    });

    test('gives nothing for a cut short or unreadable profile', () {
      final icc = displayP3Profile();
      expect(srgbConversionOf(jpegWith(icc.sublist(0, 150))), isNull);
      expect(srgbConversionOf(Uint8List.fromList([0xff, 0xd8, 0xff])), isNull);
      expect(srgbConversionOf(Uint8List(0)), isNull);
    });
  });

  test('toSrgbBytes stays within a level of the direct calculation', () {
    // The conversion as a formula: decode each channel, multiply by the
    // matrix, encode with the sRGB curve. Over a grid of colours and every
    // grey, the fast path may differ only where the result sits on a
    // rounding edge.
    final c = srgbConversionOf(jpegWith(displayP3Profile()))!;
    int encode(double linear) {
      final l = linear.clamp(0.0, 1.0);
      final v = l <= 0.0031308
          ? 12.92 * l
          : 1.055 * math.pow(l, 1 / 2.4) - 0.055;
      return (v * 255 + 0.5).floor().clamp(0, 255);
    }

    final colours = [
      for (var r = 0; r < 256; r += 15)
        for (var g = 0; g < 256; g += 15)
          for (var b = 0; b < 256; b += 15) [r, g, b],
      for (var v = 0; v < 256; v++) [v, v, v],
    ];
    final input = Uint8List.fromList([
      for (final rgb in colours) ...[...rgb, 255],
    ]);
    final out = toSrgbBytes(input, c);
    var off = 0;
    for (var p = 0; p < colours.length; p++) {
      final lin = [
        for (var ch = 0; ch < 3; ch++) c.decode[ch * 256 + colours[p][ch]],
      ];
      for (var k = 0; k < 3; k++) {
        final want = encode(
          c.matrix[k * 3] * lin[0] +
              c.matrix[k * 3 + 1] * lin[1] +
              c.matrix[k * 3 + 2] * lin[2],
        );
        final got = out[p * 4 + k];
        expect(
          (got - want).abs(),
          lessThanOrEqualTo(1),
          reason: '${colours[p]}',
        );
        if (got != want) off++;
      }
    }
    // Rounding edges are rare: well under 1% of values.
    expect(off, lessThan(colours.length * 3 ~/ 100));
  });

  test('toSrgbBytes converts every pixel and leaves the input as it was', () {
    final c = srgbConversionOf(jpegWith(displayP3Profile()))!;
    final input = Uint8List.fromList([200, 100, 50, 255, 30, 160, 220, 7]);
    final out = toSrgbBytes(input, c);
    expect(input, [200, 100, 50, 255, 30, 160, 220, 7]);
    expectNear(out.sublist(0, 3), [215, 93, 31]);
    expectNear(out.sublist(4, 7), [0, 163, 226]);
    expect(out[7], 7);
  });
}
