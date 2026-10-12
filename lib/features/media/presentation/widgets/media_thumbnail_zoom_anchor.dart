import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Gap between thumbnails, across and down, in every library grid.
const double kMediaThumbnailGap = 4;

/// Where a thumbnail sits in its view, attached to it with [MetaData] so a
/// hit test at the cursor can tell which one it found.
class MediaThumbnailSlot {
  const MediaThumbnailSlot({required this.row, required this.index});

  /// Index, in the scroll view, of the row holding this thumbnail's grid.
  /// Always 0 in the flat grid, which is one grid.
  final int row;

  /// The thumbnail's index within that grid.
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
    required this.leadingRow,
  });

  final MediaThumbnailSlot slot;

  /// The cursor's and the thumbnail's top edge's global y.
  final double cursorY;
  final double tileTop;

  /// The thumbnail's side; thumbnails are square.
  final double tileExtent;

  /// Index of the first row the scroll view had built. A lazy list keeps
  /// that row where it is when rows change height and moves the rest, so
  /// the rows from here to the anchor's are what shift it.
  final int leadingRow;

  /// The scroll offset that puts the thumbnail back on the cursor's line
  /// once it is laid out [newColumns] across, never before the start.
  /// The end is the scroll view's to enforce: it is not known until the
  /// new layout is.
  ///
  /// [heightChangeAbove] is how much taller the built rows above the
  /// anchor's grid become, negative for shorter.
  double scrollOffsetFor({
    required double pixels,
    required int oldColumns,
    required int newColumns,
    double heightChangeAbove = 0,
  }) {
    final newExtent = mediaThumbnailExtentAfter(
      tileExtent,
      oldColumns: oldColumns,
      newColumns: newColumns,
    );
    // How far down the thumbnail the cursor is. Below its foot, when the
    // cursor is over a gap or a header, that distance is kept as it is:
    // the foot stays put, it does not come down to meet the cursor.
    final fraction = ((cursorY - tileTop) / tileExtent).clamp(0.0, 1.0);
    final below = cursorY - (tileTop + fraction * tileExtent);
    final oldTopInGrid =
        (slot.index ~/ oldColumns) * (tileExtent + kMediaThumbnailGap);
    final newTopInGrid =
        (slot.index ~/ newColumns) * (newExtent + kMediaThumbnailGap);
    final newTileTop =
        tileTop - oldTopInGrid + heightChangeAbove + newTopInGrid;
    final shift = newTileTop + fraction * newExtent + below - cursorY;
    return math.max(0, pixels + shift);
  }
}

/// A thumbnail's side once its grid goes from [oldColumns] to [newColumns]
/// across the same width.
double mediaThumbnailExtentAfter(
  double extent, {
  required int oldColumns,
  required int newColumns,
}) {
  final gridWidth = oldColumns * extent + (oldColumns - 1) * kMediaThumbnailGap;
  return (gridWidth - (newColumns - 1) * kMediaThumbnailGap) / newColumns;
}

/// Height of a grid of [count] square thumbnails, [columns] across.
double mediaThumbnailGridHeight(int count, int columns, double extent) {
  final rows = (count / columns).ceil();
  return rows * extent + math.max(0, rows - 1) * kMediaThumbnailGap;
}

/// Carries the anchor from the wheel event to the scroll view that will be
/// rebuilt with the new column count a frame later.
class MediaThumbnailZoomAnchorHolder {
  MediaThumbnailZoomAnchor? _pending;

  /// Records the thumbnail at [position] inside [boundary]. Over a gap, a
  /// header or the space after the last photo, it is the thumbnail
  /// immediately above instead; with none above either, nothing is held.
  void capture(Offset position, int viewId, RenderBox boundary) {
    _pending = null;
    // Just more than a gap, so no thumbnail can be stepped over.
    const stride = kMediaThumbnailGap + 1;
    final top = boundary.localToGlobal(Offset.zero).dy;
    // Straight up first. Between two columns there is nothing straight up,
    // so then from one side of the gap, and from the other.
    for (final dx in const [0.0, -stride, stride]) {
      for (var y = position.dy; y >= top; y -= stride) {
        final found = _anchorAt(
          Offset(position.dx + dx, y),
          viewId,
          boundary,
          cursorY: position.dy,
        );
        if (found != null) {
          _pending = found;
          return;
        }
      }
    }
  }

  MediaThumbnailZoomAnchor? _anchorAt(
    Offset probe,
    int viewId,
    RenderBox boundary, {
    required double cursorY,
  }) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, probe, viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderMetaData) continue;
      final slot = target.metaData;
      if (slot is! MediaThumbnailSlot) continue;
      // The outermost lazy list or grid inside the library: the scroll
      // view's own, above any grid nested in one of its rows.
      RenderSliverMultiBoxAdaptor? rows;
      for (
        RenderObject? node = target.parent;
        node != null && node != boundary;
        node = node.parent
      ) {
        if (node is RenderSliverMultiBoxAdaptor) rows = node;
      }
      final leading = rows?.firstChild?.parentData;
      return MediaThumbnailZoomAnchor(
        slot: slot,
        cursorY: cursorY,
        tileTop: target.localToGlobal(Offset.zero).dy,
        tileExtent: target.size.height,
        leadingRow: leading is SliverMultiBoxAdaptorParentData
            ? leading.index ?? 0
            : 0,
      );
    }
    return null;
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
