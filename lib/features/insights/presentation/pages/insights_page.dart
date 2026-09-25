import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_action.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_list_content.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_equipment_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_geographic_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_marine_life_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_progression_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_social_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Main statistics page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with category list on left,
/// selected statistics on right.
/// On narrower screens (<800px): Shows category grid with navigation to detail pages.
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'insights',
        masterBuilder: (context, onItemSelected, selectedId) =>
            InsightsListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, categoryId) => _buildCategoryPage(categoryId),
        summaryBuilder: (context) => const InsightsOverviewPage(embedded: true),
        mobileDetailRoute: (id) => '/insights/$id',
      );
    }

    // Mobile: Show category grid with navigation
    return const InsightsMobileContent();
  }

  /// Builds the appropriate statistics page based on category ID.
  Widget _buildCategoryPage(String categoryId) {
    switch (categoryId) {
      case 'overview':
        return const InsightsOverviewPage(embedded: true);
      case 'gas':
        return const InsightsGasPage(embedded: true);
      case 'progression':
        return const InsightsProgressionPage(embedded: true);
      case 'conditions':
        return const InsightsConditionsPage(embedded: true);
      case 'social':
        return const InsightsSocialPage(embedded: true);
      case 'geographic':
        return const InsightsGeographicPage(embedded: true);
      case 'marine-life':
        return const InsightsMarineLifePage(embedded: true);
      case 'time-patterns':
        return const InsightsTimePatternsPage(embedded: true);
      case 'equipment':
        return const InsightsEquipmentPage(embedded: true);
      case 'profile':
        return const InsightsProfilePage(embedded: true);
      default:
        return Center(child: Text('Unknown category: $categoryId'));
    }
  }
}

/// Mobile content showing category grid for navigation.
class InsightsMobileContent extends ConsumerWidget {
  const InsightsMobileContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'insights',
          title: context.l10n.insights_appBar_title,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: context.l10n.insights_tooltip_diveRecords,
            onPressed: () => context.push('/records'),
          ),
          const InsightsFilterAction(),
        ],
      ),
      body: Column(
        children: [
          const InsightsFilterBar(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: insightsCategoriesOf(context).length,
              separatorBuilder: (context, index) {
                if (index == 0) {
                  return const Divider(height: 16, thickness: 1);
                }
                return const Divider(height: 1);
              },
              itemBuilder: (context, index) {
                final category = insightsCategoriesOf(context)[index];
                return _InsightsCategoryTile(
                  category: category,
                  onTap: () => context.push('/insights/${category.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCategoryTile extends StatelessWidget {
  final InsightsCategory category;
  final VoidCallback onTap;

  const _InsightsCategoryTile({required this.category, required this.onTap});

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
