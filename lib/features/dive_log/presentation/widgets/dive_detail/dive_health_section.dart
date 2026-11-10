import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether [record] holds anything the health card would show.
bool diveHealthHasContent(DiveHealthRecord? record) =>
    record != null &&
    (record.avgHeartRate != null ||
        record.maxHeartRate != null ||
        record.heartRateAtExit != null ||
        record.heartRateExitPlus5 != null ||
        record.heartRateExitPlus15 != null ||
        record.overnightHrvMs != null ||
        record.sleepBeforeMinutes != null);

/// Heart rate, recovery and sleep from Apple Health on a dive (issue #637).
/// Plain numbers with a line on what they are; no verdicts. A group Health
/// had nothing for is left out.
class DiveHealthSection extends StatelessWidget {
  const DiveHealthSection({super.key, required this.record});

  final DiveHealthRecord record;

  @override
  Widget build(BuildContext context) {
    if (!diveHealthHasContent(record)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String bpm(int? v) => l10n.diveLog_health_bpm(v!);

    final heartRate = [
      if (record.avgHeartRate != null)
        _Stat(l10n.diveLog_health_average, bpm(record.avgHeartRate)),
      if (record.maxHeartRate != null)
        _Stat(l10n.diveLog_health_maximum, bpm(record.maxHeartRate)),
    ];
    final recovery = [
      if (record.heartRateAtExit != null)
        _Stat(l10n.diveLog_health_atSurfacing, bpm(record.heartRateAtExit)),
      if (record.heartRateExitPlus5 != null)
        _Stat(l10n.diveLog_health_after5, bpm(record.heartRateExitPlus5)),
      if (record.heartRateExitPlus15 != null)
        _Stat(l10n.diveLog_health_after15, bpm(record.heartRateExitPlus15)),
    ];
    final hrv = record.overnightHrvMs;
    final sleep = record.sleepBeforeMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.diveLog_health_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (heartRate.isNotEmpty) _StatRow(heartRate),
            if (recovery.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.diveLog_health_recovery,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.diveLog_health_recoveryExplain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _StatRow(recovery),
            ],
            if (hrv != null) ...[
              const SizedBox(height: 12),
              _StatRow([
                _Stat(
                  l10n.diveLog_health_overnightHrv,
                  l10n.diveLog_health_ms(hrv.round()),
                ),
              ]),
            ],
            if (sleep != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.diveLog_health_sleepBefore(sleep ~/ 60, sleep % 60),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);

  final String label;
  final String value;
}

/// Stats side by side, each a small label over its value.
class _StatRow extends StatelessWidget {
  const _StatRow(this.stats);

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stat in stats)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
