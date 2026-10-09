import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart'
    show modFlushPpO2Max, modFlushPpO2Min, tecTargetMaxMeters;
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_end_limit_slider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_ppo2_limit_slider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/profile_override_caption.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// Mode, CCR gas source, target depth and, in Rec, the ppO2 chips.
class BestMixInputCard extends ConsumerWidget {
  const BestMixInputCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final prefs = ref.watch(bestMixCalculatorNotifierProvider);
    final limits = ref.watch(bestMixCalculatorLimitsProvider);
    final notifier = ref.read(bestMixCalculatorNotifierProvider.notifier);
    final mode = prefs.mode;
    final inputs = prefs.inputsFor(mode);
    final isRec = mode == BestMixMode.rec;

    final hint = switch (mode) {
      BestMixMode.rec => l10n.gasCalculators_bestMix_modeRecHint,
      BestMixMode.ocTec => l10n.gasCalculators_bestMix_modeOcTecHint,
      BestMixMode.ccrTec => l10n.gasCalculators_bestMix_modeCcrTecHint,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_bestMix_targetDive,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            BestMixLabelled(
              label: l10n.gasCalculators_bestMix_mode,
              child: SegmentedButton<BestMixMode>(
                segments: [
                  ButtonSegment(
                    value: BestMixMode.rec,
                    label: Text(l10n.gasCalculators_bestMix_modeRec),
                  ),
                  ButtonSegment(
                    value: BestMixMode.ocTec,
                    label: Text(l10n.gasCalculators_bestMix_modeOcTec),
                  ),
                  ButtonSegment(
                    value: BestMixMode.ccrTec,
                    label: Text(l10n.gasCalculators_bestMix_modeCcrTec),
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
            if (mode == BestMixMode.ccrTec) ...[
              const SizedBox(height: 16),
              BestMixLabelled(
                label: l10n.gasCalculators_bestMix_ccrSource,
                child: SegmentedButton<CcrGasSource>(
                  segments: [
                    ButtonSegment(
                      value: CcrGasSource.diluent,
                      label: Text(l10n.gasCalculators_bestMix_ccrSourceDiluent),
                    ),
                    ButtonSegment(
                      value: CcrGasSource.bailout,
                      label: Text(l10n.gasCalculators_bestMix_ccrSourceBailout),
                    ),
                  ],
                  selected: {prefs.ccrSource},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      notifier.setCcrSource(selection.first),
                ),
              ),
            ],
            const SizedBox(height: 24),
            UnitSlider(
              icon: Icons.arrow_downward,
              label: l10n.gasCalculators_bestMix_targetDepth,
              value: inputs.depthMeters,
              axis: isRec
                  ? UnitAxis.targetDepth(units)
                  : UnitAxis.depthRange(
                      units,
                      minMeters: 6,
                      maxMeters: tecTargetMaxMeters,
                    ),
              onChanged: notifier.setDepth,
            ),
            const SizedBox(height: 24),
            if (isRec) ...[
              Text(
                l10n.gasCalculators_ppO2Limit,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final limit in [1.2, 1.4, 1.6])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: limit != 1.6 ? 8 : 0),
                        child: _PpO2Chip(
                          value: limit,
                          isSelected: inputs.recPpO2 == limit,
                          onSelected: notifier.setRecPpO2,
                        ),
                      ),
                    ),
                ],
              ),
            ] else if (mode == BestMixMode.ccrTec &&
                prefs.ccrSource == CcrGasSource.diluent)
              ModPpO2LimitSlider(
                label: l10n.gasCalculators_mod_flushPpO2,
                min: modFlushPpO2Min,
                max: modFlushPpO2Max,
                step: 0.1,
                fractionDigits: 1,
                value: limits.flushPpO2,
                profileValue: settings.ccrDiluentModPpO2,
                isOverridden: limits.flushOverridden,
                onChanged: notifier.setFlushPpO2,
                onReset: notifier.resetFlushPpO2,
              )
            else if (mode == BestMixMode.ccrTec &&
                prefs.ccrSource == CcrGasSource.bailout)
              // Bailout is an OC emergency cylinder: the diver's maximum
              // (deco) ppO2, not their working one.
              ModPpO2LimitSlider(
                label: l10n.gasCalculators_mod_decoPpO2,
                value: limits.decoPpO2,
                profileValue: settings.ppO2MaxDeco,
                isOverridden: limits.decoOverridden,
                onChanged: notifier.setDecoPpO2,
                onReset: notifier.resetDecoPpO2,
              )
            else
              ModPpO2LimitSlider(
                label: l10n.gasCalculators_mod_workingPpO2,
                value: limits.workingPpO2,
                profileValue: settings.ppO2MaxWorking,
                isOverridden: limits.workingOverridden,
                onChanged: notifier.setWorkingPpO2,
                onReset: notifier.resetWorkingPpO2,
              ),
            if (!isRec) ...[
              const SizedBox(height: 24),
              BestMixEndLimitSlider(
                label: l10n.settings_decompression_endLimit,
                value: limits.endLimitMeters,
                profileValueMeters: settings.endLimit,
                isOverridden: limits.endLimitOverridden,
                units: units,
                onChanged: notifier.setEndLimit,
                onReset: notifier.resetEndLimit,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settings_decompression_o2Narcotic),
                subtitle: Text(l10n.settings_decompression_o2Narcotic_subtitle),
                value: limits.o2Narcotic,
                onChanged: notifier.setO2Narcotic,
              ),
              ProfileOverrideCaption(
                isOverridden: limits.o2NarcoticOverridden,
                profileValueText: settings.o2Narcotic
                    ? l10n.common_action_yes
                    : l10n.common_action_no,
                onReset: notifier.resetO2Narcotic,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PpO2Chip extends StatelessWidget {
  const _PpO2Chip({
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  final double value;
  final bool isSelected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      // ppO2 is a physics unit and stays in bar regardless of unit settings.
      label: Text('${value.toStringAsFixed(1)} bar'),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }
}
