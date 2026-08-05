import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundUpTo;
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// Rock Bottom calculator.
///
/// Calculates the minimum gas reserve needed for emergency ascent,
/// accounting for buddy breathing, stressed SAC rates, problem-solving time
/// at depth, and safety stops.
class RockBottomCalculator extends ConsumerWidget {
  const RockBottomCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(rockBottomDepthProvider); // meters
    final ascentRate = ref.watch(rockBottomAscentRateProvider); // m/min
    final sac = ref.watch(rockBottomSacProvider); // L/min
    final buddySac = ref.watch(rockBottomBuddySacProvider); // L/min
    final solveMinutes = ref.watch(rockBottomSolveMinutesProvider);
    final tank = ref.watch(rockBottomTankProvider);
    final includeSafetyStop = ref.watch(rockBottomSafetyStopProvider);
    final result = ref.watch(rockBottomResultProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isMetricVolume = settings.volumeUnit == VolumeUnit.liters;
    final depthSymbol = units.depthSymbol;
    final volumeSymbol = units.volumeSymbol;
    final pressureSymbol = units.pressureSymbol;

    // Reserve rounds UP onto a real-world grid: turning the dive early is
    // safe, turning it late is not.
    final pressureGrid = settings.pressureUnit == PressureUnit.bar
        ? 10.0
        : 250.0;
    final displayPressure = roundUpTo(
      units.convertPressure(result.reserveBar),
      pressureGrid,
    );
    final displayVolume = units.convertVolume(result.totalLiters);

    final tankChoices = isMetricVolume
        ? metricTankChoices()
        : imperialTankChoices();

    final safetyStopDepthDisplay = units.convertDepth(5);

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
                        context
                            .l10n
                            .gasCalculators_rockBottom_emergencyScenario,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      UnitSlider(
                        icon: Icons.arrow_downward,
                        label:
                            context.l10n.gasCalculators_rockBottom_maximumDepth,
                        value: depth,
                        axis: UnitAxis.depth(units),
                        onChanged: (v) =>
                            ref.read(rockBottomDepthProvider.notifier).state =
                                v,
                      ),
                      const SizedBox(height: 20),

                      UnitSlider(
                        icon: Icons.arrow_upward,
                        label:
                            context.l10n.gasCalculators_rockBottom_ascentRate,
                        value: ascentRate,
                        axis: UnitAxis.ascentRate(units),
                        onChanged: (v) =>
                            ref
                                    .read(rockBottomAscentRateProvider.notifier)
                                    .state =
                                v,
                      ),
                      const SizedBox(height: 20),

                      UnitSlider(
                        icon: Icons.build_outlined,
                        label: context.l10n.gasCalculators_rockBottom_solveTime,
                        value: solveMinutes,
                        axis: UnitAxis.minutes(min: 0, max: 3),
                        onChanged: (v) =>
                            ref
                                    .read(
                                      rockBottomSolveMinutesProvider.notifier,
                                    )
                                    .state =
                                v,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.gasCalculators_rockBottom_solveTimeHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SAC rates card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.air, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            context
                                .l10n
                                .gasCalculators_rockBottom_stressedSacRates,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.gasCalculators_rockBottom_stressedSacHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      UnitSlider(
                        icon: Icons.person,
                        label: context.l10n.gasCalculators_rockBottom_yourSac,
                        value: sac,
                        axis: UnitAxis.stressedSac(units),
                        onChanged: (v) =>
                            ref.read(rockBottomSacProvider.notifier).state = v,
                      ),
                      const SizedBox(height: 20),

                      UnitSlider(
                        icon: Icons.people,
                        label: context.l10n.gasCalculators_rockBottom_buddySac,
                        value: buddySac,
                        axis: UnitAxis.stressedSac(units),
                        onChanged: (v) =>
                            ref
                                    .read(rockBottomBuddySacProvider.notifier)
                                    .state =
                                v,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tank & options card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.gasCalculators_rockBottom_tankSize,
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
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context
                              .l10n
                              .gasCalculators_rockBottom_includeSafetyStop,
                        ),
                        subtitle: Text(
                          context.l10n
                              .gasCalculators_rockBottom_safetyStopDuration(
                                safetyStopDepthDisplay.toStringAsFixed(0),
                                depthSymbol,
                              ),
                        ),
                        value: includeSafetyStop,
                        onChanged: (value) =>
                            ref
                                    .read(rockBottomSafetyStopProvider.notifier)
                                    .state =
                                value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Result card
              Semantics(
                label: context.l10n.gasCalculators_rockBottom_resultSemantics(
                  displayPressure.toStringAsFixed(0),
                  pressureSymbol,
                  displayVolume.toStringAsFixed(0),
                  volumeSymbol,
                ),
                child: Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.warning_amber,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context
                                  .l10n
                                  .gasCalculators_rockBottom_minimumReserve,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${displayPressure.toStringAsFixed(0)} $pressureSymbol',
                          style: textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                        Text(
                          '(${displayVolume.toStringAsFixed(0)} $volumeSymbol)',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onErrorContainer.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.onErrorContainer.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.l10n.gasCalculators_rockBottom_turnDive(
                              displayPressure.toStringAsFixed(0),
                              pressureSymbol,
                            ),
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.gasCalculators_planningCaveat,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer.withValues(
                              alpha: 0.8,
                            ),
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
                            Icons.list_alt,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context
                                .l10n
                                .gasCalculators_rockBottom_emergencyAscentBreakdown,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownRow(
                        context,
                        context
                            .l10n
                            .gasCalculators_rockBottom_combinedStressedSac,
                        '${units.convertVolume(sac + buddySac).toStringAsFixed(isMetricVolume ? 0 : 2)} '
                        '$volumeSymbol/min',
                      ),
                      if (solveMinutes > 0)
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_rockBottom_solveGas(
                            units.convertDepth(depth).toStringAsFixed(0),
                            depthSymbol,
                          ),
                          '${units.convertVolume(result.solveGasLiters).toStringAsFixed(0)} $volumeSymbol',
                        ),
                      _buildBreakdownRow(
                        context,
                        includeSafetyStop
                            ? context.l10n
                                  .gasCalculators_rockBottom_ascentTimeToDepth(
                                    safetyStopDepthDisplay.toStringAsFixed(0),
                                    depthSymbol,
                                  )
                            : context
                                  .l10n
                                  .gasCalculators_rockBottom_ascentTimeToSurface,
                        '${result.ascentMinutes.toStringAsFixed(1)} min',
                      ),
                      _buildBreakdownRow(
                        context,
                        context
                            .l10n
                            .gasCalculators_rockBottom_ascentGasRequired,
                        '${units.convertVolume(result.ascentGasLiters + result.finalAscentGasLiters).toStringAsFixed(0)} $volumeSymbol',
                      ),
                      if (includeSafetyStop)
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_rockBottom_safetyStopGas(
                            safetyStopDepthDisplay.toStringAsFixed(0),
                            depthSymbol,
                          ),
                          '${units.convertVolume(result.safetyStopGasLiters).toStringAsFixed(0)} $volumeSymbol',
                        ),
                      const Divider(height: 24),
                      _buildBreakdownRow(
                        context,
                        context
                            .l10n
                            .gasCalculators_rockBottom_totalReserveNeeded,
                        '${displayVolume.toStringAsFixed(0)} $volumeSymbol = '
                        '${displayPressure.toStringAsFixed(0)} $pressureSymbol',
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.gasCalculators_rockBottom_aboutTitle,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.gasCalculators_rockBottom_aboutDescription,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
      onSelected: (_) => ref.read(rockBottomTankProvider.notifier).state = tank,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
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
