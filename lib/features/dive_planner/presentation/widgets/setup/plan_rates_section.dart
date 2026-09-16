import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ascent and descent rate controls for the Setup accordion (Subsurface
/// parity G7/G8). Rates are stored in m/min internally; the number boxes
/// display and edit in the diver's depth unit per minute (m/min or ft/min),
/// converting back to m/min for storage.
///
/// The ascent is four rates, not one, following TDI's decompression
/// procedures: divers do not climb the stop grid at the speed they leave the
/// bottom, and they slow further as they get shallow, where a given depth
/// change costs the most pressure change.
class PlanRatesSection extends ConsumerWidget {
  const PlanRatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RateField(
          label: context.l10n.plannerCanvas_rates_ascent,
          value: state.ascentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(ascent: v),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_intermediateAscent,
          value: state.intermediateAscentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(intermediate: v),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_shallowAscent,
          value: state.shallowAscentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(shallow: v),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_finalAscent(
            units.formatDepth(state.lastStopDepth, decimals: 0),
          ),
          value: state.finalAscentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(finalStretch: v),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_descent,
          value: state.descentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(descent: v),
        ),
      ],
    );
  }
}

/// One rate as a whole number in the diver's depth unit per minute.
class _RateField extends StatelessWidget {
  const _RateField({
    required this.label,
    required this.value,
    required this.units,
    required this.onChanged,
  });

  /// Stored rate in m/min.
  final double value;

  final String label;
  final UnitFormatter units;

  /// Receives the new rate in m/min (converted back from the display unit).
  final ValueChanged<double> onChanged;

  // Rate band, in m/min, kept canonical so the accepted range matches across
  // unit systems. The box bounds narrow inward (ceil the minimum, floor the
  // maximum) so every whole number it accepts maps back inside the band:
  // 1-30 m/min, 3-98 ft/min. The floor sits at 0.9 rather than 1 so that
  // 3 ft/min (0.91 m/min), the imperial face of the 1 m/min final-ascent
  // default, stays a legal entry instead of clamping up to 4.
  static const _minMetric = 0.9;
  static const _maxMetric = 30.0;

  @override
  Widget build(BuildContext context) {
    // Work the field in the diver's depth unit per minute; storage stays
    // m/min.
    final suffix = '${units.depthSymbol}/min';
    return PlanNumberField(
      label: label,
      value: units.convertDepth(value),
      // An emptied box still shows the rate the plan is holding.
      hintValue: units.convertDepth(value),
      suffixText: suffix,
      isInteger: true,
      allowEmpty: false,
      min: units.convertDepth(_minMetric).ceilToDouble(),
      max: units.convertDepth(_maxMetric).floorToDouble(),
      semanticsLabel: '$label ($suffix)',
      onChanged: (v) {
        if (v == null) return;
        onChanged(units.depthToMeters(v));
      },
    );
  }
}
