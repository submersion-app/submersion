import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/combine_dives_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_numbering_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Inclusive id span between the [anchor] and [target] indices in [dives].
/// Order-independent: a backward shift-click selects the same range.
List<String> rangeIds(List<DiveSummary> dives, int anchor, int target) {
  final lo = anchor < target ? anchor : target;
  final hi = anchor < target ? target : anchor;
  return [for (var i = lo; i <= hi; i++) dives[i].id];
}

/// True if [d]'s date falls within [r], inclusive of the end calendar day.
bool inDateRange(DiveSummary d, DateTimeRange r) {
  final day = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
  final start = DateTime(r.start.year, r.start.month, r.start.day);
  final end = DateTime(r.end.year, r.end.month, r.end.day);
  return !day.isBefore(start) && !day.isAfter(end);
}

/// Content widget for the dive list, used in master-detail layout.
///
/// This widget contains the core list functionality extracted from DiveListPage.
/// It can be used standalone (mobile) or as the master pane in a split view (desktop).
class DiveListContent extends ConsumerStatefulWidget {
  /// Callback when an item is selected. Used in master-detail mode.
  final void Function(String?)? onItemSelected;

  /// Currently selected item ID. Used to highlight the selected item.
  final String? selectedId;

  /// Whether to show the app bar. Set to false when used inside MasterDetailScaffold.
  final bool showAppBar;

  /// Optional floating action button to display when showAppBar is true.
  final Widget? floatingActionButton;

  /// Callback for when an item is tapped in map mode.
  /// When provided along with [isMapMode], this will be called instead of
  /// navigating to the detail page.
  final void Function(DiveSummary dive)? onItemTapForMap;

  /// Whether the list is being displayed alongside a map.
  /// When true and [onItemTapForMap] is provided, tapping an item will call
  /// [onItemTapForMap] instead of navigating to the detail page.
  final bool isMapMode;

  /// Whether map view is currently active (for toggle button highlight).
  final bool isMapViewActive;

  /// Callback when map view toggle is pressed.
  /// If null, the map icon will navigate to the map page (mobile behavior).
  final VoidCallback? onMapViewToggle;

  const DiveListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
    this.onItemTapForMap,
    this.isMapMode = false,
    this.isMapViewActive = false,
    this.onMapViewToggle,
  });

  @override
  ConsumerState<DiveListContent> createState() => _DiveListContentState();
}

