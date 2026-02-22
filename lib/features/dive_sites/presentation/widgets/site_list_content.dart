import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';

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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<DiveSite>? _deletedSites;

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

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(site.id);
    } else {
      context.push('/sites/${site.id}');
    }
  }

  void _enterSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
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
    });
  }

  void _selectAll(List<SiteWithDiveCount> sites) {
    setState(() {
      _selectedIds.addAll(sites.map((s) => s.site.id));
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
      getFieldDisplayName: (field) => field.displayName,
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

    final listContent = sitesAsync.when(
      data: (sites) => sites.isEmpty
          ? _buildEmptyState(context, filter.hasActiveFilters)
          : _buildSiteList(context, ref, sites),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    // Wrap list with active filters bar if filters are active
    final content = filter.hasActiveFilters
        ? Column(
            children: [
              _buildActiveFiltersBar(context, filter),
              Expanded(child: listContent),
            ],
          )
        : listContent;

    if (!widget.showAppBar) {
      return Column(
        children: [
          _isSelectionMode
              ? _buildCompactSelectionAppBar(
                  context,
                  sitesAsync.valueOrNull ?? [],
                )
              : _buildCompactAppBar(context),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(sitesAsync.valueOrNull ?? [])
          : AppBar(
              title: Text(context.l10n.diveSites_list_appBar_title),
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
                    switch (value) {
                      case 'import':
                        context.push('/sites/import');
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        leading: const Icon(Icons.download),
                        title: Text(context.l10n.diveSites_list_menu_import),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: content,
      floatingActionButton: _isSelectionMode
          ? null
          : widget.floatingActionButton,
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
          Text(
            context.l10n.diveSites_list_appBar_title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (widget.onMapViewToggle != null)
            MapViewToggleButton(
              isActive: widget.isMapViewActive,
              onToggle: widget.onMapViewToggle!,
            )
          else
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
            visualDensity: VisualDensity.compact,
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
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Text(context.l10n.diveSites_list_menu_import),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSelectionAppBar(
    BuildContext context,
    List<SiteWithDiveCount> sites,
  ) {
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
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: context.l10n.diveSites_list_selection_closeTooltip,
            onPressed: _exitSelectionMode,
          ),
          Text(
            context.l10n.diveSites_list_selection_count(_selectedIds.length),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_selectedIds.length < sites.length)
            IconButton(
              icon: const Icon(Icons.select_all, size: 20),
              tooltip: context.l10n.diveSites_list_selection_selectAllTooltip,
              onPressed: () => _selectAll(sites),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.deselect, size: 20),
              tooltip: context.l10n.diveSites_list_selection_deselectAllTooltip,
              onPressed: _deselectAll,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: context.l10n.diveSites_list_selection_deleteTooltip,
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
    );
  }

  AppBar _buildSelectionAppBar(List<SiteWithDiveCount> sites) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.diveSites_list_selection_closeTooltip,
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        context.l10n.diveSites_list_selection_count(_selectedIds.length),
      ),
      actions: [
        if (_selectedIds.length < sites.length)
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: context.l10n.diveSites_list_selection_selectAllTooltip,
            onPressed: () => _selectAll(sites),
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: context.l10n.diveSites_list_selection_deselectAllTooltip,
            onPressed: _deselectAll,
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: context.l10n.diveSites_list_selection_deleteTooltip,
            onPressed: _confirmAndDelete,
          ),
      ],
    );
  }

  Widget _buildSiteList(
    BuildContext context,
    WidgetRef ref,
    List<SiteWithDiveCount> sites,
  ) {
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
          final isSelected = widget.selectedId == site.id;
          final isChecked = _selectedIds.contains(site.id);

          return SiteListTile(
            name: site.name,
            location: site.locationString.isNotEmpty
                ? site.locationString
                : null,
            minDepth: site.minDepth,
            maxDepth: site.maxDepth,
            difficulty: site.difficulty?.displayName,
            diveCount: siteData.diveCount,
            rating: site.rating,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            isChecked: isChecked,
            latitude: site.location?.latitude,
            longitude: site.location?.longitude,
            onTap: () => _handleItemTap(site),
            onLongPress: _isSelectionMode
                ? null
                : () => _enterSelectionMode(site.id),
          );
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

  String _formatDepthRange(double? min, double? max) {
    if (min != null && max != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeBoth(
        min.toInt(),
        max.toInt(),
      );
    } else if (min != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeMin(
        min.toInt(),
      );
    } else if (max != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeMax(
        max.toInt(),
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
    final searchAsync = ref.watch(siteSearchProvider(query));

    return searchAsync.when(
      data: (sites) {
        if (sites.isEmpty) {
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
        }

        return ListView.builder(
          itemCount: sites.length,
          itemBuilder: (context, index) {
            final site = sites[index];
            return SiteListTile(
              name: site.name,
              location: site.locationString.isNotEmpty
                  ? site.locationString
                  : null,
              minDepth: site.minDepth,
              maxDepth: site.maxDepth,
              difficulty: site.difficulty?.displayName,
              rating: site.rating,
              latitude: site.location?.latitude,
              longitude: site.location?.longitude,
              onTap: () {
                close(context, site);
                context.push('/sites/${site.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(context.l10n.diveSites_list_search_error(error.toString())),
      ),
    );
  }
}

/// List item widget for displaying a dive site summary
class SiteListTile extends ConsumerWidget {
  final String name;
  final String? location;
  final double? minDepth;
  final double? maxDepth;
  final String? difficulty;
  final int diveCount;
  final double? rating;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isChecked;
  final double? latitude;
  final double? longitude;

  const SiteListTile({
    super.key,
    required this.name,
    this.location,
    this.minDepth,
    this.maxDepth,
    this.difficulty,
    this.diveCount = 0,
    this.rating,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isChecked = false,
    this.latitude,
    this.longitude,
  });

  String? get _depthString {
    if (minDepth != null && maxDepth != null) {
      return '${minDepth!.toStringAsFixed(0)}-${maxDepth!.toStringAsFixed(0)}m';
    }
    if (maxDepth != null) {
      return '${maxDepth!.toStringAsFixed(0)}m';
    }
    return null;
  }

  bool get _hasLocation => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final showMapBackground = ref.watch(showMapBackgroundOnSiteCardsProvider);
    final shouldShowMap =
        showMapBackground && _hasLocation && !isSelected && !isChecked;
    final useLightText = shouldShowMap;
    final primaryTextColor = useLightText ? Colors.white : null;
    final secondaryTextColor = useLightText
        ? Colors.white70
        : colorScheme.onSurfaceVariant;

    Widget buildContent() {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (isSelectionMode)
              Checkbox(
                value: isChecked,
                onChanged: (_) => onTap?.call(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )
            else
              CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.location_on,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      location!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: secondaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_depthString != null)
                  Text(
                    _depthString!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (difficulty != null)
                  Text(
                    difficulty!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                  ),
                if (diveCount > 0)
                  Text(
                    context.l10n.diveSites_list_tile_diveCount(diveCount),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                  ),
                if (rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ],
                  ),
              ],
            ),
            if (!isSelectionMode)
              Icon(Icons.chevron_right, color: secondaryTextColor),
          ],
        ),
      );
    }

    if (shouldShowMap) {
      final siteLocation = LatLng(latitude!, longitude!);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: context.l10n.diveSites_list_tile_semantics(name),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: siteLocation,
                      initialZoom: 13.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.submersion.app',
                        maxZoom: 19,
                        tileProvider: TileCacheService.instance.isInitialized
                            ? TileCacheService.instance.getTileProvider()
                            : null,
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 0.7, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                buildContent(),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : isChecked
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: true,
        label: context.l10n.diveSites_list_tile_semantics(name),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: buildContent(),
        ),
      ),
    );
  }
}
