import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../equipment/presentation/providers/equipment_providers.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_providers.dart';

class TripListPage extends ConsumerWidget {
  const TripListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tripFilterProvider);
    final tripsAsync = filter.hasActiveFilters
        ? ref.watch(filteredTripsProvider)
        : ref.watch(tripListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: TripSearchDelegate());
            },
          ),
        ],
      ),
      body: tripsAsync.when(
        data: (trips) => trips.isEmpty
            ? _buildEmptyState(context, filter.hasActiveFilters)
            : _buildTripList(context, ref, trips, filter.hasActiveFilters),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading trips: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(tripListNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Trip'),
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
                        padding: const EdgeInsets.only(right: 8),
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
            child: const Text('Clear all'),
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
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final tripWithStats = trips[index];
                return TripListTile(
                  tripWithStats: tripWithStats,
                  onTap: () => context.push('/trips/${tripWithStats.trip.id}'),
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
              'No trips match your filters',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting or clearing your filters',
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
            'No trips added yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create trips to group your dives by destination',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/trips/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Trip'),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a trip
class TripListTile extends StatelessWidget {
  final TripWithStats tripWithStats;
  final VoidCallback? onTap;

  const TripListTile({super.key, required this.tripWithStats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final trip = tripWithStats.trip;
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(trip.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (trip.subtitle != null)
              Text(
                trip.subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.scuba_diving,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tripWithStats.diveCount} dives',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (tripWithStats.totalBottomTime > 0) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.timer,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tripWithStats.formattedBottomTime,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
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
              'Search by name, location, or resort',
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
    // Use Consumer to get a valid ref within the SearchDelegate
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
                      'No trips found for "$query"',
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
          error: (error, _) => Center(child: Text('Error: $error')),
        );
      },
    );
  }
}
