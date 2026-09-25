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
    final prefs = ref.watch(modCalculatorNotifierProvider);
    final notifier = ref.read(modCalculatorNotifierProvider.notifier);
    final mode = prefs.mode;

    final working = ModPpO2LimitSlider(
      label: l10n.gasCalculators_mod_workingPpO2,
      value: prefs.workingPpO2 ?? settings.ppO2MaxWorking,
      profileValue: settings.ppO2MaxWorking,
      isOverridden: prefs.workingPpO2 != null,
      onChanged: (v) =>
          notifier.setWorkingPpO2(v, profileValue: settings.ppO2MaxWorking),
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
                  _workingDescription(
                    context,
                    prefs.workingPpO2 ?? settings.ppO2MaxWorking,
                  ),
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
                value: prefs.decoPpO2 ?? settings.ppO2MaxDeco,
                profileValue: settings.ppO2MaxDeco,
                isOverridden: prefs.decoPpO2 != null,
                onChanged: (v) =>
                    notifier.setDecoPpO2(v, profileValue: settings.ppO2MaxDeco),
                onReset: notifier.resetDecoPpO2,
              ),
            ],
            // CCR Tec follows the profile's CCR ppO2 limits: the high
            // setpoint and the diluent MOD ppO2.
            if (mode == ModCalculatorMode.ccrTec) ...[
              ModPpO2LimitSlider(
                label: l10n.gasCalculators_mod_setpoint,
                icon: Icons.tune,
                min: modSetpointMinBar,
                max: modSetpointMaxBar,
                step: 0.1,
                fractionDigits: 1,
                value: prefs.setpointBar ?? modProfileSetpoint(settings),
                profileValue: settings.ccrSetpointHigh,
                isOverridden: prefs.setpointBar != null,
                onChanged: (v) => notifier.setSetpoint(
                  v,
                  profileValue: modProfileSetpoint(settings),
                ),
                onReset: notifier.resetSetpoint,
              ),
              const SizedBox(height: 24),
              ModPpO2LimitSlider(
                label: l10n.gasCalculators_mod_flushPpO2,
                value: prefs.flushPpO2 ?? modProfileFlushPpO2(settings),
                profileValue: settings.ccrDiluentModPpO2,
                isOverridden: prefs.flushPpO2 != null,
                onChanged: (v) => notifier.setFlushPpO2(
                  v,
                  profileValue: modProfileFlushPpO2(settings),
                ),
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
