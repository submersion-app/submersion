import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_selection_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_bar.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Library section content: type filter chips over the active view mode.
/// The by-dive and timeline presentations reuse the same paged state.
class MediaLibraryView extends ConsumerWidget {
  const MediaLibraryView({super.key});

  void _openViewer(
    BuildContext context,
    List<MediaLibraryEntry> entries,
    MediaLibraryEntry entry,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MediaViewerPage(
          mediaList: entries.map((e) => e.item).toList(),
          initialMediaId: entry.item.id,
          showGoToDive: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mediaLibraryNotifierProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);
    final selection = ref.watch(mediaSelectionProvider);

    return Column(
      children: [
        if (selection.isNotEmpty)
          MediaSelectionBar(
            selectedItems: state.entries
                .where((e) => selection.contains(e.item.id))
                .map((e) => e.item)
                .toList(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Expanded(child: MediaLibraryFilterBar()),
              const SizedBox(width: 8),
              SegmentedButton<MediaLibraryViewMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: MediaLibraryViewMode.grid,
                    icon: const Icon(Icons.grid_view),
                    tooltip: context.l10n.media_library_viewMode_grid,
                  ),
                  ButtonSegment(
                    value: MediaLibraryViewMode.byDive,
                    icon: const Icon(Icons.scuba_diving),
                    tooltip: context.l10n.media_library_viewMode_byDive,
                  ),
                  ButtonSegment(
                    value: MediaLibraryViewMode.timeline,
                    icon: const Icon(Icons.calendar_month),
                    tooltip: context.l10n.media_library_viewMode_timeline,
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => ref
                    .read(mediaLibraryViewModeProvider.notifier)
                    .setMode(selection.single),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(context, ref, state, mode)),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    MediaLibraryState state,
    MediaLibraryViewMode mode,
  ) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.entries.isEmpty) {
      return Center(child: Text(context.l10n.media_library_empty));
    }
    void loadMore() =>
        ref.read(mediaLibraryNotifierProvider.notifier).loadMore();

    final selection = ref.watch(mediaSelectionProvider);
    void handleTap(MediaLibraryEntry entry) {
      if (selection.isNotEmpty) {
        ref.read(mediaSelectionProvider.notifier).toggle(entry.item.id);
      } else {
        _openViewer(context, state.entries, entry);
      }
    }

    void handleLongPress(MediaLibraryEntry entry) {
      ref.read(mediaSelectionProvider.notifier).toggle(entry.item.id);
    }

    return switch (mode) {
      MediaLibraryViewMode.grid => MediaLibraryGrid(
        entries: state.entries,
        hasMore: state.hasMore,
        onLoadMore: loadMore,
        onTileTap: (entry, index) => handleTap(entry),
        selectedIds: selection,
        onTileLongPress: handleLongPress,
      ),
      MediaLibraryViewMode.byDive => MediaLibraryGroupedList(
        groups: groupByDive(state.entries),
        hasMore: state.hasMore,
        onLoadMore: loadMore,
        onTileTap: handleTap,
        selectedIds: selection,
        onTileLongPress: handleLongPress,
      ),
      MediaLibraryViewMode.timeline => MediaLibraryGroupedList(
        groups: groupByTimeline(state.entries),
        hasMore: state.hasMore,
        onLoadMore: loadMore,
        onTileTap: handleTap,
        selectedIds: selection,
        onTileLongPress: handleLongPress,
      ),
    };
  }
}
