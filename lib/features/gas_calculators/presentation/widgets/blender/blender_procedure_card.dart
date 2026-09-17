import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_table_style.dart';
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
            const SizedBox(height: 4),
            _temperatureSummary(context, units, fillTemp, settledTemp),
            const SizedBox(height: 12),
            _stepTable(context, result.steps, units, decimals),
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

  /// The fill and settled temperatures set on the settings page, read-only
  /// here so a diver working the calculator does not have to open settings to
  /// see what they configured. Moved under this card's title, next to the
  /// procedure it conditions (issue #44 follow-up); both temperatures show
  /// unconditionally now, since a fill station cares what the cylinder settles
  /// to even when it happens to match the fill temperature today.
  ///
  /// Wraps onto two lines with [Wrap] rather than one `Text` with
  /// `overflow: ellipsis`: a phone-width card cannot fit both readings on
  /// one line, and the single-line version clipped "Ruhetemperatur" off
  /// entirely instead of just losing the middot separator (issue #1876
  /// follow-up).
  Widget _temperatureSummary(
    BuildContext context,
    UnitFormatter units,
    double fillTemp,
    double settledTemp,
  ) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    );
    return Wrap(
      key: const Key('blender-temperature-summary'),
      children: [
        Text(
          '${context.l10n.gasCalculators_blender_fillTemp}: '
          '${units.formatTemperature(fillTemp, decimals: 0)}',
          style: style,
        ),
        Text('  ·  ', style: style),
        Text(
          '${context.l10n.gasCalculators_blender_settledTemp}: '
          '${units.formatTemperature(settledTemp, decimals: 0)}',
          style: style,
        ),
      ],
    );
  }

  /// A flexible `Row`/`Expanded` table with the units in its header, so the
  /// columns compress in place on a narrow screen instead of overflowing
  /// off-screen the way `DataTable`'s fixed column widths did (issue #1876
  /// follow-up: the diver could not read the pressure or mix columns at all
  /// on a phone).
  static const List<int> _flex = [4, 4, 4, 4];

  Widget _stepTable(
    BuildContext context,
    List<BlendStep> steps,
    UnitFormatter units,
    int decimals,
  ) {
    final onPrimaryContainer = Theme.of(context).colorScheme.onPrimaryContainer;
    final headerStyle = blenderTableHeaderStyle(
      context,
      color: onPrimaryContainer,
    );
    final valueStyle = blenderTableValueStyle(
      context,
      color: onPrimaryContainer,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: _flex[0],
              child: Text(
                context.l10n.gasCalculators_blender_stepColumnAction,
                style: headerStyle,
              ),
            ),
            Expanded(
              flex: _flex[1],
              child: Text(
                '${context.l10n.gasCalculators_blender_stepColumnAdded} '
                '(${units.pressureSymbol})',
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: _flex[2],
              child: Text(
                '${context.l10n.gasCalculators_blender_stepColumnPressure} '
                '(${units.pressureSymbol})',
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: _flex[3],
              child: Text(
                context.l10n.gasCalculators_blender_stepColumnMix,
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final step in steps)
          _stepRow(context, step, units, decimals, valueStyle),
      ],
    );
  }

  Widget _stepRow(
    BuildContext context,
    BlendStep step,
    UnitFormatter units,
    int decimals,
    TextStyle? style,
  ) {
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
          Expanded(
            flex: _flex[0],
            child: Text(action, style: style),
          ),
          Expanded(
            flex: _flex[1],
            child: Text(added, style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: _flex[2],
            child: Text(
              units.formatPressureValue(step.pressureBar, decimals: decimals),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: _flex[3],
            child: Text(
              // Spaced around the '/' -- "Tx 14.7 / 55.9" rather than
              // "Tx 14.7/55.9" -- so this narrow column wraps at the spaces
              // instead of needing to fit the whole mix on one line (issue
              // #1876 follow-up). Scoped to this column rather than
              // formatPreciseMix itself, which other call sites (the
              // invoice's fill title, the cost card) still want compact.
              formatPreciseMix(
                context,
                step.resultingMix,
              ).replaceAll('/', ' / '),
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
