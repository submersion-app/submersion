import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_group_header.dart';
import 'package:submersion/features/media/presentation/widgets/media_grouped_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sectioned presentation shared by the by-dive and timeline modes: one lazy
/// grid whose cells are group headers and thumbnails, so what is built follows
/// the viewport rather than the size of a group (issue #3826), with the same
/// near-end load-more contract as the flat grid.
class MediaLibraryGroupedList extends ConsumerStatefulWidget {
  const MediaLibraryGroupedList({
    super.key,
    required this.groups,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTileTap,
    required this.columns,
    this.targetSize = kDefaultThumbnailTarget,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  });

  final List<MediaLibraryGroup> groups;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry) onTileTap;

  /// How many thumbnails go across, from the size slider (issue #3297).
  final int columns;

  /// The size to decode thumbnails at, from the pane's width and [columns]
  /// (see [mediaThumbnailDecodeTarget]).
  final Size targetSize;

  /// Ids rendered with the selection overlay.
  final Set<String> selectedIds;

  /// Whether the surface is in multi-select, which can be true with nothing
  /// checked.
  final bool isSelectionMode;

  static const double _loadMoreThreshold = 400;

  @override
  ConsumerState<MediaLibraryGroupedList> createState() =>
      _MediaLibraryGroupedListState();
}