class _DiveListContentState extends ConsumerState<DiveListContent> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<Dive>? _deletedDives;
  DiveMergeOutcome? _lastMergeOutcome;
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList =
      false; // Track if selection originated from list tap
  String? _anchorId; // anchor dive for shift-click range selection

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // If there's already a selected ID on init (e.g., from URL), scroll to it after build
    if (widget.selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
    // Initialize profile panel visibility from persisted setting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      ref.read(showProfilePanelProvider.notifier).state =
          settings.showProfilePanelInTableView;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Load next page when within 200px of bottom
    if (maxScroll - currentScroll <= 200) {
      ref.read(paginatedDiveListProvider.notifier).loadNextPage();
    }
  }

  @override
  void didUpdateWidget(DiveListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When selectedId changes and it's a new selection from outside the list, scroll to it
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      // Skip scrolling if the selection came from tapping within the list
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
      } else {
        _scrollToSelectedItem();
      }
    }
  }

  /// Scroll the list to show [overrideId], or the current [widget.selectedId]
  /// when omitted. An explicit id lets callers (e.g. the combine flow) scroll
  /// to a freshly created row without depending on when the URL selection
  /// propagates.
  void _scrollToSelectedItem([String? overrideId]) {
    final targetId = overrideId ?? widget.selectedId;
    if (targetId == null) return;

    // Get the current dive list from the paginated provider
    final divesAsync = ref.read(paginatedDiveListProvider);
    divesAsync.whenData((paginatedState) {
      final dives = paginatedState.dives;
      final index = dives.indexWhere((d) => d.id == targetId);
      if (index >= 0 && _scrollController.hasClients) {
        // Use post-frame callback to ensure layout is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || dives.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;

          // Calculate actual average item height from scroll geometry
          // Total content = viewport + max scroll extent
          // Subtract bottom padding (80px) from total to get actual list content height
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / dives.length;

          // Target position: put item 1/3 from top of viewport for comfortable viewing
          final targetOffset = (index * avgItemHeight) - (viewportHeight / 3);
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);

          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _lastScrolledToId = targetId;
        });
      }
    });
  }

  void _enterSelectionMode(String? initialId) {
    ref.read(highlightedDiveIdProvider.notifier).state = null;
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _anchorId = initialId;
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
      _anchorId = id;
    });
  }

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  /// Select the contiguous span from the anchor dive to [targetId].
  void _selectRangeTo(String targetId, List<DiveSummary> dives) {
    final targetIndex = dives.indexWhere((d) => d.id == targetId);
    if (targetIndex < 0) return;
    final anchorIndex = _anchorId == null
        ? targetIndex
        : dives.indexWhere((d) => d.id == _anchorId);
    final from = anchorIndex < 0 ? targetIndex : anchorIndex;
    setState(() {
      _selectedIds.addAll(rangeIds(dives, from, targetIndex));
      // Keep the anchor fixed across shift-clicks (only plain taps move it),
      // so consecutive shift-clicks extend from the original anchor rather
      // than walking it forward.
      _anchorId ??= targetId;
    });
  }

  /// Pick a date range and select every dive whose date falls inside it.
  Future<void> _selectByDateRange(List<DiveSummary> dives) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (range == null) return;
    setState(() {
      _selectedIds.addAll(
        dives.where((d) => inDateRange(d, range)).map((d) => d.id),
      );
    });
  }

  void _selectAll(List<DiveSummary> dives) {
    setState(() {
      _selectedIds.addAll(dives.map((d) => d.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _confirmAndDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveLog_bulkDelete_title),
        content: Text(context.l10n.diveLog_bulkDelete_confirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final idsToDelete = _selectedIds.toList();

      // If the currently selected item in master-detail is being deleted, clear it
      if (widget.selectedId != null &&
          idsToDelete.contains(widget.selectedId)) {
        widget.onItemSelected?.call(null);
      }

      _exitSelectionMode();

      final deletedDives = await ref
          .read(paginatedDiveListProvider.notifier)
          .bulkDeleteDives(idsToDelete);

      _deletedDives = deletedDives;

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_bulkDelete_snackbar(deletedDives.length),
            ),
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            action: SnackBarAction(
              label: context.l10n.diveLog_bulkDelete_undo,
              onPressed: () async {
                if (_deletedDives != null && _deletedDives!.isNotEmpty) {
                  await ref
                      .read(paginatedDiveListProvider.notifier)
                      .restoreDives(_deletedDives!);
                  _deletedDives = null;
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.diveLog_bulkDelete_restored),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    }
  }

  /// Show the combine-dives dialog for the current selection, then refresh
  /// the list/detail/stats providers and surface an undoable snackbar.
  ///
  /// Mirrors [_confirmAndDelete]'s messenger-capture and stale-detail
  /// clearing, but the snackbar action is #406-complete: `persist: false` is
  /// required whenever a SnackBar has an action, otherwise it defaults to
  /// persisting until explicitly dismissed.
  Future<void> _combineSelected() async {
    final ids = _selectedIds.toList();
    if (ids.length < 2) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final outcome = await showCombineDivesDialog(
      context: context,
      diveIds: ids,
    );
    if (outcome == null || !mounted) return;

    // Select the merged dive the same way a list tap does: highlight its row
    // (highlightedDiveIdProvider) AND open it in the detail pane
    // (onItemSelected). Scrolling happens after the list reload settles
    // below -- didUpdateWidget's scroll fires now, before the reloaded list
    // contains the brand-new merged row, so it would find nothing.
    _exitSelectionMode();
    ref.read(highlightedDiveIdProvider.notifier).state = outcome.mergedDive.id;
    widget.onItemSelected?.call(outcome.mergedDive.id);
    _lastMergeOutcome = outcome;
    _invalidateStatsAfterMerge();

    // Captured now (synchronously, while context is still valid) so the
    // Undo action's async onPressed never has to read context.l10n after an
    // await.
    final l10n = context.l10n;

    scaffoldMessenger.clearSnackBars();
    final snackBar = scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_combine_snackbar(ids.length)),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss and
        // allow closing without triggering Undo.
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.diveLog_bulkDelete_undo,
          onPressed: () async {
            final toUndo = _lastMergeOutcome;
            if (toUndo == null) return;
            _lastMergeOutcome = null;
            // Single attempt: on failure the snapshot may be partially
            // applied, so it is not restored to _lastMergeOutcome for retry
            // (#449 review F4).
            try {
              await ref.read(diveMergeServiceProvider).undo(toUndo.snapshot);
              _refreshAfterMerge();
              if (mounted) {
                // The merged dive no longer exists; clear it from the detail
                // pane and the row highlight if it is still selected.
                if (widget.selectedId == toUndo.mergedDive.id) {
                  widget.onItemSelected?.call(null);
                }
                if (ref.read(highlightedDiveIdProvider) ==
                    toUndo.mergedDive.id) {
                  ref.read(highlightedDiveIdProvider.notifier).state = null;
                }
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.diveLog_combine_undone),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (_) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.diveLog_combine_undoError),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        ),
      ),
    );

    // Drop the retained undo snapshot once the snackbar closes without Undo
    // (timeout/dismiss), so the copied profile/child rows aren't held for the
    // widget's lifetime. Guard on identity in case another merge replaced it.
    snackBar.closed.then((reason) {
      if (reason != SnackBarClosedReason.action &&
          identical(_lastMergeOutcome, outcome)) {
        _lastMergeOutcome = null;
      }
    });

    // Reload the list and wait for it to settle -- now including the new
    // merged dive -- then scroll that row into view. The reload must finish
    // first or the row won't exist yet to scroll to.
    await ref.read(paginatedDiveListProvider.notifier).refresh();
    if (mounted) _scrollToSelectedItem(outcome.mergedDive.id);
  }

  /// Invalidate the merge-derived providers other than the paginated list
  /// (which the combine path reloads explicitly so it can scroll afterwards).
  void _invalidateStatsAfterMerge() {
    ref.invalidate(diveListNotifierProvider);
    ref.invalidate(diveStatisticsProvider);
    ref.invalidate(diveNumberingInfoProvider);
  }

  void _refreshAfterMerge() {
    ref.invalidate(paginatedDiveListProvider);
    _invalidateStatsAfterMerge();
  }

  void _showExportDialog() {
    final count = _selectedIds.length;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    context.l10n.diveLog_bulkExport_title(count),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.common_action_close,
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(context.l10n.diveLog_bulkExport_pdf),
              subtitle: Text(context.l10n.diveLog_bulkExport_pdfDescription),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSelectedAs('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(context.l10n.diveLog_bulkExport_csv),
              subtitle: Text(context.l10n.diveLog_bulkExport_csvDescription),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSelectedAs('csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(context.l10n.diveLog_bulkExport_uddf),
              subtitle: Text(context.l10n.diveLog_bulkExport_uddfDescription),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSelectedAs('uddf');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelectedAs(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.diveLog_export_exporting),
          ],
        ),
      ),
    );

    try {
      final repository = ref.read(diveRepositoryProvider);
      final selectedDives = await repository.getDivesByIds(
        _selectedIds.toList(),
      );
      final exportService = ref.read(exportServiceProvider);

      switch (format) {
        case 'pdf':
          await exportService.exportDivesToPdf(selectedDives);
          break;
        case 'csv':
          await exportService.exportDivesToCsv(selectedDives);
          break;
        case 'uddf':
          final sites = selectedDives
              .where((d) => d.site != null)
              .map((d) => d.site!)
              .toSet()
              .toList();
          await exportService.exportDivesToUddf(selectedDives, sites: sites);
          break;
      }

      if (mounted) {
        Navigator.of(context).pop();
        _exitSelectionMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_bulkExport_success(selectedDives.length),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_bulkExport_failed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Open the bulk-edit form for the selected dives, then exit selection mode.
  Future<void> _openBulkEdit() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    await context.pushNamed('bulkEditDives', extra: ids);
    if (mounted) _exitSelectionMode();
  }

  /// Open the 3D comparison view for the selected dives, then exit selection.
  Future<void> _compareIn3d() async {
    final ids = _selectedIds.toList();
    if (ids.length < 2) return;
    await context.pushNamed('compareDives3d', extra: ids);
    if (mounted) _exitSelectionMode();
  }

  void _handleItemTap(DiveSummary dive) {
    if (_isSelectionMode) {
      _toggleSelection(dive.id);
      return;
    }

    // In map mode, call onItemTapForMap instead of navigating
    if (widget.isMapMode && widget.onItemTapForMap != null) {
      // Also update the visual selection highlight
      if (widget.onItemSelected != null) {
        _selectionFromList = true;
        widget.onItemSelected!(dive.id);
      }
      widget.onItemTapForMap!(dive);
      return;
    }

    // Highlight the dive in all modes.
    ref.read(highlightedDiveIdProvider.notifier).state = dive.id;

    // In card/list modes, also navigate (table mode uses double-tap instead).
    if (widget.onItemSelected != null) {
      // Master-detail mode: notify parent to open detail pane
      _selectionFromList = true;
      widget.onItemSelected!(dive.id);
    } else {
      // Standalone mode: navigate to detail page
      context.go('/dives/${dive.id}');
    }
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(diveSortProvider);

    showSortBottomSheet<DiveSortField>(
      context: context,
      title: context.l10n.diveLog_sort_title,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: DiveSortField.values,
      getFieldDisplayName: (field) => field.displayName,
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(diveSortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(diveListViewModeProvider);
    final filter = ref.watch(diveFilterProvider);

    // Table mode uses a completely different data path (full Dive objects
    // instead of DiveSummary) and renders a DiveTableView widget.
    if (viewMode == ListViewMode.table) {
      return _buildTableModeScaffold(context, filter);
    }

    final paginatedAsync = ref.watch(paginatedDiveListProvider);

    final content = paginatedAsync.when(
      data: (paginatedState) => paginatedState.dives.isEmpty
          ? _buildEmptyState(context, filter.hasActiveFilters)
          : _buildDiveList(context, paginatedState, filter.hasActiveFilters),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    final loadedDives = paginatedAsync.value?.dives ?? [];

    if (!widget.showAppBar) {
      // Used inside MasterDetailScaffold - no Scaffold wrapper
      return Column(
        children: [
          if (_isSelectionMode)
            _buildSelectionBar(loadedDives)
          else
            _buildCompactAppBar(context, filter),
          Expanded(child: content),
        ],
      );
    }

    // Standalone mode with full Scaffold
    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(loadedDives)
          : _buildAppBar(context, filter),
      body: content,
      floatingActionButton: _isSelectionMode
          ? null
          : widget.floatingActionButton,
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    DiveFilterState filter, {
    String? title,
    List<Widget> extraActions = const [],
  }) {
    return AppBar(
      title: Text(title ?? context.l10n.diveLog_listPage_title),
      actions: [
        ...extraActions,
        if (widget.onMapViewToggle != null)
          IconButton(
            icon: Icon(
              Icons.map,
              color: widget.isMapViewActive
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: context.l10n.diveLog_listPage_tooltip_mapView,
            onPressed: widget.onMapViewToggle,
          )
        else
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: context.l10n.diveLog_listPage_tooltip_mapView,
            onPressed: () => context.push('/dives/activity'),
          ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: context.l10n.diveLog_listPage_tooltip_searchDives,
          onPressed: () {
            showSearch(context: context, delegate: DiveSearchDelegate(ref));
          },
        ),
        IconButton(
          icon: Badge(
            isLabelVisible: filter.hasActiveFilters,
            child: const Icon(Icons.filter_list),
          ),
          tooltip: context.l10n.diveLog_listPage_tooltip_filterDives,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => DiveFilterSheet(ref: ref),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: context.l10n.diveLog_listPage_tooltip_sort,
          onPressed: () => _showSortSheet(context),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'numbering') {
              showDiveNumberingDialog(context);
            } else if (value == 'advanced_search') {
              context.go('/dives/search');
            } else if (value == 'match_sites') {
              context.push('/dives/match-sites');
            } else if (value.startsWith('view_')) {
              final mode = ListViewMode.fromName(
                value.replaceFirst('view_', ''),
              );
              ref.read(diveListViewModeProvider.notifier).state = mode;
            }
          },
          itemBuilder: (context) {
            final currentMode = ref.read(diveListViewModeProvider);
            return [
              ...ListViewModeToggle.menuItems(
                context,
                currentMode: currentMode,
                modes: const [
                  ListViewMode.detailed,
                  ListViewMode.compact,
                  ListViewMode.table,
                ],
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'advanced_search',
                child: Row(
                  children: [
                    const Icon(Icons.manage_search),
                    const SizedBox(width: 12),
                    Text(context.l10n.diveLog_listPage_menuAdvancedSearch),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'numbering',
                child: Row(
                  children: [
                    const Icon(Icons.format_list_numbered),
                    const SizedBox(width: 12),
                    Text(context.l10n.diveLog_listPage_menuDiveNumbering),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'match_sites',
                child: Row(
                  children: [
                    const Icon(Icons.add_location_alt_outlined),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(context.l10n.diveLog_listPage_menuMatchSites),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  /// Compact app bar for master pane in split view
  Widget _buildCompactAppBar(BuildContext context, DiveFilterState filter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.diveLog_listPage_compactTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // Map toggle: shown in detailed/compact mode only.
          // In table mode, TableModeLayout manages the map toggle.
          if (widget.onMapViewToggle != null)
            MapViewToggleButton(
              isActive: widget.isMapViewActive,
              onToggle: widget.onMapViewToggle!,
            )
          else if (ref.read(diveListViewModeProvider) != ListViewMode.table)
            IconButton(
              icon: const Icon(Icons.map, size: 20),
              tooltip: context.l10n.diveLog_listPage_tooltip_mapView,
              onPressed: () => context.push('/dives/activity'),
            ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.diveLog_listPage_tooltip_searchDives,
            onPressed: () {
              showSearch(context: context, delegate: DiveSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: filter.hasActiveFilters,
              child: const Icon(Icons.filter_list, size: 20),
            ),
            tooltip: context.l10n.diveLog_listPage_tooltip_filterDives,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => DiveFilterSheet(ref: ref),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.diveLog_listPage_tooltip_sort,
            onPressed: () => _showSortSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'numbering') {
                showDiveNumberingDialog(context);
              } else if (value == 'advanced_search') {
                context.go('/dives/search');
              } else if (value == 'match_sites') {
                context.push('/dives/match-sites');
              } else if (value.startsWith('view_')) {
                final mode = ListViewMode.fromName(
                  value.replaceFirst('view_', ''),
                );
                ref.read(diveListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(diveListViewModeProvider);
              return [
                ...ListViewModeToggle.menuItems(
                  context,
                  currentMode: currentMode,
                  modes: const [
                    ListViewMode.detailed,
                    ListViewMode.compact,
                    ListViewMode.table,
                  ],
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'advanced_search',
                  child: Row(
                    children: [
                      const Icon(Icons.manage_search, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.diveLog_listPage_menuAdvancedSearch),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'numbering',
                  child: Row(
                    children: [
                      const Icon(Icons.format_list_numbered, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.diveLog_listPage_menuDiveNumbering),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'match_sites',
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt_outlined, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          context.l10n.diveLog_listPage_menuMatchSites,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  AppBar _buildSelectionAppBar(List<DiveSummary> dives) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.diveLog_selection_tooltip_exit,
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        context.l10n.diveLog_selection_countSelected(_selectedIds.length),
      ),
      actions: [
        if (_selectedIds.length < dives.length)
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: context.l10n.diveLog_selection_tooltip_selectAll,
            onPressed: () => _selectAll(dives),
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: context.l10n.diveLog_selection_tooltip_deselectAll,
            onPressed: _deselectAll,
          ),
        IconButton(
          icon: const Icon(Icons.date_range),
          tooltip: context.l10n.diveLog_selection_tooltip_selectDateRange,
          onPressed: () => _selectByDateRange(dives),
        ),
        if (_selectedIds.length >= 2)
          IconButton(
            icon: const Icon(Icons.call_merge),
            tooltip: context.l10n.diveLog_selection_tooltip_combine,
            onPressed: _combineSelected,
          ),
        if (_selectedIds.length >= 2)
          IconButton(
            icon: const Icon(Icons.view_in_ar),
            tooltip: context.l10n.diveLog_selection_tooltip_compare3d,
            onPressed: _compareIn3d,
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: context.l10n.diveLog_selection_tooltip_export,
            onPressed: _showExportDialog,
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.diveLog_selection_tooltip_edit,
            onPressed: _openBulkEdit,
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: context.l10n.diveLog_selection_tooltip_delete,
            onPressed: _confirmAndDelete,
          ),
      ],
    );
  }

  /// Selection bar for master pane in split view
  Widget _buildSelectionBar(List<DiveSummary> dives) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: context.l10n.diveLog_selection_tooltip_exit,
            onPressed: _exitSelectionMode,
          ),
          Text(
            context.l10n.diveLog_selection_countSelected(_selectedIds.length),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_selectedIds.length < dives.length)
            IconButton(
              icon: const Icon(Icons.select_all, size: 20),
              tooltip: context.l10n.diveLog_selection_tooltip_selectAll,
              onPressed: () => _selectAll(dives),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.deselect, size: 20),
              tooltip: context.l10n.diveLog_selection_tooltip_deselectAll,
              onPressed: _deselectAll,
            ),
          IconButton(
            icon: const Icon(Icons.date_range, size: 20),
            tooltip: context.l10n.diveLog_selection_tooltip_selectDateRange,
            onPressed: () => _selectByDateRange(dives),
          ),
          if (_selectedIds.length >= 2)
            IconButton(
              icon: const Icon(Icons.call_merge, size: 20),
              tooltip: context.l10n.diveLog_selection_tooltip_combine,
              onPressed: _combineSelected,
            ),
          if (_selectedIds.length >= 2)
            IconButton(
              icon: const Icon(Icons.view_in_ar, size: 20),
              tooltip: context.l10n.diveLog_selection_tooltip_compare3d,
              onPressed: _compareIn3d,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.upload, size: 20),
              tooltip: context.l10n.diveLog_selection_tooltip_export,
              onPressed: _showExportDialog,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: context.l10n.diveLog_selection_tooltip_edit,
              onPressed: _openBulkEdit,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: context.l10n.diveLog_selection_tooltip_delete,
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
    );
  }

  /// Build the layout for table mode content.
  ///
  /// Table mode uses the [allDivesForTableProvider] (full Dive objects with
  /// filters and sorting applied) instead of the paginated DiveSummary list.
  ///
  /// When used inside [TableModeLayout] (showAppBar: false), this provides
  /// only the compact app bar (filter chips, sort controls) and the table.
  /// The outer Scaffold, profile panel, map, and column settings are all
  /// managed by [TableModeLayout].
  Widget _buildTableModeScaffold(BuildContext context, DiveFilterState filter) {
    final content = _buildTableView(context, filter);

    if (_isSelectionMode) {
      return Column(
        children: [
          _buildSelectionBar(const []),
          Expanded(child: content),
        ],
      );
    }
    return content;
  }

  /// Build the DiveTableView widget from the full-Dive provider.
  Widget _buildTableView(BuildContext context, DiveFilterState filter) {
    final divesAsync = ref.watch(allDivesForTableProvider);

    return divesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (dives) {
        if (dives.isEmpty) {
          return _buildEmptyState(context, filter.hasActiveFilters);
        }
        return Column(
          children: [
            if (filter.hasActiveFilters) _buildActiveFiltersBar(context),
            Expanded(
              child: DiveTableView(
                dives: dives,
                onDiveTapDown: (id) {
                  if (!_isSelectionMode) {
                    ref.read(highlightedDiveIdProvider.notifier).state = id;
                  }
                },
                onDiveTap: (id) {
                  if (_isSelectionMode) {
                    _toggleSelection(id);
                  }
                },
                onDiveDoubleTap: (id) {
                  if (_isSelectionMode) return;
                  context.push('/dives/$id');
                },
                onDiveLongPress: _isSelectionMode
                    ? null
                    : (id) => _enterSelectionMode(id),
                selectedIds: _selectedIds,
                isSelectionMode: _isSelectionMode,
                highlightedId: ref.watch(highlightedDiveIdProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiveList(
    BuildContext context,
    PaginatedDiveListState paginatedState,
    bool hasActiveFilters,
  ) {
    final dives = paginatedState.dives;

    // Calculate value range for card coloring based on active attribute
    final settings = ref.read(settingsProvider);
    final colorAttribute = settings.cardColorAttribute;
    final colorValues = dives
        .map((d) => getCardColorValue(d, colorAttribute))
        .whereType<double>();
    final minValue = colorValues.isNotEmpty
        ? colorValues.reduce((a, b) => a < b ? a : b)
        : null;
    final maxValue = colorValues.isNotEmpty
        ? colorValues.reduce((a, b) => a > b ? a : b)
        : null;
    final gradientColors = resolveGradientColors(
      presetName: settings.cardColorGradientPreset,
      customStart: settings.cardColorGradientStart,
      customEnd: settings.cardColorGradientEnd,
    );

    // Check if detailed mode needs full Dive objects for non-summary fields
    final detailedConfig = ref.watch(detailedCardConfigProvider);
    final needsFullDive =
        detailedConfig.extraFields.any(
          (f) => !DiveField.summaryFields.contains(f),
        ) ||
        detailedConfig.slots.any(
          (s) => !DiveField.summaryFields.contains(s.field),
        );
    final Map<String, Dive> fullDiveLookup;
    if (needsFullDive) {
      final divesAsync = ref.watch(allDivesForTableProvider);
      final fullDives = divesAsync.whenOrNull(data: (d) => d) ?? [];
      fullDiveLookup = {for (final d in fullDives) d.id: d};
    } else {
      fullDiveLookup = {};
    }

    // +1 for loading indicator when more pages are available
    final itemCount =
        dives.length +
        (paginatedState.hasMore || paginatedState.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => ref.read(paginatedDiveListProvider.notifier).refresh(),
      child: Column(
        children: [
          if (hasActiveFilters) _buildActiveFiltersBar(context),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // Loading indicator at the end
                if (index >= dives.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final dive = dives[index];
                final isSelected = _selectedIds.contains(dive.id);
                final isMasterSelected = widget.selectedId == dive.id;
                final isHighlighted =
                    ref.watch(highlightedDiveIdProvider) == dive.id;
                // Shared renderer: honours the active view mode and card
                // config, and keeps the home Recent dives list in sync (#506).
                return DiveListItem(
                  summary: dive,
                  fullDive: fullDiveLookup[dive.id],
                  diveNumber: dive.diveNumber ?? index + 1,
                  colorValue: getCardColorValue(dive, colorAttribute),
                  minValueInList: minValue,
                  maxValueInList: maxValue,
                  gradientStartColor: gradientColors.start,
                  gradientEndColor: gradientColors.end,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected,
                  isHighlighted: isMasterSelected || isHighlighted,
                  onTap: () {
                    if (_isSelectionMode && _isShiftPressed()) {
                      _selectRangeTo(dive.id, dives);
                    } else {
                      _handleItemTap(dive);
                    }
                  },
                  onLongPress: _isSelectionMode
                      ? null
                      : () => _enterSelectionMode(dive.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar(BuildContext context) {
    final filter = ref.watch(diveFilterProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final chips = <Widget>[];

    if (filter.startDate != null || filter.endDate != null) {
      String dateText;
      if (filter.startDate != null && filter.endDate != null) {
        dateText =
            '${units.formatMonthDay(filter.startDate)} - ${units.formatMonthDay(filter.endDate)}';
      } else if (filter.startDate != null) {
        dateText = context.l10n.diveLog_filterChip_from(
          units.formatMonthDay(filter.startDate),
        );
      } else {
        dateText = context.l10n.diveLog_filterChip_until(
          units.formatMonthDay(filter.endDate),
        );
      }
      chips.add(
        _buildFilterChip(context, dateText, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearStartDate: true,
            clearEndDate: true,
          );
        }),
      );
    }

    if (filter.diveTypeId != null) {
      final diveTypeName =
          ref.watch(diveTypeProvider(filter.diveTypeId!)).value?.name ??
          filter.diveTypeId!;
      chips.add(
        _buildFilterChip(context, diveTypeName, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearDiveType: true,
          );
        }),
      );
    }

    if (filter.siteId != null) {
      final siteName =
          ref.watch(siteProvider(filter.siteId!)).value?.name ?? 'Site';
      chips.add(
        _buildFilterChip(context, siteName, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearSiteId: true,
          );
        }),
      );
    }

    if (filter.tripId != null) {
      final tripName =
          ref.watch(tripByIdProvider(filter.tripId!)).value?.name ?? 'Trip';
      chips.add(
        _buildFilterChip(context, tripName, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearTripId: true,
          );
        }),
      );
    }

    if (filter.diveCenterId != null) {
      final centerName =
          ref.watch(diveCenterByIdProvider(filter.diveCenterId!)).value?.name ??
          'Dive Center';
      chips.add(
        _buildFilterChip(context, centerName, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearDiveCenterId: true,
          );
        }),
      );
    }

    if (filter.equipmentIds.isNotEmpty) {
      final label = filter.equipmentIds.length == 1
          ? (ref
                    .watch(equipmentItemProvider(filter.equipmentIds.first))
                    .value
                    ?.name ??
                'Equipment')
          : '${filter.equipmentIds.length} Equipment';
      chips.add(
        _buildFilterChip(context, label, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            equipmentIds: [],
          );
        }),
      );
    }

    if (filter.minDepth != null || filter.maxDepth != null) {
      String depthText;
      if (filter.minDepth != null && filter.maxDepth != null) {
        depthText = '${filter.minDepth!.toInt()}-${filter.maxDepth!.toInt()}m';
      } else if (filter.minDepth != null) {
        depthText = '>${filter.minDepth!.toInt()}m';
      } else {
        depthText = '<${filter.maxDepth!.toInt()}m';
      }
      chips.add(
        _buildFilterChip(context, depthText, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearMinDepth: true,
            clearMaxDepth: true,
          );
        }),
      );
    }

    if (filter.favoritesOnly == true) {
      chips.add(
        _buildFilterChip(
          context,
          context.l10n.diveLog_filterChip_favorites,
          () {
            ref.read(diveFilterProvider.notifier).state = filter.copyWith(
              clearFavoritesOnly: true,
            );
          },
        ),
      );
    }

    if (filter.tagIds.isNotEmpty) {
      final tagCount = filter.tagIds.length;
      chips.add(
        _buildFilterChip(
          context,
          '$tagCount tag${tagCount > 1 ? 's' : ''}',
          () {
            ref.read(diveFilterProvider.notifier).state = filter.copyWith(
              clearTagIds: true,
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(diveFilterProvider.notifier).state =
                  const DiveFilterState();
            },
            child: Text(context.l10n.diveLog_filterChip_clearAll),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    VoidCallback onRemove,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasActiveFilters) {
    if (hasActiveFilters) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_emptyFiltered_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveLog_emptyFiltered_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(diveFilterProvider.notifier).state =
                    const DiveFilterState();
              },
              icon: const Icon(Icons.clear_all),
              label: Text(context.l10n.diveLog_emptyFiltered_clearFilters),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.waves,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.diveLog_empty_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveLog_empty_subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => showAddDiveBottomSheet(
              context: context,
              onLogManually: () {
                if (ResponsiveBreakpoints.isMasterDetail(context)) {
                  final routerState = GoRouterState.of(context);
                  context.go('${routerState.uri.path}?mode=new');
                } else {
                  context.push('/dives/new');
                }
              },
            ),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.diveLog_empty_logFirstDive),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_error_loadingDives,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(paginatedDiveListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.diveLog_error_retry),
            ),
          ],
        ),
      ),
    );
  }
}
