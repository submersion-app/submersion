import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The optional density-aware helium switch. Tec modes only; Rec never
/// shows this card. Temperature and water type live on the input card
/// (same row as the CCR gas source), since they also affect MOD/END/EAD
/// in Tec modes regardless of this switch.
class BestMixDensityCard extends ConsumerWidget {
  const BestMixDensityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(bestMixCalculatorNotifierProvider);
    final notifier = ref.read(bestMixCalculatorNotifierProvider.notifier);
    final inputs = prefs.inputsFor(prefs.mode);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_bestMix_densityLabel,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gasCalculators_bestMix_densityAware),
              value: inputs.densityAware,
              onChanged: notifier.setDensityAware,
            ),
          ],
        ),
      ),
    );
  }
}
