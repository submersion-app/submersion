import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
                // Alerts Section (only shows if there are alerts)
                const AlertsCard(),
                const SizedBox(height: 16),
                // Recent Dives Section
                const RecentDivesCard(),
                const SizedBox(height: 16),
                // Personal Records Section
                const PersonalRecordsCard(),
                const SizedBox(height: 16),
                // Certification Wallet
                const CertificationWalletCard(),
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
    final hoursValue = _formatHours(stats.totalTimeSeconds);
    final maxDepthValue = stats.maxDepth > 0
        ? '${displayMaxDepth.toStringAsFixed(1)}${units.depthSymbol}'
        : '-';
    final cards = [
      Semantics(
        label: statLabel(
          name: context.l10n.dashboard_stats_totalDives,
          value: '${stats.totalDives}',
        ),
        child: StatSummaryCard(
          icon: Icons.waves,
          label: context.l10n.dashboard_stats_totalDives,
          value: '${stats.totalDives}',
          iconColor: Colors.blue,
        ),
      ),
      Semantics(
        label: statLabel(
          name: context.l10n.dashboard_stats_hoursLogged,
          value: hoursValue,
        ),
        child: StatSummaryCard(
          icon: Icons.timer,
          label: context.l10n.dashboard_stats_hoursLogged,
          value: hoursValue,
          iconColor: Colors.teal,
        ),
      ),
      Semantics(
        label: statLabel(
          name: context.l10n.dashboard_stats_maxDepth,
          value: maxDepthValue,
        ),
        child: StatSummaryCard(
          icon: Icons.arrow_downward,
          label: context.l10n.dashboard_stats_maxDepth,
          value: maxDepthValue,
          iconColor: Colors.indigo,
        ),
      ),
      Semantics(
        label: statLabel(
          name: context.l10n.dashboard_stats_sitesVisited,
          value: '${stats.totalSites}',
        ),
        child: StatSummaryCard(
          icon: Icons.location_on,
          label: context.l10n.dashboard_stats_sitesVisited,
          value: '${stats.totalSites}',
          iconColor: Colors.orange,
        ),
      ),
    ];

    if (isWide) {
      return Row(children: cards.map((card) => Expanded(child: card)).toList());
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 2.4,
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
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 2.4,
      children: placeholders,
    );
  }

  Widget _buildStatsGridError(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.dashboard_semantics_errorLoadingStatistics,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.dashboard_stats_errorLoadingStatistics,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
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
