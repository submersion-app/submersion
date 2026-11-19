import 'dart:math' as math;

/// One row of a justified layout: a run of consecutive items sharing one
/// height, each as wide as its aspect ratio makes it at that height.
class JustifiedRow {
  const JustifiedRow({
    required this.start,
    required this.widths,
    required this.height,
  });

  /// Index of the row's first item.
  final int start;

  /// One width per item, in order.
  final List<double> widths;

  final double height;

  int get count => widths.length;
}

/// Packs items of the given aspect [ratios] (width / height) into rows across
/// [paneWidth], issue #4738.
///
/// Items are taken left to right. A row grows while it is narrower than the
/// pane at [targetHeight]; at the item that would cross the edge it closes at
/// whichever break, before that item or after it, gives the height nearer the
/// target, measured as a ratio so that half as tall and twice as tall count
/// the same. Ties take the item. A closed row is scaled to end exactly at the
/// pane edge: its last item absorbs the rounding.
///
/// The row still open when the items run out keeps [targetHeight] and is not
/// stretched, so a single leftover photo is not blown up to the pane width.
///
/// Packing is greedy from the left, so appending items can change only the
/// last row: what is already laid out above stays where it is when a page of
/// the library arrives.
///
/// [minTileWidth] raises any ratio narrower than it at [targetHeight], and a
/// row never closes at a break that would scale a tile below it. A pane
/// narrower than that still gets one item a row, at the pane's width.
List<JustifiedRow> packJustifiedRows({
  required List<double> ratios,
  required double paneWidth,
  required double targetHeight,
  required double gap,
  double minTileWidth = 0,
}) {
  final floor = targetHeight > 0 ? minTileWidth / targetHeight : 0.0;
  final effective = [for (final r in ratios) math.max(r, floor)];
  final rows = <JustifiedRow>[];

  double heightFor(int count, double ratioSum) =>
      math.max(0, paneWidth - gap * (count - 1)) / ratioSum;

  JustifiedRow closed(int start, int count, double ratioSum) {
    final height = heightFor(count, ratioSum);
    final widths = <double>[];
    var used = 0.0;
    for (var k = 0; k < count - 1; k++) {
      final width = effective[start + k] * height;
      widths.add(width);
      used += width;
    }
    widths.add(math.max(0, paneWidth - used - gap * (count - 1)));
    return JustifiedRow(start: start, widths: widths, height: height);
  }

  var i = 0;
  while (i < effective.length) {
    final start = i;
    var count = 0;
    var ratioSum = 0.0;
    var narrowest = double.infinity;
    JustifiedRow? row;
    while (i < effective.length) {
      final nextSum = ratioSum + effective[i];
      final nextCount = count + 1;
      if (nextSum * targetHeight + gap * count < paneWidth) {
        ratioSum = nextSum;
        count = nextCount;
        narrowest = math.min(narrowest, effective[i]);
        i++;
        continue;
      }
      // Item i reaches the edge: close before it or after it.
      final after = heightFor(nextCount, nextSum);
      // Taking it scales the row down; never so far that a tile falls under
      // the minimum width. Closing before it only scales the row up.
      final keepsMinimum =
          math.min(narrowest, effective[i]) * after >= minTileWidth;
      final takeIt =
          count == 0 ||
          (keepsMinimum &&
              (math.log(after / targetHeight)).abs() <=
                  (math.log(heightFor(count, ratioSum) / targetHeight)).abs());
      if (takeIt) {
        row = closed(start, nextCount, nextSum);
        i++;
      } else {
        row = closed(start, count, ratioSum);
      }
      break;
    }
    rows.add(
      row ??
          JustifiedRow(
            start: start,
            widths: [
              for (var k = start; k < start + count; k++)
                effective[k] * targetHeight,
            ],
            height: targetHeight,
          ),
    );
  }
  return rows;
}
