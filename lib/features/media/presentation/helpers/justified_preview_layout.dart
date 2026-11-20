import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';

/// Where a justified preview puts its tiles (issue #4741): the first
/// [shownCount] items, one [Rect] each, left to right from the pane's left
/// edge, and how many of the items there are it leaves out.
class JustifiedPreviewLayout {
  const JustifiedPreviewLayout({
    required this.rects,
    required this.height,
    required this.hiddenCount,
  });

  /// One per shown item, in order.
  final List<Rect> rects;

  /// From the first row's top to the last row's bottom.
  final double height;

  /// Items not shown: those past the row limit, plus any the caller knows
  /// exist beyond the list it laid out.
  final int hiddenCount;

  int get shownCount => rects.length;
}

/// Packs [ratios] into justified rows across [width] at [rowHeight] (see
/// [packJustifiedRows]) and keeps at most [maxRows] of them; null keeps
/// every row.
///
/// Rows are packed greedily from the left, so every row kept above the limit
/// is a closed one and ends flush with the pane edge. [totalCount], when
/// larger than [ratios], is how many items exist in all: a capped read
/// passes it so the hidden count covers what it never read.
JustifiedPreviewLayout layoutJustifiedPreview({
  required List<double> ratios,
  required double width,
  required double rowHeight,
  required double gap,
  int? maxRows,
  int? totalCount,
  double minTileWidth = 48,
}) {
  final total = math.max(totalCount ?? ratios.length, ratios.length);
  if (width <= 0 || rowHeight <= 0 || ratios.isEmpty) {
    return JustifiedPreviewLayout(
      rects: const [],
      height: 0,
      hiddenCount: total,
    );
  }
  final rows = packJustifiedRows(
    ratios: ratios,
    paneWidth: width,
    targetHeight: rowHeight,
    gap: gap,
    minTileWidth: minTileWidth,
  );
  final kept = maxRows == null ? rows : rows.take(math.max(0, maxRows));
  final rects = <Rect>[];
  var top = 0.0;
  var height = 0.0;
  for (final row in kept) {
    if (rects.isNotEmpty) top += gap;
    var left = 0.0;
    for (final w in row.widths) {
      rects.add(Rect.fromLTWH(left, top, w, row.height));
      left += w + gap;
    }
    top += row.height;
    height = top;
  }
  return JustifiedPreviewLayout(
    rects: rects,
    height: height,
    hiddenCount: total - rects.length,
  );
}
