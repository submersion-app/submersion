import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/gas_exchange.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_exchange_style.dart';
import 'package:submersion/features/dive_log/presentation/widgets/loading_severity_color.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One compartment's key values above the tissue charts: load, GF, the
/// nitrogen and helium tension each with its own direction, and the
/// half-time(s).
///
/// Nitrogen and helium get separate arrows because they can move in opposite
/// directions at once (issue #4228): after a trimix dive at the surface a
/// compartment releases helium while it takes nitrogen back up. The badge
/// next to the compartment number shows the net direction of both.
class TissueCompartmentDetail extends StatelessWidget {
  final DecoStatus status;

  /// Compartment (0-based) to show.
  final int displayIndex;

  /// Whether [displayIndex] is the leading compartment.
  final bool isLeading;

  const TissueCompartmentDetail({
    super.key,
    required this.status,
    required this.displayIndex,
    required this.isLeading,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final comp = status.compartments[displayIndex];

    final gf = (comp.gradientFactor(status.ambientPressureBar) * 100).clamp(
      0.0,
      double.infinity,
    );
    // Null when the status carries no inspired gas: the badge and arrows are
    // left out rather than guessed from ambient pressure (issue #2593). The
    // net direction is derived from the per-gas ones, so the badge always
    // agrees with the arrows.
    final (:n2, :he, :net) = status.gasExchanges(comp);
    final withHelium = showsHelium(comp, status.inspiredHeBar);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              isLeading
                  ? l10n.diveLog_deco_compartmentLeading(comp.compartmentNumber)
                  : l10n.diveLog_deco_compartmentOther(comp.compartmentNumber),
              style: textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (net != null) ...[
              const SizedBox(width: 6),
              _ExchangeBadge(exchange: net),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Metric(
              label: l10n.diveLog_deco_metricLoad,
              value: l10n.diveLog_deco_percentValue(
                formatFixedForDisplay(comp.percentLoading, 0),
              ),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _Metric(
              label: 'GF',
              value: l10n.diveLog_deco_percentValue(
                formatFixedForDisplay(gf, 0),
              ),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: loadingSeverityColor(gf)),
            ),
            _Metric(
              key: const ValueKey('tissue-detail-n2'),
              label: 'N₂',
              value: '${formatFixedForDisplay(comp.currentPN2, 2)} bar',
              exchange: n2,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (withHelium)
              _Metric(
                key: const ValueKey('tissue-detail-he'),
                label: 'He',
                value: '${formatFixedForDisplay(comp.currentPHe, 2)} bar',
                exchange: he,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            _Metric(
              label: withHelium ? 't½ N₂ / He' : 't½',
              value: l10n.diveLog_deco_minutesValue(
                halfTimeText(comp, withHelium: withHelium),
              ),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _ExchangeBadge extends StatelessWidget {
  final GasExchange exchange;

  const _ExchangeBadge({required this.exchange});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = exchange.color(colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(exchange.icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            exchange.label(context.l10n),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  /// Direction arrow next to [value], or none when null.
  final GasExchange? exchange;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _Metric({
    super.key,
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.exchange,
  });

  @override
  Widget build(BuildContext context) {
    final direction = exchange;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: valueStyle, maxLines: 1),
                  if (direction != null) ...[
                    const SizedBox(width: 2),
                    Icon(
                      direction.icon,
                      size: 12,
                      color: direction.color(colorScheme),
                      semanticLabel: direction.label(context.l10n),
                    ),
                  ],
                ],
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: labelStyle, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
