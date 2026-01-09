import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../dive_sites/presentation/providers/site_providers.dart';
import '../../../dive_types/presentation/providers/dive_type_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../tags/domain/entities/tag.dart';
import '../../../equipment/presentation/providers/equipment_providers.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../tags/presentation/widgets/tag_input_widget.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../dive_centers/presentation/providers/dive_center_providers.dart';
import '../../domain/entities/dive.dart';
import '../providers/dive_providers.dart';
import '../widgets/dive_numbering_dialog.dart';
import '../widgets/dive_profile_chart.dart';

class DiveListPage extends ConsumerStatefulWidget {
  const DiveListPage({super.key});

  @override
  ConsumerState<DiveListPage> createState() => _DiveListPageState();
}

class _DiveListPageState extends ConsumerState<DiveListPage> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<Dive>? _deletedDives;

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

  void _selectAll(List<Dive> dives) {
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
        title: const Text('Delete Dives'),
        content: Text(
          'Are you sure you want to delete $count ${count == 1 ? 'dive' : 'dives'}? This action can be undone within 5 seconds.',
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

      // Perform deletion and get deleted dives for undo
      final deletedDives = await ref
          .read(diveListNotifierProvider.notifier)
          .bulkDeleteDives(idsToDelete);

      _deletedDives = deletedDives;

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${deletedDives.length} ${deletedDives.length == 1 ? 'dive' : 'dives'}',
            ),
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (_deletedDives != null && _deletedDives!.isNotEmpty) {
                  await ref
                      .read(diveListNotifierProvider.notifier)
                      .restoreDives(_deletedDives!);
                  _deletedDives = null;
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Dives restored'),
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
    final divesAsync = ref.watch(filteredDivesProvider);
    final filter = ref.watch(diveFilterProvider);

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(divesAsync.valueOrNull ?? [])
          : AppBar(
              title: const Text('Dive Log'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: DiveSearchDelegate(ref),
                    );
                  },
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: filter.hasActiveFilters,
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => DiveFilterSheet(ref: ref),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'numbering') {
                      showDiveNumberingDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'numbering',
                      child: Row(
                        children: [
                          Icon(Icons.format_list_numbered),
                          SizedBox(width: 12),
                          Text('Dive Numbering'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: divesAsync.when(
        data: (dives) => dives.isEmpty
            ? _buildEmptyState(context, filter.hasActiveFilters)
            : _buildDiveList(context, dives, filter.hasActiveFilters),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
                  'Error loading dives',
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
                      ref.read(diveListNotifierProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/dives/new'),
              icon: const Icon(Icons.add),
              label: const Text('Log Dive'),
            ),
    );
  }

  AppBar _buildSelectionAppBar(List<Dive> dives) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedIds.length} selected'),
      actions: [
        if (_selectedIds.length < dives.length)
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: () => _selectAll(dives),
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

  Widget _buildDiveList(
    BuildContext context,
    List<Dive> dives,
    bool hasActiveFilters,
  ) {
    // Calculate depth range for relative depth coloring
    final depthsWithValues = dives
        .where((d) => d.maxDepth != null)
        .map((d) => d.maxDepth!);
    final minDepth = depthsWithValues.isNotEmpty
        ? depthsWithValues.reduce((a, b) => a < b ? a : b)
        : null;
    final maxDepth = depthsWithValues.isNotEmpty
        ? depthsWithValues.reduce((a, b) => a > b ? a : b)
        : null;

    return RefreshIndicator(
      onRefresh: () => ref.read(diveListNotifierProvider.notifier).refresh(),
      child: Column(
        children: [
          if (hasActiveFilters) _buildActiveFiltersBar(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: dives.length,
              itemBuilder: (context, index) {
                final dive = dives[index];
                final isSelected = _selectedIds.contains(dive.id);
                return DiveListTile(
                  diveId: dive.id,
                  diveNumber: dive.diveNumber ?? index + 1,
                  dateTime: dive.dateTime,
                  siteName: dive.site?.name,
                  siteLocation: dive.site?.locationString,
                  maxDepth: dive.maxDepth,
                  duration: dive.duration,
                  waterTemp: dive.waterTemp,
                  rating: dive.rating,
                  isFavorite: dive.isFavorite,
                  tags: dive.tags,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected,
                  minDepthInList: minDepth,
                  maxDepthInList: maxDepth,
                  siteLatitude: dive.site?.location?.latitude,
                  siteLongitude: dive.site?.location?.longitude,
                  onTap: _isSelectionMode
                      ? () => _toggleSelection(dive.id)
                      : () => context.go('/dives/${dive.id}'),
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
    final chips = <Widget>[];

    if (filter.startDate != null || filter.endDate != null) {
      String dateText;
      if (filter.startDate != null && filter.endDate != null) {
        dateText =
            '${DateFormat('MMM d').format(filter.startDate!)} - ${DateFormat('MMM d').format(filter.endDate!)}';
      } else if (filter.startDate != null) {
        dateText = 'From ${DateFormat('MMM d').format(filter.startDate!)}';
      } else {
        dateText = 'Until ${DateFormat('MMM d').format(filter.endDate!)}';
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

    if (filter.equipmentId != null) {
      final equipmentName =
          ref.watch(equipmentItemProvider(filter.equipmentId!)).value?.name ??
          'Equipment';
      chips.add(
        _buildFilterChip(context, equipmentName, () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearEquipmentId: true,
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
        _buildFilterChip(context, 'Favorites', () {
          ref.read(diveFilterProvider.notifier).state = filter.copyWith(
            clearFavoritesOnly: true,
          );
        }),
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
            child: const Text('Clear all'),
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
      padding: const EdgeInsets.only(right: 8),
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
              'No dives match your filters',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting or clearing your filters',
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
              label: const Text('Clear Filters'),
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
            'No dives logged yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to log your first dive',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/dives/new'),
            icon: const Icon(Icons.add),
            label: const Text('Log Your First Dive'),
          ),
        ],
      ),
    );
  }
}

/// Search delegate for diving through dive logs
class DiveSearchDelegate extends SearchDelegate<Dive?> {
  final WidgetRef ref;

  DiveSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search dives...';

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
              'Search by site, buddy, or notes',
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
    final searchAsync = ref.watch(diveSearchProvider(query));

    return searchAsync.when(
      data: (dives) {
        if (dives.isEmpty) {
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
                  'No dives found for "$query"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate depth range for relative depth coloring
        final depthsWithValues = dives
            .where((d) => d.maxDepth != null)
            .map((d) => d.maxDepth!);
        final minDepth = depthsWithValues.isNotEmpty
            ? depthsWithValues.reduce((a, b) => a < b ? a : b)
            : null;
        final maxDepth = depthsWithValues.isNotEmpty
            ? depthsWithValues.reduce((a, b) => a > b ? a : b)
            : null;

        return ListView.builder(
          itemCount: dives.length,
          itemBuilder: (context, index) {
            final dive = dives[index];
            return DiveListTile(
              diveId: dive.id,
              diveNumber: dive.diveNumber ?? index + 1,
              dateTime: dive.dateTime,
              siteName: dive.site?.name,
              siteLocation: dive.site?.locationString,
              maxDepth: dive.maxDepth,
              duration: dive.duration,
              waterTemp: dive.waterTemp,
              rating: dive.rating,
              isFavorite: dive.isFavorite,
              tags: dive.tags,
              minDepthInList: minDepth,
              maxDepthInList: maxDepth,
              siteLatitude: dive.site?.location?.latitude,
              siteLongitude: dive.site?.location?.longitude,
              onTap: () {
                close(context, dive);
                context.go('/dives/${dive.id}');
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

/// List item widget for displaying a dive summary
class DiveListTile extends ConsumerWidget {
  final String diveId;
  final int diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final String? siteLocation;
  final double? maxDepth;
  final Duration? duration;
  final double? waterTemp;
  final int? rating;
  final bool isFavorite;
  final List<Tag> tags;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  /// Min depth in the current list (for relative depth coloring)
  final double? minDepthInList;

  /// Max depth in the current list (for relative depth coloring)
  final double? maxDepthInList;

  /// Site location for map background
  final double? siteLatitude;
  final double? siteLongitude;

  const DiveListTile({
    super.key,
    required this.diveId,
    required this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.siteLocation,
    this.maxDepth,
    this.duration,
    this.waterTemp,
    this.rating,
    this.isFavorite = false,
    this.tags = const [],
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.minDepthInList,
    this.maxDepthInList,
    this.siteLatitude,
    this.siteLongitude,
  });

  /// Calculate background color based on relative depth
  Color? _getDepthBackgroundColor(BuildContext context) {
    if (maxDepth == null || minDepthInList == null || maxDepthInList == null) {
      return null;
    }

    final depthRange = maxDepthInList! - minDepthInList!;
    if (depthRange <= 0) {
      // All dives are the same depth, use a medium blue
      return Colors.blue.withValues(alpha: 0.25);
    }

    // Normalize depth to 0.0 (shallowest) - 1.0 (deepest)
    final normalizedDepth = (maxDepth! - minDepthInList!) / depthRange;

    // Map to ocean colors: shallow = turquoise (Caribbean), deep = dark navy (abyss)
    // Using Color.lerp for smooth gradient between the two
    const shallowTurquoise = Color(0xFF4DD0E1); // Bright turquoise (Cyan 300)
    const deepNavy = Color(0xFF0D1B2A); // Very dark navy (deep ocean)

    return Color.lerp(shallowTurquoise, deepNavy, normalizedDepth);
  }

  /// Determine if text should be light or dark based on background color
  bool _shouldUseLightText(Color backgroundColor) {
    // Use luminance to determine if background is dark
    // Luminance < 0.5 means dark background, needs light text
    return backgroundColor.computeLuminance() < 0.5;
  }

  /// Check if map background should be shown
  bool get _hasLocation => siteLatitude != null && siteLongitude != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final profileAsync = ref.watch(diveProfileProvider(diveId));

    // Check if depth-colored cards are enabled
    final showDepthColors = ref.watch(showDepthColoredDiveCardsProvider);
    // Check if map background is enabled
    final showMapBackground = ref.watch(showMapBackgroundOnDiveCardsProvider);

    // Determine if we should show the map (setting enabled + location available)
    final shouldShowMap = showMapBackground && _hasLocation && !isSelected;

    // Determine card background: selection takes priority, then depth coloring (if enabled)
    // When map is shown, we don't use depth coloring on the card itself
    final depthColor = (showDepthColors && !shouldShowMap)
        ? _getDepthBackgroundColor(context)
        : null;
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : depthColor;

    // Determine text colors based on background luminance
    // When map is shown, use light text since the gradient overlay makes the background dark
    final effectiveBackground = shouldShowMap
        ? const Color(0xFF1A1A2E) // Dark background for map overlay
        : (cardColor ?? colorScheme.surfaceContainerHighest);
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    // Use contrasting accent colors: light cyan on dark backgrounds, dark teal on light backgrounds
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    // Build the content widget (used in both map and non-map variants)
    Widget buildContent() {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Selection checkbox or dive number badge
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap?.call(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )
            else
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  '#$diveNumber',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Site name with favorite and rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          siteName ?? 'Unknown Site',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFavorite) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.favorite,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                      ],
                      if (rating != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$rating',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: primaryTextColor,
                              ),
                        ),
                      ],
                    ],
                  ),
                  // Site location (country/region)
                  if (siteLocation != null && siteLocation!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      siteLocation!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Date and time
                  Text(
                    _formatDateTime(dateTime),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: secondaryTextColor),
                  ),
                  const SizedBox(height: 6),
                  // Depth and duration stats (always shown)
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: maxDepth != null
                            ? accentColor
                            : secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        units.formatDepth(maxDepth),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: maxDepth != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: duration != null
                            ? accentColor
                            : secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        duration != null ? _formatDuration(duration!) : '--',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: duration != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      if (waterTemp != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.thermostat_outlined,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          units.formatTemperature(waterTemp),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                        ),
                      ],
                    ],
                  ),
                  // Tags
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    TagChips(tags: tags, maxTags: 3),
                  ],
                ],
              ),
            ),
            // Dive profile mini chart (right side)
            profileAsync.when(
              data: (profile) => profile.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 80,
                        height: 50,
                        child: DiveProfileMiniChart(
                          profile: profile,
                          height: 50,
                          color: accentColor,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 80,
                  height: 50,
                  child: Center(
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            // Chevron
            Icon(Icons.chevron_right, color: secondaryTextColor),
          ],
        ),
      );
    }

    // Build the card with or without map background
    if (shouldShowMap) {
      final siteLocation = LatLng(siteLatitude!, siteLongitude!);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              // Map background layer
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: siteLocation,
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Non-interactive
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
              // Gradient overlay for text readability
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
              // Content layer
              buildContent(),
            ],
          ),
        ),
      );
    }

    // Standard card without map
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: buildContent(),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${DateFormat('MMM d, y').format(date)} at ${DateFormat('h:mm a').format(date)}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    return '$minutes min';
  }
}

