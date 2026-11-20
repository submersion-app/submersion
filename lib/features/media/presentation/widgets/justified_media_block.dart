import 'package:flutter/widgets.dart';

import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';

/// One tile of a [JustifiedMediaBlock] as its builder sees it.
class JustifiedBlockCell {
  const JustifiedBlockCell({
    required this.index,
    required this.size,
    required this.hiddenCount,
  });

  /// The item's index in the block's ratios.
  final int index;

  /// The size the tile is laid out at.
  final Size size;

  /// How many items the row cap left out. Non-zero only on the last tile
  /// shown, which is where a "+N" goes.
  final int hiddenCount;
}

/// How many leading cells of [table] to show, in whole rows: all of them
/// with no [maxRows], else the first [maxRows] rows, grown to the end of the
/// row holding cell `keepAtLeast - 1` so those cells are never cut.
int justifiedVisibleCount(
  JustifiedMediaTable table, {
  int? maxRows,
  int keepAtLeast = 0,
}) {
  final count = table.cellCount;
  if (maxRows == null) return count;
  var rows = 0;
  var cell = 0;
  while (cell < count) {
    final top = table.rectOf(cell).top;
    final rowEnd = _rowEnd(table, cell, top);
    rows++;
    if (rows > maxRows && cell >= keepAtLeast) return cell;
    cell = rowEnd;
  }
  return count;
}

/// The cell after the last one in the row starting at [start].
int _rowEnd(JustifiedMediaTable table, int start, double top) {
  var cell = start + 1;
  while (cell < table.cellCount && table.rectOf(cell).top == top) {
    cell++;
  }
  return cell;
}

/// A justified gallery that does not scroll, for a section inside a details
/// page's own scroll (issue #4740). It lays its items out with the media
/// library's table (issue #4738) and can stop after [maxRows] rows.
///
/// Every tile shown is built: the block is meant for a few rows, not a
/// library. A long one needs `JustifiedMediaScrollView` instead.
class JustifiedMediaBlock extends StatelessWidget {
  const JustifiedMediaBlock({
    super.key,
    required this.ratios,
    required this.rowHeight,
    required this.gap,
    required this.cellBuilder,
    this.maxRows,
    this.keepAtLeast = 0,
  }) : assert(maxRows == null || maxRows > 0, 'maxRows must be at least 1');

  /// Each item's shape, width / height, already clamped.
  final List<double> ratios;

  final double rowHeight;

  /// Between tiles, across and down.
  final double gap;

  /// The most rows shown, or null for all.
  final int? maxRows;

  /// How many leading items the cap may never hide.
  final int keepAtLeast;

  final Widget Function(BuildContext context, JustifiedBlockCell cell)
  cellBuilder;

  @override
  Widget build(BuildContext context) {
    if (ratios.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) return const SizedBox.shrink();
        final table = JustifiedMediaTable.build(
          sections: [JustifiedSection(headerExtents: const [], ratios: ratios)],
          paneWidth: width,
          targetHeight: rowHeight,
          gap: gap,
          inset: 0,
          minTileWidth: kMediaThumbnailMinTileWidth,
        );
        final visible = justifiedVisibleCount(
          table,
          maxRows: maxRows,
          keepAtLeast: keepAtLeast,
        );
        final hidden = ratios.length - visible;
        // The table lays rows out left to right; a right-to-left language
        // reads them from the right, as the library's grid does.
        final rtl = Directionality.of(context) == TextDirection.rtl;
        Rect place(Rect rect) => rtl
            ? Rect.fromLTWH(
                width - rect.right,
                rect.top,
                rect.width,
                rect.height,
              )
            : rect;
        return SizedBox(
          width: width,
          height: table.rectOf(visible - 1).bottom,
          child: Stack(
            children: [
              for (var i = 0; i < visible; i++)
                _positioned(
                  place(table.rectOf(i)),
                  cellBuilder(
                    context,
                    JustifiedBlockCell(
                      index: i,
                      size: table.rectOf(i).size,
                      hiddenCount: i == visible - 1 ? hidden : 0,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// [child] at [rect], keyed after the child's own key when it has a local
  /// one. A Stack matches its children by their keys, so a keyed tile keeps
  /// its state, and its decoded thumbnail, when the order shifts around it.
  /// The slot's key wraps the child's rather than repeating it, so a finder
  /// for the child's key still finds only the child.
  static Widget _positioned(Rect rect, Widget child) {
    final key = child.key;
    return Positioned.fromRect(
      key: key is LocalKey ? ValueKey<LocalKey>(key) : null,
      rect: rect,
      child: child,
    );
  }
}
