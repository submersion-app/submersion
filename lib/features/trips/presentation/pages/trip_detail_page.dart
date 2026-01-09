import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../../../dive_log/domain/entities/dive.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_providers.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  final String tripId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const TripDetailPage({
    super.key,
    required this.tripId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: If accessed directly (not embedded), redirect to master-detail view
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isDesktop(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/trips?selected=${widget.tripId}');
        }
      });
    }

    final tripAsync = ref.watch(tripWithStatsProvider(widget.tripId));

    return tripAsync.when(
      data: (tripWithStats) => _TripDetailContent(
        tripWithStats: tripWithStats,
        embedded: widget.embedded,
        onDeleted: widget.onDeleted,
      ),
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(title: const Text('Trip')),
              body: const Center(child: CircularProgressIndicator()),
            ),
      error: (error, stack) => widget.embedded
          ? Center(child: Text('Error: $error'))
          : Scaffold(
              appBar: AppBar(title: const Text('Trip')),
              body: Center(child: Text('Error: $error')),
            ),
    );
  }
}

class _TripDetailContent extends ConsumerWidget {
  final TripWithStats tripWithStats;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _TripDetailContent({
    required this.tripWithStats,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;
    final divesAsync = ref.watch(divesForTripProvider(trip.id));
    final dateFormat = DateFormat.yMMMd();

    final body = SingleChildScrollView(
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
          _buildDivesSection(context, ref, divesAsync),
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, trip),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/trips/${trip.id}/edit'),
          ),
          _buildMoreMenu(context, ref, trip),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.MMMd();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=${trip.id}&mode=edit');
            },
            tooltip: 'Edit',
          ),
          _buildMoreMenu(context, ref, trip),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, WidgetRef ref, Trip trip) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'delete') {
          final confirmed = await _showDeleteConfirmation(context);
          if (confirmed && context.mounted) {
            await ref.read(tripListNotifierProvider.notifier).deleteTrip(trip.id);
            if (context.mounted) {
              if (embedded) {
                onDeleted?.call();
              } else {
                context.pop();
              }
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
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
    AsyncValue<List<Dive>> divesAsync,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                divesAsync.when(
                  data: (dives) => TextButton(
                    onPressed: dives.isEmpty
                        ? null
                        : () {
                            ref.read(diveFilterProvider.notifier).state =
                                DiveFilterState(tripId: tripWithStats.trip.id);
                            context.go('/dives');
                          },
                    child: Text('View All (${dives.length})'),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            divesAsync.when(
              data: (dives) {
                if (dives.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No dives in this trip yet')),
                  );
                }
                final sortedDives = List<Dive>.from(dives)
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                final displayDives = sortedDives.take(5).toList();
                return Column(
                  children: displayDives.map((dive) {
                    return InkWell(
                      onTap: () => context.push('/dives/${dive.id}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#${dive.diveNumber ?? '-'}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dive.site?.name ?? 'Unknown Site',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateFormat.format(dive.dateTime),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (dive.maxDepth != null)
                                  Text(
                                    '${dive.maxDepth!.toStringAsFixed(1)}m',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (dive.duration != null)
                                  Text(
                                    '${dive.duration!.inMinutes}min',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
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
              error: (e, st) => const Text('Unable to load dives'),
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
