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
