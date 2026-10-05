import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One OTU total against its limit: "label  value / limit OTU (pct%)" over a
/// progress bar coloured by how close the total is to the limit.
///
/// Shared by [O2ToxicityCard]'s daily and weekly rows and the CNS/OTU
/// readout's totals card, so the limit colours stay in one place.
class OtuLimitProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final double limit;

  const OtuLimitProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = limit > 0 ? (value / limit) * 100 : 0.0;
    final color = _limitColor(percent, colorScheme);

    return Semantics(
      label: context.l10n.o2Toxicity_otuSemantics(
        label,
        value.toStringAsFixed(0),
        limit.toStringAsFixed(0),
        percent.toStringAsFixed(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} OTU '
                '(${percent.toStringAsFixed(0)}%)',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  static Color _limitColor(double percent, ColorScheme colorScheme) {
    if (percent >= 100) return colorScheme.error;
    if (percent >= 80) return Colors.orange;
    if (percent >= 50) return Colors.amber;
    return Colors.green;
  }
}
