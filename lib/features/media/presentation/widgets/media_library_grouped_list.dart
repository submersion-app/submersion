import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sectioned presentation shared by the by-dive and timeline modes: group
/// headers over non-scrolling thumbnail grids inside one scrolling list,
/// with the same near-end load-more contract as the flat grid.
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
  /// The list's scroll position, picked up from a row's context. Not a
  /// ScrollController: giving the list one would stop it being the page's
  /// primary scroll view.
  ScrollPosition? _position;

  /// As last built: how many thumbnails the grid at each list row holds.
  /// Header rows have no entry.
  Map<int, int> _gridCounts = const {};

  @override
  void didUpdateWidget(MediaLibraryGroupedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns == widget.columns) return;
    // A wheel zoom: move the offset now, before the new layout, so the
    // thumbnail under the cursor is drawn on the same line (issue #3297).
    final anchor = MediaThumbnailZoomAnchorScope.takeFrom(context);
    final position = _position;
    if (anchor == null || position == null || !position.hasPixels) return;
    final newExtent = mediaThumbnailExtentAfter(
      anchor.tileExtent,
      oldColumns: oldWidget.columns,
      newColumns: widget.columns,
    );
    // Every grid built above the anchor's changes height with the size and
    // pushes it down, or pulls it up, by the difference.
    var heightChangeAbove = 0.0;
    for (var row = anchor.leadingRow; row < anchor.slot.row; row++) {
      final count = _gridCounts[row];
      if (count == null) continue;
      heightChangeAbove +=
          mediaThumbnailGridHeight(count, widget.columns, newExtent) -
          mediaThumbnailGridHeight(count, oldWidget.columns, anchor.tileExtent);
    }
    position.correctPixels(
      anchor.scrollOffsetFor(
        pixels: position.pixels,
        oldColumns: oldWidget.columns,
        newColumns: widget.columns,
        heightChangeAbove: heightChangeAbove,
      ),
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

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final target = widget.targetSize;
    final columns = widget.columns;
    final selectedIds = widget.selectedIds;
    final isSelectionMode = widget.isSelectionMode;
    final rows = <Widget>[];
    final gridCounts = <int, int>{};
    DateTime? lastMonth;
    for (final group in widget.groups) {
      final header = group.header;
      if (header is DateGroupHeader) {
        if (lastMonth != header.monthStart) {
          lastMonth = header.monthStart;
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
              child: Text(
                units.formatMonthYear(header.monthStart),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              units.formatWeekdayMonthDay(header.dayStart),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        );
      } else if (header is DiveGroupHeader) {
        final label = _diveHeaderLabel(context, units, header);
        final diveId = header.diveId;
        // Inert while a selection is in progress, matching the tiles below it:
        // a tap landing a few pixels high must not navigate away from a
        // half-built selection.
        final navigable = diveId != null && !isSelectionMode;
        rows.add(
          navigable
              ? Semantics(
                  button: true,
                  label: label,
                  hint: context.l10n.media_library_diveHeaderHint,
                  child: InkWell(
                    onTap: () => context.pushOrReturnTo('/dives/$diveId'),
                    // Padding inside the InkWell so it contributes to the hit
                    // box, with a 48dp floor per Material's tap-target rule.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
        );
      }
      final gridRow = rows.length;
      gridCounts[gridRow] = group.entries.length;
      rows.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: kMediaThumbnailMaxInset / 2,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: kMediaThumbnailGap,
            crossAxisSpacing: kMediaThumbnailGap,
          ),
          itemCount: group.entries.length,
          itemBuilder: (context, index) {
            final entry = group.entries[index];
            return MetaData(
              metaData: MediaThumbnailSlot(row: gridRow, index: index),
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
        ),
      );
    }
    _gridCounts = gridCounts;

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
      child: ListView.builder(
        // Lets Ctrl + wheel resize instead of scroll (issue #3297).
        physics: const MediaThumbnailWheelZoomPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          _position = Scrollable.maybeOf(context)?.position;
          return rows[index];
        },
      ),
    );
  }
}
