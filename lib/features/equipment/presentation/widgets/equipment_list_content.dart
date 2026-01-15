import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

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
  void didUpdateWidget(EquipmentListContent oldWidget) {
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

    final AsyncValue<List<EquipmentItem>> equipmentAsync;
    if (_selectedFilter == _serviceDueFilter) {
      equipmentAsync = ref.read(serviceDueEquipmentProvider);
    } else {
      final status = _selectedFilter as EquipmentStatus?;
      equipmentAsync = ref.read(equipmentByStatusProvider(status));
    }

    equipmentAsync.whenData((equipment) {
      final index = equipment.indexWhere((e) => e.id == widget.selectedId);
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || equipment.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / equipment.length;
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
    final AsyncValue<List<EquipmentItem>> equipmentAsync;
    if (_selectedFilter == _serviceDueFilter) {
      equipmentAsync = ref.watch(serviceDueEquipmentProvider);
    } else {
      final status = _selectedFilter as EquipmentStatus?;
      equipmentAsync = ref.watch(equipmentByStatusProvider(status));
    }

    final content = equipmentAsync.when(
      data: (equipment) => equipment.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildEquipmentList(context, ref, equipment),
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
        title: const Text('Equipment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Equipment Sets',
            onPressed: () => context.push('/equipment/sets'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
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
            'Equipment',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.folder_outlined, size: 20),
            tooltip: 'Equipment Sets',
            onPressed: () => context.push('/equipment/sets'),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {
              showSearch(context: context, delegate: EquipmentSearchDelegate());
            },
          ),
        ],
      ),
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
            'Filter:',
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
                  const DropdownMenuItem<Object?>(
                    value: null,
                    child: Text('All Equipment'),
                  ),
                  const DropdownMenuItem<Object?>(
                    value: _serviceDueFilter,
                    child: Text('Service Due'),
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
          return EquipmentListTile(
            item: item,
            isSelected: isSelected,
            onTap: () => _handleItemTap(item),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    String filterText;
    if (_selectedFilter == null) {
      filterText = 'equipment';
    } else if (_selectedFilter == _serviceDueFilter) {
      filterText = 'equipment needing service';
    } else {
      filterText =
          '${(_selectedFilter as EquipmentStatus).displayName.toLowerCase()} equipment';
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
            'No $filterText',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == null
                ? 'Add your diving equipment to track usage and service'
                : _selectedFilter == _serviceDueFilter
                ? 'All your equipment is up to date on service!'
                : 'No equipment with this status',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedFilter == null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/equipment/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Equipment'),
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
          Text('Error loading equipment: $error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _invalidateCurrentProvider(ref),
            child: const Text('Retry'),
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
        subtitle: item.fullName != item.name
            ? Text(item.fullName)
            : Text(item.type.displayName),
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    if (item.isServiceDue) {
      return Chip(
        label: const Text('Service Due'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontSize: 12,
        ),
      );
    }

    if (item.daysUntilService != null) {
      final days = item.daysUntilService!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Service in',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$days days',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    if (item.status != EquipmentStatus.active) {
      return Chip(
        label: Text(item.status.displayName),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontSize: 12,
        ),
      );
    }

    return null;
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
        return Icons.propane_tank;
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
    return Consumer(
      builder: (context, ref, child) {
        final searchAsync = ref.watch(equipmentSearchProvider(query));

        return searchAsync.when(
          data: (equipment) {
            if (equipment.isEmpty) {
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
            }

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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        );
      },
    );
  }
}
