import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The counterfactual's computed stops: depth, stop length, arrival runtime
/// and gas (the planner results sheet's table, for the lab).
class LabRuntimeTable extends StatelessWidget {
  const LabRuntimeTable({
    super.key,
    required this.outcome,
    required this.units,
    this.runtimeOffsetSeconds = 0,
  });

  final PlanOutcome outcome;
  final UnitFormatter units;

  /// Added to the plan's own runtimes so rows read as dive runtime.
  final int runtimeOffsetSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final header = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    if (outcome.stops.isEmpty) {
      return Text(
        l10n.plannerCanvas_results_noDeco,
        style: theme.textTheme.bodySmall,
      );
    }
    Widget cell(String text, {int flex = 1, TextStyle? style}) => Expanded(
      flex: flex,
      child: Text(text, style: style ?? theme.textTheme.bodySmall),
    );
    return Column(
      children: [
        Row(
          children: [
            cell(l10n.plannerCanvas_table_depth, style: header),
            cell(l10n.plannerCanvas_table_stop, style: header),
            cell(l10n.plannerCanvas_table_runtime, style: header),
            cell(l10n.plannerCanvas_table_gas, flex: 2, style: header),
          ],
        ),
        const Divider(height: 12),
        for (final stop in outcome.stops)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                cell(units.formatDepth(stop.depthMeters, decimals: 0)),
                cell(formatLabMinutes(stop.durationSeconds)),
                cell(
                  formatLabTime(
                    runtimeOffsetSeconds +
                        stop.arrivalRuntimeSeconds +
                        stop.durationSeconds,
                  ),
                ),
                cell(
                  GasMix(o2: stop.gasFO2 * 100, he: stop.gasFHe * 100).name,
                  flex: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
