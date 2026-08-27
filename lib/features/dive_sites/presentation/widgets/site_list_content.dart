import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_entry_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/dense_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Content widget for the site list, used in master-detail layout.
class SiteListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  /// Callback for when an item is tapped in map mode.
  /// When provided along with [isMapMode], this will be called instead of
  /// navigating to the detail page.
  final void Function(DiveSite site)? onItemTapForMap;

  /// Whether the list is being displayed alongside a map.
  /// When true and [onItemTapForMap] is provided, tapping an item will call
  /// [onItemTapForMap] instead of navigating to the detail page.
  final bool isMapMode;

  /// Whether map view is currently active (for toggle button highlight).
  final bool isMapViewActive;

  /// Callback when map view toggle is pressed.
  /// If null, the map icon will navigate to the map page (mobile behavior).
  final VoidCallback? onMapViewToggle;

  const SiteListContent({
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
  ConsumerState<SiteListContent> createState() => _SiteListContentState();
}

class _SiteListContentState extends ConsumerState<SiteListContent> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;

  /// Owns the bulk-selection state machine for this list.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;
  List<DiveSite>? _deletedSites;
  MergeSnapshot? _mergeSnapshot;

  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SiteListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
      } else {
        _scrollToSelectedItem();
      }
    }
  }

  void _scrollToSelectedItem() {
    if (widget.selectedId == null) return;

    final sitesAsync = ref.read(sortedSitesWithCountsProvider);
    sitesAsync.whenData((sites) {
      final index = sites.indexWhere((s) => s.site.id == widget.selectedId);
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || sites.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / sites.length;
          final targetOffset = (index * avgItemHeight) - (viewportHeight / 3);
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);

          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _lastScrolledToId = widget.selectedId;
        });
      }
    });
  }

  void _handleItemTap(DiveSite site) {
    if (_isSelectionMode) {
      _toggleSelection(site.id);
      return;
    }

    // In map mode, call onItemTapForMap instead of navigating
    if (widget.isMapMode && widget.onItemTapForMap != null) {
      // Also update the visual selection highlight
      if (widget.onItemSelected != null) {
        _selectionFromList = true;
        widget.onItemSelected!(site.id);
      }
      widget.onItemTapForMap!(site);
      return;
    }

    ref.read(highlightedSiteIdProvider.notifier).state = site.id;

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(site.id);
    } else {
      context.push('/sites/${site.id}');
    }
  }

  /// Enter selection mode implicitly, from a modifier-click, checking [id].
  ///
  /// Clearing the highlight keeps the detail pane from arguing with the bulk
  /// selection about what the row means: a row left highlighted but unchecked
  /// reads as selected while no bulk action would touch it.
  ///
  /// The Select controls route to [SelectionController.enterExplicit] directly
  /// -- they have no row to check -- so this helper only ever serves the
  /// implicit path, which since the removal of long-press entry means
  /// modifier-click alone.
  void _enterImplicitSelection(String id, {String? seedId}) {
    ref.read(highlightedSiteIdProvider.notifier).state = null;
    _selection.enterImplicit(id, seedId: seedId);
  }

  void _exitSelectionMode() => _selection.exit();

  void _toggleSelection(String id) => _selection.toggle(id);

  /// Select the contiguous span from the anchor site to [targetId].
  ///
  /// With no anchor yet, the highlighted row is the origin, matching Finder.
  void _selectRangeTo(String targetId, List<String> orderedIds) {
    _selection.extendTo(
      targetId,
      orderedIds,
      fallbackAnchorId: ref.read(highlightedSiteIdProvider),
    );
  }

  /// Cmd/Ctrl-click [id], carrying the highlighted site into the selection.
  ///
  /// Outside selection mode the highlighted row is what the user sees as
  /// selected, so a modifier-click adds to it rather than replacing it. A
  /// highlight that filtering has pushed out of [orderedIds] is ignored, so
  /// the count can never include a site that is not on screen.
  void _modifierTap(String id, List<String> orderedIds) {
    final highlighted = ref.read(highlightedSiteIdProvider);
    _enterImplicitSelection(
      id,
      seedId: highlighted != null && orderedIds.contains(highlighted)
          ? highlighted
          : null,
    );
  }

  /// One tap policy for every site row, in every view mode.
  ///
  /// A held modifier turns a tap into an implicit entry -- the one path that
  /// still evaporates at zero checked, since touch has no gesture entry left.
  /// Shift extends from the anchor, falling back to the highlighted row.
  void _handleRowTap(String id, List<SiteWithDiveCount> sites) {
    final orderedIds = sites.map((s) => s.site.id).toList();
    if (SelectableListScope.isShiftPressed()) {
      _selectRangeTo(id, orderedIds);
      return;
    }
    if (SelectableListScope.isModifierPressed()) {
      _modifierTap(id, orderedIds);
      return;
    }
    if (_isSelectionMode) {
      _selection.toggle(id);
      return;
    }
    final index = sites.indexWhere((s) => s.site.id == id);
    if (index < 0) return;
    _handleItemTap(sites[index].site);
  }

  Future<void> _startMerge() async {
    final selectedCount = _selectedIds.length;
    final result = await context.push<SiteMergeResult>(
      '/sites/merge',
      extra: _selectedIds.toList(),
    );

    if (!mounted || result == null) return;

    _mergeSnapshot = result.snapshot;
    final mergedId = result.survivorId;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    _selection.exit();

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(mergedId);
    }

    // Show undo snackbar if a snapshot was captured by the merge page
    if (_mergeSnapshot != null && mounted) {
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveSites_list_merge_snackbar(selectedCount),
          ),
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
          action: SnackBarAction(
            label: context.l10n.diveSites_list_merge_undo,
            onPressed: () async {
              if (_mergeSnapshot != null) {
                await ref
                    .read(siteListNotifierProvider.notifier)
                    .undoMerge(_mergeSnapshot!);
                _mergeSnapshot = null;
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.diveSites_list_merge_restored),
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

  Future<void> _confirmAndDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveSites_list_bulkDelete_title),
        content: Text(context.l10n.diveSites_list_bulkDelete_content(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.diveSites_list_bulkDelete_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.diveSites_list_bulkDelete_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final idsToDelete = _selectedIds.toList();
      _exitSelectionMode();

      final deletedSites = await ref
          .read(siteListNotifierProvider.notifier)
          .bulkDeleteSites(idsToDelete);

      _deletedSites = deletedSites;

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveSites_list_bulkDelete_snackbar(
                deletedSites.length,
              ),
            ),
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            action: SnackBarAction(
              label: context.l10n.diveSites_list_bulkDelete_undo,
              onPressed: () async {
                if (_deletedSites != null && _deletedSites!.isNotEmpty) {
                  await ref
                      .read(siteListNotifierProvider.notifier)
                      .restoreSites(_deletedSites!);
                  _deletedSites = null;
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.diveSites_list_bulkDelete_restored,
                        ),
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

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(siteSortProvider);

    showSortBottomSheet<SiteSortField>(
      context: context,
      title: context.l10n.diveSites_list_sort_title,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: SiteSortField.values,
      getFieldDisplayName: (field) => field.localizedName(context.l10n),
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(siteSortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sortedSitesWithCountsProvider);
    final filter = ref.watch(siteFilterProvider);
    final viewMode = ref.watch(siteListViewModeProvider);

    // Table mode uses a dedicated scaffold with column configuration support.
    if (viewMode == ListViewMode.table) {
      return _buildTableModeScaffold(context, sitesAsync, filter);
    }

    // Built inside the selection listener below so rows re-render as checks
    // change; computing it here would leave the list frozen mid-selection.
    Widget buildContent() {
      final listContent = sitesAsync.when(
        data: (sites) => sites.isEmpty
            ? _buildEmptyState(context, filter.hasActiveFilters)
            : _buildSiteList(context, ref, sites),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      );

      // Wrap list with active filters bar if filters are active
      return filter.hasActiveFilters
          ? Column(
              children: [
                _buildActiveFiltersBar(context, filter),
                Expanded(child: listContent),
              ],
            )
          : listContent;
    }

    final loadedSites = sitesAsync.valueOrNull ?? const <SiteWithDiveCount>[];
    final visibleIds = loadedSites.map((s) => s.site.id).toList();

    // Drop checked sites that fell out of the filtered list, so the count
    // always matches what is on screen. pruneTo is a no-op when nothing
    // changed, which keeps this off a rebuild loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    if (!widget.showAppBar) {
      return SelectableListScope(
        controller: _selection,
        selectableIds: visibleIds,
        child: ValueListenableBuilder<SelectionState>(
          valueListenable: _selection,
          builder: (context, selection, _) => Column(
            children: [
              selection.isActive
                  ? _buildCompactSelectionAppBar(context, loadedSites)
                  : _buildCompactAppBar(context),
              Expanded(child: buildContent()),
            ],
          ),
        ),
      );
    }

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? _buildSelectionAppBar(loadedSites)
              : AppBar(
                  title: FeatureAppBarTitle(
                    featureId: 'sites',
                    title: context.l10n.diveSites_list_appBar_title,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.map),
                      tooltip: context.l10n.diveSites_list_tooltip_mapView,
                      onPressed: () => context.push('/sites/map'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: context.l10n.diveSites_list_tooltip_searchSites,
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: SiteSearchDelegate(ref),
                        );
                      },
                    ),
                    IconButton(
                      icon: Badge(
                        isLabelVisible: filter.hasActiveFilters,
                        child: const Icon(Icons.filter_list),
                      ),
                      tooltip: context.l10n.diveSites_list_tooltip_filterSites,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => SiteFilterSheet(ref: ref),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: context.l10n.diveSites_list_tooltip_sort,
                      onPressed: () => _showSortSheet(context),
                    ),
                    // The only way into bulk actions: entry by long-press was removed,
                    // so nothing but this control opens selection mode on touch.
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'select') {
                          _selection.enterExplicit();
                        } else if (value == 'import') {
                          context.push('/sites/import');
                        } else if (value == 'fill_location_details') {
                          unawaited(showSiteLocationBackfillFlow(context, ref));
                        } else if (value.startsWith('view_')) {
                          final mode = ListViewMode.fromName(
                            value.replaceFirst('view_', ''),
                          );
                          ref.read(siteListViewModeProvider.notifier).state =
                              mode;
                        }
                      },
                      itemBuilder: (context) {
                        final currentMode = ref.read(siteListViewModeProvider);
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
                            value: 'select',
                            child: ListTile(
                              leading: const Icon(Icons.checklist),
                              title: Text(
                                context.l10n.diveSites_list_menu_select,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'import',
                            child: ListTile(
                              leading: const Icon(Icons.download),
                              title: Text(
                                context.l10n.diveSites_list_menu_import,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'fill_location_details',
                            child: ListTile(
                              leading: const Icon(Icons.travel_explore),
                              title: Text(
                                context
                                    .l10n
                                    .diveSites_list_menu_fillLocationDetails,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
          body: buildContent(),
          floatingActionButton: selection.isActive
              ? null
              : widget.floatingActionButton,
        ),
      ),
    );
  }

  /// Build the table content for table mode.
  ///
  /// When used inside [TableModeLayout], this provides only the table content
  /// (or selection app bar + table during multi-selection). The outer Scaffold,
  /// app bar, map, and column settings are all managed by [TableModeLayout].
  Widget _buildTableModeScaffold(
    BuildContext context,
    AsyncValue<List<SiteWithDiveCount>> sitesAsync,
    SiteFilterState filter,
  ) {
    final loadedSites = sitesAsync.valueOrNull ?? const <SiteWithDiveCount>[];
    final visibleIds = loadedSites.map((s) => s.site.id).toList();

    // Same pruning the list path does: drop checked sites that fell out of
    // the visible list, so the count always matches what is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // The scope carries Escape, Ctrl/Cmd-A and the Android back handling, and
    // the builder is what repaints the table as checks change -- the table is
    // built inside it for that reason.
    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) {
          final tableContent = _buildTableView(context, sitesAsync, filter);

          // Table mode has no app bar of its own, so the Select affordance
          // lives in the same slot the contextual bar takes, at the same
          // height -- the table does not shift as the mode opens.
          return Column(
            children: [
              if (selection.isActive)
                _buildCompactSelectionAppBar(context, loadedSites)
              else
                SelectionEntryBar(controller: _selection),
              Expanded(child: tableContent),
            ],
          );
        },
      ),
    );
  }

  /// Build the [EntityTableView] for site table mode.
  Widget _buildTableView(
    BuildContext context,
    AsyncValue<List<SiteWithDiveCount>> sitesAsync,
    SiteFilterState filter,
  ) {
    return sitesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (sites) {
        if (sites.isEmpty) {
          return _buildEmptyState(context, filter.hasActiveFilters);
        }
        final config = ref.watch(siteTableConfigProvider);
        final notifier = ref.read(siteTableConfigProvider.notifier);
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);

        return Column(
          children: [
            if (filter.hasActiveFilters)
              _buildActiveFiltersBar(context, filter),
            Expanded(
              child: EntityTableView<SiteWithCount, SiteField>(
                entities: sites,
                idExtractor: (s) => s.site.id,
                adapter: SiteFieldAdapter.instance,
                config: config,
                units: units,
                onSortFieldChanged: notifier.setSortField,
                onResizeColumn: notifier.resizeColumn,
                onEntityTapDown: (id) {
                  // Rows carry a double-tap, so onEntityTap only resolves
                  // after the double-tap timer -- long after this fires. A
                  // modified click is a selection gesture, not a navigation
                  // one: moving the highlight here would overwrite the very
                  // anchor the shift-click is about to extend from.
                  if (_isSelectionMode ||
                      SelectableListScope.isShiftPressed() ||
                      SelectableListScope.isModifierPressed()) {
                    return;
                  }
                  ref.read(highlightedSiteIdProvider.notifier).state = id;
                },
                onEntityTap: (id) {
                  // Table mode honours modifier and shift clicks too, so
                  // selection works the same way as in the list view modes.
                  final orderedIds = sites.map((s) => s.site.id).toList();
                  if (SelectableListScope.isShiftPressed()) {
                    _selectRangeTo(id, orderedIds);
                  } else if (SelectableListScope.isModifierPressed()) {
                    _modifierTap(id, orderedIds);
                  } else if (_isSelectionMode) {
                    _toggleSelection(id);
                  }
                },
                onEntityDoubleTap: (id) {
                  if (_isSelectionMode) return;
                  context.push('/sites/$id');
                },
                selectedIds: _selectedIds,
                isSelectionMode: _isSelectionMode,
                highlightedId: ref.watch(highlightedSiteIdProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactAppBar(BuildContext context) {
    final filter = ref.watch(siteFilterProvider);

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
          // Expanded, and no Spacer: the title must be the row's only flexible
          // child, or Spacer takes half the free space and the leftover half
          // lands after the last icon (see trip_list_content for the detail).
          // The pane is narrow and this bar carries up to seven controls, so
          // the title still has to yield; FeatureAppBarTitle ellipsises.
          Expanded(
            child: FeatureAppBarTitle(
              featureId: 'sites',
              title: context.l10n.diveSites_list_appBar_title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // Map toggle: shown in detailed/compact mode only.
          // In table mode, TableModeLayout manages the map toggle.
          if (widget.onMapViewToggle != null)
            MapViewToggleButton(
              isActive: widget.isMapViewActive,
              onToggle: widget.onMapViewToggle!,
            )
          else if (ref.watch(siteListViewModeProvider) != ListViewMode.table)
            IconButton(
              icon: const Icon(Icons.map, size: 20),
              tooltip: context.l10n.diveSites_list_tooltip_mapView,
              onPressed: () => context.push('/sites/map'),
            ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.diveSites_list_tooltip_searchSites,
            onPressed: () {
              showSearch(context: context, delegate: SiteSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: filter.hasActiveFilters,
              child: const Icon(Icons.filter_list, size: 20),
            ),
            tooltip: context.l10n.diveSites_list_tooltip_filterSites,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => SiteFilterSheet(ref: ref),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.diveSites_list_tooltip_sort,
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            key: const ValueKey('enter_selection'),
            icon: const Icon(Icons.checklist, size: 20),
            tooltip: context.l10n.common_selection_enterTooltip,
            onPressed: _selection.enterExplicit,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'select') {
                _selection.enterExplicit();
              } else if (value == 'import') {
                context.push('/sites/import');
              } else if (value == 'fill_location_details') {
                unawaited(showSiteLocationBackfillFlow(context, ref));
              } else if (value.startsWith('view_')) {
                final mode = ListViewMode.fromName(
                  value.replaceFirst('view_', ''),
                );
                ref.read(siteListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(siteListViewModeProvider);
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
                  value: 'select',
                  child: Text(context.l10n.diveSites_list_menu_select),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Text(context.l10n.diveSites_list_menu_import),
                ),
                PopupMenuItem(
                  value: 'fill_location_details',
                  child: ListTile(
                    leading: const Icon(Icons.travel_explore),
                    title: Text(
                      context.l10n.diveSites_list_menu_fillLocationDetails,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  /// Site-specific extras. Select-all, deselect-all and delete are supplied by
  /// SelectionAppBar, so they are deliberately absent here. Computed once and
  /// shared by both shells so the pane cannot drift from the full-width bar.
  List<BulkAction> _bulkActions(List<SiteWithDiveCount> sites) {
    return [
      BulkAction(
        id: 'merge',
        icon: Icons.merge_type,
        label: context.l10n.diveSites_list_selection_mergeTooltip,
        minCount: 2,
        onInvoke: _startMerge,
      ),
    ];
  }

  /// Contextual bar for the master pane, which is too narrow for every icon.
  Widget _buildCompactSelectionAppBar(
    BuildContext context,
    List<SiteWithDiveCount> sites,
  ) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: sites.map((s) => s.site.id).toList(),
      actions: _bulkActions(sites),
      shell: SelectionBarShell.pane,
      maxInlineActions: 1,
      onDelete: _confirmAndDelete,
    );
  }

  /// Contextual bar for the full-width standalone layout.
  SelectionAppBar _buildSelectionAppBar(List<SiteWithDiveCount> sites) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: sites.map((s) => s.site.id).toList(),
      actions: _bulkActions(sites),
      shell: SelectionBarShell.appBar,
      onDelete: _confirmAndDelete,
    );
  }

  Widget _buildSiteList(
    BuildContext context,
    WidgetRef ref,
    List<SiteWithDiveCount> sites,
  ) {
    final diversCount = ref
        .watch(allDiversProvider)
        .when(data: (d) => d.length, loading: () => 0, error: (_, _) => 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sortedSitesWithCountsProvider);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sites.length,
        itemBuilder: (context, index) {
          final siteData = sites[index];
          final site = siteData.site;
          final isSelected =
              widget.selectedId == site.id ||
              ref.watch(highlightedSiteIdProvider) == site.id;
          final isChecked = _selectedIds.contains(site.id);
          final showSharedBadge = site.isShared && diversCount >= 2;

          final viewMode = ref.watch(siteListViewModeProvider);
          final locationString = site.locationString.isNotEmpty
              ? site.locationString
              : null;
          return switch (viewMode) {
            ListViewMode.detailed => SiteListTile(
              entry: siteData,
              isSelectionMode: _isSelectionMode,
              isSelected: isSelected,
              isChecked: isChecked,
              showSharedBadge: showSharedBadge,
              onTap: () => _handleRowTap(site.id, sites),
            ),
            ListViewMode.compact => CompactSiteListTile(
              entry: siteData,
              isSelectionMode: _isSelectionMode,
              isSelected: isChecked,
              isHighlighted: !_isSelectionMode && isSelected,
              showSharedBadge: showSharedBadge,
              onTap: () => _handleRowTap(site.id, sites),
            ),
            ListViewMode.dense || ListViewMode.table => DenseSiteListTile(
              name: site.name,
              location: locationString,
              diveCount: siteData.diveCount,
              isSelectionMode: _isSelectionMode,
              isSelected: isChecked,
              isHighlighted: !_isSelectionMode && isSelected,
              showSharedBadge: showSharedBadge,
              onTap: () => _handleRowTap(site.id, sites),
            ),
          };
        },
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
              context.l10n.diveSites_list_emptyFiltered_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveSites_list_emptyFiltered_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(siteFilterProvider.notifier).state =
                    const SiteFilterState();
              },
              icon: const Icon(Icons.clear_all),
              label: Text(context.l10n.diveSites_list_emptyFiltered_clearAll),
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
            Icons.location_on,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.diveSites_list_empty_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveSites_list_empty_subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              if (ResponsiveBreakpoints.isMasterDetail(context)) {
                final routerState = GoRouterState.of(context);
                context.go('${routerState.uri.path}?mode=new');
              } else {
                context.push('/sites/new');
              }
            },
            icon: const Icon(Icons.add_location),
            label: Text(context.l10n.diveSites_list_empty_addFirstSite),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/sites/import'),
            icon: const Icon(Icons.download),
            label: Text(context.l10n.diveSites_list_empty_import),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar(BuildContext context, SiteFilterState filter) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Clear all button
            ActionChip(
              avatar: const Icon(Icons.clear_all, size: 18),
              label: Text(context.l10n.diveSites_list_activeFilter_clear),
              onPressed: () {
                ref.read(siteFilterProvider.notifier).state =
                    const SiteFilterState();
              },
            ),
            const SizedBox(width: 8),
            // Individual filter chips
            if (filter.country != null)
              _buildFilterChip(
                context.l10n.diveSites_list_activeFilter_country(
                  filter.country!,
                ),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearCountry: true),
              ),
            if (filter.region != null)
              _buildFilterChip(
                context.l10n.diveSites_list_activeFilter_region(filter.region!),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearRegion: true),
              ),
            if (filter.difficulty != null)
              _buildFilterChip(
                filter.difficulty!.displayName,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearDifficulty: true),
              ),
            if (filter.minDepth != null || filter.maxDepth != null)
              _buildFilterChip(
                _formatDepthRange(filter.minDepth, filter.maxDepth),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearMinDepth: true, clearMaxDepth: true),
              ),
            if (filter.minRating != null)
              _buildFilterChip(
                context.l10n.diveSites_filter_rating_starsPlus(
                  filter.minRating!.toInt(),
                ),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearMinRating: true),
              ),
            if (filter.hasCoordinates == true)
              _buildFilterChip(
                context.l10n.diveSites_list_activeFilter_hasCoordinates,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearHasCoordinates: true),
              ),
            if (filter.hasDives == true)
              _buildFilterChip(
                context.l10n.diveSites_list_activeFilter_hasDives,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearHasDives: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Chip label for the active depth filter.
  ///
  /// The bounds are held in meters, like every other stored depth, so they are
  /// converted for display. A two-ended range carries a single trailing symbol,
  /// so only the upper bound is formatted with one.
  String _formatDepthRange(double? min, double? max) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    if (min != null && max != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeBoth(
        units.convertDepth(min).toStringAsFixed(0),
        units.formatDepth(max, decimals: 0),
      );
    } else if (min != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeMin(
        units.formatDepth(min, decimals: 0),
      );
    } else if (max != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeMax(
        units.formatDepth(max, decimals: 0),
      );
    }
    return '';
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            context.l10n.diveSites_list_error_loadingSites(error.toString()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(sortedSitesWithCountsProvider),
            child: Text(context.l10n.diveSites_list_error_retry),
          ),
        ],
      ),
    );
  }
}

/// Search delegate for dive sites
class SiteSearchDelegate extends SearchDelegate<DiveSite?> {
  final WidgetRef ref;

  SiteSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search sites...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.l10n.diveSites_list_search_clearTooltip,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.diveSites_list_search_backTooltip,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveSites_list_search_emptyHint,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return DebouncedSearchResults<DiveSite>(
      query: query,
      watchProvider: (ref, q) => ref.watch(siteSearchProvider(q)),
      dataBuilder: (context, sites) {
        return ListView.builder(
          itemCount: sites.length,
          itemBuilder: (context, index) {
            final site = sites[index];
            return SiteListTile(
              entry: SiteWithDiveCount(site: site, diveCount: 0),
              onTap: () {
                close(context, site);
                context.push('/sites/${site.id}');
              },
            );
          },
        );
      },
      emptyBuilder: (context, query) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveSites_list_search_noResults(query),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error) {
        return Center(
          child: Text(
            context.l10n.diveSites_list_search_error(error.toString()),
          ),
        );
      },
    );
  }
}
