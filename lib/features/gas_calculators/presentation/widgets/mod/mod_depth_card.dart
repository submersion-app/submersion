import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/density_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Colour of a density level, shared with the assessment card.
Color densityLevelColor(GasDensityLevel level, ColorScheme scheme) =>
    switch (level) {
      GasDensityLevel.ok => Colors.green,
      GasDensityLevel.warn => Colors.orange,
      GasDensityLevel.critical => scheme.error,
    };

/// The gas assessed at the MOD and, when one is set, at the target depth:
/// ppO2, EAD, and in the Tec modes END, EADD and the density level.
class ModDepthCard extends ConsumerWidget {
  const ModDepthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final result = ref.watch(modCalculatorResultProvider);
    final isTec = result.mode != ModCalculatorMode.rec;
    final columns = [
      result.atMod,
      if (result.atTarget != null) result.atTarget!,
    ];

    String depth(double meters) => units.formatDepth(meters, decimals: 1);

    TableRow row(String label, List<Widget> cells, {bool header = false}) =>
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                label,
                style: header
                    ? textTheme.labelLarge
                    : textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
            for (final cell in cells)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Align(alignment: Alignment.centerRight, child: cell),
              ),
          ],
        );

    Widget value(String text) => Text(
      text,
      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    Widget density(DepthAssessment a) {
      final level = a.densityLevel!;
      // Wraps rather than overflows in a narrow detail pane.
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: densityLevelColor(level, colorScheme),
          ),
          value('${formatFixedForDisplay(a.densityGPerL!, 2)} g/L'),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_mod_atDepthTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                row('', [
                  Text(
                    l10n.gasCalculators_mod_atMod,
                    style: textTheme.labelLarge,
                  ),
                  if (result.atTarget != null)
                    Text(
                      l10n.gasCalculators_mod_atTarget,
                      textAlign: TextAlign.right,
                      style: textTheme.labelLarge,
                    ),
                ], header: true),
                row(l10n.gasCalculators_mod_rowDepth, [
                  // The MOD column's depth is the MOD itself: floored.
                  value(units.formatDepthFloor(result.atMod.depthMeters)),
                  if (result.atTarget != null)
                    value(depth(result.atTarget!.depthMeters)),
                ]),
                row(l10n.gasCalculators_mod_rowPpO2, [
                  for (final a in columns)
                    value('${formatFixedForDisplay(a.pO2Bar, 2)} bar'),
                ]),
                row(l10n.gasCalculators_mod_rowEad, [
                  for (final a in columns) value(depth(a.eadMeters)),
                ]),
                if (isTec) ...[
                  row(l10n.gasCalculators_mod_rowEnd, [
                    for (final a in columns) value(depth(a.endMeters)),
                  ]),
                  row(l10n.gasCalculators_mod_rowEadd, [
                    for (final a in columns) value(depth(a.eaddMeters!)),
                  ]),
                  row(l10n.gasCalculators_mod_rowDensity, [
                    for (final a in columns) density(a),
                  ]),
                ],
              ],
            ),
            if (isTec) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.compress, size: 18),
                  label: Text(l10n.gasCalculators_mod_openDensity),
                  onPressed: () => _openDensityCalculator(context, ref, result),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hands the mix to the gas density calculator and opens it, at the
  /// target depth when one is set, otherwise at the MOD.
  void _openDensityCalculator(
    BuildContext context,
    WidgetRef ref,
    GasLimitsResult result,
  ) {
    final inputs = ref.read(modCalculatorInputsProvider);
    final isCcr = result.mode == ModCalculatorMode.ccrTec;
    final depth = (result.atTarget ?? result.atMod).depthMeters;
    ref.read(densityO2Provider.notifier).state = result.o2Percent;
    ref.read(densityHeProvider.notifier).state = result.hePercent;
    // The density slider steps in whole meters; floored, like the MOD.
    ref.read(densityDepthProvider.notifier).state = depth.floorToDouble().clamp(
      0.0,
      150.0,
    );
    ref.read(densityCcrProvider.notifier).state = isCcr;
    if (isCcr) {
      ref.read(densitySetpointProvider.notifier).state = inputs.setpointBar;
    }
    ref.read(densityWaterTypeProvider.notifier).state = inputs.waterType;
    context.go('$kGasCalculatorsRoutePrefix/density');
  }
}
