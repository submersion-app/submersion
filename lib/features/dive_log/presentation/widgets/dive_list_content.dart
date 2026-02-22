import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/card_color.dart';
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
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_numbering_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList =
      false; // Track if selection originated from list tap

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

  /// Scroll the list to show the selected item
  void _scrollToSelectedItem() {
    if (widget.selectedId == null) return;

    // Get the current dive list from the paginated provider
    final divesAsync = ref.read(paginatedDiveListProvider);
    divesAsync.whenData((paginatedState) {
      final dives = paginatedState.dives;
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

  void _showBulkEditSheet() {
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
                    context.l10n.diveLog_bulkEdit_title(count),
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
              leading: const Icon(Icons.flight),
              title: Text(context.l10n.diveLog_bulkEdit_changeTrip),
              subtitle: Text(
                context.l10n.diveLog_bulkEdit_changeTripDescription,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showTripSelector();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: Text(context.l10n.diveLog_bulkEdit_addTags),
              subtitle: Text(context.l10n.diveLog_bulkEdit_addTagsDescription),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddTagsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_off),
              title: Text(context.l10n.diveLog_bulkEdit_removeTags),
              subtitle: Text(
                context.l10n.diveLog_bulkEdit_removeTagsDescription,
              ),
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
        title: Text(context.l10n.diveLog_bulkEdit_selectTrip),
        content: SizedBox(
          width: double.maxFinite,
          child: trips.when(
            data: (tripList) => ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: Text(context.l10n.diveLog_bulkEdit_noTrip),
                  subtitle: Text(context.l10n.diveLog_bulkEdit_removeFromTrip),
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
            error: (_, _) =>
                Text(context.l10n.diveLog_bulkEdit_errorLoadingTrips),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_action_cancel),
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
          .read(paginatedDiveListProvider.notifier)
          .bulkUpdateTrip(diveIds, tripId);

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tripId == null
                  ? context.l10n.diveLog_bulkEdit_removedFromTrip(count)
                  : context.l10n.diveLog_bulkEdit_movedToTrip(count),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_bulkEdit_failedUpdateTrip(e.toString()),
            ),
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
          SnackBar(
            content: Text(context.l10n.diveLog_bulkEdit_noTagsAvailableCreate),
          ),
        );
        return;
      }

      final selectedTagIds = <String>{};

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(context.l10n.diveLog_bulkEdit_addTags),
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
                child: Text(context.l10n.common_action_cancel),
              ),
              FilledButton(
                onPressed: selectedTagIds.isEmpty
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _bulkAddTags(selectedTagIds.toList());
                      },
                child: Text(context.l10n.diveLog_edit_add),
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
          .read(paginatedDiveListProvider.notifier)
          .bulkAddTags(diveIds, tagIds);

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_bulkEdit_addedTags(tagIds.length, count),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_bulkEdit_failedAddTags(e.toString()),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_bulkEdit_noTagsAvailable),
          ),
        );
        return;
      }

      final selectedTagIds = <String>{};

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(context.l10n.diveLog_bulkEdit_removeTags),
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
                child: Text(context.l10n.common_action_cancel),
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
                child: Text(context.l10n.diveLog_bulkEdit_removeTags),
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
          .read(paginatedDiveListProvider.notifier)
          .bulkRemoveTags(diveIds, tagIds);

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed ${tagIds.length} ${tagIds.length == 1 ? 'tag' : 'tags'} from $count ${count == 1 ? 'dive' : 'dives'}', // TODO: l10n
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove tags: $e'), // TODO: l10n
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final paginatedAsync = ref.watch(paginatedDiveListProvider);
    final filter = ref.watch(diveFilterProvider);

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

  AppBar _buildAppBar(BuildContext context, DiveFilterState filter) {
    return AppBar(
      title: Text(context.l10n.diveLog_listPage_title),
      actions: [
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
          onSelected: (value) {
            if (value == 'numbering') {
              showDiveNumberingDialog(context);
            } else if (value == 'advanced_search') {
              context.go('/dives/search');
            }
          },
          itemBuilder: (context) => [
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
            context.l10n.diveLog_listPage_compactTitle,
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
              tooltip: context.l10n.diveLog_listPage_tooltip_mapView,
              onPressed: () => context.push('/dives/activity'),
            ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            visualDensity: VisualDensity.compact,
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
            visualDensity: VisualDensity.compact,
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
            visualDensity: VisualDensity.compact,
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
              }
            },
            itemBuilder: (context) => [
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
            ],
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
            onPressed: _showBulkEditSheet,
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
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.diveLog_selection_tooltip_exit,
            onPressed: _exitSelectionMode,
          ),
          Text(
            context.l10n.diveLog_selection_countSelected(_selectedIds.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          if (_selectedIds.length < dives.length)
            IconButton(
              icon: const Icon(Icons.select_all, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.diveLog_selection_tooltip_selectAll,
              onPressed: () => _selectAll(dives),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.upload, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.diveLog_selection_tooltip_export,
              onPressed: _showExportDialog,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.diveLog_selection_tooltip_edit,
              onPressed: _showBulkEditSheet,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.diveLog_selection_tooltip_delete,
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
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
                return DiveListTile(
                  diveId: dive.id,
                  diveNumber: dive.diveNumber ?? index + 1,
                  dateTime: dive.dateTime,
                  siteName: dive.siteName,
                  siteLocation: dive.siteLocation,
                  maxDepth: dive.maxDepth,
                  duration: dive.duration,
                  waterTemp: dive.waterTemp,
                  rating: dive.rating,
                  isFavorite: dive.isFavorite,
                  tags: dive.tags,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected || isMasterSelected,
                  colorValue: getCardColorValue(dive, colorAttribute),
                  minValueInList: minValue,
                  maxValueInList: maxValue,
                  gradientStartColor: gradientColors.start,
                  gradientEndColor: gradientColors.end,
                  siteLatitude: dive.siteLatitude,
                  siteLongitude: dive.siteLongitude,
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
              onLogManually: () => context.go('/dives/new'),
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
