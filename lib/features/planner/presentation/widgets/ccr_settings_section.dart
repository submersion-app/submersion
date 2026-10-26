import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Setpoint controls for a CCR plan: low/high setpoints (bar) and the
/// depth below which the high setpoint is in force (display units).
///
/// All three are already live-resolved against the diver's Settings when
/// unset (issue #2801); this uses the same `PlanNumberField` hint-text
/// pattern as every other overridable Setup field (issue #3552), so an
/// empty box visibly follows Settings and a typed value visibly overrides
/// it, instead of showing a plain number with no indication of which.
class CcrSettingsSection extends ConsumerWidget {
  const CcrSettingsSection({super.key});

  // Below this width the three fields no longer fit their label without
  // ellipsis-truncating it (#3130), so they stack instead.
  static const double _narrowBreakpoint = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final ccrSetpointLow = ref.watch(ccrSetpointLowProvider);
    final ccrSetpointHigh = ref.watch(ccrSetpointHighProvider);

    final fields = [
      PlanNumberField(
        label: context.l10n.plannerCanvas_ccr_setpointLow,
        value: state.setpointLow,
        hintValue: ccrSetpointLow,
        suffixText: 'bar',
        decimals: 1,
        // A setpoint of exactly 0 bar is meaningless; a diver typing it
        // clamps up to this practical minimum on blur rather than being
        // silently accepted.
        min: 0.1,
        onChanged: (v) => notifier.updateSetpoints(low: v, clearLow: v == null),
      ),
      PlanNumberField(
        label: context.l10n.plannerCanvas_ccr_setpointHigh,
        value: state.setpointHigh,
        hintValue: ccrSetpointHigh,
        suffixText: 'bar',
        decimals: 1,
        min: 0.1,
        onChanged: (v) =>
            notifier.updateSetpoints(high: v, clearHigh: v == null),
      ),
      PlanNumberField(
        label:
            '${context.l10n.plannerCanvas_ccr_switchDepth} '
            '(${units.depthSymbol})',
        value: state.setpointSwitchDepth != null
            ? units.convertDepth(state.setpointSwitchDepth!)
            : null,
        hintValue: units.convertDepth(10.0),
        suffixText: units.depthSymbol,
        decimals: 0,
        min: 0,
        onChanged: (v) => notifier.updateSetpoints(
          switchDepth: v != null ? units.depthToMeters(v) : null,
          clearSwitchDepth: v == null,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _narrowBreakpoint) {
            return Column(
              children: [
                for (final (index, f) in fields.indexed) ...[
                  if (index > 0) const SizedBox(height: 8),
                  f,
                ],
              ],
            );
          }
          return Row(
            children: [
              for (final (index, f) in fields.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: f),
              ],
            ],
          );
        },
      ),
    );
  }
}
