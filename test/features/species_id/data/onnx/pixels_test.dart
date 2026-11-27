import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

import 'icc_test_profiles.dart';

void main() {
  RgbaImage uniform(int width, int height, List<int> rgb) => RgbaImage(
    width,
    height,
    Uint8List.fromList([
      for (var i = 0; i < width * height; i++) ...[rgb[0], rgb[1], rgb[2], 255],
    ]),
  );

  List<int> pixel(RgbaImage image, int x, int y) {
    final i = (y * image.width + x) * 4;
    return image.bytes.sublist(i, i + 3);
  }

  group('toTensor', () {
    test('puts R, G and B in three planes, normalised', () {
      final image = RgbaImage(
        2,
        2,
        Uint8List.fromList([
          10, 20, 30, 255, //
          40, 50, 60, 255,
          70, 80, 90, 255,
          100, 110, 120, 255,
        ]),
      );
      const mean = [0.5, 0.4, 0.3], std = [0.2, 0.25, 0.5];
      final tensor = toTensor(image, mean: mean, std: std);
      expect(tensor, hasLength(12));
      for (var c = 0; c < 3; c++) {
        for (var i = 0; i < 4; i++) {
          final v = image.bytes[i * 4 + c];
          expect(
            tensor[c * 4 + i],
            closeTo((v / 255 - mean[c]) / std[c], 1e-6),
            reason: 'channel $c pixel $i',
          );
        }
      }
    });
  });

  group('fitRect', () {
    void expectRect(PixelRect r, List<double> want) {
      expect(r.left, closeTo(want[0], 1e-9));
      expect(r.top, closeTo(want[1], 1e-9));
      expect(r.width, closeTo(want[2], 1e-9));
      expect(r.height, closeTo(want[3], 1e-9));
    }

    test('fits a crop inside the square for pad to square', () {
      final r = fitRect(400, 200, 224, CropFit.padSquare);
      expectRect(r, [0, 56, 224, 112]);
    });

    test('covers the square for centre crop', () {
      final r = fitRect(400, 200, 224, CropFit.centreCrop);
      expectRect(r, [-112, 0, 448, 224]);
    });
  });

  group('paddedCrop', () {
    test('pads the box on each side', () {
      expect(
        paddedCrop(
          imageWidth: 1000,
          imageHeight: 500,
          x: 0.1,
          y: 0.1,
          w: 0.2,
          h: 0.2,
          padding: 0.1,
        ),
        (x: 80, y: 40, width: 240, height: 120),
      );
    });

    test('clamps the padded box to the image', () {
      expect(
        paddedCrop(
          imageWidth: 1000,
          imageHeight: 500,
          x: 0.9,
          y: 0.1,
          w: 0.2,
          h: 0.2,
          padding: 0.1,
        ),
        (x: 880, y: 40, width: 120, height: 120),
      );
    });

    test('takes whole pixels outward, as CGRect.integral does', () {
      expect(
        paddedCrop(
          imageWidth: 10,
          imageHeight: 10,
          x: 0.11,
          y: 0.11,
          w: 0.33,
          h: 0.33,
          padding: 0,
        ),
        (x: 1, y: 1, width: 4, height: 4),
      );
    });

    test('gives nothing for a crop under 2 pixels', () {
      expect(
        paddedCrop(
          imageWidth: 100,
          imageHeight: 100,
          x: 0.5,
          y: 0.5,
          w: 0.01,
          h: 0.2,
          padding: 0,
        ),
        isNull,
      );
    });
  });

  group('drawInto', () {
    test('fills outside the target and draws the source inside it', () {
      final out = drawInto(
        uniform(16, 16, [10, 20, 30]),
        (left: 2.0, top: 2.0, width: 4.0, height: 4.0),
        canvas: 8,
        fill: const [1, 0, 0],
      );
      expect(out.width, 8);
      expect(out.height, 8);
      expect(pixel(out, 0, 0), [255, 0, 0]);
      expect(pixel(out, 7, 7), [255, 0, 0]);
      expect(pixel(out, 3, 3), [10, 20, 30]);
      expect(pixel(out, 4, 4), [10, 20, 30]);
    });

    test('leaves black outside the target with no fill', () {
      final out = drawInto(uniform(4, 4, [10, 20, 30]), (
        left: 0.0,
        top: 0.0,
        width: 2.0,
        height: 2.0,
      ), canvas: 4);
      expect(pixel(out, 3, 3), [0, 0, 0]);
      expect(pixel(out, 0, 0), [10, 20, 30]);
    });
  });

  group('CanvasDrawer', () {
    test('draws the detectors\' inputs from one photo as drawInto does', () {
      var seed = 3;
      final photo = RgbaImage(
        97,
        61,
        Uint8List.fromList([
          for (var i = 0; i < 97 * 61; i++) ...[
            for (var k = 0; k < 3; k++)
              (seed = (seed * 1103515245 + 12345) & 0x7fffffff) >> 23,
            255,
          ],
        ]),
      );
      const square = (left: 0.0, top: 0.0, width: 32.0, height: 32.0);
      final letterbox = letterboxRect(97, 61, 32);
      const grey = [114 / 255, 114 / 255, 114 / 255];
      final drawer = CanvasDrawer(photo);
      final drawn = [
        drawer.draw(square, canvas: 32),
        drawer.draw(letterbox, canvas: 32, fill: grey),
      ];
      final alone = [
        drawInto(photo, square, canvas: 32),
        drawInto(photo, letterbox, canvas: 32, fill: grey),
      ];
      for (var d = 0; d < 2; d++) {
        expect(drawn[d].width, 32);
        for (var i = 0; i < drawn[d].bytes.length; i++) {
          expect(
            (drawn[d].bytes[i] - alone[d].bytes[i]).abs(),
            lessThanOrEqualTo(1),
            reason: 'input $d, byte $i',
          );
        }
      }
      // The letterbox keeps its grey bars.
      expect(pixel(drawn[1], 0, 0), [114, 114, 114]);
    });
  });

  group('cropOf', () {
    test('copies the pixels inside the rectangle', () {
      final image = RgbaImage(
        4,
        4,
        Uint8List.fromList([
          for (var i = 0; i < 16; i++) ...[i, i, i, 255],
        ]),
      );
      final crop = cropOf(image, (x: 1, y: 1, width: 2, height: 2));
      expect(crop.width, 2);
      expect(crop.height, 2);
      expect(pixel(crop, 0, 0), [5, 5, 5]);
      expect(pixel(crop, 1, 1), [10, 10, 10]);
    });
  });

  group('fittedWithin', () {
    test('shrinks the longer side to the limit', () {
      final out = fittedWithin(uniform(1000, 500, [1, 2, 3]), 320);
      expect((out.width, out.height), (320, 160));
    });

    test('leaves a smaller image as it is', () {
      final image = uniform(200, 100, [1, 2, 3]);
      expect(identical(fittedWithin(image, 320), image), isTrue);
    });
  });

  group('jpegOf', () {
    test('writes a JPEG', () {
      final jpeg = jpegOf(uniform(8, 8, [1, 2, 3]));
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
    });
  });

  group('inSrgb', () {
    test('converts a photo carrying a conversion, and drops it', () {
      final p3 = uniform(2, 1, [200, 100, 50]);
      final photo = RgbaImage(
        p3.width,
        p3.height,
        p3.bytes,
        colour: srgbConversionOf(jpegWith(displayP3Profile())),
      );

      final srgb = inSrgb(photo);

      expect(srgb.colour, isNull);
      expect((srgb.width, srgb.height), (2, 1));
      for (final (got, want) in [
        (pixel(srgb, 0, 0), [215, 93, 31]),
        (pixel(srgb, 1, 0), [215, 93, 31]),
      ]) {
        for (var c = 0; c < 3; c++) {
          expect(
            (got[c] - want[c]).abs(),
            lessThanOrEqualTo(1),
            reason: '$got',
          );
        }
      }
      expect(pixel(photo, 0, 0), [200, 100, 50], reason: 'input untouched');
    });

    test('returns a photo with no conversion as it is', () {
      final photo = uniform(2, 1, [200, 100, 50]);
      expect(identical(inSrgb(photo), photo), isTrue);
    });
  });
}
