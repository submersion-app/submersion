import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A row of quick stat cards showing top buddy, countries visited, and species discovered
class QuickStatsRow extends ConsumerWidget {
  const QuickStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardQuickStatsProvider);
    final theme = Theme.of(context);

    return statsAsync.when(
      data: (stats) {
        // Only show if there's meaningful data
        if (stats.topBuddyName == null &&
            stats.countriesVisited == 0 &&
            stats.speciesDiscovered == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashboard_quickStats_sectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Top Buddy
                    Expanded(
                      child: _QuickStatTile(
                        icon: Icons.person,
                        iconColor: Colors.blue,
                        label: context.l10n.dashboard_quickStats_topBuddy,
                        value: stats.topBuddyName ?? '-',
                        subtitle: stats.topBuddyDiveCount != null
                            ? context.l10n.dashboard_quickStats_topBuddyDives(
                                stats.topBuddyDiveCount!,
                              )
                            : null,
                        onTap: () => context.go('/statistics'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Countries Visited
                    Expanded(
                      child: _QuickStatTile(
                        icon: Icons.public,
                        iconColor: Colors.green,
                        label: context.l10n.dashboard_quickStats_countries,
                        value: stats.countriesVisited.toString(),
                        subtitle:
                            context.l10n.dashboard_quickStats_countriesSubtitle,
                        onTap: () => context.go('/statistics'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Species Discovered
                    Expanded(
                      child: _QuickStatTile(
                        icon: Icons.set_meal,
                        iconColor: Colors.orange,
                        label: context.l10n.dashboard_quickStats_species,
                        value: stats.speciesDiscovered.toString(),
                        subtitle:
                            context.l10n.dashboard_quickStats_speciesSubtitle,
                        onTap: () => context.go('/statistics'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  const _QuickStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );

    final semanticDescription = subtitle != null
        ? '$label: $value $subtitle'
        : '$label: $value';

    if (onTap != null) {
      return Semantics(
        button: true,
        label: semanticDescription,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }

    return Semantics(label: semanticDescription, child: content);
  }
}
