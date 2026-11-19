import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart';

/// One cell of a [JustifiedMediaScrollView] as its builder sees it: a
/// group's header or one of its thumbnails, and the size it is laid out at.
class JustifiedCell {
  const JustifiedCell({
    required this.section,
    required this.header,
    required this.tile,
    required this.size,
  });

  final int section;

  /// The header's index in its group, or -1 for a thumbnail.
  final int header;

  /// The thumbnail's index in its group, or -1 for a header.
  final int tile;

  final Size size;

  bool get isHeader => header >= 0;
}

/// A lazy, scrollable justified gallery (issue #4738): the flat library grid
/// is one section with no headers, the by-dive and timeline views a section
/// per group.
///
/// Only cells near the viewport are built (issue #3826). Whenever the layout
/// changes (a new width, row height, header height, or a shape learned from a
/// decoded thumbnail) the view keeps its place: a wheel zoom keeps the
/// thumbnail under the cursor on the cursor's line (issue #3297), and
/// anything else keeps the cell at the top edge where it is. An exact table
/// has no estimates to absorb a change above the viewport, so without this
/// the view would jump.
class JustifiedMediaScrollView extends StatefulWidget {
  const JustifiedMediaScrollView({
    super.key,
    required this.sectionsFor,
    required this.rowHeight,
    required this.cellBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.padding = EdgeInsets.zero,
  });

  /// The sections to lay out across a pane of the given width. Header
  /// heights can depend on the width, as a wrapping title does.
  final List<JustifiedSection> Function(double paneWidth) sectionsFor;

  final double rowHeight;
  final Widget Function(BuildContext context, JustifiedCell cell) cellBuilder;
  final bool hasMore;
  final VoidCallback onLoadMore;

  /// Above and below the gallery only: the sides are part of the layout.
  final EdgeInsets padding;

  static const double loadMoreThreshold = 400;

  @override
  State<JustifiedMediaScrollView> createState() =>
      _JustifiedMediaScrollViewState();
}

class _JustifiedMediaScrollViewState extends State<JustifiedMediaScrollView> {
  /// The view's scroll position, picked up from a cell's context. Not a
  /// ScrollController: giving the view one would stop it being the page's
  /// primary scroll view.
  ScrollPosition? _position;

  JustifiedMediaTable? _table;
  List<JustifiedSection> _sections = const [];

  /// The table for this build, kept when nothing about the layout changed,
  /// so that a selection toggle does not lay the gallery out again.
  JustifiedMediaTable _tableFor(double paneWidth) {
    final sections = widget.sectionsFor(paneWidth);
    final previous = _table;
    if (previous != null &&
        previous.targetHeight == widget.rowHeight &&
        previous.paneWidth == paneWidth &&
        listEquals(_sections, sections)) {
      return previous;
    }
    final next = JustifiedMediaTable.build(
      sections: sections,
      paneWidth: paneWidth,
      targetHeight: widget.rowHeight,
      gap: mediaThumbnailGap(paneWidth),
      inset: mediaThumbnailInset(paneWidth),
      minTileWidth: kMediaThumbnailMinTileWidth,
    );
    _keepPlace(previous, next);
    _sections = sections;
    return _table = next;
  }

  /// Moves the offset as [next] replaces [previous], before the new layout,
  /// so the first frame at it is already in place.
  void _keepPlace(JustifiedMediaTable? previous, JustifiedMediaTable next) {
    if (previous == null) return;
    final anchor = previous.targetHeight == next.targetHeight
        ? null
        : MediaThumbnailZoomAnchorScope.takeFrom(context);
    final position = _position;
    if (position == null || !position.hasPixels) return;
    final top = widget.padding.top;
    final oldCell = anchor == null
        ? null
        : previous.tileCellOf(anchor.slot.row, anchor.slot.index);
    final newCell = anchor == null
        ? null
        : next.tileCellOf(anchor.slot.row, anchor.slot.index);
    if (anchor != null && oldCell != null && newCell != null) {
      final newRect = next.rectOf(newCell);
      position.correctPixels(
        anchor.scrollOffsetFor(
          pixels: position.pixels,
          oldTop: previous.rectOf(oldCell).top,
          newTop: newRect.top,
          newHeight: newRect.height,
        ),
      );
    } else if (position.pixels > top) {
      // Only the cells up to the one at the top edge need to match: a page
      // that grows the groups below it, arriving with a shape learned above
      // it, must not move the view.
      final place = previous.placeAt(position.pixels - top);
      if (previous.sharesCellsThrough(next, place.cell)) {
        position.correctPixels(next.offsetOf(place) + top);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.hasMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent -
                    JustifiedMediaScrollView.loadMoreThreshold) {
          widget.onLoadMore();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final table = _tableFor(constraints.maxWidth);
          return GridView.builder(
            // Lets Ctrl + wheel resize instead of scroll (issue #3297).
            physics: const MediaThumbnailWheelZoomPhysics(),
            // Two pane heights beyond the visible area, not the default
            // 250px: a fast scroll otherwise brings tiles on screen before
            // their decode has finished (issue #3337).
            scrollCacheExtent: const ScrollCacheExtent.viewport(2),
            padding: widget.padding,
            gridDelegate: JustifiedMediaGridDelegate(table),
            itemCount: table.cellCount,
            itemBuilder: (context, cell) {
              _position = Scrollable.maybeOf(context)?.position;
              final section = table.sectionOf(cell);
              final tile = table.tileIndexOf(cell);
              final built = widget.cellBuilder(
                context,
                JustifiedCell(
                  section: section,
                  header: table.headerIndexOf(cell),
                  tile: tile,
                  size: table.rectOf(cell).size,
                ),
              );
              if (tile < 0) return built;
              return MetaData(
                metaData: MediaThumbnailSlot(row: section, index: tile),
                behavior: HitTestBehavior.opaque,
                child: built,
              );
            },
          );
        },
      ),
    );
  }
}
