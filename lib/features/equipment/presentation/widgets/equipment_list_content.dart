import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// Special filter value for computed "service due" items
const String _serviceDueFilter = '_service_due_';

/// Content widget for the equipment list, used in master-detail layout.
class EquipmentListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const EquipmentListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<EquipmentListContent> createState() =>
      _EquipmentListContentState();
}

class _EquipmentListContentState extends ConsumerState<EquipmentListContent> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;
  Object? _selectedFilter;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EquipmentListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
      }
      // External selection changes are handled by _buildEquipmentList
      // when the sorted data is available.
    }
  }

  /// Scroll the list to bring the item at [index] into view.
  ///
  /// Uses an estimated item height (Card + ListTile ~ 80px) since
  /// ListView.builder is lazy and off-screen items have no context.
  void _scrollToIndex(int index) {
    if (!mounted || !_scrollController.hasClients) return;

    const estimatedItemHeight = 80.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * estimatedItemHeight) - (viewportHeight / 3);
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _lastScrolledToId = widget.selectedId;
  }

  void _handleItemTap(EquipmentItem equipment) {
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(equipment.id);
    } else {
      context.push('/equipment/${equipment.id}');
    }
  }

  void _invalidateCurrentProvider(WidgetRef ref) {
    if (_selectedFilter == _serviceDueFilter) {
      ref.invalidate(serviceDueEquipmentProvider);
    } else {
      final status = _selectedFilter as EquipmentStatus?;
      ref.invalidate(equipmentByStatusProvider(status));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sort = ref.watch(equipmentSortProvider);

    final AsyncValue<List<EquipmentItem>> equipmentAsync;
    if (_selectedFilter == _serviceDueFilter) {
      equipmentAsync = ref.watch(serviceDueEquipmentProvider);
    } else {
      final status = _selectedFilter as EquipmentStatus?;
      equipmentAsync = ref.watch(equipmentByStatusProvider(status));
    }

    final content = equipmentAsync.when(
      data: (equipment) {
        final sorted = applyEquipmentSorting(equipment, sort);
        return sorted.isEmpty
            ? _buildEmptyState(context, ref)
            : _buildEquipmentList(context, ref, sorted);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    if (!widget.showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          _buildFilterChips(context),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.equipment_appBar_title),
        actions: [
          ListViewModeToggle(
            currentMode: ref.watch(equipmentListViewModeProvider),
            availableModes: const [ListViewMode.detailed, ListViewMode.dense],
            onModeChanged: (mode) {
              ref.read(equipmentListViewModeProvider.notifier).state = mode;
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.equipment_list_sortTooltip,
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.l10n.equipment_list_searchTooltip,
            onPressed: () {
              showSearch(context: context, delegate: EquipmentSearchDelegate());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(context),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
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
            context.l10n.equipment_appBar_title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          ListViewModeToggle(
            currentMode: ref.watch(equipmentListViewModeProvider),
            availableModes: const [ListViewMode.detailed, ListViewMode.dense],
            onModeChanged: (mode) {
              ref.read(equipmentListViewModeProvider.notifier).state = mode;
            },
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.equipment_list_sortTooltip,
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.equipment_list_searchTooltip,
            onPressed: () {
              showSearch(context: context, delegate: EquipmentSearchDelegate());
            },
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(equipmentSortProvider);
    showSortBottomSheet<EquipmentSortField>(
      context: context,
      title: context.l10n.equipment_list_sortTitle,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: EquipmentSortField.values,
      getFieldDisplayName: (field) => field.displayName,
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(equipmentSortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.equipment_list_filterLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<Object?>(
                value: _selectedFilter,
                underline: const SizedBox(),
                focusColor: Colors.transparent,
                isExpanded: true,
                items: [
                  DropdownMenuItem<Object?>(
                    value: null,
                    child: Text(context.l10n.equipment_list_filterAll),
                  ),
                  DropdownMenuItem<Object?>(
                    value: _serviceDueFilter,
                    child: Text(context.l10n.equipment_list_filterServiceDue),
                  ),
                  ...EquipmentStatus.values
                      .where((status) => status != EquipmentStatus.needsService)
                      .map((status) {
                        return DropdownMenuItem<Object?>(
                          value: status,
                          child: Text(status.displayName),
                        );
                      }),
                ],
                onChanged: (value) {
                  setState(() => _selectedFilter = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentList(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentItem> equipment,
  ) {
    // Scroll to selected item when data is available but we haven't
    // scrolled yet (e.g., navigated from dive detail or set detail).
    if (widget.selectedId != null &&
        widget.selectedId != _lastScrolledToId &&
        !_selectionFromList) {
      final selectedIndex = equipment.indexWhere(
        (e) => e.id == widget.selectedId,
      );
      if (selectedIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(selectedIndex);
        });
      }
    }
    return RefreshIndicator(
      onRefresh: () async {
        _invalidateCurrentProvider(ref);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: equipment.length,
        itemBuilder: (context, index) {
          final item = equipment[index];
          final isSelected = widget.selectedId == item.id;
          final viewMode = ref.watch(equipmentListViewModeProvider);
          return switch (viewMode) {
            ListViewMode.detailed || ListViewMode.compact => EquipmentListTile(
              item: item,
              isSelected: isSelected,
              onTap: () => _handleItemTap(item),
            ),
            ListViewMode.dense => DenseEquipmentListTile(
              item: item,
              isSelected: isSelected,
              onTap: () => _handleItemTap(item),
            ),
          };
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    String filterText;
    if (_selectedFilter == null) {
      filterText = context.l10n.equipment_list_emptyState_filterText_equipment;
    } else if (_selectedFilter == _serviceDueFilter) {
      filterText = context.l10n.equipment_list_emptyState_filterText_serviceDue;
    } else {
      filterText = context.l10n.equipment_list_emptyState_filterText_status(
        (_selectedFilter as EquipmentStatus).displayName.toLowerCase(),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backpack,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.equipment_list_emptyState_noEquipment(filterText),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == null
                ? context.l10n.equipment_list_emptyState_addPrompt
                : _selectedFilter == _serviceDueFilter
                ? context.l10n.equipment_list_emptyState_serviceDueUpToDate
                : context.l10n.equipment_list_emptyState_noStatusMatch,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedFilter == null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (ResponsiveBreakpoints.isMasterDetail(context)) {
                  final routerState = GoRouterState.of(context);
                  context.go('${routerState.uri.path}?mode=new');
                } else {
                  context.push('/equipment/new');
                }
              },
              icon: const Icon(Icons.add),
              label: Text(
                context.l10n.equipment_list_emptyState_addFirstButton,
              ),
            ),
          ],
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
          Text(context.l10n.equipment_list_errorLoading('$error')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _invalidateCurrentProvider(ref),
            child: Text(context.l10n.equipment_list_retryButton),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying equipment
class EquipmentListTile extends StatelessWidget {
  final EquipmentItem item;
  final bool isSelected;
  final VoidCallback? onTap;

  const EquipmentListTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: item.isServiceDue
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.tertiaryContainer,
          child: Icon(
            _getIconForType(item.type),
            color: item.isServiceDue
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onTertiaryContainer,
          ),
        ),
        title: Text(item.name),
        subtitle: item.fullName != item.name ? Text(item.fullName) : null,
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final theme = Theme.of(context);

    final typeLabel = Text(
      item.type.displayName,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (item.isServiceDue) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          typeLabel,
          const SizedBox(height: 2),
          Text(
            'Service Due',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (item.daysUntilService != null) {
      final days = item.daysUntilService!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          typeLabel,
          const SizedBox(height: 2),
          Text(
            'Service in $days days',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (item.status != EquipmentStatus.active) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          typeLabel,
          const SizedBox(height: 2),
          Text(
            item.status.displayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return typeLabel;
  }

  IconData _getIconForType(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.accessibility_new;
      case EquipmentType.wetsuit:
      case EquipmentType.drysuit:
        return Icons.checkroom;
      case EquipmentType.fins:
        return Icons.directions_walk;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.tank:
        return MdiIcons.divingScubaTank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      default:
        return Icons.backpack;
    }
  }
}

/// Search delegate for equipment
class EquipmentSearchDelegate extends SearchDelegate<EquipmentItem?> {
  EquipmentSearchDelegate();

  @override
  String get searchFieldLabel => 'Search equipment...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear Search',
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
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
              'Search by name, brand, model, or serial number',
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
    return DebouncedSearchResults<EquipmentItem>(
      query: query,
      watchProvider: (ref, q) => ref.watch(equipmentSearchProvider(q)),
      dataBuilder: (context, equipment) {
        return ListView.builder(
          itemCount: equipment.length,
          itemBuilder: (context, index) {
            final item = equipment[index];
            return EquipmentListTile(
              item: item,
              onTap: () {
                close(context, item);
                context.push('/equipment/${item.id}');
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
                'No equipment found for "$query"',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error) {
        return Center(child: Text('Error: $error'));
      },
    );
  }
}
