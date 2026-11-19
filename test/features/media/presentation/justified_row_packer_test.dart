import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';

double _rowWidth(JustifiedRow row, double gap) =>
    row.widths.fold<double>(0, (sum, w) => sum + w) + gap * (row.count - 1);

void main() {
  const gap = 4.0;
  const pane = 1000.0;
  const target = 200.0;

  List<JustifiedRow> pack(
    List<double> ratios, {
    double paneWidth = pane,
    double targetHeight = target,
    double minTileWidth = 0,
  }) => packJustifiedRows(
    ratios: ratios,
    paneWidth: paneWidth,
    targetHeight: targetHeight,
    gap: gap,
    minTileWidth: minTileWidth,
  );

  group('packJustifiedRows', () {
    const mixed = [1.5, 0.75, 1.33, 1.0, 1.78, 0.56, 2.33, 1.5];

    test('closed rows end flush and keep each ratio', () {
      final rows = pack(mixed);
      expect(rows.length, greaterThan(1));
      for (final row in rows.take(rows.length - 1)) {
        expect(_rowWidth(row, gap), closeTo(pane, 1e-9));
        for (var i = 0; i < row.count; i++) {
          expect(
            row.widths[i],
            closeTo(mixed[row.start + i] * row.height, 1e-6),
          );
        }
      }
    });

    test('every item is placed once, in order', () {
      final rows = pack(mixed);
      var next = 0;
      for (final row in rows) {
        expect(row.start, next);
        next += row.count;
      }
      expect(next, mixed.length);
    });

    test('the last row keeps the target height and is not stretched', () {
      final last = pack(mixed).last;
      expect(last.height, target);
      expect(_rowWidth(last, gap), lessThan(pane));
    });

    test('a single item stays at the target height', () {
      final rows = pack([1.5]);
      expect(rows, hasLength(1));
      expect(rows.single.height, target);
      expect(rows.single.widths, [300]);
    });

    test('a very wide item gets its own row, scaled down', () {
      final rows = pack([3], paneWidth: 400);
      expect(rows, hasLength(1));
      expect(rows.single.height, closeTo(400 / 3, 1e-9));
      expect(rows.single.widths.single, closeTo(400, 1e-9));
    });

    test('a row closes at the break nearest the target height', () {
      final rows = pack([1, 1, 1, 1, 3]);
      expect(rows.first.count, 4);
      expect(rows.first.height, closeTo((pane - 3 * gap) / 4, 1e-9));
      expect(
        (math.log(rows.first.height / target)).abs(),
        lessThan((math.log(((pane - 4 * gap) / 7) / target)).abs()),
      );
      expect(rows[1].start, 4);
      expect(rows[1].height, target);
    });

    test('appending items changes only the last row', () {
      final before = pack(mixed);
      final after = pack([...mixed, 1.2, 0.8]);
      for (var r = 0; r < before.length - 1; r++) {
        expect(after[r].start, before[r].start);
        expect(after[r].height, before[r].height);
        expect(after[r].widths, before[r].widths);
      }
    });

    test('the minimum width raises narrow items', () {
      final rows = pack([1 / 3], targetHeight: 64, minTileWidth: 48);
      expect(rows.single.widths.single, closeTo(48, 1e-9));
    });

    test('a pane narrower than the minimum width gives one item a row', () {
      final rows = pack([1, 1], paneWidth: 30, minTileWidth: 48);
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.widths.single, closeTo(30, 1e-9));
        expect(row.height, closeTo(30, 1e-9));
      }
    });

    test('a closed row never scales a tile under the minimum width', () {
      // Two 3:4 photos at the smallest stop in a 96 px pane: taking the
      // second would shrink both to about 47 px.
      final narrow = pack(
        [0.75, 0.75],
        paneWidth: 96,
        targetHeight: 64,
        minTileWidth: 48,
      );
      // Four 4:3 photos and a portrait across a phone-width pane.
      final phone = pack(
        [4 / 3, 4 / 3, 4 / 3, 4 / 3, 0.75, 4 / 3, 4 / 3],
        paneWidth: 386,
        targetHeight: 64,
        minTileWidth: 48,
      );
      for (final rows in [narrow, phone]) {
        for (final row in rows) {
          for (final width in row.widths) {
            expect(width, greaterThanOrEqualTo(48 - 1e-9));
          }
        }
      }
    });

    test('nothing to pack gives no rows', () {
      expect(pack([]), isEmpty);
    });
  });
}
