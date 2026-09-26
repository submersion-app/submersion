import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/density_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_slider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// Slider and toggle bounds. The O2 floor reaches hypoxic trimix; the
/// setpoint range covers the low and high setpoints in common use.
const double _o2Min = 5;
const double _o2Max = 100;
const double _depthMaxMeters = 150;
const double _setpointMin = 0.4;
const double _setpointMax = 1.6;

/// Inputs of the gas density calculator: breathing mode, mix, setpoint,
/// depth, temperature and water type.
class DensityInputCard extends ConsumerWidget {
  const DensityInputCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final isCcr = ref.watch(densityCcrProvider);
    final o2 = ref.watch(densityO2Provider);
    final he = ref.watch(densityHeProvider);
    final setpoint = ref.watch(densitySetpointProvider);
    final depth = ref.watch(densityDepthProvider);
    final temperature = ref.watch(densityTemperatureProvider);
    final waterType = ref.watch(densityWaterTypeProvider);
    final heMax = 100.0 - o2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_density_inputParameters,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _Labelled(
              label: l10n.gasCalculators_density_mode,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.gasCalculators_density_modeOc),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.gasCalculators_density_modeCcr),
                  ),
                ],
                selected: {isCcr},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    ref.read(densityCcrProvider.notifier).state =
                        selection.first,
              ),
            ),
            if (isCcr) ...[
              const SizedBox(height: 8),
              Text(
                l10n.gasCalculators_density_diluentHint,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            DensitySlider(
              label: l10n.gasCalculators_density_o2Percent,
              value: o2,
              unit: '%',
              min: _o2Min,
              max: _o2Max,
              divisions: (_o2Max - _o2Min).toInt(),
              onChanged: (value) {
                ref.read(densityO2Provider.notifier).state = value;
                // Keep He within the room the new O2 leaves.
                final maxHe = 100.0 - value;
                if (ref.read(densityHeProvider) > maxHe) {
                  ref.read(densityHeProvider.notifier).state = maxHe;
                }
              },
            ),
            const SizedBox(height: 24),
            DensitySlider(
              label: l10n.gasCalculators_density_hePercent,
              value: he.clamp(0, heMax).toDouble(),
              unit: '%',
              min: 0,
              max: heMax,
              divisions: heMax.toInt().clamp(1, 95),
              onChanged: (value) =>
                  ref.read(densityHeProvider.notifier).state = value,
            ),
            if (isCcr) ...[
              const SizedBox(height: 24),
              DensitySlider(
                label: l10n.gasCalculators_density_setpoint,
                icon: Icons.tune,
                value: setpoint,
                unit: '',
                fractionDigits: 1,
                min: _setpointMin,
                max: _setpointMax,
                divisions: ((_setpointMax - _setpointMin) * 10).round(),
                onChanged: (value) =>
                    ref.read(densitySetpointProvider.notifier).state = value,
              ),
            ],
            const SizedBox(height: 24),
            // The shared depth axis steps in 1 m or 5 ft and derives the feet
            // bounds from the canonical range, as the other calculators do.
            UnitSlider(
              icon: Icons.arrow_downward,
              label: l10n.gasCalculators_density_depth,
              value: depth,
              axis: UnitAxis.depthRange(
                units,
                minMeters: 0,
                maxMeters: _depthMaxMeters,
              ),
              onChanged: (meters) =>
                  ref.read(densityDepthProvider.notifier).state = meters,
            ),
            const SizedBox(height: 24),
            // Side by side where they fit, one below the other on a narrow
            // screen.
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _Labelled(
                  label: l10n.gasCalculators_density_temperature,
                  child: SegmentedButton<GasDensityTemperature>(
                    segments: [
                      for (final option in GasDensityTemperature.values)
                        ButtonSegment(
                          value: option,
                          label: Text(
                            units.formatTemperature(
                              option.celsius,
                              decimals: 0,
                            ),
                          ),
                        ),
                    ],
                    selected: {temperature},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        ref.read(densityTemperatureProvider.notifier).state =
                            selection.first,
                  ),
                ),
                _Labelled(
                  label: l10n.decoCalculator_waterType,
                  child: SegmentedButton<WaterType>(
                    segments: [
                      for (final type in const [
                        WaterType.salt,
                        WaterType.fresh,
                      ])
                        ButtonSegment(
                          value: type,
                          label: Text(type.localizedName(l10n)),
                        ),
                    ],
                    selected: {waterType},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        ref.read(densityWaterTypeProvider.notifier).state =
                            selection.first,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small caption above a toggle.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
