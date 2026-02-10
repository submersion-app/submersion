import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';

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

/// List of all statistics categories.
const statisticsCategories = [
  StatisticsCategory(
    id: 'gas',
    icon: Icons.air,
    title: 'Air Consumption',
    subtitle: 'SAC rates & gas mixes',
    color: Colors.blue,
  ),
  StatisticsCategory(
    id: 'progression',
    icon: Icons.trending_up,
    title: 'Progression',
    subtitle: 'Depth & time trends',
    color: Colors.green,
  ),
  StatisticsCategory(
    id: 'conditions',
    icon: Icons.thermostat,
    title: 'Conditions',
    subtitle: 'Visibility & temperature',
    color: Colors.orange,
  ),
  StatisticsCategory(
    id: 'social',
    icon: Icons.people,
    title: 'Social',
    subtitle: 'Buddies & dive centers',
    color: Colors.purple,
  ),
  StatisticsCategory(
    id: 'geographic',
    icon: Icons.public,
    title: 'Geographic',
    subtitle: 'Countries & regions',
    color: Colors.teal,
  ),
  StatisticsCategory(
    id: 'marine-life',
    icon: Icons.pets,
    title: 'Marine Life',
    subtitle: 'Species sightings',
    color: Colors.cyan,
  ),
  StatisticsCategory(
    id: 'time-patterns',
    icon: Icons.schedule,
    title: 'Time Patterns',
    subtitle: 'When you dive',
    color: Colors.amber,
  ),
  StatisticsCategory(
    id: 'equipment',
    icon: Icons.build,
    title: 'Equipment',
    subtitle: 'Gear usage & weight',
    color: Colors.brown,
  ),
  StatisticsCategory(
    id: 'profile',
    icon: Icons.show_chart,
    title: 'Profile Analysis',
    subtitle: 'Ascent rates & deco',
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
              title: const Text('Statistics'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.emoji_events),
                  tooltip: 'Dive Records',
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
                          'Statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_events),
                        tooltip: 'Dive Records',
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
        itemCount: statisticsCategories.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = statisticsCategories[index];
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
    final selectedLabel = isSelected ? ', selected' : '';

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
