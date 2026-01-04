import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/trip.dart';
import '../providers/trip_providers.dart';

class TripDetailPage extends ConsumerWidget {
  final String tripId;

  const TripDetailPage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripWithStatsProvider(tripId));

    return tripAsync.when(
      data: (tripWithStats) => _TripDetailContent(tripWithStats: tripWithStats),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _TripDetailContent extends ConsumerWidget {
  final TripWithStats tripWithStats;

  const _TripDetailContent({required this.tripWithStats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;
    final diveIdsAsync = ref.watch(diveIdsForTripProvider(trip.id));
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/trips/${trip.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await _showDeleteConfirmation(context);
                if (confirmed && context.mounted) {
                  await ref
                      .read(tripListNotifierProvider.notifier)
                      .deleteTrip(trip.id);
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip deleted')),
                    );
                  }
                }
              } else if (value == 'export') {
                _showExportOptions(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip header
            _buildTripHeader(context, trip, dateFormat),
            const SizedBox(height: 24),

            // Trip info
            if (trip.location != null ||
                trip.resortName != null ||
                trip.liveaboardName != null) ...[
              _buildInfoSection(context, trip),
              const SizedBox(height: 24),
            ],

            // Statistics
            _buildStatsSection(context),
            const SizedBox(height: 24),

            // Notes
            if (trip.notes.isNotEmpty) ...[
              _buildNotesSection(context, trip),
              const SizedBox(height: 24),
            ],

            // Dives
            _buildDivesSection(context, ref, diveIdsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeader(
    BuildContext context,
    Trip trip,
    DateFormat dateFormat,
  ) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
              size: 50,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            trip.name,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${trip.durationDays} days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Trip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (trip.location != null)
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Location'),
                subtitle: Text(trip.location!),
                contentPadding: EdgeInsets.zero,
              ),
            if (trip.resortName != null)
              ListTile(
                leading: const Icon(Icons.hotel),
                title: const Text('Resort'),
                subtitle: Text(trip.resortName!),
                contentPadding: EdgeInsets.zero,
              ),
            if (trip.liveaboardName != null)
              ListTile(
                leading: const Icon(Icons.sailing),
                title: const Text('Liveaboard'),
                subtitle: Text(trip.liveaboardName!),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.scuba_diving,
              label: 'Total Dives',
              value: tripWithStats.diveCount.toString(),
            ),
            _StatRow(
              icon: Icons.timer,
              label: 'Total Bottom Time',
              value: tripWithStats.formattedBottomTime,
            ),
            if (tripWithStats.maxDepth != null)
              _StatRow(
                icon: Icons.arrow_downward,
                label: 'Max Depth',
                value: '${tripWithStats.maxDepth!.toStringAsFixed(1)} m',
              ),
            if (tripWithStats.avgDepth != null)
              _StatRow(
                icon: Icons.trending_flat,
                label: 'Avg Depth',
                value: '${tripWithStats.avgDepth!.toStringAsFixed(1)} m',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, Trip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(trip.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildDivesSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<String>> diveIdsAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dives',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                diveIdsAsync.when(
                  data: (ids) => TextButton(
                    onPressed: ids.isEmpty
                        ? null
                        : () {
                            // Navigate to filtered dive list (future enhancement)
                          },
                    child: Text('View All (${ids.length})'),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            diveIdsAsync.when(
              data: (ids) {
                if (ids.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No dives in this trip yet')),
                  );
                }
                // Show first 5 dive IDs as tappable items
                final displayIds = ids.take(5).toList();
                return Column(
                  children: displayIds.map((diveId) {
                    return ListTile(
                      leading: const Icon(Icons.scuba_diving),
                      title: const Text('Dive'),
                      subtitle: Text(diveId.substring(0, 8)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/dives/$diveId'),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
              error: (_, _) => const Text('Unable to load dives'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Trip?'),
            content: Text(
              'Are you sure you want to delete "${tripWithStats.trip.name}"? This will remove the trip but keep the dives.',
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
        ) ??
        false;
  }

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Export to CSV'),
              subtitle: const Text('All dives in this trip'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV export coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export to PDF'),
              subtitle: const Text('Trip summary with dive details'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
