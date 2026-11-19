import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Where a thumbnail sits in its view, attached to it with [MetaData] so a
/// hit test at the cursor can tell which one it found.
class MediaThumbnailSlot {
  const MediaThumbnailSlot({required this.row, required this.index});

  /// Index of the group holding this thumbnail. Always 0 in the flat grid,
  /// which is one group.
  final int row;

  /// The thumbnail's index within that group.
  final int index;
}

/// The thumbnail under the cursor when the wheel asked for a new size, or
/// the one just above it when the cursor is over a gap, as it was laid out
/// before the change.
class MediaThumbnailZoomAnchor {
  const MediaThumbnailZoomAnchor({
    required this.slot,
    required this.cursorY,
    required this.tileTop,
    required this.tileExtent,
  });

  final MediaThumbnailSlot slot;

  /// The cursor's and the thumbnail's top edge's global y.
  final double cursorY;
  final double tileTop;

  /// The thumbnail's height as it was laid out.
  final double tileExtent;

  /// The scroll offset that puts the thumbnail back on the cursor's line
  /// once the gallery is laid out again (issues #3297, #4738), never before
  /// the start. The end is the scroll view's to enforce: it is not known
  /// until the new layout is.
  ///
  /// [pixels] is the offset the anchor was captured at, [oldTop] and
  /// [newTop] the thumbnail's top in the old and new layouts, and
  /// [newHeight] its new height. The layouts are exact, so this is exact:
  /// the same fraction of the thumbnail stays under the cursor. Over a gap
  /// or a header below the thumbnail, where the fraction is 1, its foot
  /// stays put. Padding above the gallery is the same in both layouts and
  /// cancels out.
  double scrollOffsetFor({
    required double pixels,
    required double oldTop,
    required double newTop,
    required double newHeight,
  }) {
    final fraction = tileExtent > 0
        ? ((cursorY - tileTop) / tileExtent).clamp(0.0, 1.0)
        : 0.0;
    return math.max(
      0,
      pixels + (newTop - oldTop) + fraction * (newHeight - tileExtent),
    );
  }
}

/// Carries the anchor from the wheel event to the scroll view that will be
/// rebuilt with the new column count a frame later.
class MediaThumbnailZoomAnchorHolder {
  MediaThumbnailZoomAnchor? _pending;

  /// Records the thumbnail at [position] inside [boundary]. Over a gap, a
  /// header or the space after the last photo, it is the thumbnail
  /// immediately above instead; with none above either, nothing is held.
  ///
  /// One walk of the thumbnails laid out under [boundary], rather than hit
  /// testing the view at points up the pane: those cost a whole-tree hit
  /// test each, and over empty space ran to hundreds per wheel click.
  void capture(Offset position, RenderBox boundary) {
    _pending = null;
    final top = boundary.localToGlobal(Offset.zero).dy;
    final tiles = <(RenderMetaData, Rect)>[];
    void visit(RenderObject node) {
      if (node is RenderMetaData && node.metaData is MediaThumbnailSlot) {
        if (node.hasSize) {
          tiles.add((node, node.localToGlobal(Offset.zero) & node.size));
        }
        return;
      }
      // Skips what is laid out but not shown, such as offstage children
      // and a lazy list's kept-alive rows.
      node.visitChildrenForSemantics(visit);
    }

    boundary.visitChildrenForSemantics(visit);
    // Just more than the widest gap, so a thumbnail beside the cursor is
    // reached.
    const stride = 5.0;
    // Straight up first. Between two columns there is nothing straight up,
    // so then from one side of the gap, and from the other.
    for (final dx in const [0.0, -stride, stride]) {
      final x = position.dx + dx;
      RenderMetaData? nearest;
      var nearestTop = double.negativeInfinity;
      for (final (tile, rect) in tiles) {
        // In this column, starting at or above the cursor, and showing
        // some of itself below the top of the pane.
        if (x < rect.left || x >= rect.right) continue;
        if (rect.top > position.dy || rect.bottom <= top) continue;
        if (rect.top > nearestTop) {
          nearest = tile;
          nearestTop = rect.top;
        }
      }
      if (nearest != null) {
        _pending = _anchorFor(nearest, cursorY: position.dy);
        return;
      }
    }
  }

  MediaThumbnailZoomAnchor _anchorFor(
    RenderMetaData target, {
    required double cursorY,
  }) {
    return MediaThumbnailZoomAnchor(
      slot: target.metaData as MediaThumbnailSlot,
      cursorY: cursorY,
      tileTop: target.localToGlobal(Offset.zero).dy,
      tileExtent: target.size.height,
    );
  }

  /// The pending anchor, handed over once.
  MediaThumbnailZoomAnchor? take() {
    final anchor = _pending;
    _pending = null;
    return anchor;
  }

  void clear() => _pending = null;
}

/// Makes the wheel zoom's [MediaThumbnailZoomAnchorHolder] reachable from
/// the thumbnail views beneath it.
class MediaThumbnailZoomAnchorScope extends InheritedWidget {
  const MediaThumbnailZoomAnchorScope({
    super.key,
    required this.holder,
    required super.child,
  });

  final MediaThumbnailZoomAnchorHolder holder;

  /// The anchor waiting for the view at [context], if a wheel zoom is in
  /// flight. Null outside a wheel zoom, as with the size slider.
  static MediaThumbnailZoomAnchor? takeFrom(BuildContext context) => context
      .getInheritedWidgetOfExactType<MediaThumbnailZoomAnchorScope>()
      ?.holder
      .take();

  @override
  bool updateShouldNotify(MediaThumbnailZoomAnchorScope oldWidget) =>
      holder != oldWidget.holder;
}
