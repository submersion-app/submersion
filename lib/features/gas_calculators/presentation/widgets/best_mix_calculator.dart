import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_alternative_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_common_mixes_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_density_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_input_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_result_card.dart';

/// Best Mix calculator - finds the best breathing mix for a target depth.
///
/// Three modes (issue #3112), mirroring the MOD calculator (issue #2342):
/// Rec for nitrox, OC-Tec for trimix on open circuit, CCR-Tec for a diluent
/// flush or a bailout cylinder. Oxygen rounds DOWN to a whole percent so the
/// recommended mix's own MOD is at or beyond the target depth, and the MOD
/// is always shown alongside it. Helium is added when the diver's END
/// limit, or (Tec modes, optional) gas density, requires it.
class BestMixCalculator extends ConsumerWidget {
  const BestMixCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(bestMixCalculatorNotifierProvider).mode;
    final isTec = mode != BestMixMode.rec;
    final hasAlternative =
        ref.watch(bestMixCalculatorResultProvider).nitroxAlternative != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BestMixInputCard(),
              const SizedBox(height: 16),
              if (isTec) ...[
                const BestMixDensityCard(),
                const SizedBox(height: 16),
              ],
              const BestMixResultCard(),
              const SizedBox(height: 16),
              if (hasAlternative) ...[
                const BestMixAlternativeCard(),
                const SizedBox(height: 16),
              ],
              const BestMixCommonMixesCard(),
            ],
          ),
        ),
      ),
    );
  }
}
