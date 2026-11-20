import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_row_height_builder.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';

/// The thumbnails of a paged library [state] in [mode]: the grid, or the
/// by-dive or timeline groups, with the loading and empty states. Shared by
/// the Media screen's library and the focused gallery a detail card opens
/// (issue #4741), so the two lay media out alike.
///
/// Not the map: its query and states are its own.
class MediaLibraryGallery extends StatelessWidget {
  const MediaLibraryGallery({
    super.key,
    required this.state,
    required this.mode,
    required this.onLoadMore,
    required this.onTileTap,
    required this.emptyMessage,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  }) : assert(mode != MediaLibraryViewMode.map, 'the map draws itself');

  final MediaLibraryState state;
  final MediaLibraryViewMode mode;
  final VoidCallback onLoadMore;

  /// A tapped tile, with the entries in the order the gallery shows them,
  /// which is the order the viewer pages through (issue #4146).
  final void Function(MediaLibraryEntry entry, List<MediaLibraryEntry> shown)
  onTileTap;

  /// Shown when there is nothing to lay out.
  final String emptyMessage;

  final Set<String> selectedIds;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.entries.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    // The grouped modes load pages already ordered by group (issue #4268),
    // so each group here is one run of rows. The viewer pages through what
    // the gallery shows, so it gets the groups' order (issue #4146).
    final groups = switch (mode) {
      MediaLibraryViewMode.byDive => groupByDive(state.entries),
      MediaLibraryViewMode.timeline => groupByTimeline(state.entries),
      MediaLibraryViewMode.grid || MediaLibraryViewMode.map => null,
    };
    final shown = groups == null
        ? state.entries
        : [for (final group in groups) ...group.entries];
    void handleTap(MediaLibraryEntry entry) => onTileTap(entry, shown);

    // One size for all three thumbnail views, from the toolbar's slider or
    // the mouse wheel with Ctrl held (issue #3297).
    return MediaThumbnailWheelZoom(
      child: MediaThumbnailRowHeightBuilder(
        builder: (context, rowHeight) => groups == null
            ? MediaLibraryGrid(
                entries: state.entries,
                hasMore: state.hasMore,
                onLoadMore: onLoadMore,
                onTileTap: (entry, index) => handleTap(entry),
                rowHeight: rowHeight,
                selectedIds: selectedIds,
                isSelectionMode: isSelectionMode,
              )
            : MediaLibraryGroupedList(
                groups: groups,
                hasMore: state.hasMore,
                onLoadMore: onLoadMore,
                onTileTap: handleTap,
                rowHeight: rowHeight,
                selectedIds: selectedIds,
                isSelectionMode: isSelectionMode,
              ),
      ),
    );
  }
}
