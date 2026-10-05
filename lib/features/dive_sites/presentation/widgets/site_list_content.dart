import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_group_by_selector.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_active_filters_bar.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/dense_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_delete_usage.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_list_count_provider.dart';

/// Content widget for the site list, used in master-detail layout.
final _log = LoggerService.forClass(SiteListContent);

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

  /// Drives bulk selection from outside the list when set.
  ///
  /// In table mode the page's header carries the overflow menu, "Select
  /// items" among it, so the page has to reach the same controller the rows
  /// use. Left null, the list owns its own.
  final SelectionController? selectionController;

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
    this.selectionController,
  });

  @override
  ConsumerState<SiteListContent> createState() => _SiteListContentState();
}

class _SiteListContentState extends ConsumerState<SiteListContent> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;

  /// The bulk-selection state machine for this list: the page's when it
  /// passes one, otherwise this list's own.
  late final SelectionController _selection = _adoptSelection();

  /// Only a controller this list created is this list's to dispose. Set in
  /// the same step that picks the controller, so the two cannot disagree.
  bool _ownsSelection = false;

  SelectionController _adoptSelection() {
    final external = widget.selectionController;
    _ownsSelection = external == null;
    return external ?? SelectionController();
  }

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;
  ({List<DiveSite> sites, SiteLinks links})? _deletedSites;

  /// Another profile's shared sites the last bulk delete hid instead of
  /// deleting (issue #2594), for its Undo.
  List<String> _hiddenSiteIds = const [];
  MergeSnapshot? _mergeSnapshot;

  /// Countries closed by hand while a filter is active; reset when the
  /// filter changes, since a new filter opens every match again.
  Set<String> _filterCollapsed = const {};

  /// The grouping of the last site list seen, reused while that list is the
  /// same instance, so a rebuild that changes only checks or expansion (each
  /// selection tap) does not re-fold every site's country and region.
  List<SiteWithDiveCount>? _groupedSites;
  List<SiteCountryGroup<SiteWithDiveCount>> _groups = const [];

  List<SiteCountryGroup<SiteWithDiveCount>> _groupsFor(
    List<SiteWithDiveCount> sites,
  ) {
    if (!identical(sites, _groupedSites)) {
      _groupedSites = sites;
      _groups = groupSitesByLocation(sites, (s) => s.site);
    }
    return _groups;
  }

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
    if (_ownsSelection) _selection.dispose();
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
      // A site selected from outside the list (map, a new site, a deep link)
      // can sit in a country the diver collapsed. Open it first, after this
      // frame since a provider cannot change mid-build, then scroll once the
      // list has rebuilt with it open.
      final hiddenCountry = _collapsedCountryOfSelected(sites);
      if (hiddenCountry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final stored = ref.read(siteListExpandedCountriesProvider);
          if (stored != null) {
            ref.read(siteListExpandedCountriesProvider.notifier).state = {
              ...stored,
              hiddenCountry,
            };
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToSelectedItem();
          });
        });
        return;
      }
      // Grouped, the selected site's offset is its row among the visible
      // headers and sites, not its position in the flat list.
      final rows = _groupedView(sites, listen: false)?.rows;
      final index = rows == null
          ? sites.indexWhere((s) => s.site.id == widget.selectedId)
          : rows.indexWhere(
              (row) =>
                  row is SiteRow<SiteWithDiveCount> &&
                  row.item.site.id == widget.selectedId,
            );
      final rowCount = rows?.length ?? sites.length;
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || sites.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / rowCount;
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

  /// The checked sites with their owners, read before a merge or bulk
  /// delete decides what it may do to each (issue #2594). A failed read
  /// logs, tells the diver to try again and returns null, so the action
  /// stops before its dialog rather than failing unseen.
  Future<List<DiveSite>?> _readSelectedSites(List<String> ids) async {
    try {
      return await ref.read(siteRepositoryProvider).getSitesByIds(ids);
    } catch (e, stackTrace) {
      _log.error(
        'Could not read the selected sites',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.common_error_tryAgain)),
        );
      }
      return null;
    }
  }

  Future<BulkActionOutcome> _startMerge() async {
    final selectedCount = _selectedIds.length;
    // A merge destroys every site but the first (issue #2594): another
    // profile's shared site may only be the survivor, so at most one fits.
    final sharing = await readSharingContext(ref, context);
    if (sharing == null) return BulkActionOutcome.failed;
    final selected = await _readSelectedSites(_selectedIds.toList());
    if (selected == null) return BulkActionOutcome.failed;
    final notOwned = [
      for (final s in selected)
        if (!canDestroySharedItem(
          ownerId: s.diverId,
          activeDiverId: sharing.activeDiverId,
        ))
          s.id,
    ];
    if (!mounted) return BulkActionOutcome.cancelled;
    if (notOwned.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sharedItems_mergeTooManyShared)),
      );
      return BulkActionOutcome.cancelled;
    }
    final orderedIds = [
      ...notOwned,
      for (final id in _selectedIds)
        if (!notOwned.contains(id)) id,
    ];
    final result = await context.push<SiteMergeResult>(
      '/sites/merge',
      extra: orderedIds,
    );

    if (result == null) return BulkActionOutcome.cancelled;
    if (!mounted) return BulkActionOutcome.completed;

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
    return BulkActionOutcome.completed;
  }

  Future<BulkActionOutcome> _confirmAndDelete() async {
    // One snapshot for the dialog and the delete: the selection can change
    // while the usage is read, and the delete must remove exactly the sites
    // the dialog described.
    final idsToDelete = _selectedIds.toList();
    // Another profile's shared sites are hidden, not deleted, and the
    // owner's shared ones are named as going for everyone (issue #2594).
    final sharing = await readSharingContext(ref, context);
    if (sharing == null) return BulkActionOutcome.failed;
    final selectedSites = await _readSelectedSites(idsToDelete);
    if (selectedSites == null) return BulkActionOutcome.failed;
    final split = splitForBulkDelete(
      selectedSites,
      ownerOf: (s) => s.diverId,
      isSharedOf: (s) => s.isShared,
      activeDiverId: sharing.activeDiverId,
    );
    final destroyIds = [for (final s in split.destroy) s.id];
    final hideIds = [for (final s in split.hide) s.id];
    final deleteCount = destroyIds.length;
    final hideCount = hideIds.length;
    final sharedDeleteCount = sharing.diverCount >= 2
        ? split.destroy.where((s) => s.isShared).length
        : 0;
    final usage = deleteCount > 0
        ? await readSiteDeleteUsage(ref, destroyIds)
        : const SiteUsage();
    if (!mounted || deleteCount + hideCount == 0) {
      return BulkActionOutcome.cancelled;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          deleteCount > 0
              ? context.l10n.diveSites_list_bulkDelete_title
              : context.l10n.sharedItems_bulkRemoveTitle(hideCount),
        ),
        content: Text(
          [
            ...bulkDeleteLines(
              context.l10n,
              SharedItemKind.site,
              deleteCount: deleteCount,
              hideCount: hideCount,
              sharedDeleteCount: sharedDeleteCount,
              // The site list's own line below states it, with its Undo.
              includeDeleteCount: false,
            ),
            if (deleteCount > 0)
              withSiteDeleteUsage(
                context.l10n,
                context.l10n.diveSites_list_bulkDelete_content(deleteCount),
                usage,
              ),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.diveSites_list_bulkDelete_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: deleteCount > 0
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(
              deleteCount > 0
                  ? context.l10n.diveSites_list_bulkDelete_confirm
                  : context.l10n.common_action_remove,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final l10n = context.l10n;
      final notifier = ref.read(siteListNotifierProvider.notifier);
      _exitSelectionMode();

      final deleted = deleteCount > 0
          ? await notifier.bulkDeleteSites(destroyIds)
          : null;
      // Null when the hide failed: the summary says so beside the deletes.
      final hidden = hideCount > 0
          ? await tryHideChange(() => notifier.hideSites(hideIds))
          : 0;

      _deletedSites = deleted;
      // Even after a failed hide: it may have been written before the
      // refresh failed, and an unhide of one not hidden does nothing.
      _hiddenSiteIds = hideIds;

      final summary = [
        if (deleted != null && deleted.sites.isNotEmpty)
          l10n.diveSites_list_bulkDelete_snackbar(deleted.sites.length),
        if (hidden case final n? when n > 0)
          l10n.sharedItems_bulkHiddenSnackbar(n),
        if (hidden == null) l10n.common_error_tryAgain,
      ];
      // Only a failed hide to report: nothing for Undo to take back.
      if (hidden == null && (deleted?.sites.isEmpty ?? true)) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.common_error_tryAgain)),
        );
        return BulkActionOutcome.completed;
      }
      // Takes back what the bulk delete did, clearing each half once it is
      // back. Anything left says so, even once the list has closed, and
      // offers Undo again for the rest (issue #2677).
      Future<void> undo() async {
        final toRestore = _deletedSites;
        if (toRestore == null || toRestore.sites.isEmpty) {
          _deletedSites = null;
        } else {
          try {
            await notifier.restoreSites(
              toRestore.sites,
              links: toRestore.links,
            );
            _deletedSites = null;
          } catch (e, stackTrace) {
            _log.error(
              'Could not restore the deleted sites',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
        final toUnhide = _hiddenSiteIds;
        if (toUnhide.isEmpty ||
            await tryHideChange(
                  () => notifier.unhideSites(toUnhide).then((_) => true),
                ) ==
                true) {
          _hiddenSiteIds = const [];
        }
        if (_deletedSites != null || _hiddenSiteIds.isNotEmpty) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.common_error_tryAgain),
              action: SnackBarAction(
                label: l10n.diveSites_list_bulkDelete_undo,
                onPressed: undo,
              ),
            ),
          );
        } else if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.diveSites_list_bulkDelete_restored),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Nothing done (every action refused): no empty snackbar. A failure
      // says so even once the list has closed.
      if ((mounted || hidden == null) && summary.isNotEmpty) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(summary.join(' · ')),
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            action: SnackBarAction(
              label: l10n.diveSites_list_bulkDelete_undo,
              onPressed: undo,
            ),
          ),
        );
      }
      return BulkActionOutcome.completed;
    }
    return BulkActionOutcome.cancelled;
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
      // Table mode keeps a flat grid; headers would cut across its columns.
      footer: ref.read(siteListViewModeProvider) == ListViewMode.table
          ? null
          : const SiteGroupBySelector(),
    );
  }

  /// The grouped list for [sites], or null when the list is not grouped.
  /// [listen] is false outside build, where watching is not allowed.
  _GroupedSites? _groupedView(
    List<SiteWithDiveCount> sites, {
    bool listen = true,
  }) {
    final groupBy = listen
        ? ref.watch(siteGroupByProvider)
        : ref.read(siteGroupByProvider);
    if (groupBy != SiteGroupBy.location) return null;
    final groups = _groupsFor(sites);
    final expanded = _groupedExpansion(groups, sites, listen: listen);
    return (
      groups: groups,
      expanded: expanded,
      rows: flattenSiteGroups(groups, expanded: expanded),
    );
  }

  /// The open countries for [groups]: everything while a filter narrows the
  /// list, else the diver's own choice, seeded with the detail pane's site.
  Set<String> _groupedExpansion(
    List<SiteCountryGroup<SiteWithDiveCount>> groups,
    List<SiteWithDiveCount> sites, {
    bool listen = true,
  }) {
    final filter = listen
        ? ref.watch(siteFilterProvider)
        : ref.read(siteFilterProvider);
    if (filter.hasActiveFilters) {
      return allCountryKeys(groups).difference(_filterCollapsed);
    }
    final stored = listen
        ? ref.watch(siteListExpandedCountriesProvider)
        : ref.read(siteListExpandedCountriesProvider);
    if (stored != null) return stored;
    final selected = sites
        .where((s) => s.site.id == widget.selectedId)
        .firstOrNull;
    return initialExpandedCountries(groups, selected: selected?.site);
  }

  /// The country key of the selected site when the grouped list keeps it
  /// collapsed in the diver's stored expansion, else null. Before the first
  /// toggle there is no stored set and the initial expansion already opens
  /// the selected site's country; a filter opens every country by itself.
  String? _collapsedCountryOfSelected(List<SiteWithDiveCount> sites) {
    if (ref.read(siteGroupByProvider) != SiteGroupBy.location) return null;
    if (ref.read(siteFilterProvider).hasActiveFilters) return null;
    final stored = ref.read(siteListExpandedCountriesProvider);
    if (stored == null) return null;
    final selected = sites
        .where((s) => s.site.id == widget.selectedId)
        .firstOrNull;
    if (selected == null) return null;
    final key = siteCountryKey(selected.site);
    return stored.contains(key) ? null : key;
  }

  void _toggleCountry(String key, Set<String> current) {
    final next = toggleCountryKey(current, key);
    if (ref.read(siteFilterProvider).hasActiveFilters) {
      final keys = current.union(_filterCollapsed);
      setState(() => _filterCollapsed = keys.difference(next));
      return;
    }
    ref.read(siteListExpandedCountriesProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sortedSitesWithCountsProvider);
    final filter = ref.watch(siteFilterProvider);
    final viewMode = ref.watch(siteListViewModeProvider);
    ref.listen(siteFilterProvider, (_, _) {
      if (_filterCollapsed.isNotEmpty) {
        setState(() => _filterCollapsed = const {});
      }
    });

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
                SiteActiveFiltersBar(filter: filter),
                Expanded(child: listContent),
              ],
            )
          : listContent;
    }

    final loadedSites = sitesAsync.value ?? const <SiteWithDiveCount>[];
    final visibleIds = loadedSites.map((s) => s.site.id).toList();

    // Drop checked sites that fell out of the filtered list, so the count
    // always matches what is on screen. pruneTo is a no-op when nothing
    // changed, which keeps this off a rebuild loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sitesAsync.hasSettled) _selection.pruneTo(visibleIds);
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
                    subtitle: siteListCountLabel(context, ref),
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
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'import') {
                          context.push('/sites/import');
                        } else if (value == 'fill_location_details') {
                          unawaited(
                            showSiteLocationBackfillFlow(
                              context,
                              ref,
                              mode: SiteLocationLookupMode.fillMissing,
                            ),
                          );
                        } else if (value == 'refresh_place_names') {
                          unawaited(
                            showSiteLocationBackfillFlow(
                              context,
                              ref,
                              mode: SiteLocationLookupMode.refreshAll,
                            ),
                          );
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
                          ...selectItemsMenuEntries(
                            context,
                            onSelect: _selection.enterExplicit,
                          ),
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
                          PopupMenuItem(
                            value: 'refresh_place_names',
                            child: ListTile(
                              leading: const Icon(Icons.translate),
                              title: Text(
                                context
                                    .l10n
                                    .diveSites_list_menu_refreshPlaceNames,
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
    final loadedSites = sitesAsync.value ?? const <SiteWithDiveCount>[];
    final visibleIds = loadedSites.map((s) => s.site.id).toList();

    // Same pruning the list path does: drop checked sites that fell out of
    // the visible list, so the count always matches what is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sitesAsync.hasSettled) _selection.pruneTo(visibleIds);
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

          // Table mode has no app bar of its own: "Select items" sits in the
          // page header's overflow menu, and the contextual bar opens above
          // the table while selecting.
          return Column(
            children: [
              if (selection.isActive)
                _buildCompactSelectionAppBar(context, loadedSites),
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
            if (filter.hasActiveFilters) SiteActiveFiltersBar(filter: filter),
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
              subtitle: siteListCountLabel(context, ref),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'import') {
                context.push('/sites/import');
              } else if (value == 'fill_location_details') {
                unawaited(
                  showSiteLocationBackfillFlow(
                    context,
                    ref,
                    mode: SiteLocationLookupMode.fillMissing,
                  ),
                );
              } else if (value == 'refresh_place_names') {
                unawaited(
                  showSiteLocationBackfillFlow(
                    context,
                    ref,
                    mode: SiteLocationLookupMode.refreshAll,
                  ),
                );
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
                ...selectItemsMenuEntries(
                  context,
                  onSelect: _selection.enterExplicit,
                ),
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
                  value: 'import',
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(context.l10n.diveSites_list_menu_import),
                    contentPadding: EdgeInsets.zero,
                  ),
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
                PopupMenuItem(
                  value: 'refresh_place_names',
                  child: ListTile(
                    leading: const Icon(Icons.translate),
                    title: Text(
                      context.l10n.diveSites_list_menu_refreshPlaceNames,
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

    final grouped = _groupedView(sites);
    final rows = grouped?.rows;
    final expanded = grouped?.expanded ?? const <String>{};
    // Range selection follows what the diver sees: grouped, it walks only
    // the sites on screen, so a shift-click across a collapsed country never
    // checks the sites hidden inside it.
    final orderedSites = grouped == null
        ? sites
        : [
            for (final row in grouped.rows)
              if (row is SiteRow<SiteWithDiveCount>) row.item,
          ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sortedSitesWithCountsProvider);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: rows?.length ?? sites.length,
        itemBuilder: (context, index) {
          if (rows == null) {
            return _buildSiteTile(sites[index], orderedSites, diversCount);
          }
          return switch (rows[index]) {
            CountryHeaderRow(:final group, :final isExpanded) =>
              SiteCountryHeader(
                label: countryGroupLabel(context.l10n, group),
                siteCount: group.siteCount,
                isExpanded: isExpanded,
                onTap: () => _toggleCountry(group.key, expanded),
              ),
            RegionHeaderRow(:final label) => SiteSectionLabel(
              label,
              indent: 32,
            ),
            SiteRow(:final item) => _buildSiteTile(
              item,
              orderedSites,
              diversCount,
            ),
          };
        },
      ),
    );
  }

  Widget _buildSiteTile(
    SiteWithDiveCount siteData,
    List<SiteWithDiveCount> orderedSites,
    int diversCount,
  ) {
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
        onTap: () => _handleRowTap(site.id, orderedSites),
      ),
      ListViewMode.compact => CompactSiteListTile(
        entry: siteData,
        isSelectionMode: _isSelectionMode,
        isSelected: isChecked,
        isHighlighted: !_isSelectionMode && isSelected,
        showSharedBadge: showSharedBadge,
        onTap: () => _handleRowTap(site.id, orderedSites),
      ),
      ListViewMode.dense || ListViewMode.table => DenseSiteListTile(
        name: site.name,
        location: locationString,
        diveCount: siteData.diveCount,
        isSelectionMode: _isSelectionMode,
        isSelected: isChecked,
        isHighlighted: !_isSelectionMode && isSelected,
        showSharedBadge: showSharedBadge,
        onTap: () => _handleRowTap(site.id, orderedSites),
      ),
    };
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

/// The grouped Dive Sites list for one build: its groups, the countries
/// open, and the flattened rows those give.
typedef _GroupedSites = ({
  List<SiteCountryGroup<SiteWithDiveCount>> groups,
  Set<String> expanded,
  List<SiteListRow<SiteWithDiveCount>> rows,
});
