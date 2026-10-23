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
    final lastStopDepth =
        state.lastStopDepth ?? ref.watch(lastStopDepthProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RateField(
          label: context.l10n.plannerCanvas_rates_ascent,
          value: state.ascentRate,
          hintValue: ref.watch(plannerAscentRateProvider),
          units: units,
          onChanged: (v) =>
              notifier.updateRates(ascent: v, clearAscent: v == null),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_intermediateAscent,
          value: state.intermediateAscentRate,
          hintValue: ref.watch(plannerIntermediateAscentRateProvider),
          units: units,
          onChanged: (v) => notifier.updateRates(
            intermediate: v,
            clearIntermediate: v == null,
          ),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_shallowAscent,
          value: state.shallowAscentRate,
          hintValue: ref.watch(plannerShallowAscentRateProvider),
          units: units,
          onChanged: (v) =>
              notifier.updateRates(shallow: v, clearShallow: v == null),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_finalAscent(
            units.formatDepth(lastStopDepth, decimals: 0),
          ),
          value: state.finalAscentRate,
          hintValue: ref.watch(plannerFinalAscentRateProvider),
          units: units,
          onChanged: (v) => notifier.updateRates(
            finalStretch: v,
            clearFinalStretch: v == null,
          ),
        ),
        _RateField(
          label: context.l10n.plannerCanvas_rates_descent,
          value: state.descentRate,
          hintValue: ref.watch(plannerDescentRateProvider),
          units: units,
          onChanged: (v) =>
              notifier.updateRates(descent: v, clearDescent: v == null),
        ),
      ],
    );
  }
}

/// One rate as a whole number in the diver's depth unit per minute. An empty
/// box follows the diver's Settings default ([hintValue], shown greyed);
/// typing a value overrides it for this plan only (issue #3552) - the same
/// pattern Gas options already uses for ppO2/SAC overrides.
class _RateField extends StatelessWidget {
  const _RateField({
    required this.label,
    required this.value,
    required this.hintValue,
    required this.units,
    required this.onChanged,
  });

  /// Stored rate in m/min; null = follow the diver's Settings default.
  final double? value;

  /// The diver's Settings default, in m/min.
  final double hintValue;

  final String label;
  final UnitFormatter units;

  /// Receives the new rate in m/min (converted back from the display unit),
  /// or null when the plan's override is cleared.
  final ValueChanged<double?> onChanged;

  // Rate band, in m/min, kept canonical so the accepted range matches across
  // unit systems, and shared with the Settings defaults. The box bounds
  // narrow inward (ceil the minimum, floor the maximum) so every whole
  // number it accepts maps back inside the band: 1-30 m/min, 3-98 ft/min.
  static const _minMetric = kPlannerRateMinMetersPerMinute;
  static const _maxMetric = kPlannerRateMaxMetersPerMinute;

  @override
  Widget build(BuildContext context) {
    // Work the field in the diver's depth unit per minute; storage stays
    // m/min.
    final suffix = units.depthRateSymbol;
    return PlanNumberField(
      label: label,
      value: value != null ? units.convertDepth(value!) : null,
      hintValue: units.convertDepth(hintValue),
      suffixText: suffix,
      isInteger: true,
      min: units.convertDepth(_minMetric).ceilToDouble(),
      max: units.convertDepth(_maxMetric).floorToDouble(),
      semanticsLabel: '$label ($suffix)',
      onChanged: (v) => onChanged(v != null ? units.depthToMeters(v) : null),
    );
  }
}
