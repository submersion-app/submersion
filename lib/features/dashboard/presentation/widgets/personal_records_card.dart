import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card showing personal dive records in a horizontal scrollable format
class PersonalRecordsCard extends ConsumerWidget {
  const PersonalRecordsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(personalRecordsProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);

    return recordsAsync.when(
      data: (records) {
        if (!records.hasRecords) {
          return const SizedBox.shrink();
        }

        final recordWidgets = <Widget>[];

        // Deepest dive
        if (records.deepestDive != null) {
          final displayDepth = units.convertDepth(
            records.deepestDive!.maxDepth!,
          );
          recordWidgets.add(
            _RecordChip(
              icon: Icons.arrow_downward,
              label: context.l10n.dashboard_personalRecords_deepest,
              value: '${displayDepth.toStringAsFixed(1)}${units.depthSymbol}',
              subtitle: records.deepestDive!.site?.name,
              color: Colors.indigo,
              onTap: () => context.push('/dives/${records.deepestDive!.id}'),
            ),
          );
        }

        // Longest dive
        if (records.longestDive != null) {
          recordWidgets.add(
            _RecordChip(
              icon: Icons.timer,
              label: context.l10n.dashboard_personalRecords_longest,
              value: '${records.longestDive!.duration!.inMinutes}min',
              subtitle: records.longestDive!.site?.name,
              color: Colors.teal,
              onTap: () => context.push('/dives/${records.longestDive!.id}'),
            ),
          );
        }

        // Coldest dive
        if (records.coldestDive != null) {
          final displayTemp = units.convertTemperature(
            records.coldestDive!.waterTemp!,
          );
          recordWidgets.add(
            _RecordChip(
              icon: Icons.ac_unit,
              label: context.l10n.dashboard_personalRecords_coldest,
              value:
                  '${displayTemp.toStringAsFixed(0)}${units.temperatureSymbol}',
              subtitle: records.coldestDive!.site?.name,
              color: Colors.blue,
              onTap: () => context.push('/dives/${records.coldestDive!.id}'),
            ),
          );
        }

        // Warmest dive
        if (records.warmestDive != null) {
          final displayTemp = units.convertTemperature(
            records.warmestDive!.waterTemp!,
          );
          recordWidgets.add(
            _RecordChip(
              icon: Icons.whatshot,
              label: context.l10n.dashboard_personalRecords_warmest,
              value:
                  '${displayTemp.toStringAsFixed(0)}${units.temperatureSymbol}',
              subtitle: records.warmestDive!.site?.name,
              color: Colors.orange,
              onTap: () => context.push('/dives/${records.warmestDive!.id}'),
            ),
          );
        }

        if (recordWidgets.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.dashboard_personalRecords_sectionTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: recordWidgets
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: w,
                          ),
                        )
                        .toList(),
                  ),
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

class _RecordChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _RecordChip({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        '• $subtitle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    final semanticDescription = subtitle != null
        ? '$label: $value at $subtitle'
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