/// Filter sheet for dive list
class DiveFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const DiveFilterSheet({super.key, required this.ref});

  @override
  ConsumerState<DiveFilterSheet> createState() => _DiveFilterSheetState();
}

class _DiveFilterSheetState extends ConsumerState<DiveFilterSheet> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _diveTypeId;
  late String? _siteId;
  late double? _minDepth;
  late double? _maxDepth;
  late bool _favoritesOnly;
  late List<String> _selectedTagIds;

  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter = widget.ref.read(diveFilterProvider);
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _diveTypeId = filter.diveTypeId;
    _siteId = filter.siteId;
    _minDepth = filter.minDepth;
    _maxDepth = filter.maxDepth;
    _favoritesOnly = filter.favoritesOnly ?? false;
    _selectedTagIds = List.from(filter.tagIds);
    _minDepthController.text = _minDepth?.toStringAsFixed(0) ?? '';
    _maxDepthController.text = _maxDepth?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _minDepthController.dispose();
    _maxDepthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Dives',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Date Range Section
              Text(
                'Date Range',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _startDate != null
                            ? DateFormat('MMM d, y').format(_startDate!)
                            : 'Start Date',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, isStart: false),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _endDate != null
                            ? DateFormat('MMM d, y').format(_endDate!)
                            : 'End Date',
                      ),
                    ),
                  ),
                ],
              ),
              if (_startDate != null || _endDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: const Text('Clear dates'),
                  ),
                ),
              const SizedBox(height: 24),

              // Dive Type Section
              Text('Dive Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final diveTypesAsync = ref.watch(diveTypesProvider);
                  return diveTypesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error: $e'),
                    data: (diveTypes) => DropdownButtonFormField<String?>(
                      initialValue: _diveTypeId,
                      decoration: const InputDecoration(
                        hintText: 'All types',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All types'),
                        ),
                        ...diveTypes.map((type) {
                          return DropdownMenuItem(
                            value: type.id,
                            child: Text(type.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _diveTypeId = value);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Site Section
              Text('Dive Site', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              sites.when(
                data: (siteList) => DropdownButtonFormField<String?>(
                  initialValue: _siteId,
                  decoration: const InputDecoration(
                    hintText: 'All sites',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All sites'),
                    ),
                    ...siteList.map((site) {
                      return DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _siteId = value);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Error loading sites'),
              ),
              const SizedBox(height: 24),

              // Depth Range Section
              Text(
                'Depth Range (meters)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minDepthController,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        prefixIcon: Icon(Icons.arrow_downward),
                        suffixText: 'm',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _minDepth = double.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _maxDepthController,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        prefixIcon: Icon(Icons.arrow_downward),
                        suffixText: 'm',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _maxDepth = double.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Favorites Section
              SwitchListTile(
                title: const Text('Favorites Only'),
                subtitle: const Text('Show only favorite dives'),
                secondary: Icon(
                  Icons.favorite,
                  color: _favoritesOnly ? Colors.red : null,
                ),
                value: _favoritesOnly,
                onChanged: (value) {
                  setState(() => _favoritesOnly = value);
                },
              ),
              const SizedBox(height: 24),

              // Tags Section
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ref
                  .watch(tagListNotifierProvider)
                  .when(
                    data: (allTags) {
                      if (allTags.isEmpty) {
                        return const Text(
                          'No tags created yet',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allTags.map((tag) {
                          final isSelected = _selectedTagIds.contains(tag.id);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            selectedColor: tag.color.withValues(alpha: 0.3),
                            checkmarkColor: tag.color,
                            side: BorderSide(
                              color: isSelected
                                  ? tag.color
                                  : Colors.grey.shade300,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTagIds.add(tag.id);
                                } else {
                                  _selectedTagIds.remove(tag.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Error loading tags'),
                  ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.ref.read(diveFilterProvider.notifier).state =
                            const DiveFilterState();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applyFilters,
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = DateTime(2000);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _applyFilters() {
    widget.ref.read(diveFilterProvider.notifier).state = DiveFilterState(
      startDate: _startDate,
      endDate: _endDate,
      diveTypeId: _diveTypeId,
      siteId: _siteId,
      minDepth: _minDepth,
      maxDepth: _maxDepth,
      favoritesOnly: _favoritesOnly ? true : null,
      tagIds: _selectedTagIds,
    );
    Navigator.of(context).pop();
  }
}