class _MediaLibraryGroupedListState
    extends ConsumerState<MediaLibraryGroupedList> {
  /// The list's scroll position, picked up from a cell's context. Not a
  /// ScrollController: giving the list one would stop it being the page's
  /// primary scroll view.
  ScrollPosition? _position;

  MediaGroupHeaderMeasurer? _measurer;
  MediaGroupedGridTable? _table;
  List<MediaGridSection> _sections = const [];

  /// Moves the offset as [next] replaces [previous], before the new layout, so
  /// the first frame at it is already in place. An exact table has no estimates
  /// to absorb a change in height above the viewport, so with the offset left
  /// alone, entering selection or resizing the pane would throw the view
  /// somewhere else.
  void _keepPlace(MediaGroupedGridTable? previous, MediaGroupedGridTable next) {
    if (previous == null) return;
    final anchor = previous.columns == next.columns
        ? null
        : MediaThumbnailZoomAnchorScope.takeFrom(context);
    final position = _position;
    if (position == null || !position.hasPixels) return;
    if (anchor != null) {
      position.correctPixels(
        _offsetKeeping(anchor, position.pixels, previous.columns, next.columns),
      );
    } else if (previous.hasSameCellsAs(next)) {
      position.correctPixels(next.offsetOf(previous.placeAt(position.pixels)));
    }
  }

  /// A wheel zoom's offset, which keeps the thumbnail under the cursor on the
  /// same line (issue #3297) rather than the cell at the top edge.
  double _offsetKeeping(
    MediaThumbnailZoomAnchor anchor,
    double pixels,
    int oldColumns,
    int newColumns,
  ) {
    final newExtent = mediaThumbnailExtentAfter(
      anchor.tileExtent,
      oldColumns: oldColumns,
      newColumns: newColumns,
    );
    // Every group above the anchor's changes height with the size and pushes
    // it down, or pulls it up, by the difference.
    var heightChangeAbove = 0.0;
    for (final section in _sections.take(anchor.slot.row)) {
      final count = section.tileCount;
      heightChangeAbove +=
          mediaThumbnailGridHeight(count, newColumns, newExtent) -
          mediaThumbnailGridHeight(count, oldColumns, anchor.tileExtent);
    }
    return anchor.scrollOffsetFor(
      pixels: pixels,
      oldColumns: oldColumns,
      newColumns: newColumns,
      heightChangeAbove: heightChangeAbove,
    );
  }

  String _diveHeaderLabel(
    BuildContext context,
    UnitFormatter units,
    DiveGroupHeader header,
  ) {
    if (header.diveId == null) {
      return context.l10n.media_library_unlinkedHeader;
    }
    final siteName = header.siteName;
    final parts = <String>[
      if (header.diveNumber != null) '#${header.diveNumber}',
      if (siteName != null && siteName.isNotEmpty) siteName,
    ];
    if (parts.isEmpty) {
      final date = header.diveDateTime;
      if (date != null) {
        return units.formatDate(date);
      }
      // A linked dive with no number, site or date still needs a visible
      // label: the header is this view's only route to that dive, and an
      // empty string renders a zero-size, untappable target.
      return context.l10n.media_library_untitledDiveHeader;
    }
    return parts.join(' · ');
  }

  /// Each group's headers, in order. The timeline carries a month header
  /// whenever the month changes between groups.
  List<List<MediaGroupHeaderSpec>> _headers(
    BuildContext context,
    UnitFormatter units,
  ) {
    DateTime? lastMonth;
    final headers = <List<MediaGroupHeaderSpec>>[];
    for (final group in widget.groups) {
      switch (group.header) {
        case DateGroupHeader(:final monthStart, :final dayStart):
          headers.add([
            if (lastMonth != monthStart)
              MediaGroupHeaderSpec(
                kind: MediaGroupHeaderKind.month,
                label: units.formatMonthYear(monthStart),
              ),
            MediaGroupHeaderSpec(
              kind: MediaGroupHeaderKind.day,
              label: units.formatWeekdayMonthDay(dayStart),
            ),
          ]);
          lastMonth = monthStart;
        case final DiveGroupHeader header:
          headers.add([
            MediaGroupHeaderSpec(
              kind: MediaGroupHeaderKind.dive,
              label: _diveHeaderLabel(context, units, header),
              // Inert while a selection is in progress, matching the tiles
              // below it: a tap landing a few pixels high must not navigate
              // away from a half-built selection.
              diveId: widget.isSelectionMode ? null : header.diveId,
            ),
          ]);
      }
    }
    return headers;
  }

  /// The table for this build, kept when nothing about the layout changed, so
  /// that a selection toggle does not lay the gallery out again.
  MediaGroupedGridTable _tableFor(
    BuildContext context,
    List<List<MediaGroupHeaderSpec>> headers,
    double paneWidth,
  ) {
    final measurer = MediaGroupHeaderMeasurer.of(context);
    final current = _measurer;
    final kept = current != null && current.matches(measurer)
        ? current
        : _measurer = measurer;
    final sections = [
      for (var g = 0; g < headers.length; g++)
        MediaGridSection(
          headerExtents: [
            for (final spec in headers[g]) kept.extentOf(spec, paneWidth),
          ],
          tileCount: widget.groups[g].entries.length,
        ),
    ];
    final previous = _table;
    if (previous != null &&
        previous.columns == widget.columns &&
        previous.paneWidth == paneWidth &&
        listEquals(_sections, sections)) {
      return previous;
    }
    final next = MediaGroupedGridTable.build(
      sections: sections,
      columns: widget.columns,
      paneWidth: paneWidth,
    );
    _keepPlace(previous, next);
    _sections = sections;
    return _table = next;
  }

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final headers = _headers(context, units);
    final groups = widget.groups;
    final target = widget.targetSize;
    final selectedIds = widget.selectedIds;
    final isSelectionMode = widget.isSelectionMode;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.hasMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent -
                    MediaLibraryGroupedList._loadMoreThreshold) {
          widget.onLoadMore();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final table = _tableFor(context, headers, constraints.maxWidth);
          return GridView.builder(
            // Lets Ctrl + wheel resize instead of scroll (issue #3297).
            physics: const MediaThumbnailWheelZoomPhysics(),
            // As the flat grid does (issue #3337).
            scrollCacheExtent: const ScrollCacheExtent.viewport(2),
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: MediaGroupedGridDelegate(table),
            itemCount: table.cellCount,
            itemBuilder: (context, cell) {
              _position = Scrollable.maybeOf(context)?.position;
              final group = table.sectionOf(cell);
              final header = table.headerIndexOf(cell);
              if (header >= 0) {
                final spec = headers[group][header];
                return MediaGroupHeader(
                  spec: spec,
                  onTap: () => context.pushOrReturnTo('/dives/${spec.diveId}'),
                );
              }
              final index = table.tileIndexOf(cell);
              final entry = groups[group].entries[index];
              return MetaData(
                metaData: MediaThumbnailSlot(row: group, index: index),
                behavior: HitTestBehavior.opaque,
                child: MediaLibraryTile(
                  entry: entry,
                  selected: selectedIds.contains(entry.item.id),
                  isSelectionMode: isSelectionMode,
                  targetSize: target,
                  onTap: () => widget.onTileTap(entry),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
