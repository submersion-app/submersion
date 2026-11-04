import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One tank's line in a plan's gas consumption: what it uses against what
/// it holds, with its turn and reserve pressures.
class PlanGasRow extends StatelessWidget {
  const PlanGasRow({
    super.key,
    required this.usage,
    required this.label,
    required this.units,
  });

  final PlanTankUsage usage;
  final String label;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final statsStyle = theme.textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(
                l10n.plannerCanvas_gas_usedReading(
                  _reading(usage.litersUsed, usage.usedPressure),
                ),
                style: statsStyle,
              ),
              Text(
                l10n.plannerCanvas_gas_endReading(
                  _reading(usage.remainingLiters, usage.remainingPressure),
                ),
                style: statsStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: usage.reserveViolation
                      ? theme.colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
          if (_limitParts(l10n) case final parts when parts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                parts.join(' \u00b7 '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(height: 4),
          _bar(theme),
        ],
      ),
    );
  }

  /// The turn-pressure and minimum-gas line: each figure where the engine
  /// computed it, else the input it is missing (#3603), so a back gas never
  /// just goes quiet. One missing start pressure blanks both figures, and
  /// says so once.
  List<String> _limitParts(AppLocalizations l10n) {
    final turnGap = usage.turnPressureGap;
    final minGap = usage.minGasGap;
    if (turnGap == PlanGasLimitGap.noStartPressure &&
        minGap == PlanGasLimitGap.noStartPressure) {
      return [l10n.plannerCanvas_gas_limitsNoStartPressure];
    }
    return [
      if (usage.turnPressureBar != null)
        l10n.plannerCanvas_gas_turnAt(
          units.formatPressure(usage.turnPressureBar),
        )
      else if (turnGap == PlanGasLimitGap.noTurnRule)
        l10n.plannerCanvas_gas_noTurnRule
      else if (turnGap == PlanGasLimitGap.noStartPressure)
        l10n.plannerCanvas_gas_turnNoStartPressure,
      if (usage.minGasBar != null)
        l10n.plannerCanvas_gas_minGas(units.formatPressure(usage.minGasBar))
      else if (minGap == PlanGasLimitGap.noStartPressure)
        l10n.plannerCanvas_gas_minGasNoStartPressure
      else if (minGap == PlanGasLimitGap.noVolume)
        l10n.plannerCanvas_gas_minGasNoVolume,
    ];
  }

  /// A cylinder that holds enough gas gets the ordinary single-colour bar.
  /// One that does not gets a bar spanning the full NEED instead of the
  /// cylinder's own capacity: blue for the share the cylinder actually
  /// covers, red for the share still missing -- the shortfall is exactly as
  /// visible as the surplus a diver reads on an ordinary line (#3190).
  Widget _bar(ThemeData theme) {
    final total = usage.totalLiters;
    final overBudget = total != null && usage.litersUsed > total;
    if (!overBudget) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (usage.percentUsed / 100).clamp(0.0, 1.0),
          minHeight: 4,
          color: usage.reserveViolation
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    }
    final coveredPermille = ((total / usage.litersUsed) * 1000).round().clamp(
      1,
      999,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: double.infinity,
        height: 4,
        child: Row(
          // A childless ColoredBox takes the smallest size its constraints
          // allow, and a Row only hands its children LOOSE cross-axis
          // constraints by default -- so without stretch each segment was
          // laid out 0 px tall and the whole bar vanished (a diver saw both
          // over-capacity cylinders print their negative readings with no
          // bar underneath at all).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: coveredPermille,
              child: ColoredBox(color: theme.colorScheme.primary),
            ),
            Expanded(
              flex: 1000 - coveredPermille,
              child: ColoredBox(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact "411L/37bar" pair; no space before the unit, matching the
  /// slate-style gas row.
  String _reading(double? liters, double? bar) {
    final volume = liters == null
        ? '--'
        : '${units.convertVolume(liters).round()}${units.volumeSymbol}';
    final pressure = bar == null
        ? '--'
        : '${units.convertPressure(bar).round()}${units.pressureSymbol}';
    return '$volume/$pressure';
  }
}
