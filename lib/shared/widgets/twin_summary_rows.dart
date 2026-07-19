import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shared summary tiles for buoyancy-twin outputs: begin/end net, swing,
/// peak lift demand, minimum ditchable weight, and drysuit gas. Used by the
/// dive-detail section, the Dive Planner, and the Weight Planner tool.
class TwinSummaryRows extends StatelessWidget {
  final TwinOutputs outputs;
  final double? wingLiftCapacityKg;
  final UnitFormatter units;

  const TwinSummaryRows({
    super.key,
    required this.outputs,
    required this.units,
    this.wingLiftCapacityKg,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final o = outputs;
    // Only a positive rated lift is meaningful; a non-positive value (e.g.
    // imported/legacy bad data) would fire a spurious "exceeds wing lift"
    // warning against any positive demand.
    final wing = (wingLiftCapacityKg != null && wingLiftCapacityKg! > 0)
        ? wingLiftCapacityKg
        : null;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _tile(
          context,
          l10n.buoyancy_beginNet,
          units.formatWeight(o.beginNetKg),
        ),
        _tile(context, l10n.buoyancy_endNet, units.formatWeight(o.endNetKg)),
        _tile(
          context,
          l10n.buoyancy_swing,
          units.formatWeight((o.endNetKg - o.beginNetKg).abs()),
        ),
        _tile(
          context,
          l10n.buoyancy_peakLift,
          units.formatWeight(o.peakLiftDemandKg),
          warning: wing != null && o.peakLiftDemandKg > wing
              ? l10n.buoyancy_wingWarning
              : null,
        ),
        _tile(
          context,
          l10n.buoyancy_minDitchable,
          units.formatWeight(o.minDitchableKg),
          warning: o.droppableLeadKg < o.minDitchableKg
              ? l10n.buoyancy_ditchWarning
              : null,
        ),
        if (o.drysuitGasLiters > 0)
          _tile(
            context,
            l10n.buoyancy_drysuitGas,
            units.formatVolume(o.drysuitGasLiters),
          ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    String label,
    String value, {
    String? warning,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(value, style: theme.textTheme.titleMedium),
              if (warning != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: warning,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
