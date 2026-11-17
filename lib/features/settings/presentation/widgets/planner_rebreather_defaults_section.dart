import 'package:flutter/material.dart';

import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The diver's semi-closed loop defaults (issue #4660): the SCR supply
/// injection rate and VO2, and the pSCR VO2, in the diver's volume unit per
/// minute. A plan's own value in its SCR or pSCR Setup section overrides these
/// for that plan only.
class PlannerRebreatherDefaultsSection extends ConsumerWidget {
  const PlannerRebreatherDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      settingsProvider.select(
        (s) => (
          rate: s.plannerScrInjectionRate,
          scrVo2: s.plannerScrVo2,
          pscrVo2: s.plannerPscrVo2,
        ),
      ),
    );
    final units = ref.watch(unitFormatterProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Each row shows a loop flow as the plan's own fields do, so a default
    // reads here exactly as it does as the plan's hint.
    final decimals = units.loopFlowDecimals;
    Widget tile({
      required String label,
      required double litersPerMinute,
      required ValueChanged<double> onChanged,
    }) {
      // The dialog opens two places finer than the row shows, and saving it
      // unchanged keeps the stored litres: a cuft/min round trip would
      // otherwise rewrite 12 L/min as 11.89.
      final seeded = double.parse(
        units.convertRmv(litersPerMinute).toStringAsFixed(decimals + 2),
      );
      return PlannerDefaultTile(
        label: label,
        valueText: units.formatRmv(litersPerMinute, decimals: decimals),
        initialValue: seeded,
        unitSymbol: units.rmvSymbol,
        // The floor the plan's own fields and agent writes hold to.
        accept: (entered) =>
            units.volumeToLiters(entered) >= ScrCalculator.minLoopFlowLpm,
        onSaved: (entered) {
          if (entered == seeded) return;
          onChanged(units.volumeToLiters(entered));
        },
      );
    }

    final l10n = context.l10n;
    return Card(
      child: Column(
        children: [
          tile(
            label: l10n.plannerCanvas_scr_injectionRate,
            litersPerMinute: settings.rate,
            onChanged: notifier.setPlannerScrInjectionRate,
          ),
          const Divider(height: 1),
          tile(
            label: l10n.plannerCanvas_scr_vo2,
            litersPerMinute: settings.scrVo2,
            onChanged: notifier.setPlannerScrVo2,
          ),
          const Divider(height: 1),
          tile(
            label: l10n.plannerCanvas_pscr_vo2,
            litersPerMinute: settings.pscrVo2,
            onChanged: notifier.setPlannerPscrVo2,
          ),
        ],
      ),
    );
  }
}
