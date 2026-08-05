import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundUpTo;
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// Gas Consumption calculator.
///
/// Calculates how much gas will be used during a dive based on
/// depth, time, SAC rate, and the selected cylinder.
class GasConsumptionCalculator extends ConsumerWidget {
  const GasConsumptionCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(consumptionDepthProvider); // meters
    final time = ref.watch(consumptionTimeProvider);
    final sac = ref.watch(consumptionSacProvider); // L/min
    final tank = ref.watch(consumptionTankProvider);
    final result = ref.watch(consumptionResultProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isMetricVolume = settings.volumeUnit == VolumeUnit.liters;
    final depthSymbol = units.depthSymbol;
    final volumeSymbol = units.volumeSymbol;
    final pressureSymbol = units.pressureSymbol;

    final displayDepth = units.convertDepth(depth);
    final displayVolume = units.convertVolume(result.litersConsumed);

    // Consumption rounds UP: planning to need more gas than you do is safe.
    final pressureGrid = settings.pressureUnit == PressureUnit.bar
        ? 10.0
        : 100.0;
    final displayPressure = roundUpTo(
      units.convertPressure(result.barConsumed),
      pressureGrid,
    );

    final tankChoices = isMetricVolume
        ? metricTankChoices()
        : imperialTankChoices();

    // The cylinder's own working pressure, not a flat 200 bar assumption.
    final tankFillPressure = units.convertPressure(tank.workingPressureBar);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.decoCalculator_diveParameters,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      UnitSlider(
                        icon: Icons.arrow_downward,
                        label: context.l10n.gasCalculators_consumption_avgDepth,
                        value: depth,
                        axis: UnitAxis.depth(units),
                        onChanged: (v) =>
                            ref.read(consumptionDepthProvider.notifier).state =
                                v,
                      ),
                      const SizedBox(height: 20),

                      UnitSlider(
                        icon: Icons.timer,
                        label: context.l10n.gasCalculators_consumption_diveTime,
                        value: time.toDouble(),
                        axis: UnitAxis.diveTime(),
                        onChanged: (v) =>
                            ref.read(consumptionTimeProvider.notifier).state = v
                                .toInt(),
                      ),
                      const SizedBox(height: 20),

                      UnitSlider(
                        icon: Icons.air,
                        label: context.l10n.gasCalculators_sacRate,
                        value: sac,
                        axis: UnitAxis.normalSac(units),
                        onChanged: (v) =>
                            ref.read(consumptionSacProvider.notifier).state = v,
                      ),
                      const SizedBox(height: 20),

                      // Tank size selector
                      Text(
                        context.l10n.gasCalculators_tankSize,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final choice in tankChoices)
                            _buildTankChip(
                              context,
                              ref,
                              choice,
                              choice == tank,
                              units,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Results card
              Semantics(
                label:
                    'Gas consumption: ${displayVolume.toStringAsFixed(0)} $volumeSymbol, '
                    '${displayPressure.toStringAsFixed(0)} $pressureSymbol'
                    '${result.exceedsTank ? '. Warning: exceeds tank capacity' : ''}',
                child: Card(
                  color: result.exceedsTank
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          context.l10n.gasCalculators_consumption_title,
                          style: textTheme.titleMedium?.copyWith(
                            color: result.exceedsTank
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildResultColumn(
                              context,
                              label: context
                                  .l10n
                                  .gasCalculators_consumption_volume,
                              value: displayVolume.toStringAsFixed(0),
                              unit: volumeSymbol,
                              isError: result.exceedsTank,
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color:
                                  (result.exceedsTank
                                          ? colorScheme.onErrorContainer
                                          : colorScheme.onPrimaryContainer)
                                      .withValues(alpha: 0.3),
                            ),
                            _buildResultColumn(
                              context,
                              label: context
                                  .l10n
                                  .gasCalculators_consumption_pressure,
                              value: displayPressure.toStringAsFixed(0),
                              unit: pressureSymbol,
                              isError: result.exceedsTank,
                            ),
                          ],
                        ),
                        if (result.exceedsTank) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: colorScheme.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.l10n
                                        .gasCalculators_consumption_exceedsTank(
                                          tankFillPressure.toStringAsFixed(0),
                                          pressureSymbol,
                                        ),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.gasCalculators_planningCaveat,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color:
                                (result.exceedsTank
                                        ? colorScheme.onErrorContainer
                                        : colorScheme.onPrimaryContainer)
                                    .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calculate,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.gasCalculators_consumption_breakdown,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownRow(
                        context,
                        context.l10n.gasCalculators_consumption_ambientPressure(
                          displayDepth.toStringAsFixed(0),
                          depthSymbol,
                        ),
                        '${((depth / 10) + 1).toStringAsFixed(2)} ATM',
                      ),
                      _buildBreakdownRow(
                        context,
                        context.l10n.gasCalculators_consumption_gasAtDepth,
                        '${units.convertVolume(result.gasAtDepthLitersPerMin).toStringAsFixed(isMetricVolume ? 1 : 2)} $volumeSymbol/min',
                      ),
                      _buildBreakdownRow(
                        context,
                        context.l10n.gasCalculators_consumption_totalGas(
                          time.toString(),
                        ),
                        '${displayVolume.toStringAsFixed(0)} $volumeSymbol',
                      ),
                      _buildBreakdownRow(
                        context,
                        context.l10n.gasCalculators_consumption_tankCapacity(
                          units
                              .convertVolume(tank.waterVolumeLiters)
                              .toStringAsFixed(isMetricVolume ? 0 : 1),
                          volumeSymbol,
                          tankFillPressure.toStringAsFixed(0),
                          pressureSymbol,
                        ),
                        '${units.convertVolume(tank.freeGasLiters).toStringAsFixed(0)} $volumeSymbol',
                      ),
                      const Divider(height: 24),
                      _buildBreakdownRow(
                        context,
                        context.l10n.gasCalculators_consumption_remainingGas,
                        '${units.convertVolume(result.litersRemaining).toStringAsFixed(0)} $volumeSymbol '
                        '(${units.convertPressure(result.barRemaining).toStringAsFixed(0)} $pressureSymbol)',
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTankChip(
    BuildContext context,
    WidgetRef ref,
    TankSpec tank,
    bool isSelected,
    UnitFormatter units,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(
        units.formatTankVolume(
          tank.waterVolumeLiters,
          tank.workingPressureBar,
          ratedCapacityCuft: tank.ratedCapacityCuft,
        ),
      ),
      selected: isSelected,
      onSelected: (_) =>
          ref.read(consumptionTankProvider.notifier).state = tank,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildResultColumn(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required bool isError,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Column(
      children: [
        Text(
          value,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          unit,
          style: textTheme.titleMedium?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: isHighlight
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isHighlight ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: isHighlight ? colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
