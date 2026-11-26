import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_setpoint_control.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_switch_depth_control.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Setpoint controls for a CCR plan: low and high setpoint (bar) and the
/// depth below which the high setpoint is in force.
///
/// Each is a Default/Custom (switch depth: Default/Off/Custom) choice, like
/// the other overridable Setup controls (issue #3793). Default follows the
/// diver's Settings and shows that value; Custom writes the plan's own,
/// starting from the Settings value. The controls stack, which keeps every
/// label and choice readable at any width.
class CcrSettingsSection extends ConsumerWidget {
  const CcrSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = ref.watch(unitFormatterProvider);
    final settingsLow = ref.watch(ccrSetpointLowProvider);
    final settingsHigh = ref.watch(ccrSetpointHighProvider);
    final settingsDepth = ref.watch(ccrSetpointSwitchDepthProvider);

    // Full width, so the controls start at the accordion's left edge rather
    // than being centred by a parent that shrink-wraps them on a phone.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CcrSetpointControl(
            title: l10n.plannerCanvas_ccr_setpointLow,
            value: state.setpointLow,
            defaultValue: settingsLow,
            onDefault: () => notifier.updateSetpoints(clearLow: true),
            onCustom: (v) => notifier.updateSetpoints(low: v),
          ),
          const SizedBox(height: 12),
          CcrSetpointControl(
            title: l10n.plannerCanvas_ccr_setpointHigh,
            value: state.setpointHigh,
            defaultValue: settingsHigh,
            onDefault: () => notifier.updateSetpoints(clearHigh: true),
            onCustom: (v) => notifier.updateSetpoints(high: v),
          ),
          const SizedBox(height: 12),
          CcrSwitchDepthControl(
            title: l10n.plannerCanvas_ccr_switchDepth,
            depth: state.setpointSwitchDepth,
            switchOff: state.setpointSwitchOff,
            defaultDepth: settingsDepth,
            units: units,
            onDefault: () => notifier.updateSetpoints(
              clearSwitchDepth: true,
              switchOff: false,
            ),
            onOff: () => notifier.updateSetpoints(switchOff: true),
            onCustom: (meters) =>
                notifier.updateSetpoints(switchDepth: meters, switchOff: false),
          ),
        ],
      ),
    );
  }
}
