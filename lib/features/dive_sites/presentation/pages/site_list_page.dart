import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/site_repository_impl.dart';
import '../../domain/entities/dive_site.dart';
import '../providers/site_providers.dart';

class SiteListPage extends ConsumerStatefulWidget {
  const SiteListPage({super.key});

  @override
  ConsumerState<SiteListPage> createState() => _SiteListPageState();
}

class _SiteListPageState extends ConsumerState<SiteListPage> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<DiveSite>? _deletedSites;

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
      // Capture ScaffoldMessenger before async operations to prevent stale context
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final idsToDelete = _selectedIds.toList();
      _exitSelectionMode();

      // Perform deletion and get deleted sites for undo
      final deletedSites = await ref
          .read(siteListNotifierProvider.notifier)
          .bulkDeleteSites(idsToDelete);

      _deletedSites = deletedSites;

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Deleted ${deletedSites.length} ${deletedSites.length == 1 ? 'site' : 'sites'}'),
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
      body: sitesAsync.when(
        data: (sites) => sites.isEmpty
            ? _buildEmptyState(context)
            : _buildSiteList(context, ref, sites),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/sites/new'),
              icon: const Icon(Icons.add_location),
              label: const Text('Add Site'),
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

  Widget _buildSiteList(BuildContext context, WidgetRef ref, List<SiteWithDiveCount> sites) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sitesWithCountsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sites.length,
        itemBuilder: (context, index) {
          final siteData = sites[index];
          final site = siteData.site;
          final isSelected = _selectedIds.contains(site.id);
          return SiteListTile(
            name: site.name,
            location: site.locationString.isNotEmpty ? site.locationString : null,
            maxDepth: site.maxDepth,
            diveCount: siteData.diveCount,
            rating: site.rating,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onTap: _isSelectionMode
                ? () => _toggleSelection(site.id)
                : () => context.push('/sites/${site.id}'),
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
          onPressed: () => query = '',
        ),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              location: site.locationString.isNotEmpty ? site.locationString : null,
              maxDepth: site.maxDepth,
              rating: site.rating,
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
        child: Text('Error: $error'),
      ),
    );
  }
}

/// List item widget for displaying a dive site summary
class SiteListTile extends StatelessWidget {
  final String name;
  final String? location;
  final double? maxDepth;
  final int diveCount;
  final double? rating;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const SiteListTile({
    super.key,
    required this.name,
    this.location,
    this.maxDepth,
    this.diveCount = 0,
    this.rating,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection checkbox or location icon
              if (isSelectionMode)
                Checkbox(
                  value: isSelected,
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
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        location!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Trailing info
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (diveCount > 0)
                    Text(
                      '$diveCount dives',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(rating!.toStringAsFixed(1)),
                      ],
                    ),
                ],
              ),
              if (!isSelectionMode)
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
