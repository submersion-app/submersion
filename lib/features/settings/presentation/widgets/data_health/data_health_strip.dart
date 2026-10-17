import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The top of Settings > Data (#3390): four status symbols in one row, then
/// a line of words only for what is failing or needs attention. When all is
/// well the lines are gone and the strip reads as four ticks.
class DataHealthStrip extends ConsumerWidget {
  const DataHealthStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(dataHealthProvider);
    final now = DateTime.now();
    // Failing first, then attention, each in strip order.
    final lines = [
      ...health.where((h) => h.level == HealthLevel.failing),
      ...health.where((h) => h.level == HealthLevel.attention),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final h in health) Expanded(child: _Item(h))],
          ),
        ),
        if (lines.isNotEmpty) const SizedBox(height: 12),
        for (final h in lines) _AttentionLine(h, now: now),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.health);

  final FeatureHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The label sits on the tappable node and the visuals are excluded, so
    // a screen reader hears "Backup: Needs attention" and can still activate
    // it (excluding at the outer Semantics would drop the tap action).
    return Semantics(
      button: true,
      label: healthSemanticsLabel(l10n, health),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(dataFeatureRoute(health.feature)),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                HealthSymbol(level: health.level),
                const SizedBox(height: 6),
                Text(
                  dataFeatureLabel(l10n, health.feature),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttentionLine extends StatelessWidget {
  const _AttentionLine(this.health, {required this.now});

  final FeatureHealth health;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('dataHealth_attentionLine'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(dataFeatureRoute(health.feature)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            HealthSymbol(level: health.level, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                healthReasonText(context.l10n, health, now),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
