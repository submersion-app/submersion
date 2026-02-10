import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_list_content.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_summary_widget.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_equipment_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_gas_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_geographic_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_marine_life_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_profile_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_progression_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_social_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_time_patterns_page.dart';

/// Main statistics page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with category list on left,
/// selected statistics on right.
/// On narrower screens (<800px): Shows category grid with navigation to detail pages.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'statistics',
        masterBuilder: (context, onItemSelected, selectedId) =>
            StatisticsListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, categoryId) => _buildCategoryPage(categoryId),
        summaryBuilder: (context) => const StatisticsSummaryWidget(),
        mobileDetailRoute: (id) => '/statistics/$id',
      );
    }

    // Mobile: Show category grid with navigation
    return const StatisticsMobileContent();
  }

  /// Builds the appropriate statistics page based on category ID.
  Widget _buildCategoryPage(String categoryId) {
    switch (categoryId) {
      case 'gas':
        return const StatisticsGasPage(embedded: true);
      case 'progression':
        return const StatisticsProgressionPage(embedded: true);
      case 'conditions':
        return const StatisticsConditionsPage(embedded: true);
      case 'social':
        return const StatisticsSocialPage(embedded: true);
      case 'geographic':
        return const StatisticsGeographicPage(embedded: true);
      case 'marine-life':
        return const StatisticsMarineLifePage(embedded: true);
      case 'time-patterns':
        return const StatisticsTimePatternsPage(embedded: true);
      case 'equipment':
        return const StatisticsEquipmentPage(embedded: true);
      case 'profile':
        return const StatisticsProfilePage(embedded: true);
      default:
        return Center(child: Text('Unknown category: $categoryId'));
    }
  }
}

/// Mobile content showing category grid for navigation.
class StatisticsMobileContent extends StatelessWidget {
  const StatisticsMobileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Dive Records',
            onPressed: () => context.push('/records'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: statisticsCategories.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = statisticsCategories[index];
          return _StatisticsCategoryTile(
            category: category,
            onTap: () => context.push('/statistics/${category.id}'),
          );
        },
      ),
    );
  }
}

class _StatisticsCategoryTile extends StatelessWidget {
  final StatisticsCategory category;
  final VoidCallback onTap;

  const _StatisticsCategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '${category.title}, ${category.subtitle}',
      child: ListTile(
        leading: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 24),
          ),
        ),
        title: Text(
          category.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          category.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ).excludeFromSemantics(),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
