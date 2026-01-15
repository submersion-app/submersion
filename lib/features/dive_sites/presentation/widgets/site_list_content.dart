import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Content widget for the site list, used in master-detail layout.
class SiteListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const SiteListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
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

    final sitesAsync = ref.read(sitesWithCountsProvider);
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
        title: const Text('Delete Sites'),
        content: Text(
          'Are you sure you want to delete $count ${count == 1 ? 'site' : 'sites'}? This action can be undone within 5 seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
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
              'Deleted ${deletedSites.length} ${deletedSites.length == 1 ? 'site' : 'sites'}',
            ),
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (_deletedSites != null && _deletedSites!.isNotEmpty) {
                  await ref
                      .read(siteListNotifierProvider.notifier)
                      .restoreSites(_deletedSites!);
                  _deletedSites = null;
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Sites restored'),
                        duration: Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);

    final content = sitesAsync.when(
      data: (sites) => sites.isEmpty
          ? _buildEmptyState(context)
          : _buildSiteList(context, ref, sites),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

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
              title: const Text('Dive Sites'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: SiteSearchDelegate(ref),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.map),
                  tooltip: 'Map View',
                  onPressed: () => context.push('/sites/map'),
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
                    const PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        leading: Icon(Icons.travel_explore),
                        title: Text('Import from Online'),
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
            'Dive Sites',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {
              showSearch(context: context, delegate: SiteSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: const Icon(Icons.map, size: 20),
            tooltip: 'Map View',
            onPressed: () => context.push('/sites/map'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'import') {
                context.push('/sites/import');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Text('Import from Online'),
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
            onPressed: _exitSelectionMode,
          ),
          Text(
            '${_selectedIds.length} selected',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_selectedIds.length < sites.length)
            IconButton(
              icon: const Icon(Icons.select_all, size: 20),
              tooltip: 'Select All',
              onPressed: () => _selectAll(sites),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.deselect, size: 20),
              tooltip: 'Deselect All',
              onPressed: _deselectAll,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Delete Selected',
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
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedIds.length} selected'),
      actions: [
        if (_selectedIds.length < sites.length)
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: () => _selectAll(sites),
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: 'Deselect All',
            onPressed: _deselectAll,
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Delete Selected',
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
        ref.invalidate(sitesWithCountsProvider);
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

  Widget _buildEmptyState(BuildContext context) {
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
            'No dive sites yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add dive sites to track your favorite locations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/sites/new'),
            icon: const Icon(Icons.add_location),
            label: const Text('Add Your First Site'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/sites/import'),
            icon: const Icon(Icons.travel_explore),
            label: const Text('Import from Online'),
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
          Text('Error loading sites: $error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(sitesWithCountsProvider),
            child: const Text('Retry'),
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
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
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
              'Search by site name, country, or region',
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
                  'No sites found for "$query"',
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
      error: (error, _) => Center(child: Text('Error: $error')),
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
                    '$diveCount ${diveCount == 1 ? 'dive' : 'dives'}',
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
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : isChecked
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: buildContent(),
      ),
    );
  }
}
