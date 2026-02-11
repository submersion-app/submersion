import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Statistics category data model.
class StatisticsCategory {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const StatisticsCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

/// List of all statistics categories (static structure, titles filled at build time).
List<StatisticsCategory> statisticsCategoriesOf(BuildContext context) => [
  StatisticsCategory(
    id: 'gas',
    icon: Icons.air,
    title: context.l10n.statistics_category_gas_title,
    subtitle: context.l10n.statistics_category_gas_subtitle,
    color: Colors.blue,
  ),
  StatisticsCategory(
    id: 'progression',
    icon: Icons.trending_up,
    title: context.l10n.statistics_category_progression_title,
    subtitle: context.l10n.statistics_category_progression_subtitle,
    color: Colors.green,
  ),
  StatisticsCategory(
    id: 'conditions',
    icon: Icons.thermostat,
    title: context.l10n.statistics_category_conditions_title,
    subtitle: context.l10n.statistics_category_conditions_subtitle,
    color: Colors.orange,
  ),
  StatisticsCategory(
    id: 'social',
    icon: Icons.people,
    title: context.l10n.statistics_category_social_title,
    subtitle: context.l10n.statistics_category_social_subtitle,
    color: Colors.purple,
  ),
  StatisticsCategory(
    id: 'geographic',
    icon: Icons.public,
    title: context.l10n.statistics_category_geographic_title,
    subtitle: context.l10n.statistics_category_geographic_subtitle,
    color: Colors.teal,
  ),
  StatisticsCategory(
    id: 'marine-life',
    icon: Icons.pets,
    title: context.l10n.statistics_category_marineLife_title,
    subtitle: context.l10n.statistics_category_marineLife_subtitle,
    color: Colors.cyan,
  ),
  StatisticsCategory(
    id: 'time-patterns',
    icon: Icons.schedule,
    title: context.l10n.statistics_category_timePatterns_title,
    subtitle: context.l10n.statistics_category_timePatterns_subtitle,
    color: Colors.amber,
  ),
  StatisticsCategory(
    id: 'equipment',
    icon: Icons.build,
    title: context.l10n.statistics_category_equipment_title,
    subtitle: context.l10n.statistics_category_equipment_subtitle,
    color: Colors.brown,
  ),
  StatisticsCategory(
    id: 'profile',
    icon: Icons.show_chart,
    title: context.l10n.statistics_category_profile_title,
    subtitle: context.l10n.statistics_category_profile_subtitle,
    color: Colors.indigo,
  ),
];

/// Content widget for the statistics category list, used in master-detail layout.
class StatisticsListContent extends StatelessWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;

  const StatisticsListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(context.l10n.statistics_appBar_title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.emoji_events),
                  tooltip: context.l10n.statistics_tooltip_diveRecords,
                  onPressed: () {
                    // Navigate to records page
                    context.push('/records');
                  },
                ),
              ],
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.statistics_appBar_title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_events),
                        tooltip: context.l10n.statistics_tooltip_diveRecords,
                        onPressed: () {
                          context.push('/records');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: statisticsCategoriesOf(context).length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = statisticsCategoriesOf(context)[index];
          final isSelected = selectedId == category.id;

          return _StatisticsCategoryTile(
            category: category,
            isSelected: isSelected,
            onTap: () {
              if (onItemSelected != null) {
                onItemSelected!(category.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _StatisticsCategoryTile extends StatelessWidget {
  final StatisticsCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatisticsCategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedLabel = isSelected
        ? context.l10n.statistics_listContent_selectedSuffix
        : '';

    return Semantics(
      button: true,
      label: '${category.title}, ${category.subtitle}$selectedLabel',
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            category.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ).excludeFromSemantics(),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
      ),
    );
  }
}
