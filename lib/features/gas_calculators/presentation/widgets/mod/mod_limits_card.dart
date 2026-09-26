import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_ppo2_limit_slider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The ppO2 limits the MOD is computed for, each defaulting to the active
/// diver's profile: working (Rec, OC Tec), deco (OC Tec) and the diluent's
/// flush ppO2 (CCR Tec).
class ModLimitsCard extends ConsumerWidget {
  const ModLimitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final mode = ref.watch(modCalculatorNotifierProvider).mode;
    final limits = ref.watch(modCalculatorLimitsProvider);
    final notifier = ref.read(modCalculatorNotifierProvider.notifier);

    final working = ModPpO2LimitSlider(
      label: l10n.gasCalculators_mod_workingPpO2,
      value: limits.workingPpO2,
      profileValue: settings.ppO2MaxWorking,
      isOverridden: limits.workingOverridden,
      onChanged: notifier.setWorkingPpO2,
      onReset: notifier.resetWorkingPpO2,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_mod_limitsTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (mode != ModCalculatorMode.ccrTec) ...[
              working,
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _workingDescription(context, limits.workingPpO2),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (mode == ModCalculatorMode.ocTec) ...[
              const SizedBox(height: 24),
              ModPpO2LimitSlider(
                label: l10n.gasCalculators_mod_decoPpO2,
                value: limits.decoPpO2,
                profileValue: settings.ppO2MaxDeco,
                isOverridden: limits.decoOverridden,
                onChanged: notifier.setDecoPpO2,
                onReset: notifier.resetDecoPpO2,
              ),
            ],
            // CCR Tec: only the diluent MOD ppO2, from the profile's CCR
            // limits. The setpoint sits with the target depth it applies to.
            if (mode == ModCalculatorMode.ccrTec) ...[
              // The profile's Dil MOD range and 0.1 bar grid.
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _workingDescription(BuildContext context, double ppO2) {
    if (ppO2 <= 1.2) return context.l10n.gasCalculators_mod_ppO2Conservative;
    if (ppO2 <= 1.4) return context.l10n.gasCalculators_mod_ppO2Standard;
    return context.l10n.gasCalculators_mod_ppO2Maximum;
  }
}
