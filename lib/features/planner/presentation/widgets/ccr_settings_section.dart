import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Setpoint controls for a CCR plan: low/high setpoints (bar) and the
/// depth below which the high setpoint is in force (display units).
class CcrSettingsSection extends ConsumerStatefulWidget {
  const CcrSettingsSection({super.key});

  @override
  ConsumerState<CcrSettingsSection> createState() => _CcrSettingsSectionState();
}

class _CcrSettingsSectionState extends ConsumerState<CcrSettingsSection> {
  late final TextEditingController _lowController;
  late final TextEditingController _highController;
  late final TextEditingController _switchController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(divePlanNotifierProvider);
    final units = UnitFormatter(ref.read(settingsProvider));
    _lowController = TextEditingController(
      text: (state.setpointLow ?? 0.7).toStringAsFixed(1),
    );
    _highController = TextEditingController(
      text: (state.setpointHigh ?? 1.3).toStringAsFixed(1),
    );
    _switchController = TextEditingController(
      text: units
          .convertDepth(state.setpointSwitchDepth ?? 10.0)
          .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _lowController.dispose();
    _highController.dispose();
    _switchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notifier = ref.read(divePlanNotifierProvider.notifier);

    Widget field(
      TextEditingController controller,
      String label,
      void Function(double) onChanged, {
      double Function(double)? toMetric,
      bool allowZero = false,
    }) {
      return Expanded(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) {
            final parsed = double.tryParse(text);
            // Setpoints must be positive; a switch depth of 0 (surface) is a
            // valid, useful configuration, so it opts into allowZero.
            if (parsed == null || (allowZero ? parsed < 0 : parsed <= 0)) {
              return;
            }
            onChanged(toMetric != null ? toMetric(parsed) : parsed);
          },
        ),
      );
    }

    // Display-units depth back to meters.
    double depthToMetric(double display) {
      final factor = units.convertDepth(1.0);
      return factor > 0 ? display / factor : display;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          field(
            _lowController,
            context.l10n.plannerCanvas_ccr_setpointLow,
            (v) => notifier.updateSetpoints(low: v),
          ),
          const SizedBox(width: 8),
          field(
            _highController,
            context.l10n.plannerCanvas_ccr_setpointHigh,
            (v) => notifier.updateSetpoints(high: v),
          ),
          const SizedBox(width: 8),
          field(
            _switchController,
            '${context.l10n.plannerCanvas_ccr_switchDepth} '
            '(${units.depthSymbol})',
            (v) => notifier.updateSetpoints(switchDepth: v),
            toMetric: depthToMetric,
            allowZero: true,
          ),
        ],
      ),
    );
  }
}
