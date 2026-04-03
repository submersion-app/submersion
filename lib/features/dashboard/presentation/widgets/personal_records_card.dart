import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card showing personal dive records as a compact vertical list
class PersonalRecordsCard extends ConsumerWidget {
  const PersonalRecordsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(personalRecordsProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);
    final bodyMedium = theme.textTheme.bodyMedium;

    final records = recordsAsync.valueOrNull;

    String deepestValue = '-';
    VoidCallback? deepestTap;
    if (records?.deepestDive != null) {
      final d = units.convertDepth(records!.deepestDive!.maxDepth!);
      deepestValue = '${d.toStringAsFixed(1)}${units.depthSymbol}';
      deepestTap = () => context.push('/dives/${records.deepestDive!.id}');
    }

    String longestValue = '-';
    VoidCallback? longestTap;
    if (records?.longestDive != null) {
      longestValue = '${records!.longestDive!.bottomTime!.inMinutes}min';
      longestTap = () => context.push('/dives/${records.longestDive!.id}');
    }

    String coldestValue = '-';
    VoidCallback? coldestTap;
    if (records?.coldestDive != null) {
      final t = units.convertTemperature(records!.coldestDive!.waterTemp!);
      coldestValue = '${t.toStringAsFixed(0)}${units.temperatureSymbol}';
      coldestTap = () => context.push('/dives/${records.coldestDive!.id}');
    }

    String warmestValue = '-';
    VoidCallback? warmestTap;
    if (records?.warmestDive != null) {
      final t = units.convertTemperature(records!.warmestDive!.waterTemp!);
      warmestValue = '${t.toStringAsFixed(0)}${units.temperatureSymbol}';
      warmestTap = () => context.push('/dives/${records.warmestDive!.id}');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.dashboard_personalRecords_sectionTitle,
                  style: bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RecordRow(
              label: context.l10n.dashboard_personalRecords_deepest,
              value: deepestValue,
              color: Colors.indigo,
              onTap: deepestTap,
            ),
            _RecordRow(
              label: context.l10n.dashboard_personalRecords_longest,
              value: longestValue,
              color: Colors.teal,
              onTap: longestTap,
            ),
            _RecordRow(
              label: context.l10n.dashboard_personalRecords_coldest,
              value: coldestValue,
              color: Colors.blue,
              onTap: coldestTap,
            ),
            _RecordRow(
              label: context.l10n.dashboard_personalRecords_warmest,
              value: warmestValue,
              color: Colors.orange,
              onTap: warmestTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _RecordRow({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final bodyMedium = theme.textTheme.bodyMedium;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: bodyMedium?.copyWith(color: onSurfaceVariant)),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
