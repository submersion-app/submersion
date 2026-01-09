import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../dive_sites/presentation/providers/site_providers.dart';
import '../../../dive_types/presentation/providers/dive_type_providers.dart';
import '../../../equipment/presentation/providers/equipment_providers.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../dive_centers/presentation/providers/dive_center_providers.dart';
import '../../domain/entities/dive.dart';
import '../providers/dive_providers.dart';
import '../pages/dive_list_page.dart';
import 'dive_numbering_dialog.dart';

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

  const DiveListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<DiveListContent> createState() => _DiveListContentState();
}

class _DiveListContentState extends ConsumerState<DiveListContent> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<Dive>? _deletedDives;
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false; // Track if selection originated from list tap

  @override
  void initState() {
    super.initState();
    // If there's already a selected ID on init (e.g., from URL), scroll to it after build
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

  /// Scroll the list to show the selected item
  void _scrollToSelectedItem() {
    if (widget.selectedId == null) return;

    // Get the current dive list from the provider
    final divesAsync = ref.read(filteredDivesProvider);
    divesAsync.whenData((dives) {
      final index = dives.indexWhere((d) => d.id == widget.selectedId);
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
          _lastScrolledToId = widget.selectedId;
        });
      }
    });
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
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final idsToDelete = _selectedIds.toList();

      // If the currently selected item in master-detail is being deleted, clear it
      if (widget.selectedId != null && idsToDelete.contains(widget.selectedId)) {
        widget.onItemSelected?.call(null);
      }

      _exitSelectionMode();

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

  void _handleItemTap(Dive dive) {
    if (_isSelectionMode) {
      _toggleSelection(dive.id);
    } else if (widget.onItemSelected != null) {
      // Master-detail mode: notify parent
      // Mark that selection came from list tap (don't scroll)
      _selectionFromList = true;
      widget.onItemSelected!(dive.id);
    } else {
      // Standalone mode: navigate
      context.go('/dives/${dive.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final divesAsync = ref.watch(filteredDivesProvider);
    final filter = ref.watch(diveFilterProvider);

    final content = divesAsync.when(
      data: (dives) => dives.isEmpty
          ? _buildEmptyState(context, filter.hasActiveFilters)
          : _buildDiveList(context, dives, filter.hasActiveFilters),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    if (!widget.showAppBar) {
      // Used inside MasterDetailScaffold - no Scaffold wrapper
      return Column(
        children: [
          if (_isSelectionMode)
            _buildSelectionBar(divesAsync.value ?? [])
          else
            _buildCompactAppBar(context, filter),
          Expanded(child: content),
        ],
      );
    }

    // Standalone mode with full Scaffold
    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(divesAsync.value ?? [])
          : _buildAppBar(context, filter),
      body: content,
      floatingActionButton: _isSelectionMode ? null : widget.floatingActionButton,
    );
  }

  AppBar _buildAppBar(BuildContext context, DiveFilterState filter) {
    return AppBar(
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
            'Dives',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            visualDensity: VisualDensity.compact,
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
              child: const Icon(Icons.filter_list, size: 20),
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => DiveFilterSheet(ref: ref),
              );
            },
          ),
        ],
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

  /// Selection bar for master pane in split view
  Widget _buildSelectionBar(List<Dive> dives) {
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
            visualDensity: VisualDensity.compact,
            onPressed: _exitSelectionMode,
          ),
          Text(
            '${_selectedIds.length} selected',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          if (_selectedIds.length < dives.length)
            IconButton(
              icon: const Icon(Icons.select_all, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: 'Select All',
              onPressed: () => _selectAll(dives),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete Selected',
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
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
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: dives.length,
              itemBuilder: (context, index) {
                final dive = dives[index];
                final isSelected = _selectedIds.contains(dive.id);
                final isMasterSelected = widget.selectedId == dive.id;
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
                  isSelected: isSelected || isMasterSelected,
                  minDepthInList: minDepth,
                  maxDepthInList: maxDepth,
                  siteLatitude: dive.site?.location?.latitude,
                  siteLongitude: dive.site?.location?.longitude,
                  onTap: () => _handleItemTap(dive),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
    );
  }
}
