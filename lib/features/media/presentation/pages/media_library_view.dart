import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media/presentation/widgets/media_missing_banner.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// The Library section content: the filter and sort toolbar, the active
/// filter chips, the repair banner while the Missing files facet is active,
/// then the active view mode. The by-dive and timeline presentations reuse
/// the same paged state.
class MediaLibraryView extends ConsumerStatefulWidget {
  const MediaLibraryView({super.key});

  @override
  ConsumerState<MediaLibraryView> createState() => _MediaLibraryViewState();
}

class _MediaLibraryViewState extends ConsumerState<MediaLibraryView> {
  /// Owns the bulk-selection state machine for the library.
  ///
  /// Deliberately view state rather than a provider: the selection prunes to
  /// what is on screen and does not outlive the surface, and a single owner
  /// is what keeps "mode is active" and "something is checked" from being
  /// the same fact -- which is exactly what the old id-set provider could
  /// not express, and why long-press was its only way in.
  final SelectionController _selection = SelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final state = ref.watch(mediaLibraryNotifierProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);
    final showingMissing =
        ref.watch(mediaLibraryFilterProvider).health ==
        MediaHealthFilter.missing;

    final visibleIds = state.entries.map((e) => e.item.id).toList();
    // Drop checked ids that a filter or sort change pushed off screen, so a
    // bulk action can never reach a row the user cannot see.
    //
    // Guarded rather than scheduled unconditionally, unlike the dive media
    // section: `pruneTo` walks the whole visible set to build its lookup, and
    // this library pages through thousands of rows where a dive holds a
    // handful. The guard cannot skip a prune that mattered -- `state.entries`
    // comes from a watched provider, so every change to it runs this build,
    // and entering the mode starts from an empty checked set with nothing
    // stale to drop. Selection changes alone do not reach here at all; the
    // ValueListenableBuilder below owns those.
    if (_selection.value.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selection.pruneTo(visibleIds);
      });
    }

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Column(
          children: [
            if (selection.isActive)
              MediaSelectionBar(
                controller: _selection,
                selectableIds: visibleIds,
                selectedItems: state.entries
                    .where((e) => selection.isChecked(e.item.id))
                    .map((e) => e.item)
                    .toList(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: MediaLibraryToolbar(
                selection: _selection,
                // Filter and sort stay reachable inside the mode -- narrow
                // the list, then Select All -- but the control that opens a
                // mode already open would just be dead weight.
                canSelect: state.entries.isNotEmpty && !selection.isActive,
              ),
            ),
            const MediaLibraryActiveFilterChips(),
            if (showingMissing)
              MediaMissingBanner(isEmpty: state.entries.isEmpty),
            Expanded(
              child: _buildBody(
                context,
                state,
                mode,
                showingMissing,
                selection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MediaLibraryState state,
    MediaLibraryViewMode mode,
    bool showingMissing,
    SelectionState selection,
  ) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.entries.isEmpty) {
      return Center(
        child: Text(
          showingMissing
              ? context.l10n.media_missing_empty
              : context.l10n.media_library_empty,
        ),
      );
    }
    void loadMore() =>
        ref.read(mediaLibraryNotifierProvider.notifier).loadMore();

    void handleTap(MediaLibraryEntry entry) {
      if (selection.isActive) {
        _selection.toggle(entry.item.id);
      } else {
        _openViewer(context, state.entries, entry);
      }
    }

    final checkedIds = selection.checkedIds;

    return switch (mode) {
      MediaLibraryViewMode.grid => MediaLibraryGrid(
        entries: state.entries,
        hasMore: state.hasMore,
        onLoadMore: loadMore,
        onTileTap: (entry, index) => handleTap(entry),
        selectedIds: checkedIds,
        isSelectionMode: selection.isActive,
      ),
      MediaLibraryViewMode.byDive => MediaLibraryGroupedList(
        groups: groupByDive(state.entries),
        hasMore: state.hasMore,
        onLoadMore: loadMore,
        onTileTap: handleTap,
        selectedIds: checkedIds,
        isSelectionMode: selection.isActive,
      ),
      MediaLibraryViewMode.timeline => MediaLibraryGroupedList(
        groups: groupByTimeline(state.entries),
        hasMore: state.hasMore,
        onLoadMore: loadMore,
        onTileTap: handleTap,
        selectedIds: checkedIds,
        isSelectionMode: selection.isActive,
      ),
    };
  }
}
