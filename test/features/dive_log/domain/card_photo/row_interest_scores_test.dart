import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/card_photo/row_interest_scores.dart';

/// A [w]x[h] straight-RGBA image painted by [paint].
Uint8List _image(int w, int h, List<int> Function(int x, int y) paint) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = paint(x, y);
      final i = (y * w + x) * 4;
      out[i] = c[0];
      out[i + 1] = c[1];
      out[i + 2] = c[2];
      out[i + 3] = 255;
    }
  }
  return out;
}

const _water = [20, 80, 140];

int _argMax(List<double> v) {
  var best = 0;
  for (var i = 1; i < v.length; i++) {
    if (v[i] > v[best]) best = i;
  }
  return best;
}

void main() {
  group('rowInterestScores', () {
    test('returns one score per row', () {
      final rgba = _image(32, 24, (_, _) => _water);
      expect(rowInterestScores(rgba, 32, 24)!.length, 24);
    });

    test('scores a plain image as flat', () {
      final rgba = _image(32, 24, (_, _) => _water);
      final rows = rowInterestScores(rgba, 32, 24)!;
      final spread =
          rows.reduce((a, b) => a > b ? a : b) -
          rows.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(1e-6));
    });

    test('finds a detailed block at a known height', () {
      // Checkerboard "reef" in rows 30..41 of 48, open water elsewhere.
      final rgba = _image(48, 48, (x, y) {
        if (y >= 30 && y < 42) {
          return ((x ~/ 2) + (y ~/ 2)).isEven
              ? const [230, 200, 120]
              : const [60, 40, 30];
        }
        return _water;
      });
      final rows = rowInterestScores(rgba, 48, 48)!;
      final peak = _argMax(rows);
      expect(peak, inInclusiveRange(29, 42));
      expect(rows[peak], greaterThan(rows[10] * 3));
    });

    test('scores a smooth coloured subject above open water', () {
      // An orange disc-ish block with no texture of its own.
      final rgba = _image(48, 48, (x, y) {
        final inBlock = y >= 8 && y < 18 && x >= 14 && x < 34;
        return inBlock ? const [240, 120, 40] : _water;
      });
      final rows = rowInterestScores(rgba, 48, 48)!;
      expect(rows[12], greaterThan(rows[36] * 3));
    });

    test('lets the blur wipe out isolated bright specks', () {
      // Backscatter: single bright pixels scattered through the top half,
      // a real textured subject in the bottom rows.
      final rgba = _image(48, 48, (x, y) {
        if (y < 24 && (x * 7 + y * 13) % 29 == 0) {
          return const [255, 255, 255];
        }
        if (y >= 36) {
          return ((x ~/ 2) + (y ~/ 2)).isEven
              ? const [200, 160, 90]
              : const [50, 40, 30];
        }
        return _water;
      });
      final rows = rowInterestScores(rgba, 48, 48)!;
      final top = rows.sublist(0, 24).reduce((a, b) => a + b);
      final bottom = rows.sublist(36).reduce((a, b) => a + b);
      // The bottom has half as many rows and must still outweigh the top.
      expect(bottom, greaterThan(top));
    });

    test('returns null for a black frame', () {
      final rgba = _image(32, 24, (_, _) => const [2, 2, 2]);
      expect(rowInterestScores(rgba, 32, 24), isNull);
    });

    test('returns null when the byte count does not match the size', () {
      expect(rowInterestScores(Uint8List(10), 32, 24), isNull);
    });
  });
}
