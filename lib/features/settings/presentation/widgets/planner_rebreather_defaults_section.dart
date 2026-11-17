import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
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

    // VO2 shows one more place than a flow: 1.3 L/min is 0.046 cuft/min, and
    // two places would round it to about 1.42 L/min.
    Widget tile({
      required String label,
      required double litersPerMinute,
      required int decimals,
      required ValueChanged<double> onChanged,
    }) {
      final shown = units.convertRmv(litersPerMinute);
      // The dialog opens two places finer than the row shows, and saving it
      // unchanged keeps the stored litres: a cuft/min round trip would
      // otherwise rewrite 12 L/min as 11.89.
      final seeded = double.parse(shown.toStringAsFixed(decimals + 2));
      return PlannerDefaultTile(
        label: label,
        valueText:
            '${formatFixedForDisplay(shown, decimals)} ${units.rmvSymbol}',
        initialValue: seeded,
        unitSymbol: units.rmvSymbol,
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
            decimals: units.rmvDecimals,
            onChanged: notifier.setPlannerScrInjectionRate,
          ),
          const Divider(height: 1),
          tile(
            label: l10n.plannerCanvas_scr_vo2,
            litersPerMinute: settings.scrVo2,
            decimals: units.rmvDecimals + 1,
            onChanged: notifier.setPlannerScrVo2,
          ),
          const Divider(height: 1),
          tile(
            label: l10n.plannerCanvas_pscr_vo2,
            litersPerMinute: settings.pscrVo2,
            decimals: units.rmvDecimals + 1,
            onChanged: notifier.setPlannerPscrVo2,
          ),
        ],
      ),
    );
  }
}
