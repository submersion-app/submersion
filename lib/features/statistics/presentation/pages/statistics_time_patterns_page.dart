import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/statistics_providers.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsTimePatternsPage extends ConsumerWidget {
  const StatisticsTimePatternsPage({super.key});

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Patterns'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDayOfWeekSection(context, ref),
            const SizedBox(height: 16),
            _buildTimeOfDaySection(context, ref),
            const SizedBox(height: 16),
            _buildSeasonalSection(context, ref),
            const SizedBox(height: 16),
            _buildSurfaceIntervalSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOfWeekSection(BuildContext context, WidgetRef ref) {
    final dayOfWeekAsync = ref.watch(divesByDayOfWeekProvider);

    return StatSectionCard(
      title: 'Dives by Day of Week',
      subtitle: 'When do you dive most?',
      child: dayOfWeekAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.calendar_today,
              message: 'No data available',
            );
          }
          // Fill in missing days with 0
          final fullData = List.generate(7, (day) {
            final existing = data.firstWhere(
              (d) => d.dayOfWeek == day,
              orElse: () => (dayOfWeek: day, count: 0),
            );
            return (label: _dayNames[day], count: existing.count);
          });
          return CategoryBarChart(
            data: fullData,
            barColor: Colors.blue,
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load day of week data',
        ),
      ),
    );
  }

  Widget _buildTimeOfDaySection(BuildContext context, WidgetRef ref) {
    final timeOfDayAsync = ref.watch(divesByTimeOfDayProvider);

    return StatSectionCard(
      title: 'Dives by Time of Day',
      subtitle: 'Morning, afternoon, evening, or night',
      child: timeOfDayAsync.when(
        data: (data) => DistributionPieChart(
          data: data,
          colors: const [
            Colors.amber, // Morning
            Colors.orange, // Afternoon
            Colors.deepOrange, // Evening
            Colors.indigo, // Night
          ],
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load time of day data',
        ),
      ),
    );
  }

  Widget _buildSeasonalSection(BuildContext context, WidgetRef ref) {
    final seasonalAsync = ref.watch(divesBySeasonProvider);

    return StatSectionCard(
      title: 'Seasonal Patterns',
      subtitle: 'Dives by month (all years)',
      child: seasonalAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.calendar_month,
              message: 'No data available',
            );
          }
          // Fill in missing months with 0
          final fullData = List.generate(12, (month) {
            final m = month + 1;
            final existing = data.firstWhere(
              (d) => d.month == m,
              orElse: () => (month: m, count: 0),
            );
            return (label: _monthNames[month], count: existing.count);
          });
          return CategoryBarChart(
            data: fullData,
            barColor: Colors.teal,
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load seasonal data',
        ),
      ),
    );
  }

  Widget _buildSurfaceIntervalSection(BuildContext context, WidgetRef ref) {
    final siStatsAsync = ref.watch(surfaceIntervalStatsProvider);

    return StatSectionCard(
      title: 'Surface Interval Statistics',
      subtitle: 'Time between dives',
      child: siStatsAsync.when(
        data: (data) {
          if (data.avgMinutes == null) {
            return const StatEmptyState(
              icon: Icons.timer,
              message: 'No surface interval data available',
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSiStat(
                  context,
                  'Average',
                  _formatMinutes(data.avgMinutes!),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSiStat(
                  context,
                  'Minimum',
                  _formatMinutes(data.minMinutes ?? 0),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSiStat(
                  context,
                  'Maximum',
                  _formatMinutes(data.maxMinutes ?? 0),
                  Colors.orange,
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load surface interval data',
        ),
      ),
    );
  }

  Widget _buildSiStat(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(double minutes) {
    if (minutes < 60) {
      return '${minutes.round()} min';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    return '${hours}h ${mins}m';
  }
}
