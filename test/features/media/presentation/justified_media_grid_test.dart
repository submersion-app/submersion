import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';

const _gap = 4.0;
const _inset = 8.0;
const _pane = 1016.0;
const _usable = _pane - 2 * _inset;
const _target = 200.0;

const _six = [1.5, 0.75, 1.33, 1.0, 1.78, 0.56];
const _three = [1.5, 1.0, 0.75];

const _twoSections = [
  JustifiedSection(headerExtents: [40], ratios: _six),
  JustifiedSection(headerExtents: [48, 30], ratios: _three),
];

JustifiedMediaTable _table(
  List<JustifiedSection> sections, {
  double paneWidth = _pane,
  double targetHeight = _target,
}) => JustifiedMediaTable.build(
  sections: sections,
  paneWidth: paneWidth,
  targetHeight: targetHeight,
  gap: _gap,
  inset: _inset,
);

List<int> _tilesOf(JustifiedMediaTable table, int section) => [
  for (var c = 0; c < table.cellCount; c++)
    if (table.sectionOf(c) == section && table.tileIndexOf(c) >= 0) c,
];

/// The cell table behind the justified media library (issue #4738).
void main() {
  group('cells', () {
    test('headers then tiles, section by section', () {
      final table = _table(_twoSections);

      expect(table.cellCount, 1 + 6 + 2 + 3);
      expect(table.headerIndexOf(0), 0);
      expect(table.tileIndexOf(1), 0);
      expect(table.headerIndexOf(7), 0);
      expect(table.headerIndexOf(8), 1);
      expect(table.sectionOf(8), 1);
      expect(table.tileIndexOf(9), 0);
    });

    test('tiles keep their packed rectangles', () {
      final table = _table(_twoSections);
      final rows = packJustifiedRows(
        ratios: _six,
        paneWidth: _usable,
        targetHeight: _target,
        gap: _gap,
        minTileWidth: 48,
      );
      final tiles = _tilesOf(table, 0);
      var top = 40.0;
      for (final row in rows) {
        var left = _inset;
        for (var k = 0; k < row.count; k++) {
          final rect = table.rectOf(tiles[row.start + k]);
          expect(rect.left, moreOrLessEquals(left));
          expect(rect.top, moreOrLessEquals(top));
          expect(rect.width, moreOrLessEquals(row.widths[k]));
          expect(rect.height, moreOrLessEquals(row.height));
          left += row.widths[k] + _gap;
        }
        top += row.height + _gap;
      }
    });

    test('rows of a group never mix with the next group', () {
      final table = _table(_twoSections);
      final lastOfFirst = table.rectOf(_tilesOf(table, 0).last);
      final firstOfSecond = table.rectOf(_tilesOf(table, 1).first);

      expect(firstOfSecond.top, moreOrLessEquals(lastOfFirst.bottom + 48 + 30));
      expect(firstOfSecond.left, _inset);
    });

    test('headers span the pane', () {
      final table = _table(_twoSections);
      final geometry = table.geometryOf(0, reverseCrossAxis: false);

      expect(geometry.crossAxisOffset, 0);
      expect(geometry.crossAxisExtent, _pane);
      expect(geometry.mainAxisExtent, 40);
    });

    test('right to left mirrors tiles and leaves headers full width', () {
      final table = _table(_twoSections);

      for (final cell in _tilesOf(table, 0)) {
        final rect = table.rectOf(cell);
        expect(
          table.geometryOf(cell, reverseCrossAxis: true).crossAxisOffset,
          moreOrLessEquals(_pane - rect.right),
        );
      }
      expect(table.geometryOf(0, reverseCrossAxis: true).crossAxisOffset, 0);
    });

    test('a section with no tiles is only its headers', () {
      final table = _table(const [
        JustifiedSection(headerExtents: [40], ratios: []),
      ]);

      expect(table.cellCount, 1);
      expect(table.totalExtent, 40);
    });

    test('cellOf finds every tile by group and index', () {
      final table = _table(_twoSections);

      for (var c = 0; c < table.cellCount; c++) {
        final tile = table.tileIndexOf(c);
        if (tile < 0) continue;
        expect(table.cellOf(table.sectionOf(c), tile), c);
      }
    });
  });

  test('tileCellOf answers null for a thumbnail the table lacks', () {
    final table = _table(_twoSections);

    expect(table.tileCellOf(1, 2), table.cellOf(1, 2));
    expect(table.tileCellOf(1, 3), isNull);
    expect(table.tileCellOf(2, 0), isNull);
    expect(table.tileCellOf(-1, 0), isNull);
  });

  group('lookups', () {
    test('return the start and end of a row', () {
      final table = _table(_twoSections);
      final tiles = _tilesOf(table, 0);
      final firstRow = [
        for (final c in tiles)
          if (table.rectOf(c).top == table.rectOf(tiles.first).top) c,
      ];
      final middle = table.rectOf(tiles.first).center.dy;

      expect(table.minCellAt(0), 0);
      expect(table.minCellAt(middle), firstRow.first);
      expect(table.maxCellAt(middle), firstRow.last);
      // Inside the gap below the first row: still that row.
      final gapY = table.rectOf(tiles.first).bottom + _gap / 2;
      expect(table.minCellAt(gapY), firstRow.first);
    });

    test('stay inside the table past either end', () {
      final table = _table(_twoSections);

      expect(table.minCellAt(-10), 0);
      expect(table.maxCellAt(1e9), table.cellCount - 1);
    });

    test('answer out of range, as the sliver asks', () {
      final empty = _table(const []);
      expect(empty.cellCount, 0);
      expect(empty.totalExtent, 0);
      expect(empty.minCellAt(0), 0);
      expect(empty.maxCellAt(0), 0);
      expect(empty.geometryOf(0, reverseCrossAxis: false).mainAxisExtent, 0);

      final table = _table(_twoSections);
      final past = table.geometryOf(table.cellCount, reverseCrossAxis: false);
      expect(past.scrollOffset, table.totalExtent);
      expect(past.mainAxisExtent, 0);
    });
  });

  group('places', () {
    test('round trip through the same table', () {
      final table = _table(_twoSections);

      for (final offset in [0.0, 30.0, 48.0, 100.0, 300.0]) {
        expect(table.offsetOf(table.placeAt(offset)), moreOrLessEquals(offset));
      }
    });

    test('keep a cell and how far down it across a new layout', () {
      final before = _table(_twoSections);
      final after = _table(_twoSections, targetHeight: 120);
      final cell = _tilesOf(before, 1).first;
      final rect = before.rectOf(cell);

      final place = before.placeAt(rect.top + 10);
      expect(place.cell, cell);
      expect(place.fraction, moreOrLessEquals(10 / rect.height));
      final moved = after.rectOf(cell);
      expect(
        after.offsetOf(place),
        moreOrLessEquals(moved.top + moved.height * 10 / rect.height),
      );
    });

    test('an empty table has nowhere to go', () {
      final empty = _table(const []);

      expect(empty.offsetOf(empty.placeAt(100)), 0);
    });
  });

  group('hasSameCellsAs', () {
    test('holds across width, row height and shapes', () {
      final table = _table(_twoSections);

      expect(
        table.hasSameCellsAs(
          _table(_twoSections, paneWidth: 500, targetHeight: 90),
        ),
        isTrue,
      );
      expect(
        table.hasSameCellsAs(
          _table(const [
            JustifiedSection(headerExtents: [40], ratios: [1, 1, 1, 1, 1, 1]),
            JustifiedSection(headerExtents: [48, 30], ratios: _three),
          ]),
        ),
        isTrue,
      );
    });

    test('fails when the cells differ', () {
      final table = _table(_twoSections);

      expect(
        table.hasSameCellsAs(
          _table(const [
            JustifiedSection(headerExtents: [40], ratios: [..._six, 1]),
            JustifiedSection(headerExtents: [48, 30], ratios: _three),
          ]),
        ),
        isFalse,
      );
      expect(table.hasSameCellsAs(_table(_twoSections.sublist(0, 1))), isFalse);
    });
  });

  group('sharesCellsThrough', () {
    test('holds up to a cell when only later groups grew', () {
      final table = _table(_twoSections);
      final paged = _table(const [
        JustifiedSection(headerExtents: [40], ratios: [0.75, 0.75, 1, 1, 1, 1]),
        JustifiedSection(headerExtents: [48, 30], ratios: [..._three, 1, 1]),
      ]);
      final inFirst = _tilesOf(table, 0).last;

      expect(table.sharesCellsThrough(paged, inFirst), isTrue);
      expect(
        table.sharesCellsThrough(paged, _tilesOf(table, 1).first),
        isFalse,
      );
    });

    test('fails when a group up to the cell changed size', () {
      final table = _table(_twoSections);
      final grown = _table(const [
        JustifiedSection(headerExtents: [40], ratios: [..._six, 1]),
        JustifiedSection(headerExtents: [48, 30], ratios: _three),
      ]);

      expect(table.sharesCellsThrough(grown, 1), isFalse);
    });
  });

  test('JustifiedSection compares by value', () {
    expect(
      const JustifiedSection(headerExtents: [40.0], ratios: [1.5]),
      const JustifiedSection(headerExtents: [20.0 + 20.0], ratios: [1.5]),
    );
    expect(
      const JustifiedSection(headerExtents: [40.0], ratios: [1.5]),
      isNot(const JustifiedSection(headerExtents: [40.0], ratios: [1.4])),
    );
  });

  test('the delegate relays out only for a new table', () {
    final table = _table(_twoSections);

    expect(
      JustifiedMediaGridDelegate(
        table,
      ).shouldRelayout(JustifiedMediaGridDelegate(table)),
      isFalse,
    );
    expect(
      JustifiedMediaGridDelegate(
        table,
      ).shouldRelayout(JustifiedMediaGridDelegate(_table(_twoSections))),
      isTrue,
    );
  });
}
