import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_content.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media/presentation/widgets/media_missing_banner.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_row_height_builder.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// The Library section content: the filter and sort toolbar, the active
/// filter chips, the repair banner while the Missing files facet is active,
/// then the active view mode. The by-dive and timeline presentations reuse
/// the same paged state.
class MediaLibraryView extends ConsumerStatefulWidget {
  const MediaLibraryView({
    super.key,
    this.openViewer = openMediaViewer,
    this.selection,
    this.showToolbar = true,
  });

  /// Opens the viewer on a tapped tile; a test passes one that records the
  /// list it is handed.
  final MediaViewerOpener openViewer;

  /// The bulk-selection state, when a host shows the toolbar somewhere else
  /// and so has to share it (#4777). The host owns and disposes it and
  /// decides when it ends, which can outlive this view: `MediaSectionPage`
  /// keeps it across the remount a resize past the master-detail breakpoint
  /// causes. Null gives the view one of its own.
  final SelectionController? selection;

  /// Whether the view shows [MediaLibraryHeaderToolbar] above its content.
  /// False where a host shows it in the page header instead.
  final bool showToolbar;

  @override
  ConsumerState<MediaLibraryView> createState() => _MediaLibraryViewState();
}

class _MediaLibraryViewState extends ConsumerState<MediaLibraryView> {
  /// The bulk-selection state machine for the library when no host passes
  /// [MediaLibraryView.selection]; the view owns and disposes only this one.
  ///
  /// Deliberately widget state rather than a provider: the selection prunes
  /// to what is on screen and does not outlive the surface, and a single
  /// owner (this view, or the page hosting it, #4777) is what keeps "mode is
  /// active" and "something is checked" from being the same fact. That is
  /// exactly what the old id-set provider could not express, and why
  /// long-press was its only way in.
  SelectionController? _ownSelection;

  SelectionController get _selection =>
      widget.selection ?? (_ownSelection ??= SelectionController());

  @override
  void dispose() {
    _ownSelection?.dispose();
    super.dispose();
  }

  void _openViewer(
    BuildContext context,
    List<MediaLibraryEntry> entries,
    MediaLibraryEntry entry,
  ) {
    widget.openViewer(
      context,
      entries.map((e) => e.item).toList(),
      entry.item.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaLibraryNotifierProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);
    final filter = ref.watch(mediaLibraryFilterProvider);
    final showingMissing = filter.health == MediaHealthFilter.missing;

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
    //
    // Not while page one loads: a new filter, sort or view grouping builds a
    // new notifier that starts with no rows, and pruning against that would
    // drop every checked row, even ones the new query brings straight back
    // (issue #4268 made a mode switch one of these). The prune runs once the
    // rows land.
    if (_selection.value.isActive && !state.isLoading) {
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
            if (widget.showToolbar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: MediaLibraryHeaderToolbar(selection: _selection),
              ),
            const MediaLibraryActiveFilterChips(),
            if (showingMissing)
              MediaMissingBanner(isEmpty: state.entries.isEmpty),
            Expanded(
              child: _buildBody(context, state, mode, filter, selection),
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
    MediaLibraryFilter filter,
    SelectionState selection,
  ) {
    // The map runs its own unpaged query and owns its loading, empty and
    // error states; the grid's page one must not stand in for them.
    if (mode == MediaLibraryViewMode.map) return const MediaMapContent();
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.entries.isEmpty) {
      // Under a filter, empty means nothing matches it, not an empty
      // library; with the cleanup filters (issue #4148) it is the finished
      // state. So a read that failed must not pass for either.
      final message = state.error != null
          ? context.l10n.media_diveMediaSection_errorLoading
          : filter.health == MediaHealthFilter.missing
          ? context.l10n.media_missing_empty
          : filter.isEmpty
          ? context.l10n.media_library_empty
          : context.l10n.media_library_emptyFiltered;
      return Center(child: Text(message));
    }
    void loadMore() =>
        ref.read(mediaLibraryNotifierProvider.notifier).loadMore();

    // The grouped modes load pages already ordered by group (issue #4268),
    // so each group here is one run of rows. The viewer pages through what
    // the gallery shows, so it gets the groups' order (issue #4146).
    final groups = switch (mode) {
      MediaLibraryViewMode.byDive => groupByDive(state.entries),
      MediaLibraryViewMode.timeline => groupByTimeline(state.entries),
      MediaLibraryViewMode.grid || MediaLibraryViewMode.map => null,
    };

    void handleTap(MediaLibraryEntry entry) {
      if (selection.isActive) {
        _selection.toggle(entry.item.id);
      } else {
        final shown = groups == null
            ? state.entries
            : [for (final group in groups) ...group.entries];
        _openViewer(context, shown, entry);
      }
    }

    final checkedIds = selection.checkedIds;

    // One size for all three thumbnail views, from the toolbar's slider or
    // the mouse wheel with Ctrl held (issue #3297).
    return MediaThumbnailWheelZoom(
      child: MediaThumbnailRowHeightBuilder(
        builder: (context, rowHeight) => switch (mode) {
          MediaLibraryViewMode.grid => MediaLibraryGrid(
            entries: state.entries,
            hasMore: state.hasMore,
            onLoadMore: loadMore,
            onTileTap: (entry, index) => handleTap(entry),
            rowHeight: rowHeight,
            selectedIds: checkedIds,
            isSelectionMode: selection.isActive,
          ),
          MediaLibraryViewMode.byDive ||
          MediaLibraryViewMode.timeline => MediaLibraryGroupedList(
            groups: groups!,
            hasMore: state.hasMore,
            onLoadMore: loadMore,
            onTileTap: handleTap,
            rowHeight: rowHeight,
            selectedIds: checkedIds,
            isSelectionMode: selection.isActive,
          ),
          // Returned above, before the grid's paged-state guards.
          MediaLibraryViewMode.map => const MediaMapContent(),
        },
      ),
    );
  }
}

/// The Library's [MediaLibraryToolbar] for [selection], wherever it is
/// shown: above the Library on a phone, in the page header's tab row at
/// desktop widths (#4777).
class MediaLibraryHeaderToolbar extends ConsumerWidget {
  const MediaLibraryHeaderToolbar({
    super.key,
    required this.selection,
    this.keyboardScope = false,
  });

  final SelectionController selection;

  /// Whether the toolbar brings its own [SelectableListScope]. A toolbar in
  /// the page header sits outside the Library's scope, so without one,
  /// Escape and Ctrl/Cmd-A would do nothing while focus is on one of its
  /// controls, such as the Select button just used to enter the mode.
  final bool keyboardScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEntries = ref.watch(
      mediaLibraryNotifierProvider.select((s) => s.entries.isNotEmpty),
    );
    final toolbar = ValueListenableBuilder<SelectionState>(
      valueListenable: selection,
      builder: (context, state, _) => MediaLibraryToolbar(
        selection: selection,
        // Filter and sort stay reachable inside the mode (narrow the list,
        // then Select All), but the control that opens a mode already open
        // would just be dead weight.
        canSelect: hasEntries && !state.isActive,
      ),
    );
    if (!keyboardScope) return toolbar;
    final entries = ref.watch(
      mediaLibraryNotifierProvider.select((s) => s.entries),
    );
    return SelectableListScope(
      controller: selection,
      selectableIds: [for (final e in entries) e.item.id],
      child: toolbar,
    );
  }
}
