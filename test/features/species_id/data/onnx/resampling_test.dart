import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/resampling.dart';

/// Every expected row here was read from Core Graphics drawing the same
/// source with `interpolationQuality = .high`, as the Swift pipeline
/// draws (macOS 27, Apple silicon), so the ONNX engine's pixels match the
/// Core ML engine's. Rows are four pixels high and drawn four high, so
/// only the width is resampled.
void main() {
  const rows = 4;

  Uint8List grey(List<int> row) => Uint8List.fromList([
    for (var y = 0; y < rows; y++)
      for (final v in row) ...[v, v, v, 255],
  ]);

  /// [row] drawn [outWidth] wide; the middle row's red values.
  List<int> drawn(List<int> row, int outWidth) {
    final out = Uint8List(outWidth * rows * 4);
    resampleRgba(
      grey(row),
      row.length,
      rows,
      out,
      outWidth,
      rows,
      left: 0,
      top: 0,
      width: outWidth.toDouble(),
      height: rows.toDouble(),
    );
    return [
      for (var x = 0; x < outWidth; x++) out[((rows ~/ 2) * outWidth + x) * 4],
    ];
  }

  void expectNear(List<int> got, List<int> want, int within) {
    expect(got, hasLength(want.length));
    for (var i = 0; i < want.length; i++) {
      expect(
        (got[i] - want[i]).abs(),
        lessThanOrEqualTo(within),
        reason: 'pixel $i: got ${got[i]}, Core Graphics ${want[i]}',
      );
    }
  }

  List<int> impulse(int length, int at) => [
    for (var i = 0; i < length; i++) i == at ? 200 : 0,
  ];
  List<int> step(int length) => [
    for (var i = 0; i < length; i++) i < length ~/ 2 ? 40 : 220,
  ];

  group('growing', () {
    test('blends the two nearest pixels on the snapped curve, 2x', () {
      final got = drawn(impulse(16, 8), 32);
      expect(got.sublist(15, 19), [25, 175, 175, 25]);
      expect(got.where((v) => v != 0), hasLength(4));
    });

    test('blends the two nearest pixels on the snapped curve, 3x', () {
      expect(drawn(impulse(16, 8), 48).sublist(23, 28), [
        50,
        150,
        200,
        150,
        50,
      ]);
    });

    test('blends the two nearest pixels on the snapped curve, 4x', () {
      expectNear(drawn(impulse(16, 8), 64).sublist(30, 38), [
        12, 50, 150, 188, 188, 150, 50, 12, //
      ], 1);
    });

    test('takes an edge across one source pixel in eighths, 7x', () {
      expectNear(drawn(step(8), 56).sublist(25, 31), [
        51, 62, 85, 175, 198, 209, //
      ], 1);
    });
  });

  group('shrinking', () {
    test('rings slightly at an edge, as a cubic does, 1.6x', () {
      expectNear(drawn(step(64), 40).sublist(17, 23), [
        40, 39, 50, 210, 221, 220, //
      ], 1);
    });

    test('rings slightly at an edge, as a cubic does, 2.5x', () {
      expectNear(drawn(step(64), 26).sublist(11, 15), [38, 53, 207, 222], 1);
    });

    test('rings slightly at an edge, as a cubic does, 4.3x', () {
      expectNear(drawn(step(86), 20).sublist(8, 12), [38, 54, 206, 222], 2);
    });

    test('maps the first and last pixels to the first and last, 2.2x', () {
      // Seeded noise, the same generator as the probe's: a mapping that
      // spaces pixel centres evenly instead puts every output up to half
      // a source pixel off, about 9 levels apart on noise.
      var seed = 11;
      final noise = <int>[];
      for (var i = 0; i < 143; i++) {
        seed = seed * 6364136223846793005 + 1442695040888963407;
        noise.add((seed >>> 33) & 0xff);
      }
      expect(noise.sublist(0, 6), [184, 131, 31, 88, 158, 99]);
      const coreGraphics = [
        167, 75, 117, 181, 232, 73, 205, 100, 128, 140, 42, 41, 183, 221, //
        166, 173, 201, 119, 142, 157, 58, 96, 197, 16, 108, 129, 161, 135,
        180, 187, 139, 129, 115, 175, 125, 107, 158, 135, 124, 134, 153, 119,
        97, 59, 195, 121, 133, 171, 188, 131, 205, 136, 108, 168, 81, 110, 57,
        170, 158, 159, 135, 169, 179, 200,
      ];
      final got = drawn(noise, 64);
      var total = 0;
      for (var i = 0; i < 64; i++) {
        total += (got[i] - coreGraphics[i]).abs();
      }
      expect(total / 64, lessThan(1.0));
    });
  });

  test('keeps a uniform source uniform at any scale, edges included', () {
    for (final out in [3, 7, 40, 64, 101]) {
      expect(
        drawn(List.filled(64, 137), out),
        everyElement(137),
        reason: '64 to $out',
      );
    }
  });

  group('several draws from one source', () {
    Uint8List noiseImage(int width, int height) {
      var seed = 5;
      return Uint8List.fromList([
        for (var i = 0; i < width * height; i++) ...[
          for (var k = 0; k < 3; k++)
            (seed = (seed * 1103515245 + 12345) & 0x7fffffff) >> 23,
          255,
        ],
      ]);
    }

    int worstDifference(Uint8List a, Uint8List b) {
      var worst = 0;
      for (var i = 0; i < a.length; i++) {
        worst = math.max(worst, (a[i] - b[i]).abs());
      }
      return worst;
    }

    // The detectors' inputs from one photo: a square stretched to the
    // input, and a letterbox that shares one of its axes.
    for (final (shape, width, height, letterbox) in [
      ('wide', 403, 302, (left: 0.0, top: 8.0, width: 64.0, height: 48.0)),
      ('tall', 302, 403, (left: 8.0, top: 0.0, width: 48.0, height: 64.0)),
    ]) {
      test('a $shape photo\'s letterbox reuses the square\'s first pass', () {
        final source = noiseImage(width, height);
        final resampler = Resampler(source, width, height);
        final square = Uint8List(64 * 64 * 4);
        resampler.draw(square, 64, 64, left: 0, top: 0, width: 64, height: 64);
        final shared = Uint8List(64 * 64 * 4);
        resampler.draw(
          shared,
          64,
          64,
          left: letterbox.left,
          top: letterbox.top,
          width: letterbox.width,
          height: letterbox.height,
        );
        expect(resampler.firstPasses, 1);
        // Drawn as a draw of its own draws it, give or take a rounding
        // edge from taking the axes in the other order.
        final alone = Uint8List(64 * 64 * 4);
        resampleRgba(
          source,
          width,
          height,
          alone,
          64,
          64,
          left: letterbox.left,
          top: letterbox.top,
          width: letterbox.width,
          height: letterbox.height,
        );
        expect(worstDifference(shared, alone), lessThanOrEqualTo(1));
      });
    }

    test('a draw that shares no axis with the last makes its own pass', () {
      final source = noiseImage(120, 90);
      final resampler = Resampler(source, 120, 90);
      final out = Uint8List(64 * 64 * 4);
      resampler.draw(out, 64, 64, left: 0, top: 0, width: 64, height: 64);
      resampler.draw(out, 64, 64, left: 3, top: 5, width: 20, height: 30);
      expect(resampler.firstPasses, 2);
    });
  });

  test('draws only the pixels whose centres lie in the target', () {
    final out = Uint8List(10 * 4 * 4);
    resampleRgba(
      grey(List.filled(8, 90)),
      8,
      rows,
      out,
      10,
      4,
      left: 2.6,
      top: 0,
      width: 5,
      height: 4,
    );
    final row = [for (var x = 0; x < 10; x++) out[(2 * 10 + x) * 4]];
    // Centres 2.5 and 7.5 fall outside [2.6, 7.6); 3.5 to 7.5 inside.
    expect(row, [0, 0, 0, 90, 90, 90, 90, 90, 0, 0]);
  });
}
