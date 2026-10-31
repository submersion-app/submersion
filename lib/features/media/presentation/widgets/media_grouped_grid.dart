import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart';

/// One group as the grid lays it out: its headers' heights and how many
/// thumbnails follow them.
class MediaGridSection {
  const MediaGridSection({
    required this.headerExtents,
    required this.tileCount,
  });

  final List<double> headerExtents;
  final int tileCount;

  @override
  bool operator ==(Object other) =>
      other is MediaGridSection &&
      other.tileCount == tileCount &&
      listEquals(other.headerExtents, headerExtents);

  @override
  int get hashCode => Object.hash(tileCount, Object.hashAll(headerExtents));
}

/// A spot in the gallery that survives a change of layout: a cell, and how far
/// down it. A cell's index does not depend on the column count.
class MediaGridPlace {
  const MediaGridPlace({required this.cell, required this.fraction});

  final int cell;
  final double fraction;
}

/// Where every cell of the grouped gallery goes: each group's headers, full
/// width, then its thumbnails. One table for the whole gallery is what lets
/// the headers and thumbnails both be built only near the viewport. A grid per
/// group cannot do that: a viewport lays out all its slivers on every pass, and
/// each one keeps a child built however far off screen it is.
class MediaGroupedGridTable {
  MediaGroupedGridTable._({
    required this.columns,
    required this.tileExtent,
    required this.totalExtent,
    required this.paneWidth,
    required List<MediaGridSection> sections,
    required Float64List tops,
    required Float64List heights,
    required Int32List cellSections,
    required Int32List slots,
    required Int32List cellColumns,
  }) : _sections = sections,
       _tops = tops,
       _heights = heights,
       _cellSections = cellSections,
       _slots = slots,
       _cellColumns = cellColumns;

