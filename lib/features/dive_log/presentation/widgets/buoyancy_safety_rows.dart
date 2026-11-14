import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _RowState { pass, warn, neutral }

/// The safety checks on the Buoyancy card, each a figure and a plain verdict:
/// whether the wing can hold the diver at their heaviest, whether enough lead
/// can be ditched to get positive, and how much gas a drysuit took.
class BuoyancySafetyRows extends StatelessWidget {
  final TwinOutputs outputs;
  final UnitFormatter units;
  final double? wingLiftCapacityKg;

  /// Whether the dive has any lead recorded. Without it the ditchable row
  /// states its figure and passes no verdict: "you can ditch nothing" would
  /// be a warning about missing data, not about the dive.
  final bool leadRecorded;

  const BuoyancySafetyRows({
    super.key,
    required this.outputs,
    required this.units,
    this.wingLiftCapacityKg,
    this.leadRecorded = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final o = outputs;
    // Only a positive rated lift means anything; a zero or negative one (bad
    // imported data) would warn against any demand at all.
    final wing = (wingLiftCapacityKg != null && wingLiftCapacityKg! > 0)
        ? wingLiftCapacityKg
        : null;
    final wingText = wing == null ? null : units.formatWeight(wing);
    final liftExceeds = wing != null && o.peakLiftDemandKg > wing;
    final ditchCovered = o.droppableLeadKg >= o.minDitchableKg;
    final droppable = units.formatWeight(o.droppableLeadKg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          context,
          key: 'safety-peak-lift',
          label: l10n.buoyancy_peakLift,
          value: units.formatWeight(o.peakLiftDemandKg),
          qualifier: wingText == null
              ? null
              : liftExceeds
              ? l10n.buoyancy_peakLiftExceeds(wingText)
              : l10n.buoyancy_peakLiftWithin(wingText),
          state: wing == null
              ? _RowState.neutral
              : liftExceeds
              ? _RowState.warn
              : _RowState.pass,
        ),
        _row(
          context,
          key: 'safety-ditchable',
          label: l10n.buoyancy_minDitchable,
          value: units.formatWeight(o.minDitchableKg),
          qualifier: !leadRecorded
              ? null
              : ditchCovered
              ? l10n.buoyancy_ditchCovered(droppable)
              : l10n.buoyancy_ditchShort(droppable),
          state: !leadRecorded
              ? _RowState.neutral
              : ditchCovered
              ? _RowState.pass
              : _RowState.warn,
        ),
        if (o.drysuitGasLiters > 0)
          _row(
            context,
            key: 'safety-drysuit-gas',
            label: l10n.buoyancy_drysuitGas,
            value: units.formatVolume(o.drysuitGasLiters),
            qualifier: null,
            state: _RowState.neutral,
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required String value,
    required String? qualifier,
    required _RowState state,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (state) {
      _RowState.pass => (Icons.check_circle_outline, scheme.primary),
      _RowState.warn => (Icons.warning_amber_rounded, scheme.error),
      _RowState.neutral => (Icons.info_outline, scheme.outline),
    };
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (qualifier != null)
                  Text(
                    qualifier,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
