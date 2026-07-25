import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives from this date in prior years.
class OnThisDayCard extends ConsumerWidget {
  const OnThisDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(onThisDayProvider);
    final dives = divesAsync.valueOrNull ?? const [];
    if (dives.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final fmt = UnitFormatter(settings);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboard_onThisDay_title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            for (final dive in dives)
              InkWell(
                onTap: () => context.push('/dives/${dive.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.dashboard_onThisDay_entry(
                                dive.effectiveEntryTime.year.toString(),
                                dive.site?.name ?? dive.name ?? '-',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _subtitle(context, fmt, dive),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, UnitFormatter fmt, Dive dive) {
    final parts = <String>[];
    final maxDepth = dive.maxDepth;
    if (maxDepth != null) parts.add(fmt.formatDepth(maxDepth));
    final runtime = dive.effectiveRuntime;
    if (runtime != null) {
      parts.add(context.l10n.diveLog_sources_minutes(runtime.inMinutes));
    }
    return parts.join(' · ');
  }
}