  factory MediaGroupedGridTable.build({
    required List<MediaGridSection> sections,
    required int columns,
    required double paneWidth,
  }) {
    final usable = math.max(0.0, paneWidth - kMediaThumbnailMaxInset);
    final tileExtent = math.max(
      0.0,
      (usable - (columns - 1) * kMediaThumbnailGap) / columns,
    );
    var cellCount = 0;
    for (final section in sections) {
      cellCount += section.headerExtents.length + section.tileCount;
    }
    final tops = Float64List(cellCount);
    final heights = Float64List(cellCount);
    final cellSections = Int32List(cellCount);
    final slots = Int32List(cellCount);
    final cellColumns = Int32List(cellCount);
    var cell = 0;
    var offset = 0.0;
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      for (var h = 0; h < section.headerExtents.length; h++) {
        tops[cell] = offset;
        heights[cell] = section.headerExtents[h];
        cellSections[cell] = s;
        slots[cell] = _headerSlot(h);
        cellColumns[cell] = -1;
        offset += section.headerExtents[h];
        cell++;
      }
      for (var t = 0; t < section.tileCount; t++) {
        tops[cell] =
            offset + (t ~/ columns) * (tileExtent + kMediaThumbnailGap);
        heights[cell] = tileExtent;
        cellSections[cell] = s;
        slots[cell] = t;
        cellColumns[cell] = t % columns;
        cell++;
      }
      offset += mediaThumbnailGridHeight(
        section.tileCount,
        columns,
        tileExtent,
      );
    }
    return MediaGroupedGridTable._(
      columns: columns,
      tileExtent: tileExtent,
      totalExtent: offset,
      paneWidth: paneWidth,
      sections: sections,
      tops: tops,
      heights: heights,
      cellSections: cellSections,
      slots: slots,
      cellColumns: cellColumns,
    );
  }

  final int columns;
  final double tileExtent;
  final double totalExtent;
  final double paneWidth;
  final List<MediaGridSection> _sections;
  final Float64List _tops;
  final Float64List _heights;
  final Int32List _cellSections;

  /// A thumbnail's index in its group, or [_headerSlot] of a header's.
  final Int32List _slots;

  /// A thumbnail's column, or -1 for a header.
  final Int32List _cellColumns;

  static int _headerSlot(int header) => -1 - header;

  int get cellCount => _tops.length;

  int sectionOf(int cell) => _cellSections[cell];

  /// The thumbnail's index in its group, or -1 for a header.
  int tileIndexOf(int cell) => math.max(-1, _slots[cell]);

  /// The header's index in its group, or -1 for a thumbnail.
  int headerIndexOf(int cell) => _slots[cell] < 0 ? -1 - _slots[cell] : -1;

  /// The last cell starting at or before [offset].
  int _lastStartingBy(double offset) {
    var low = 0;
    var high = cellCount - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (_tops[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  /// The first cell of the row at [offset].
  int minCellAt(double offset) {
    if (cellCount == 0) return 0;
    var cell = _lastStartingBy(offset);
    while (cell > 0 && _tops[cell - 1] == _tops[cell]) {
      cell--;
    }
    return cell;
  }

  /// The last cell of the row at [offset].
  int maxCellAt(double offset) => cellCount == 0 ? 0 : _lastStartingBy(offset);

  /// Where [cell] goes. Past the end it is empty: the grid asks for the cell
  /// after the last before it learns there is none.
  SliverGridGeometry geometryOf(int cell, {required bool reverseCrossAxis}) {
    if (cell >= cellCount) {
      return SliverGridGeometry(
        scrollOffset: totalExtent,
        crossAxisOffset: 0,
        mainAxisExtent: 0,
        crossAxisExtent: 0,
      );
    }
    final column = _cellColumns[cell];
    if (column < 0) {
      return SliverGridGeometry(
        scrollOffset: _tops[cell],
        crossAxisOffset: 0,
        mainAxisExtent: _heights[cell],
        crossAxisExtent: paneWidth,
      );
    }
    final fromStart = reverseCrossAxis ? columns - 1 - column : column;
    return SliverGridGeometry(
      scrollOffset: _tops[cell],
      crossAxisOffset:
          kMediaThumbnailMaxInset / 2 +
          fromStart * (tileExtent + kMediaThumbnailGap),
      mainAxisExtent: tileExtent,
      crossAxisExtent: tileExtent,
    );
  }

  /// The spot at [offset]. Within a row of thumbnails it is the row's first.
  MediaGridPlace placeAt(double offset) {
    if (cellCount == 0) return const MediaGridPlace(cell: 0, fraction: 0);
    final cell = minCellAt(offset);
    final height = _heights[cell];
    return MediaGridPlace(
      cell: cell,
      fraction: height > 0 ? (offset - _tops[cell]) / height : 0,
    );
  }

  /// The offset of [place] in this table.
  double offsetOf(MediaGridPlace place) {
    if (place.cell >= cellCount) return totalExtent;
    return _tops[place.cell] + place.fraction * _heights[place.cell];
  }

  /// Whether [other] holds the same cells in the same order, however it lays
  /// them out, so a cell index means the same thing in both.
  bool hasSameCellsAs(MediaGroupedGridTable other) {
    if (other._sections.length != _sections.length) return false;
    for (var s = 0; s < _sections.length; s++) {
      final mine = _sections[s];
      final theirs = other._sections[s];
      if (mine.tileCount != theirs.tileCount ||
          mine.headerExtents.length != theirs.headerExtents.length) {
        return false;
      }
    }
    return true;
  }
}

/// Lays a [GridView] out from a [MediaGroupedGridTable].
class MediaGroupedGridDelegate extends SliverGridDelegate {
  const MediaGroupedGridDelegate(this.table);

  final MediaGroupedGridTable table;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      _MediaGroupedGridLayout(
        table,
        reverseCrossAxis: axisDirectionIsReversed(
          constraints.crossAxisDirection,
        ),
      );

  @override
  bool shouldRelayout(MediaGroupedGridDelegate oldDelegate) =>
      !identical(oldDelegate.table, table);
}

class _MediaGroupedGridLayout extends SliverGridLayout {
  const _MediaGroupedGridLayout(this.table, {required this.reverseCrossAxis});

  final MediaGroupedGridTable table;
  final bool reverseCrossAxis;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      table.minCellAt(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      table.maxCellAt(scrollOffset);

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) =>
      table.geometryOf(index, reverseCrossAxis: reverseCrossAxis);

  @override
  double computeMaxScrollOffset(int childCount) => table.totalExtent;
}
