import 'package:flutter/material.dart';

import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_input_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_result_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gas density calculator.
///
/// Density in g/L of the breathed gas at a target depth, for a trimix on
/// open circuit or as the diluent of a CCR loop at a setpoint, at a gas
/// temperature of 0 C or 20 C, in salt or fresh water.
class DensityCalculator extends StatelessWidget {
  const DensityCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DensityInputCard(),
              SizedBox(height: 16),
              DensityResultCard(),
              SizedBox(height: 16),
              _InfoCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.gasCalculators_density_infoTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.gasCalculators_density_infoContent(
                formatFixedForDisplay(gasDensityWarnGPerL, 1),
                formatFixedForDisplay(gasDensityCriticalGPerL, 1),
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.gasCalculators_density_eaddInfo,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
