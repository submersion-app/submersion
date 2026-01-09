import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/trip_providers.dart';

/// Summary widget shown when no trip is selected.
class TripSummaryWidget extends ConsumerWidget {
  const TripSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListNotifierProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            tripsAsync.when(
              data: (trips) => _buildOverview(context, trips),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Trips',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select a trip from the list to view details',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context, List trips) {
    // Calculate stats
    num totalDives = 0;
    num totalDays = 0;
    int liveaboardCount = 0;
    double? maxDepth;

    for (final tripWithStats in trips) {
      totalDives += tripWithStats.diveCount as num;
      totalDays += tripWithStats.trip.durationDays as num;
      if (tripWithStats.trip.isLiveaboard) liveaboardCount++;
      if (tripWithStats.maxDepth != null) {
        if (maxDepth == null || tripWithStats.maxDepth > maxDepth) {
          maxDepth = tripWithStats.maxDepth;
        }
      }
    }

    // Find upcoming trips
    final now = DateTime.now();
    final upcomingTrips =
        trips.where((t) => t.trip.startDate.isAfter(now)).toList()
          ..sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.flight_takeoff,
              value: '${trips.length}',
              label: 'Total Trips',
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.scuba_diving,
              value: '$totalDives',
              label: 'Total Dives',
              color: Colors.teal,
            ),
            _buildStatCard(
              context,
              icon: Icons.calendar_today,
              value: '$totalDays',
              label: 'Days Diving',
              color: Colors.green,
            ),
            if (liveaboardCount > 0)
              _buildStatCard(
                context,
                icon: Icons.sailing,
                value: '$liveaboardCount',
                label: 'Liveaboards',
                color: Colors.indigo,
              ),
          ],
        ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTripListPreview(context, trips),
        ],
        if (upcomingTrips.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildUpcomingTrips(context, upcomingTrips),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripListPreview(BuildContext context, List trips) {
    // Sort by start date descending and take recent 3
    final sortedTrips = List.from(trips)
      ..sort((a, b) => b.trip.startDate.compareTo(a.trip.startDate));
    final previewTrips = sortedTrips.take(3).toList();
    final dateFormat = DateFormat.yMMMd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Trips',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: previewTrips.map((tripWithStats) {
              final trip = tripWithStats.trip;
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
                  '${dateFormat.format(trip.startDate)} • ${tripWithStats.diveCount} dives',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.go('$currentPath?selected=${trip.id}');
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTrips(BuildContext context, List upcomingTrips) {
    final dateFormat = DateFormat.yMMMd();
    final nextTrip = upcomingTrips.first;
    final daysUntil = nextTrip.trip.startDate.difference(DateTime.now()).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                nextTrip.trip.isLiveaboard
                    ? Icons.sailing
                    : Icons.flight_takeoff,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            title: Text(
              nextTrip.trip.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${dateFormat.format(nextTrip.trip.startDate)} • In $daysUntil days',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onTap: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=${nextTrip.trip.id}');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Trip'),
            ),
          ],
        ),
      ],
    );
  }
}
