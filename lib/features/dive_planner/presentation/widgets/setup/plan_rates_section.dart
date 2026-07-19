import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ascent and descent rate controls for the Setup accordion (Subsurface
/// parity G7/G8). Rates are stored in m/min internally; the sliders display
/// and edit in the diver's depth unit per minute (m/min or ft/min), converting
/// back to m/min for storage. Per-depth-band ascent rates land in a later phase.
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
        _RateSlider(
          label: context.l10n.plannerCanvas_rates_ascent,
          value: state.ascentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(ascent: v),
        ),
        _RateSlider(
          label: context.l10n.plannerCanvas_rates_descent,
          value: state.descentRate,
          units: units,
          onChanged: (v) => notifier.updateRates(descent: v),
        ),
      ],
    );
  }
}

class _RateSlider extends StatelessWidget {
  const _RateSlider({
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

  // Rate band, in m/min, kept canonical so the slider range matches across
  // unit systems (1-30 m/min ~= 3-98 ft/min).
  static const _minMetric = 1.0;
  static const _maxMetric = 30.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Work the slider in the diver's depth unit per minute; storage stays m/min.
    final minDisplay = units.convertDepth(_minMetric).roundToDouble();
    final maxDisplay = units.convertDepth(_maxMetric).roundToDouble();
    final display = units.convertDepth(value).clamp(minDisplay, maxDisplay);
    final suffix = '${units.depthSymbol}/min';
    final readout = '${display.round()} $suffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            Text(readout, style: theme.textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: display,
          min: minDisplay,
          max: maxDisplay,
          divisions: (maxDisplay - minDisplay).round(),
          label: readout,
          onChanged: (v) => onChanged(units.depthToMeters(v)),
        ),
      ],
    );
  }
}
