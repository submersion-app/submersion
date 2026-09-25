import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_slider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// Mode, mix, CCR setpoint, target depth and, in the Tec modes, the water
/// type and the minimum ppO2.
class ModInputCard extends ConsumerWidget {
  const ModInputCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final prefs = ref.watch(modCalculatorNotifierProvider);
    final notifier = ref.read(modCalculatorNotifierProvider.notifier);
    final mode = prefs.mode;
    final inputs = prefs.inputsFor(mode);
    final isRec = mode == ModCalculatorMode.rec;
    final isCcr = mode == ModCalculatorMode.ccrTec;

    final o2Min = isRec ? recMinO2Percent : tecMinO2Percent;
    final o2Max = isRec ? recMaxO2Percent : 100.0;
    final o2 = inputs.o2Percent.clamp(o2Min, o2Max).toDouble();
    final heMax = 100.0 - o2;

    final hint = switch (mode) {
      ModCalculatorMode.rec => l10n.gasCalculators_mod_modeRecHint,
      ModCalculatorMode.ocTec => l10n.gasCalculators_mod_modeOcTecHint,
      ModCalculatorMode.ccrTec => l10n.gasCalculators_mod_modeCcrTecHint,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_mod_inputParameters,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _Labelled(
              label: l10n.gasCalculators_mod_mode,
              child: SegmentedButton<ModCalculatorMode>(
                segments: [
                  ButtonSegment(
                    value: ModCalculatorMode.rec,
                    label: Text(l10n.gasCalculators_mod_modeRec),
                  ),
                  ButtonSegment(
                    value: ModCalculatorMode.ocTec,
                    label: Text(l10n.gasCalculators_mod_modeOcTec),
                  ),
                  ButtonSegment(
                    value: ModCalculatorMode.ccrTec,
                    label: Text(l10n.gasCalculators_mod_modeCcrTec),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    notifier.setMode(selection.first),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            DensitySlider(
              label: l10n.gasCalculators_mod_oxygenO2,
              value: o2,
              unit: '%',
              min: o2Min,
              max: o2Max,
              divisions: (o2Max - o2Min).round(),
              onChanged: notifier.setO2Percent,
            ),
            if (!isRec) ...[
              const SizedBox(height: 24),
              DensitySlider(
                label: l10n.gasCalculators_mod_heliumHe,
                value: inputs.hePercent.clamp(0, heMax).toDouble(),
                unit: '%',
                min: 0,
                max: heMax,
                divisions: heMax.round().clamp(1, 95),
                onChanged: notifier.setHePercent,
              ),
            ],
            if (isCcr) ...[
              const SizedBox(height: 24),
              DensitySlider(
                label: l10n.gasCalculators_mod_setpoint,
                icon: Icons.tune,
                value: inputs.setpointBar,
                unit: '',
                fractionDigits: 1,
                min: modSetpointMinBar,
                max: modSetpointMaxBar,
                divisions: ((modSetpointMaxBar - modSetpointMinBar) * 10)
                    .round(),
                onChanged: notifier.setSetpoint,
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gasCalculators_mod_checkTargetDepth),
              value: inputs.checkTargetDepth,
              onChanged: notifier.setCheckTargetDepth,
            ),
            if (inputs.checkTargetDepth)
              UnitSlider(
                icon: Icons.arrow_downward,
                label: l10n.gasCalculators_mod_targetDepth,
                value: inputs.targetDepthMeters,
                axis: UnitAxis.depthRange(
                  units,
                  minMeters: 0,
                  maxMeters: isRec ? recTargetMaxMeters : tecTargetMaxMeters,
                ),
                onChanged: notifier.setTargetDepth,
              ),
            if (!isRec) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
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
                      selected: {modCalculatorWaterType(prefs, settings)},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          notifier.setWaterType(selection.first),
                    ),
                  ),
                  _Labelled(
                    label: l10n.gasCalculators_mod_minPpO2,
                    child: SegmentedButton<double>(
                      segments: [
                        for (final option in modMinPpO2Options)
                          ButtonSegment(
                            value: option,
                            label: Text(formatFixedForDisplay(option, 2)),
                          ),
                      ],
                      selected: {prefs.minPpO2},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          notifier.setMinPpO2(selection.first),
                    ),
                  ),
                ],
              ),
            ],
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
