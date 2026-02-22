import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Content widget for the trip list, used in master-detail layout.
class TripListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const TripListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<TripListContent> createState() => _TripListContentState();
}

class _TripListContentState extends ConsumerState<TripListContent> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;

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
  void didUpdateWidget(TripListContent oldWidget) {
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

    final tripsAsync = ref.read(tripListNotifierProvider);
    tripsAsync.whenData((trips) {
      final index = trips.indexWhere((t) => t.trip.id == widget.selectedId);
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || trips.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / trips.length;
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

  void _handleItemTap(Trip trip) {
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(trip.id);
    } else {
      context.push('/trips/${trip.id}');
    }
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(tripSortProvider);

    showSortBottomSheet<TripSortField>(
      context: context,
      title: context.l10n.trips_list_sort_title,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: TripSortField.values,
      getFieldDisplayName: (field) => field.displayName,
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(tripSortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(tripFilterProvider);
    final tripsAsync = ref.watch(sortedFilteredTripsProvider);

    final content = tripsAsync.when(
      data: (trips) => trips.isEmpty
          ? _buildEmptyState(context, filter.hasActiveFilters)
          : _buildTripList(context, ref, trips, filter.hasActiveFilters),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    if (!widget.showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trips_appBar_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.l10n.trips_list_tooltip_search,
            onPressed: () {
              showSearch(context: context, delegate: TripSearchDelegate());
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.trips_list_tooltip_sort,
            onPressed: () => _showSortSheet(context),
          ),
        ],
      ),
      body: content,
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
            context.l10n.trips_appBar_title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.trips_list_tooltip_search,
            onPressed: () {
              showSearch(context: context, delegate: TripSearchDelegate());
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.trips_list_tooltip_sort,
            onPressed: () => _showSortSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tripFilterProvider);
    final chips = <Widget>[];

    if (filter.equipmentId != null) {
      final equipmentName =
          ref.watch(equipmentItemProvider(filter.equipmentId!)).value?.name ??
          'Equipment';
      chips.add(
        InputChip(
          label: Text(equipmentName),
          onDeleted: () {
            ref.read(tripFilterProvider.notifier).state = filter.copyWith(
              clearEquipmentId: true,
            );
          },
          deleteIcon: const Icon(Icons.close, size: 18),
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
              child: Row(
                children: chips
                    .map(
                      (chip) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: chip,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(tripFilterProvider.notifier).state =
                  const TripFilterState();
            },
            child: Text(context.l10n.trips_list_filters_clearAll),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList(
    BuildContext context,
    WidgetRef ref,
    List<TripWithStats> trips,
    bool hasActiveFilters,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(tripListNotifierProvider.notifier).refresh();
      },
      child: Column(
        children: [
          if (hasActiveFilters) _buildActiveFiltersBar(context, ref),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final tripWithStats = trips[index];
                final isSelected = widget.selectedId == tripWithStats.trip.id;
                return TripListTile(
                  tripWithStats: tripWithStats,
                  isSelected: isSelected,
                  onTap: () => _handleItemTap(tripWithStats.trip),
                );
              },
            ),
          ),
        ],
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
              context.l10n.trips_list_empty_filtered_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.trips_list_empty_filtered_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
            Icons.flight_takeoff,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.trips_list_empty_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_list_empty_subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              if (ResponsiveBreakpoints.isMasterDetail(context)) {
                final routerState = GoRouterState.of(context);
                context.go('${routerState.uri.path}?mode=new');
              } else {
                context.push('/trips/new');
              }
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.trips_list_empty_button),
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
          Text(context.l10n.trips_list_error_loading('$error')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(tripListNotifierProvider.notifier).refresh(),
            child: Text(context.l10n.trips_list_button_retry),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a trip
class TripListTile extends StatelessWidget {
  final TripWithStats tripWithStats;
  final bool isSelected;
  final VoidCallback? onTap;

  const TripListTile({
    super.key,
    required this.tripWithStats,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trip = tripWithStats.trip;
    final dateFormat = DateFormat.yMMMd();
    final theme = Theme.of(context);

    final subtitleStr = trip.subtitle != null ? ', ${trip.subtitle}' : '';
    final diveCountStr = '${tripWithStats.diveCount} dives';
    final bottomTimeStr = tripWithStats.totalBottomTime > 0
        ? ', ${tripWithStats.formattedBottomTime}'
        : '';
    final tripLabel =
        '${trip.name}, ${dateFormat.format(trip.startDate)} to ${dateFormat.format(trip.endDate)}$subtitleStr, $diveCountStr$bottomTimeStr${isSelected ? ', selected' : ''}';

    return Semantics(
      label: tripLabel,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(trip.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
                style: theme.textTheme.bodySmall,
              ),
              if (trip.subtitle != null)
                Text(
                  trip.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.scuba_diving,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.trips_list_tile_diveCount(
                      tripWithStats.diveCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (tripWithStats.totalBottomTime > 0) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tripWithStats.formattedBottomTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          isThreeLine: true,
        ),
      ),
    );
  }
}

/// Search delegate for trips
class TripSearchDelegate extends SearchDelegate<Trip?> {
  TripSearchDelegate();

  @override
  String get searchFieldLabel => 'Search trips...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.l10n.trips_search_tooltip_clear,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.trips_search_tooltip_back,
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
              context.l10n.trips_search_empty_hint,
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
        final searchAsync = ref.watch(tripSearchProvider(query));

        return searchAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
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
                      context.l10n.trips_search_noResults(query),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                final dateFormat = DateFormat.yMMMd();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(trip.name),
                  subtitle: Text(
                    '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
                  ),
                  onTap: () {
                    close(context, trip);
                    context.push('/trips/${trip.id}');
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('${context.l10n.common_label_error}: $error')),
        );
      },
    );
  }
}
