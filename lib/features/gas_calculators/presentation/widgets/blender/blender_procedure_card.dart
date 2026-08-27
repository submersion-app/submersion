import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The fill procedure, or the reason there is not one.
///
/// Each line names the gas, the bar it delivers, the pressure to stop at, and
/// what is in the cylinder afterwards. The bar delivered is what issue #936
/// asked for and what a fill station meters; the build this replaces reported
/// a surface volume in litres instead, which is not a quantity anyone can read
/// off a gauge.
class BlenderProcedureCard extends ConsumerWidget {
  const BlenderProcedureCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final outcome = ref.watch(blenderResultProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final decimals = pressureDecimalsFor(settings.pressureUnit);

    if (outcome.error != null) {
      return Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorText(
                    context,
                    units,
                    outcome.error!,
                    outcome.drainToBar,
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final result = outcome.result!;
    final fillTemp = ref.watch(blenderFillTempProvider);
    final settledTemp = ref.watch(blenderSettledTempProvider);

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.gasCalculators_blender_procedure,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            for (final step in result.steps)
              _stepLine(context, step, units, decimals),
            // Only worth saying when the two temperatures differ. At equal
            // temperatures the last step already reads the target, and a
            // "settles to" line would restate it.
            if (fillTemp != settledTemp) ...[
              const Divider(height: 24),
              Text(
                context.l10n.gasCalculators_blender_settlesTo(
                  units.formatPressure(
                    result.settledPressureBar,
                    decimals: decimals,
                  ),
                  units.formatTemperature(settledTemp, decimals: 0),
                ),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepLine(
    BuildContext context,
    BlendStep step,
    UnitFormatter units,
    int decimals,
  ) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    );
    final action = step.fillGas == null
        ? context.l10n.gasCalculators_blender_stepStartLabel
        : context.l10n.gasCalculators_blender_stepAdd(
            formatPreciseGasName(context, step.fillGas!),
          );
    final added = step.fillGas == null
        ? ''
        : '+${units.formatPressureValue(step.addedBar, decimals: decimals)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(action, style: style)),
          Expanded(
            flex: 4,
            child: Text(added, style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 5,
            child: Text(
              units.formatPressure(step.pressureBar, decimals: decimals),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              formatPreciseMix(context, step.resultingMix),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _errorText(
    BuildContext context,
    UnitFormatter units,
    BlendError error,
    double? drainToBar,
  ) {
    switch (error) {
      case BlendError.targetPressureNotHigher:
        return context.l10n.gasCalculators_blender_error_targetPressure;
      case BlendError.invalidMix:
        return context.l10n.gasCalculators_blender_error_invalidMix;
      case BlendError.identicalNitroxGases:
        return context.l10n.gasCalculators_blender_error_identicalGases;
      case BlendError.linearlyDependentGases:
        return context.l10n.gasCalculators_blender_error_linearlyDependent;
      case BlendError.cannotRemoveHelium:
        return context.l10n.gasCalculators_blender_error_cannotRemoveHelium;
      case BlendError.insufficientFillGases:
        return context.l10n.gasCalculators_blender_error_insufficientGases;
      case BlendError.targetNotReached:
        return context.l10n.gasCalculators_blender_error_targetNotReached;
      case BlendError.implausibleStartMix:
        return context.l10n.gasCalculators_blender_error_implausibleStartMix;
      case BlendError.negativeAmountRequired:
        // Naming the pressure to bleed down to is the whole answer here; a
        // bare "not achievable" leaves the blender to guess it.
        if (drainToBar == null) {
          return context.l10n.gasCalculators_blender_error_negativeAmount;
        }
        if (drainToBar < 1) {
          return context.l10n.gasCalculators_blender_error_drainEmpty;
        }
        return context.l10n.gasCalculators_blender_error_drainTo(
          units.formatPressure(drainToBar),
        );
    }
  }
}
