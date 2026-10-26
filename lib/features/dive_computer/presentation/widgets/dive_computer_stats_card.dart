import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives imported and the last download, on a dive computer's Equipment page.
class DiveComputerStatsCard extends ConsumerWidget {
  const DiveComputerStatsCard({super.key, required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveComputer_detail_statisticsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.scuba_diving,
                    value: '${computer.diveCount}',
                    label: context.l10n.diveComputer_detail_divesImported,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.download,
                    value: formatLastDownload(
                      context,
                      computer.lastDownload,
                      units: units,
                    ),
                    label: context.l10n.diveComputer_detail_lastDownload,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
