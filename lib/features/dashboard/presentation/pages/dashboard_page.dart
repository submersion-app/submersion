import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_wallet_card.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/activity_status_row.dart';
import 'package:submersion/features/dashboard/presentation/widgets/alerts_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dashboard/presentation/widgets/personal_records_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/stat_summary_card.dart';

/// Dashboard home page showing dive statistics and alerts
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(diveStatisticsProvider);
            ref.invalidate(recentDivesProvider);
            ref.invalidate(dashboardAlertsProvider);
            ref.invalidate(daysSinceLastDiveProvider);
            ref.invalidate(monthlyDiveCountProvider);
            ref.invalidate(yearToDateDiveCountProvider);
            ref.invalidate(personalRecordsProvider);
            ref.invalidate(certificationListNotifierProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Header with personalized greeting
                const HeroHeader(),
                const SizedBox(height: 16),
                // Activity Status Row (days since last dive, monthly, YTD)
                const ActivityStatusRow(),
                const SizedBox(height: 16),
                // Key Stats Section
                _buildStatsSection(context, statsAsync, units),
                const SizedBox(height: 16),
                // Personal Records Section
                const PersonalRecordsCard(),
                const SizedBox(height: 16),
                // Certification Wallet
                const CertificationWalletCard(),
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
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    AsyncValue<DiveStatistics> statsAsync,
    UnitFormatter units,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return statsAsync.when(
      data: (stats) => _buildStatsGrid(context, stats, isWide, units),
      loading: () => _buildStatsGridLoading(isWide),
      error: (error, _) => _buildStatsGridError(context),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    DiveStatistics stats,
    bool isWide,
    UnitFormatter units,
  ) {
    final displayMaxDepth = units.convertDepth(stats.maxDepth);
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
        value: stats.maxDepth > 0
            ? '${displayMaxDepth.toStringAsFixed(1)}${units.depthSymbol}'
            : '-',
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
      return Row(children: cards.map((card) => Expanded(child: card)).toList());
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
      (_) => const Card(child: Center(child: CircularProgressIndicator())),
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
