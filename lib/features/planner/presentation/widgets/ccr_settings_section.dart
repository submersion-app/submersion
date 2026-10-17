import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

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
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    // An unset plan setpoint shows the diver's Settings value, the same
    // fallback the PlanEngine computes with (issue #2801).
    //
    // A setpoint is decimal by nature (1,2 bar for a comma-decimal diver), so
    // the seed and the parse both go through the locale helpers (#1091).
    _lowController = TextEditingController(
      text: formatRoundedForInput(
        state.setpointLow ?? settings.ccrSetpointLow,
        1,
      ),
    );
    _highController = TextEditingController(
      text: formatRoundedForInput(
        state.setpointHigh ?? settings.ccrSetpointHigh,
        1,
      ),
    );
    _switchController = TextEditingController(
      text: formatRoundedForInput(
        units.convertDepth(state.setpointSwitchDepth ?? 10.0),
        0,
      ),
    );
  }

  @override
  void dispose() {
    _lowController.dispose();
    _highController.dispose();
    _switchController.dispose();
    super.dispose();
  }

  // Below this width the three fields no longer fit their label without
  // ellipsis-truncating it (#3130), so they stack instead.
  static const double _narrowBreakpoint = 360;

  /// Shows the diver's new Settings setpoint in [controller] while the plan
  /// leaves that setpoint unset, so the field keeps matching what the engine
  /// computes with after a Settings change or a late settings load. A field
  /// no longer showing the [previous] Settings value (blanked, or mid-edit)
  /// is the diver's text and is left alone.
  void _followSettings(
    double? Function(DivePlanState) planValue,
    TextEditingController controller,
    double? previous,
    double next,
  ) {
    if (planValue(ref.read(divePlanNotifierProvider)) != null) return;
    if (previous != null &&
        controller.text != formatRoundedForInput(previous, 1)) {
      return;
    }
    controller.text = formatRoundedForInput(next, 1);
  }

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    ref.listen<double>(
      settingsProvider.select((s) => s.ccrSetpointLow),
      (previous, next) =>
          _followSettings((s) => s.setpointLow, _lowController, previous, next),
    );
    ref.listen<double>(
      settingsProvider.select((s) => s.ccrSetpointHigh),
      (previous, next) => _followSettings(
        (s) => s.setpointHigh,
        _highController,
        previous,
        next,
      ),
    );

    Widget field(
      TextEditingController controller,
      String label,
      void Function(double) onChanged, {
      double Function(double)? toMetric,
      bool allowZero = false,
    }) {
      return NumberField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (read) {
          // Blank and unreadable text leave the plan alone; the field shows
          // why for unreadable text.
          if (read is! NumberValue) return;
          final parsed = read.value;
          // Setpoints must be positive; a switch depth of 0 (surface) is a
          // valid, useful configuration, so it opts into allowZero.
          if (allowZero ? parsed < 0 : parsed <= 0) return;
          onChanged(toMetric != null ? toMetric(parsed) : parsed);
        },
      );
    }

    // Display-units depth back to meters.
    double depthToMetric(double display) {
      final factor = units.convertDepth(1.0);
      return factor > 0 ? display / factor : display;
    }

    final fields = [
      field(
        _lowController,
        context.l10n.plannerCanvas_ccr_setpointLow,
        (v) => notifier.updateSetpoints(low: v),
      ),
      field(
        _highController,
        context.l10n.plannerCanvas_ccr_setpointHigh,
        (v) => notifier.updateSetpoints(high: v),
      ),
      field(
        _switchController,
        '${context.l10n.plannerCanvas_ccr_switchDepth} '
        '(${units.depthSymbol})',
        (v) => notifier.updateSetpoints(switchDepth: v),
        toMetric: depthToMetric,
        allowZero: true,
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
