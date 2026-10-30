import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_grouped_grid.dart';

const _inset = kMediaThumbnailMaxInset / 2;
const _gap = kMediaThumbnailGap;

MediaGroupedGridTable _table(
  List<MediaGridSection> sections, {
  int columns = 4,
  double paneWidth = 816,
}) => MediaGroupedGridTable.build(
  sections: sections,
  columns: columns,
  paneWidth: paneWidth,
);

const _twoSections = [
  MediaGridSection(headerExtents: [48], tileCount: 6),
  MediaGridSection(headerExtents: [40, 30], tileCount: 2),
];

void main() {
  group('cells', () {
    test('headers then tiles, section by section', () {
      final table = _table(_twoSections);

      expect(table.cellCount, 1 + 6 + 2 + 2);
      expect(table.headerIndexOf(0), 0);
      expect(table.tileIndexOf(0), -1);
      expect(table.tileIndexOf(1), 0);
      expect(table.sectionOf(6), 0);
      expect(table.headerIndexOf(7), 0);
      expect(table.sectionOf(7), 1);
      expect(table.headerIndexOf(8), 1);
      expect(table.tileIndexOf(9), 0);
      expect(table.sectionOf(10), 1);
    });

    test('a tile extent is what is left of the pane, shared out', () {
      expect(_table(_twoSections).tileExtent, (816 - 16 - 3 * 4) / 4);
    });

    test('tiles sit in rows with gaps, and the next header follows the last '
        'row with none', () {
      final table = _table(_twoSections);
      final extent = table.tileExtent;
      SliverGridGeometry at(int cell) =>
          table.geometryOf(cell, reverseCrossAxis: false);

      expect(at(0).scrollOffset, 0);
      expect(at(0).crossAxisOffset, 0);
      expect(at(0).crossAxisExtent, 816);
      expect(at(0).mainAxisExtent, 48);

      expect(at(1).scrollOffset, 48);
      expect(at(1).crossAxisOffset, _inset);
      expect(at(1).mainAxisExtent, extent);
      expect(at(1).crossAxisExtent, extent);
      expect(at(4).crossAxisOffset, _inset + 3 * (extent + _gap));
      expect(at(5).scrollOffset, 48 + extent + _gap);
      expect(at(5).crossAxisOffset, _inset);

      // Six tiles at four across: a short last row, then straight to the
      // next header.
      final secondHeader = 48 + 2 * extent + _gap;
      expect(at(7).scrollOffset, secondHeader);
      expect(at(8).scrollOffset, secondHeader + 40);
      expect(at(9).scrollOffset, secondHeader + 70);
      expect(table.totalExtent, secondHeader + 70 + extent);
    });

    test('tiles land where a fixed-count grid puts them', () {
      for (final columns in [2, 3, 6, 11]) {
        final table = _table([
          const MediaGridSection(headerExtents: [], tileCount: 25),
        ], columns: columns);
        final layout =
            SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
            ).getLayout(
              const SliverConstraints(
                axisDirection: AxisDirection.down,
                growthDirection: GrowthDirection.forward,
                userScrollDirection: ScrollDirection.idle,
                scrollOffset: 0,
                precedingScrollExtent: 0,
                overlap: 0,
                remainingPaintExtent: 600,
                crossAxisExtent: 816 - 16,
                crossAxisDirection: AxisDirection.right,
                viewportMainAxisExtent: 600,
                remainingCacheExtent: 600,
                cacheOrigin: 0,
              ),
            );
        for (var i = 0; i < 25; i++) {
          final expected = layout.getGeometryForChildIndex(i);
          final actual = table.geometryOf(i, reverseCrossAxis: false);
          expect(actual.scrollOffset, moreOrLessEquals(expected.scrollOffset));
          expect(
            actual.crossAxisOffset,
            moreOrLessEquals(expected.crossAxisOffset + _inset),
          );
          expect(
            actual.mainAxisExtent,
            moreOrLessEquals(expected.mainAxisExtent),
          );
        }
      }
    });

    test('right to left mirrors tiles and leaves headers full width', () {
      final table = _table(_twoSections);
      final extent = table.tileExtent;

      expect(table.geometryOf(0, reverseCrossAxis: true).crossAxisOffset, 0);
      expect(
        table.geometryOf(1, reverseCrossAxis: true).crossAxisOffset,
        moreOrLessEquals(_inset + 3 * (extent + _gap)),
      );
      expect(
        table.geometryOf(4, reverseCrossAxis: true).crossAxisOffset,
        moreOrLessEquals(_inset),
      );
    });

    test('a section with no tiles is only its headers', () {
      final table = _table(const [
        MediaGridSection(headerExtents: [40], tileCount: 0),
        MediaGridSection(headerExtents: [40], tileCount: 1),
      ]);

      expect(table.cellCount, 3);
      expect(table.geometryOf(1, reverseCrossAxis: false).scrollOffset, 40);
      expect(table.geometryOf(2, reverseCrossAxis: false).scrollOffset, 80);
    });
  });

  group('lookups', () {
    test('return the start and end of a row', () {
      final table = _table(_twoSections);
      final extent = table.tileExtent;
      final rowTwo = 48 + extent + _gap;

      expect(table.minCellAt(0), 0);
      expect(table.minCellAt(48), 1);
      // Inside the first row, whichever tile is asked about.
      expect(table.minCellAt(48 + extent / 2), 1);
      expect(table.maxCellAt(48 + extent / 2), 4);
      // Inside the gap: still the row above.
      expect(table.minCellAt(rowTwo - 1), 1);
      expect(table.minCellAt(rowTwo), 5);
      expect(table.maxCellAt(rowTwo), 6);
    });

    test('stay inside the table past either end', () {
      final table = _table(_twoSections);

      expect(table.minCellAt(-10), 0);
      // The last row has two thumbnails.
      expect(table.minCellAt(1e9), table.cellCount - 2);
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
      final after = _table(_twoSections, columns: 2);
      final cell = 7;
      final top = before.geometryOf(cell, reverseCrossAxis: false).scrollOffset;

      final place = before.placeAt(top + 10);
      expect(place.cell, cell);
      expect(place.fraction, moreOrLessEquals(10 / 40));
      expect(
        after.offsetOf(place),
        moreOrLessEquals(
          after.geometryOf(cell, reverseCrossAxis: false).scrollOffset + 10,
        ),
      );
    });

    test('in a tile row, measure from the row', () {
      final table = _table(_twoSections);
      final extent = table.tileExtent;

      final place = table.placeAt(48 + extent / 2);
      expect(place.cell, 1);
      expect(place.fraction, moreOrLessEquals(0.5));
    });

    test('an empty table has nowhere to go', () {
      final empty = _table(const []);

      expect(empty.offsetOf(empty.placeAt(100)), 0);
    });
  });

  group('hasSameCellsAs', () {
    test('holds across width, columns and header heights', () {
      final table = _table(_twoSections);

      expect(
        table.hasSameCellsAs(_table(_twoSections, columns: 2, paneWidth: 500)),
        isTrue,
      );
      expect(
        table.hasSameCellsAs(
          _table(const [
            MediaGridSection(headerExtents: [40], tileCount: 6),
            MediaGridSection(headerExtents: [48, 30], tileCount: 2),
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
            MediaGridSection(headerExtents: [48], tileCount: 7),
            MediaGridSection(headerExtents: [40, 30], tileCount: 2),
          ]),
        ),
        isFalse,
      );
      expect(table.hasSameCellsAs(_table(_twoSections.sublist(0, 1))), isFalse);
    });
  });

  test('MediaGridSection compares by value', () {
    expect(
      const MediaGridSection(headerExtents: [40.0], tileCount: 2),
      MediaGridSection(headerExtents: [20.0 + 20.0], tileCount: 2),
    );
    expect(
      const MediaGridSection(headerExtents: [40.0], tileCount: 2),
      isNot(const MediaGridSection(headerExtents: [41.0], tileCount: 2)),
    );
  });

  test('the delegate relays out only for a new table', () {
    final table = _table(_twoSections);

    expect(
      MediaGroupedGridDelegate(
        table,
      ).shouldRelayout(MediaGroupedGridDelegate(table)),
      isFalse,
    );
    expect(
      MediaGroupedGridDelegate(
        table,
      ).shouldRelayout(MediaGroupedGridDelegate(_table(_twoSections))),
      isTrue,
    );
  });
}
