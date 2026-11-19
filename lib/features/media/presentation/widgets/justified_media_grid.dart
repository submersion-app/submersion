import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';

/// One group as the justified grid lays it out: its headers' heights and its
/// items' aspect ratios (width / height, already clamped).
class JustifiedSection {
  const JustifiedSection({required this.headerExtents, required this.ratios});

  final List<double> headerExtents;
  final List<double> ratios;

  @override
  bool operator ==(Object other) =>
      other is JustifiedSection &&
      listEquals(other.headerExtents, headerExtents) &&
      listEquals(other.ratios, ratios);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(headerExtents), Object.hashAll(ratios));
}

/// A spot in the gallery that survives a change of layout: a cell, and how
/// far down it. A cell's index does not depend on the row height or width.
class MediaGridPlace {
  const MediaGridPlace({required this.cell, required this.fraction});

  final int cell;
  final double fraction;
}

/// Where every cell of a justified gallery goes (issue #4738): each group's
/// headers, full width, then its thumbnails packed into rows that share a
/// height and end flush with the pane (see [packJustifiedRows]).
///
/// One table for the whole gallery is what lets the headers and thumbnails
/// both be built only near the viewport. A grid per group cannot do that: a
/// viewport lays out all its slivers on every pass, and each one keeps a
/// child built however far off screen it is (issue #3826).
class JustifiedMediaTable {
  JustifiedMediaTable._({
    required this.paneWidth,
    required this.targetHeight,
    required this.totalExtent,
    required List<JustifiedSection> sections,
    required Float64List tops,
    required Float64List lefts,
    required Float64List widths,
    required Float64List heights,
    required Int32List cellSections,
    required Int32List slots,
    required Int32List sectionFirstTile,
  }) : _sections = sections,
       _tops = tops,
       _lefts = lefts,
       _widths = widths,
       _heights = heights,
       _cellSections = cellSections,
       _slots = slots,
       _sectionFirstTile = sectionFirstTile;

  /// Lays [sections] out across [paneWidth], with [inset] on each side of the
  /// thumbnails and [gap] between them, across and down.
  factory JustifiedMediaTable.build({
    required List<JustifiedSection> sections,
    required double paneWidth,
    required double targetHeight,
    required double gap,
    required double inset,
    double minTileWidth = 48,
  }) {
    final usable = math.max(0.0, paneWidth - 2 * inset);
    var cellCount = 0;
    for (final section in sections) {
      cellCount += section.headerExtents.length + section.ratios.length;
    }
    final tops = Float64List(cellCount);
    final lefts = Float64List(cellCount);
    final widths = Float64List(cellCount);
    final heights = Float64List(cellCount);
    final cellSections = Int32List(cellCount);
    final slots = Int32List(cellCount);
    final sectionFirstTile = Int32List(sections.length);
    var cell = 0;
    var offset = 0.0;
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      for (var h = 0; h < section.headerExtents.length; h++) {
        tops[cell] = offset;
        widths[cell] = paneWidth;
        heights[cell] = section.headerExtents[h];
        cellSections[cell] = s;
        slots[cell] = _headerSlot(h);
        offset += section.headerExtents[h];
        cell++;
      }
      sectionFirstTile[s] = cell;
      final rows = packJustifiedRows(
        ratios: section.ratios,
        paneWidth: usable,
        targetHeight: targetHeight,
        gap: gap,
        minTileWidth: minTileWidth,
      );
      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        if (r > 0) offset += gap;
        var left = inset;
        for (var k = 0; k < row.count; k++) {
          tops[cell] = offset;
          lefts[cell] = left;
          widths[cell] = row.widths[k];
          heights[cell] = row.height;
          cellSections[cell] = s;
          slots[cell] = row.start + k;
          left += row.widths[k] + gap;
          cell++;
        }
        offset += row.height;
      }
    }
    return JustifiedMediaTable._(
      paneWidth: paneWidth,
      targetHeight: targetHeight,
      totalExtent: offset,
      sections: sections,
      tops: tops,
      lefts: lefts,
      widths: widths,
      heights: heights,
      cellSections: cellSections,
      slots: slots,
      sectionFirstTile: sectionFirstTile,
    );
  }

  final double paneWidth;
  final double targetHeight;
  final double totalExtent;
  final List<JustifiedSection> _sections;
  final Float64List _tops;
  final Float64List _lefts;
  final Float64List _widths;
  final Float64List _heights;
  final Int32List _cellSections;

  /// A thumbnail's index in its group, or [_headerSlot] of a header's.
  final Int32List _slots;

  /// The cell of each group's first thumbnail.
  final Int32List _sectionFirstTile;

  static int _headerSlot(int header) => -1 - header;

  int get cellCount => _tops.length;

  int sectionOf(int cell) => _cellSections[cell];

  /// The thumbnail's index in its group, or -1 for a header.
  int tileIndexOf(int cell) => math.max(-1, _slots[cell]);

  /// The header's index in its group, or -1 for a thumbnail.
  int headerIndexOf(int cell) => _slots[cell] < 0 ? -1 - _slots[cell] : -1;

  /// The cell of thumbnail [tileIndex] in group [section].
  int cellOf(int section, int tileIndex) =>
      _sectionFirstTile[section] + tileIndex;

  /// The cell of thumbnail [tileIndex] in group [section], or null when this
  /// table has no such thumbnail.
  int? tileCellOf(int section, int tileIndex) {
    if (section < 0 || section >= _sections.length) return null;
    if (tileIndex < 0 || tileIndex >= _sections[section].ratios.length) {
      return null;
    }
    return cellOf(section, tileIndex);
  }

  /// Where [cell] sits, left to right, in the gallery's coordinates.
  Rect rectOf(int cell) =>
      Rect.fromLTWH(_lefts[cell], _tops[cell], _widths[cell], _heights[cell]);

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
    final left = _lefts[cell];
    final width = _widths[cell];
    return SliverGridGeometry(
      scrollOffset: _tops[cell],
      crossAxisOffset: reverseCrossAxis ? paneWidth - left - width : left,
      mainAxisExtent: _heights[cell],
      crossAxisExtent: width,
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
  bool hasSameCellsAs(JustifiedMediaTable other) {
    if (other._sections.length != _sections.length) return false;
    for (var s = 0; s < _sections.length; s++) {
      final mine = _sections[s];
      final theirs = other._sections[s];
      if (mine.ratios.length != theirs.ratios.length ||
          mine.headerExtents.length != theirs.headerExtents.length) {
        return false;
      }
    }
    return true;
  }
}

/// Lays a [GridView] out from a [JustifiedMediaTable].
class JustifiedMediaGridDelegate extends SliverGridDelegate {
  const JustifiedMediaGridDelegate(this.table);

  final JustifiedMediaTable table;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      _JustifiedMediaGridLayout(
        table,
        reverseCrossAxis: axisDirectionIsReversed(
          constraints.crossAxisDirection,
        ),
      );

  @override
  bool shouldRelayout(JustifiedMediaGridDelegate oldDelegate) =>
      !identical(oldDelegate.table, table);
}

class _JustifiedMediaGridLayout extends SliverGridLayout {
  const _JustifiedMediaGridLayout(this.table, {required this.reverseCrossAxis});

  final JustifiedMediaTable table;
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
