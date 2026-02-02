import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_numbering_dialog.dart';

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
  final void Function(Dive dive)? onItemTapForMap;

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
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList =
      false; // Track if selection originated from list tap

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
    final divesAsync = ref.read(sortedFilteredDivesProvider);
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
      if (widget.selectedId != null &&
          idsToDelete.contains(widget.selectedId)) {
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

  void _showExportDialog(List<Dive> allDives) {
    final selectedDives = allDives
        .where((d) => _selectedIds.contains(d.id))
        .toList();
    final count = selectedDives.length;

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
                    'Export $count ${count == 1 ? 'Dive' : 'Dives'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF Logbook'),
              subtitle: const Text('Printable dive log pages'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSelected(selectedDives, 'pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSelected(selectedDives, 'csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('UDDF'),
              subtitle: const Text('Universal Dive Data Format'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSelected(selectedDives, 'uddf');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelected(List<Dive> selectedDives, String format) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Exporting...'),
          ],
        ),
      ),
    );

    try {
      final exportService = ref.read(exportServiceProvider);

      switch (format) {
        case 'pdf':
          await exportService.exportDivesToPdf(selectedDives);
          break;
        case 'csv':
          await exportService.exportDivesToCsv(selectedDives);
          break;
        case 'uddf':
          // Collect unique sites from selected dives
          final sites = selectedDives
              .where((d) => d.site != null)
              .map((d) => d.site!)
              .toSet()
              .toList();
          await exportService.exportDivesToUddf(selectedDives, sites: sites);
          break;
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _exitSelectionMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${selectedDives.length} ${selectedDives.length == 1 ? 'dive' : 'dives'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBulkEditSheet(List<Dive> allDives) {
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
                    'Edit $count ${count == 1 ? 'Dive' : 'Dives'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flight),
              title: const Text('Change Trip'),
              subtitle: const Text('Move selected dives to a trip'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showTripSelector();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('Add Tags'),
              subtitle: const Text('Add tags to selected dives'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddTagsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_off),
              title: const Text('Remove Tags'),
              subtitle: const Text('Remove tags from selected dives'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRemoveTagsDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTripSelector() {
    final trips = ref.read(allTripsProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Trip'),
        content: SizedBox(
          width: double.maxFinite,
          child: trips.when(
            data: (tripList) => ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('No Trip'),
                  subtitle: const Text('Remove from trip'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _bulkUpdateTrip(null);
                  },
                ),
                const Divider(),
                ...tripList.map(
                  (trip) => ListTile(
                    leading: const Icon(Icons.flight),
                    title: Text(trip.name),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _bulkUpdateTrip(trip.id);
                    },
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Error loading trips'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkUpdateTrip(String? tripId) async {
    final count = _selectedIds.length;
    final diveIds = _selectedIds.toList();

    try {
      await ref
          .read(diveListNotifierProvider.notifier)
          .bulkUpdateTrip(diveIds, tripId);

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tripId == null
                  ? 'Removed $count ${count == 1 ? 'dive' : 'dives'} from trip'
                  : 'Moved $count ${count == 1 ? 'dive' : 'dives'} to trip',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddTagsDialog() {
    final tagsAsync = ref.read(tagListNotifierProvider);

    tagsAsync.whenData((allTags) {
      if (allTags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tags available. Create tags first.'),
          ),
        );
        return;
      }

      final selectedTagIds = <String>{};

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Tags'),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) {
                final isSelected = selectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  selectedColor: tag.color.withValues(alpha: 0.3),
                  checkmarkColor: tag.color,
                  onSelected: (selected) {
                    setDialogState(() {
                      if (selected) {
                        selectedTagIds.add(tag.id);
                      } else {
                        selectedTagIds.remove(tag.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedTagIds.isEmpty
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _bulkAddTags(selectedTagIds.toList());
                      },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _bulkAddTags(List<String> tagIds) async {
    final count = _selectedIds.length;
    final diveIds = _selectedIds.toList();

    try {
      await ref
          .read(diveListNotifierProvider.notifier)
          .bulkAddTags(diveIds, tagIds);

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${tagIds.length} ${tagIds.length == 1 ? 'tag' : 'tags'} to $count ${count == 1 ? 'dive' : 'dives'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRemoveTagsDialog() {
    final tagsAsync = ref.read(tagListNotifierProvider);

    tagsAsync.whenData((allTags) {
      if (allTags.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No tags available.')));
        return;
      }

      final selectedTagIds = <String>{};

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Remove Tags'),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) {
                final isSelected = selectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  selectedColor: Colors.red.withValues(alpha: 0.3),
                  checkmarkColor: Colors.red,
                  onSelected: (selected) {
                    setDialogState(() {
                      if (selected) {
                        selectedTagIds.add(tag.id);
                      } else {
                        selectedTagIds.remove(tag.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedTagIds.isEmpty
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _bulkRemoveTags(selectedTagIds.toList());
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _bulkRemoveTags(List<String> tagIds) async {
    final count = _selectedIds.length;
    final diveIds = _selectedIds.toList();

    try {
      await ref
          .read(diveListNotifierProvider.notifier)
          .bulkRemoveTags(diveIds, tagIds);

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed ${tagIds.length} ${tagIds.length == 1 ? 'tag' : 'tags'} from $count ${count == 1 ? 'dive' : 'dives'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleItemTap(Dive dive) {
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

    if (widget.onItemSelected != null) {
      // Master-detail mode: notify parent
      // Mark that selection came from list tap (don't scroll)
      _selectionFromList = true;
      widget.onItemSelected!(dive.id);
    } else {
      // Standalone mode: navigate
      context.go('/dives/${dive.id}');
    }
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(diveSortProvider);

    showSortBottomSheet<DiveSortField>(
      context: context,
      title: 'Sort Dives',
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
    final divesAsync = ref.watch(sortedFilteredDivesProvider);
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
      floatingActionButton: _isSelectionMode
          ? null
          : widget.floatingActionButton,
    );
  }

  AppBar _buildAppBar(BuildContext context, DiveFilterState filter) {
    return AppBar(
      title: const Text('Dive Log'),
      actions: [
        IconButton(
          icon: const Icon(Icons.map),
          tooltip: 'Map View',
          onPressed: () => context.push('/dives/activity'),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            showSearch(context: context, delegate: DiveSearchDelegate(ref));
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
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onPressed: () => _showSortSheet(context),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'numbering') {
              showDiveNumberingDialog(context);
            } else if (value == 'advanced_search') {
              context.go('/dives/search');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'advanced_search',
              child: Row(
                children: [
                  Icon(Icons.manage_search),
                  SizedBox(width: 12),
                  Text('Advanced Search'),
                ],
              ),
            ),
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
              visualDensity: VisualDensity.compact,
              tooltip: 'Map View',
              onPressed: () => context.push('/dives/activity'),
            ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              showSearch(context: context, delegate: DiveSearchDelegate(ref));
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
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'numbering') {
                showDiveNumberingDialog(context);
              } else if (value == 'advanced_search') {
                context.go('/dives/search');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'advanced_search',
                child: Row(
                  children: [
                    Icon(Icons.manage_search, size: 20),
                    SizedBox(width: 12),
                    Text('Advanced Search'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'numbering',
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered, size: 20),
                    SizedBox(width: 12),
                    Text('Dive Numbering'),
                  ],
                ),
              ),
            ],
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
            icon: const Icon(Icons.upload),
            tooltip: 'Export Selected',
            onPressed: () => _showExportDialog(dives),
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Selected',
            onPressed: () => _showBulkEditSheet(dives),
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
              icon: const Icon(Icons.upload, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: 'Export Selected',
              onPressed: () => _showExportDialog(dives),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit Selected',
              onPressed: () => _showBulkEditSheet(dives),
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
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final chips = <Widget>[];

    if (filter.startDate != null || filter.endDate != null) {
      String dateText;
      if (filter.startDate != null && filter.endDate != null) {
        dateText =
            '${units.formatMonthDay(filter.startDate)} - ${units.formatMonthDay(filter.endDate)}';
      } else if (filter.startDate != null) {
        dateText = 'From ${units.formatMonthDay(filter.startDate)}';
      } else {
        dateText = 'Until ${units.formatMonthDay(filter.endDate)}';
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
