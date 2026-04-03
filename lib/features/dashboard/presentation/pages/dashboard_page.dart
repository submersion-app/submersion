import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/activity_stats_bar.dart';
import 'package:submersion/features/dashboard/presentation/widgets/alerts_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dashboard/presentation/widgets/personal_records_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';

/// Dashboard home page showing dive statistics and alerts
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const HeroHeader(),
                const SizedBox(height: 12),
                const ActivityStatsBar(),
                const SizedBox(height: 12),
                const AlertsCard(),
                const SizedBox(height: 12),
                const RecentDivesCard(),
                const SizedBox(height: 12),
                _buildBottomRow(context, ref),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRow(BuildContext context, WidgetRef ref) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: PersonalRecordsCard()),
          SizedBox(width: 8),
          Expanded(child: QuickActionsCard()),
        ],
      ),
    );
  }
}
