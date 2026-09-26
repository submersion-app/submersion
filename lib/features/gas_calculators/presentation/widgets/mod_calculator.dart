import 'package:flutter/material.dart';

import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_assessment_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_depth_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_input_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_limits_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_result_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Maximum Operating Depth (MOD) calculator.
///
/// Three modes (issue #2342): Rec for nitrox, OC Tec for trimix on open
/// circuit, CCR Tec for a diluent on a rebreather loop. Each gives the MOD,
/// rounded down, and assesses the gas at the MOD and at an optional target
/// depth. The inputs are saved like the blender's preferences.
class ModCalculator extends StatelessWidget {
  const ModCalculator({super.key});

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
              ModInputCard(),
              SizedBox(height: 16),
              ModLimitsCard(),
              SizedBox(height: 16),
              ModResultCard(),
              SizedBox(height: 16),
              ModAssessmentCard(),
              SizedBox(height: 16),
              ModDepthCard(),
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
                  context.l10n.gasCalculators_mod_aboutMod,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.gasCalculators_mod_aboutModesBody,
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
