import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';

/// One cell of a group laid out by [packJustifiedSpans]: a large item or a
/// tile, and where it goes in the group.
class JustifiedSpanCell {
  const JustifiedSpanCell({
    required this.isLarge,
    required this.index,
    required this.rect,
  });

  /// Whether this is one of the large items rather than a tile.
  final bool isLarge;

  /// The item's index in its own list, large or tile.
  final int index;

  /// Where the item goes, from the group's top-left corner.
  final Rect rect;
}

/// Lays a group out with each of [largeRatios] spanning two rows of
/// [tileRatios] (issue #4786). Ratios are width / height.
///
/// Each large item opens a block at the left of the pane, in order. The
/// tiles that follow fill two rows beside it; the large item's height is
/// solved so that both rows end flush with the pane edge and the lower one
/// with the large item's bottom, and the split between the rows is the one
/// that keeps both nearest [targetHeight]. Every item keeps its ratio.
///
/// The exceptions, in the order they are checked:
///
/// - A large item with less than [targetHeight] of pane beside it at two
///   rows' height fills the pane width on its own, up to three rows' height,
///   whether or not tiles are left: a column that narrow holds no useful
///   tile.
/// - One with no tiles left keeps two rows' height and is not stretched.
/// - Tiles too few to fill both rows sit beside it at the target height, as
///   the row packer leaves its last row.
/// - If no split of plenty of tiles keeps each at [minTileWidth], it stands
///   alone at two rows and the tiles flow on under it.
///
/// The tiles left after the last block go into ordinary justified rows under
/// it ([packJustifiedRows]). Cells come back in reading order: each large
/// item, then the tiles beside it, so their tops never decrease.
List<JustifiedSpanCell> packJustifiedSpans({
  required List<double> largeRatios,
  required List<double> tileRatios,
  required double paneWidth,
  required double targetHeight,
  required double gap,
  double minTileWidth = 0,
}) {
  final floor = targetHeight > 0 ? minTileWidth / targetHeight : 0.0;
  final tiles = [for (final r in tileRatios) math.max(r, floor)];
  final twoRows = 2 * targetHeight + gap;
  final threeRows = 3 * targetHeight + 2 * gap;
  final cells = <JustifiedSpanCell>[];
  var top = 0.0;
  var next = 0;

  /// Places [rows] of the tiles from [first] at [left], [rowTop] down, and
  /// returns the bottom of the last row.
  double placeRows(
    List<JustifiedRow> rows,
    int first,
    double left,
    double rowTop,
  ) {
    var y = rowTop;
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (r > 0) y += gap;
      var x = left;
      for (var k = 0; k < row.count; k++) {
        cells.add(
          JustifiedSpanCell(
            isLarge: false,
            index: first + row.start + k,
            rect: Rect.fromLTWH(x, y, row.widths[k], row.height),
          ),
        );
        x += row.widths[k] + gap;
      }
      y += row.height;
    }
    return y;
  }

  for (var l = 0; l < largeRatios.length; l++) {
    if (cells.isNotEmpty) top += gap;
    final ratio = largeRatios[l];
    final width = ratio * twoRows;
    final beside = paneWidth - width - gap;

    JustifiedSpanCell large(Rect rect) =>
        JustifiedSpanCell(isLarge: true, index: l, rect: rect);

    if (beside < targetHeight) {
      // The pane's width, but never taller than three rows: a portrait on a
      // narrow pane narrows instead.
      final natural = ratio > 0 ? paneWidth / ratio : twoRows;
      final height = math.min(natural, threeRows);
      final soloWidth = height < natural ? ratio * height : paneWidth;
      cells.add(large(Rect.fromLTWH(0, top, soloWidth, height)));
      top += height;
      continue;
    }
    if (next == tiles.length) {
      cells.add(large(Rect.fromLTWH(0, top, width, twoRows)));
      top += twoRows;
      continue;
    }
    if (!_fillsTwoRows(
      tiles: tiles,
      first: next,
      targetHeight: targetHeight,
      gap: gap,
      besideAtTwoRows: beside,
    )) {
      // Too few tiles to fill both rows: they keep the target height.
      cells.add(large(Rect.fromLTWH(0, top, width, twoRows)));
      final bottom = placeRows(
        packJustifiedRows(
          ratios: tileRatios.sublist(next),
          paneWidth: beside,
          targetHeight: targetHeight,
          gap: gap,
          minTileWidth: minTileWidth,
        ),
        next,
        width + gap,
        top,
      );
      next = tiles.length;
      top = math.max(top + twoRows, bottom);
      continue;
    }
    final split = _bestSplit(
      largeRatio: ratio,
      tiles: tiles,
      first: next,
      paneWidth: paneWidth,
      targetHeight: targetHeight,
      gap: gap,
      minTileWidth: minTileWidth,
    );
    if (split == null) {
      // Tiles enough, but every split puts one under the minimum width:
      // the large item stands alone and the tiles flow on under it.
      cells.add(large(Rect.fromLTWH(0, top, width, twoRows)));
      top += twoRows;
      continue;
    }
    final largeWidth = ratio * split.height;
    cells.add(large(Rect.fromLTWH(0, top, largeWidth, split.height)));
    final left = largeWidth + gap;
    placeRows(
      [
        _flushRow(
          tiles,
          next,
          split.upperCount,
          split.upperHeight,
          left,
          paneWidth,
          gap,
        ),
        _flushRow(
          tiles,
          next + split.upperCount,
          split.lowerCount,
          split.height - gap - split.upperHeight,
          left,
          paneWidth,
          gap,
        ),
      ],
      0,
      left,
      top,
    );
    next += split.upperCount + split.lowerCount;
    top += split.height;
  }

  if (next < tiles.length) {
    if (cells.isNotEmpty) top += gap;
    placeRows(
      packJustifiedRows(
        ratios: tileRatios.sublist(next),
        paneWidth: paneWidth,
        targetHeight: targetHeight,
        gap: gap,
        minTileWidth: minTileWidth,
      ),
      next,
      0,
      top,
    );
  }
  return cells;
}

