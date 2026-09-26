import 'package:flutter/material.dart';

import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/density_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The density at depth, its standing against the 5.2 / 6.2 g/L limits, and
/// on CCR the loop gas the density was computed for.
class DensityResultCard extends ConsumerWidget {
  const DensityResultCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final result = ref.watch(densityResultProvider);
    final isCcr = ref.watch(densityCcrProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onContainer = colorScheme.onPrimaryContainer;

    const digits = 2;
    final density = '${formatFixedForDisplay(result.densityGPerL, digits)} g/L';
    final level = gasDensityLevelForDisplay(result.densityGPerL, digits);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final eadd =
        '${l10n.gasCalculators_density_eaddLabel}: '
        '${units.formatDepth(result.eaddMeters, decimals: 0)}';
    final (statusIcon, statusColor, statusText) = switch (level) {
      GasDensityLevel.ok => (
        Icons.check_circle,
        Colors.green,
        l10n.gasCalculators_density_withinLimit(
          formatFixedForDisplay(gasDensityWarnGPerL, 1),
        ),
      ),
      GasDensityLevel.warn => (
        Icons.warning,
        Colors.orange,
        l10n.gasCalculators_bestMix_densityWarn(
          formatFixedForDisplay(gasDensityWarnGPerL, 1),
        ),
      ),
      GasDensityLevel.critical => (
        Icons.error,
        colorScheme.error,
        l10n.gasCalculators_bestMix_densityCritical(
          formatFixedForDisplay(gasDensityCriticalGPerL, 1),
        ),
      ),
    };

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // One announcement for the headline figures. The CCR loop details
            // below stay outside it, so a screen reader still reaches them.
            Semantics(
              label:
                  '${l10n.gasCalculators_density_resultTitle}: $density. '
                  '$statusText $eadd',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text(
                      l10n.gasCalculators_density_resultTitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: onContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      density,
                      style: textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(statusIcon, size: 24, color: statusColor),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            statusText,
                            style: textTheme.bodyMedium?.copyWith(
                              color: onContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      eadd,
                      textAlign: TextAlign.center,
                      style: textTheme.titleSmall?.copyWith(color: onContainer),
                    ),
                  ],
                ),
              ),
            ),
            if (isCcr) ..._loopDetails(context, result, onContainer),
          ],
        ),
      ),
    );
  }

  List<Widget> _loopDetails(
    BuildContext context,
    GasDensityResult result,
    Color color,
  ) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final subtle = color.withValues(alpha: 0.8);
    String percent(double value) => formatFixedForDisplay(value, 1);

    return [
      const SizedBox(height: 24),
      Text(
        l10n.gasCalculators_density_loopGasTitle,
        style: textTheme.titleSmall?.copyWith(color: color),
      ),
      const SizedBox(height: 4),
      Text(
        l10n.gasCalculators_density_loopComposition(
          percent(result.loopO2Percent),
          percent(result.loopHePercent),
          percent(result.loopN2Percent),
        ),
        style: textTheme.bodyMedium?.copyWith(color: subtle),
      ),
      if (result.setpointCapped) ...[
        const SizedBox(height: 12),
        _Hint(text: l10n.gasCalculators_density_setpointCapped, color: color),
      ],
      if (result.diluentAboveSetpoint) ...[
        const SizedBox(height: 12),
        _Hint(
          text: l10n.gasCalculators_density_diluentAboveSetpoint(
            formatFixedForDisplay(result.pO2Bar, 2),
          ),
          color: color,
        ),
      ],
    ];
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
