import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/alerts_card.dart';
import '../widgets/quick_actions_card.dart';
import '../widgets/recent_dives_card.dart';
import '../widgets/stat_summary_card.dart';

/// Dashboard home page showing at-a-glance dive statistics and alerts
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);
    final diverAsync = ref.watch(dashboardDiverProvider);

    return Scaffold(
      appBar: AppBar(
        title: diverAsync.when(
          data: (diver) => Text(
            diver != null
                ? 'Welcome, ${diver.name.split(' ').first}'
                : 'Dashboard',
          ),
          loading: () => const Text('Dashboard'),
          error: (_, __) => const Text('Dashboard'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(diveStatisticsProvider);
          ref.invalidate(recentDivesProvider);
          ref.invalidate(dashboardAlertsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Stats Section
              _buildStatsSection(context, statsAsync),
              const SizedBox(height: 16),
              // Alerts Section (only shows if there are alerts)
              const AlertsCard(),
              // Recent Dives Section
              const RecentDivesCard(),
              const SizedBox(height: 16),
              // Quick Actions Section
              const QuickActionsCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    AsyncValue<DiveStatistics> statsAsync,
  ) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'At a Glance',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        statsAsync.when(
          data: (stats) => _buildStatsGrid(context, stats, isWide),
          loading: () => _buildStatsGridLoading(isWide),
          error: (error, _) => _buildStatsGridError(context),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    DiveStatistics stats,
    bool isWide,
  ) {
    final cards = [
      StatSummaryCard(
        icon: Icons.waves,
        label: 'Total Dives',
        value: '${stats.totalDives}',
        iconColor: Colors.blue,
      ),
      StatSummaryCard(
        icon: Icons.timer,
        label: 'Hours Logged',
        value: _formatHours(stats.totalTimeSeconds),
        iconColor: Colors.teal,
      ),
      StatSummaryCard(
        icon: Icons.arrow_downward,
        label: 'Max Depth',
        value:
            stats.maxDepth > 0 ? '${stats.maxDepth.toStringAsFixed(1)}m' : '-',
        iconColor: Colors.indigo,
      ),
      StatSummaryCard(
        icon: Icons.location_on,
        label: 'Sites Visited',
        value: '${stats.totalSites}',
        iconColor: Colors.orange,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((card) => Expanded(child: card)).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: cards,
    );
  }

  Widget _buildStatsGridLoading(bool isWide) {
    final placeholders = List.generate(
      4,
      (_) => const Card(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    if (isWide) {
      return Row(
        children: placeholders.map((p) => Expanded(child: p)).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: placeholders,
    );
  }

  Widget _buildStatsGridError(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load statistics',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHours(int totalSeconds) {
    final hours = totalSeconds / 3600;
    if (hours < 1) {
      final minutes = totalSeconds ~/ 60;
      return '${minutes}m';
    }
    if (hours < 10) {
      return hours.toStringAsFixed(1);
    }
    return hours.round().toString();
  }
}
