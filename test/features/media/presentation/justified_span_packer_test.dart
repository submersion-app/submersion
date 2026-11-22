import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';
import 'package:submersion/features/media/presentation/widgets/justified_span_packer.dart';

/// Issue #4786: a Large site attachment spans two rows of a group's tiles.
void main() {
  const gap = 4.0;
  const target = 120.0;
  const twoRows = 2 * target + gap;
  const wide = 900.0;
  const phone = 358.0;

  List<JustifiedSpanCell> pack(
    List<double> large,
    List<double> tiles, {
    double paneWidth = wide,
    double minTileWidth = 0,
  }) => packJustifiedSpans(
    largeRatios: large,
    tileRatios: tiles,
    paneWidth: paneWidth,
    targetHeight: target,
    gap: gap,
    minTileWidth: minTileWidth,
  );

  const mixed = [1.5, 0.75, 1.33, 1.0, 1.78, 0.56, 2.33, 1.5, 1.0, 0.75];

  Iterable<JustifiedSpanCell> tilesIn(List<JustifiedSpanCell> cells) =>
      cells.where((c) => !c.isLarge);

  group('packJustifiedSpans', () {
    test('with no large item it lays tiles out as the row packer does', () {
      final cells = pack(const [], mixed);
      final rows = packJustifiedRows(
        ratios: mixed,
        paneWidth: wide,
        targetHeight: target,
        gap: gap,
      );
      var top = 0.0;
      var i = 0;
      for (final row in rows) {
        var left = 0.0;
        for (final width in row.widths) {
          final rect = cells[i].rect;
          expect(cells[i].index, i);
          expect(rect.left, closeTo(left, 1e-9));
          expect(rect.top, closeTo(top, 1e-9));
          expect(rect.width, closeTo(width, 1e-9));
          expect(rect.height, closeTo(row.height, 1e-9));
          left += width + gap;
          i++;
        }
        top += row.height + gap;
      }
      expect(i, cells.length);
    });

    test('a large item spans two rows that end flush with it and with the '
        'pane', () {
      final cells = pack(const [4 / 3], mixed);
      final large = cells.first;
      expect(large.isLarge, isTrue);
      expect(large.rect.topLeft, Offset.zero);
      expect(large.rect.width / large.rect.height, closeTo(4 / 3, 1e-6));
      // Near two rows' height, as a closed row is near the target.
      expect(large.rect.height, greaterThan(twoRows * 0.75));
      expect(large.rect.height, lessThan(twoRows * 1.33));

      final beside = tilesIn(
        cells,
      ).where((c) => c.rect.top < large.rect.bottom).toList();
      final tops = {for (final c in beside) c.rect.top};
      expect(tops.length, 2, reason: 'two rows beside the large item');
      for (final top in tops) {
        final row = beside.where((c) => c.rect.top == top).toList();
        expect(row.first.rect.left, closeTo(large.rect.right + gap, 1e-6));
        expect(row.last.rect.right, closeTo(wide, 1e-6));
      }
      final lower = beside.where((c) => c.rect.top == tops.last);
      for (final c in lower) {
        expect(c.rect.bottom, closeTo(large.rect.bottom, 1e-6));
      }
      // Every tile keeps its shape.
      for (final c in tilesIn(cells)) {
        expect(c.rect.width / c.rect.height, closeTo(mixed[c.index], 1e-6));
      }
    });

    test('tiles past the block continue in rows under it', () {
      final cells = pack(const [4 / 3], mixed);
      final large = cells.first.rect;
      final below = tilesIn(
        cells,
      ).where((c) => c.rect.top >= large.bottom).toList();
      expect(below, isNotEmpty);
      expect(below.first.rect.top, closeTo(large.bottom + gap, 1e-6));
      expect(below.first.rect.left, 0);
    });

    test('with no room beside it a large item fills the pane on its own', () {
      // A 4:3 map two rows tall is 325 wide: on a phone that leaves too
      // little beside it for a tile.
      final cells = pack(const [4 / 3], mixed, paneWidth: phone);
      final large = cells.first.rect;
      expect(large, const Rect.fromLTWH(0, 0, phone, phone * 3 / 4));
      final next = cells[1].rect;
      expect(next.top, closeTo(large.bottom + gap, 1e-9));
      expect(next.left, 0);
    });

    test('a portrait large item keeps tiles beside it on a phone', () {
      final cells = pack(const [3 / 4], mixed, paneWidth: phone);
      final large = cells.first.rect;
      expect(large.width, lessThan(phone));
      expect(cells[1].rect.top, 0);
      expect(cells[1].rect.left, closeTo(large.right + gap, 1e-6));
    });

    test('with no tiles a large item keeps two rows and is not stretched', () {
      final cells = pack(const [4 / 3], const []);
      expect(
        cells.single.rect,
        const Rect.fromLTWH(0, 0, twoRows * 4 / 3, twoRows),
      );
    });

    test('too few tiles to fill two rows sit at the target height', () {
      final cells = pack(const [4 / 3], const [1.0]);
      final large = cells.first.rect;
      expect(large, const Rect.fromLTWH(0, 0, twoRows * 4 / 3, twoRows));
      expect(
        cells[1].rect,
        Rect.fromLTWH(large.right + gap, 0, target, target),
      );
    });

    test('a lone tile wider than the space beside it scales into it', () {
      // 500 px pane, a 3:2 large item: 130 px beside it, and a 3:1 tile that
      // is 360 wide at the target height.
      final cells = pack(const [1.5], const [3.0], paneWidth: 500);
      final tile = cells[1].rect;
      expect(tile.left, closeTo(cells.first.rect.right + gap, 1e-9));
      expect(tile.right, closeTo(500, 1e-9));
      expect(tile.width / tile.height, closeTo(3, 1e-9));
    });

    test('with no tiles and no room beside it a large item fills the pane, as '
        'the room rule comes first', () {
      final cells = pack(const [4 / 3], const [], paneWidth: 390);
      expect(cells.single.rect, const Rect.fromLTWH(0, 0, 390, 292.5));
    });

    test('each large item opens its own block, in order', () {
      final cells = pack(const [4 / 3, 1.5], mixed);
      final larges = cells.where((c) => c.isLarge).toList();
      expect([for (final c in larges) c.index], [0, 1]);
      expect(larges[1].rect.top, closeTo(larges[0].rect.bottom + gap, 1e-6));
      expect(larges[1].rect.left, 0);
    });

    test('a large item with no tiles left follows the one before it', () {
      final cells = pack(const [4 / 3, 1.5], const []);
      expect(cells[1].rect.top, closeTo(twoRows + gap, 1e-9));
    });

    test('every item is placed once and tiles stay in order', () {
      final cells = pack(const [4 / 3, 0.75], mixed);
      expect(cells.where((c) => c.isLarge).length, 2);
      expect(
        [for (final c in tilesIn(cells)) c.index],
        [for (var i = 0; i < mixed.length; i++) i],
      );
    });

    test('cells start in reading order, top to bottom', () {
      for (final pane in [phone, 600.0, wide, 1400.0]) {
        final cells = pack(const [4 / 3, 0.75], mixed, paneWidth: pane);
        for (var i = 1; i < cells.length; i++) {
          expect(
            cells[i].rect.top,
            greaterThanOrEqualTo(cells[i - 1].rect.top),
            reason: 'pane $pane cell $i',
          );
        }
      }
    });

    test('no tile beside a large item falls under the minimum width', () {
      final cells = pack(
        const [4 / 3],
        const [0.34, 0.34, 3.0, 0.34, 2.5, 0.34, 1.0],
        minTileWidth: 48,
      );
      for (final c in cells) {
        expect(c.rect.width, greaterThanOrEqualTo(48 - 1e-6));
      }
    });

    test('with tiles enough but no split above the minimum width, a large '
        'item stands alone and the tiles flow under it', () {
      // Every split of these tiles beside a 3:1 panorama puts one under
      // 150 px, though there are plenty to fill both rows.
      final cells = pack(
        const [3.0],
        List.filled(20, 1.25),
        paneWidth: 880,
        minTileWidth: 150,
      );
      expect(cells.first.rect, const Rect.fromLTWH(0, 0, 3 * twoRows, twoRows));
      expect(cells[1].rect.top, closeTo(twoRows + gap, 1e-9));
      expect(cells[1].rect.left, 0);
    });

    test('a large item alone at the pane width stops at three rows', () {
      // A 1:3 portrait on a 200 px pane: too little beside it, and at the
      // full width it would be 600 tall.
      final cells = pack(const [1 / 3], const [], paneWidth: 200);
      const cap = 3 * target + 2 * gap;
      final rect = cells.single.rect;
      expect(rect.topLeft, Offset.zero);
      expect(rect.height, closeTo(cap, 1e-9));
      expect(rect.width, closeTo(cap / 3, 1e-9));
    });

    test('on a very wide pane the rows beside a large item take as many '
        'tiles as reach the target height', () {
      // About 4670 px beside a 4:3 map holds some 90 tiles 48 px wide.
      final cells = pack(
        const [4 / 3],
        List.filled(200, 0.4),
        paneWidth: 5000,
        minTileWidth: 48,
      );
      final large = cells.first.rect;
      final beside = tilesIn(
        cells,
      ).where((c) => c.rect.top < large.bottom).toList();
      for (final c in beside) {
        expect(c.rect.height, closeTo(target, target * 0.15));
      }
    });

    test('nothing overlaps and nothing passes the pane edge', () {
      for (final pane in [phone, 600.0, wide]) {
        final cells = pack(const [4 / 3, 0.75], mixed, paneWidth: pane);
        for (final c in cells) {
          expect(c.rect.left, greaterThanOrEqualTo(-1e-9));
          expect(c.rect.right, lessThanOrEqualTo(pane + 1e-6));
        }
        for (var i = 0; i < cells.length; i++) {
          for (var j = i + 1; j < cells.length; j++) {
            final overlap = cells[i].rect
                .deflate(0.5)
                .overlaps(cells[j].rect.deflate(0.5));
            expect(overlap, isFalse, reason: 'pane $pane cells $i and $j');
          }
        }
      }
    });
  });

  group('JustifiedMediaTable.placed', () {
    test('keeps the rects and the extent of the cells it is given', () {
      final cells = pack(const [4 / 3], mixed);
      final table = JustifiedMediaTable.placed(
        rects: [for (final c in cells) c.rect],
        ratios: const [4 / 3, ...mixed],
        paneWidth: wide,
        targetHeight: target,
      );
      expect(table.cellCount, cells.length);
      for (var i = 0; i < cells.length; i++) {
        expect(table.rectOf(i), cells[i].rect);
      }
      expect(
        table.totalExtent,
        cells.map((c) => c.rect.bottom).reduce(math.max),
      );
    });

    test('a row beside a large item starts at the large item', () {
      final cells = pack(const [4 / 3], mixed);
      final table = JustifiedMediaTable.placed(
        rects: [for (final c in cells) c.rect],
        ratios: const [4 / 3, ...mixed],
        paneWidth: wide,
        targetHeight: target,
      );
      final large = cells.first.rect;
      // An offset in the lower row beside it: the large cell still shows.
      expect(table.minCellAt(large.bottom - 1), 0);
      // Below the block it no longer does.
      expect(table.minCellAt(large.bottom + gap + 1), greaterThan(0));
    });
  });
}