/// A row of [count] tiles from [start] at [height], with its last tile
/// absorbing the rounding so the row ends exactly at [paneWidth]. Its start
/// is the tiles' absolute index, so it is placed with a first index of 0.
JustifiedRow _flushRow(
  List<double> tiles,
  int start,
  int count,
  double height,
  double left,
  double paneWidth,
  double gap,
) {
  final widths = <double>[];
  var x = left;
  for (var k = 0; k < count - 1; k++) {
    final width = tiles[start + k] * height;
    widths.add(width);
    x += width + gap;
  }
  widths.add(math.max(0, paneWidth - x));
  return JustifiedRow(start: start, widths: widths, height: height);
}

/// How a large item's block splits its tiles: [upperCount] in the upper row
/// at [upperHeight], [lowerCount] in the lower one, the block [height] tall.
typedef _Split = ({
  int upperCount,
  int lowerCount,
  double height,
  double upperHeight,
});

/// Whether the tiles from [first], at [targetHeight], reach across both
/// rows beside a large item, each [besideAtTwoRows] wide. Fewer keep the
/// target height, as the row packer's last row does.
bool _fillsTwoRows({
  required List<double> tiles,
  required int first,
  required double targetHeight,
  required double gap,
  required double besideAtTwoRows,
}) {
  final left = tiles.length - first;
  if (left < 2) return false;
  var total = 0.0;
  for (var i = first; i < tiles.length; i++) {
    total += tiles[i];
  }
  return total * targetHeight + gap * (left - 2) >= 2 * besideAtTwoRows;
}

/// The split of the tiles from [first] into two rows beside a large item of
/// [largeRatio] that keeps both rows nearest [targetHeight], or null when no
/// split keeps every tile at [minTileWidth].
///
/// With the block H tall, the large item is `largeRatio * H` wide and a row
/// of ratio sum S and n tiles is `(paneWidth - largeRatio * H - gap * n) / S`
/// tall. The two rows and the gap between them make H, which is linear in
/// H, so each split has exactly one height that ends every edge flush.
///
/// Every split is tried, with no cap on a row's tiles, so a very wide pane
/// fills its rows. Adding a tile to the lower row lowers H and raises the
/// upper row, so the lower row only gets shorter: once it is under the
/// minimum, no longer lower row can do better.
_Split? _bestSplit({
  required double largeRatio,
  required List<double> tiles,
  required int first,
  required double paneWidth,
  required double targetHeight,
  required double gap,
  required double minTileWidth,
}) {
  final left = tiles.length - first;

  _Split? best;
  var bestCost = double.infinity;
  var upperSum = 0.0;
  var upperMin = double.infinity;
  for (var k1 = 1; k1 < left; k1++) {
    final upperRatio = tiles[first + k1 - 1];
    upperSum += upperRatio;
    upperMin = math.min(upperMin, upperRatio);
    var lowerSum = 0.0;
    var lowerMin = double.infinity;
    for (var k2 = 1; k2 <= left - k1; k2++) {
      final lowerRatio = tiles[first + k1 + k2 - 1];
      lowerSum += lowerRatio;
      lowerMin = math.min(lowerMin, lowerRatio);
      final a = 1 / upperSum;
      final b = 1 / lowerSum;
      final height =
          (a * (paneWidth - gap * k1) + b * (paneWidth - gap * k2) + gap) /
          (1 + largeRatio * (a + b));
      final upper = a * (paneWidth - largeRatio * height - gap * k1);
      final lower = height - gap - upper;
      if (lower <= 0 || lowerMin * lower < minTileWidth) break;
      if (upper <= 0 || upperMin * upper < minTileWidth) continue;
      final cost =
          (math.log(upper / targetHeight)).abs() +
          (math.log(lower / targetHeight)).abs();
      if (cost < bestCost) {
        bestCost = cost;
        best = (
          upperCount: k1,
          lowerCount: k2,
          height: height,
          upperHeight: upper,
        );
      }
    }
  }
  return best;
}
