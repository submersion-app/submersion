import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(diveRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(diveRecordsProvider),
          ),
        ],
      ),
      body: recordsAsync.when(
        data: (records) => _buildContent(context, ref, records),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              const Text('Error loading records'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(diveRecordsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, DiveRecords records) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    
    final hasRecords = records.deepestDive != null ||
        records.longestDive != null ||
        records.coldestDive != null ||
        records.warmestDive != null;

    if (!hasRecords) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Records Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging dives to see your records here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (records.deepestDive != null)
          _buildRecordCard(
            context,
            title: 'Deepest Dive',
            icon: Icons.arrow_downward,
            color: Colors.blue,
            record: records.deepestDive!,
            value: units.formatDepth(records.deepestDive!.maxDepth),
          ),
        if (records.longestDive != null)
          _buildRecordCard(
            context,
            title: 'Longest Dive',
            icon: Icons.timer,
            color: Colors.green,
            record: records.longestDive!,
            value: '${records.longestDive!.duration?.inMinutes} min',
          ),
        if (records.coldestDive != null)
          _buildRecordCard(
            context,
            title: 'Coldest Dive',
            icon: Icons.ac_unit,
            color: Colors.cyan,
            record: records.coldestDive!,
            value: units.formatTemperature(records.coldestDive!.waterTemp),
          ),
        if (records.warmestDive != null)
          _buildRecordCard(
            context,
            title: 'Warmest Dive',
            icon: Icons.whatshot,
            color: Colors.orange,
            record: records.warmestDive!,
            value: units.formatTemperature(records.warmestDive!.waterTemp),
          ),
        if (records.shallowestDive != null)
          _buildRecordCard(
            context,
            title: 'Shallowest Dive',
            icon: Icons.arrow_upward,
            color: Colors.teal,
            record: records.shallowestDive!,
            value: units.formatDepth(records.shallowestDive!.maxDepth),
          ),
        const SizedBox(height: 24),
        Text(
          'Milestones',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (records.firstDive != null)
          _buildMilestoneCard(
            context,
            title: 'First Dive',
            icon: Icons.flag,
            color: Colors.purple,
            record: records.firstDive!,
          ),
        if (records.lastDive != null)
          _buildMilestoneCard(
            context,
            title: 'Most Recent Dive',
            icon: Icons.update,
            color: Colors.indigo,
            record: records.lastDive!,
          ),
      ],
    );
  }

  Widget _buildRecordCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required DiveRecord record,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/dives/${record.diveId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.siteName ?? 'Unknown Site',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(record.dateTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (record.diveNumber != null)
                    Text(
                      'Dive #${record.diveNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required DiveRecord record,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/dives/${record.diveId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      record.siteName ?? 'Unknown Site',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(record.dateTime),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (record.diveNumber != null)
                    Text(
                      'Dive #${record.diveNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
