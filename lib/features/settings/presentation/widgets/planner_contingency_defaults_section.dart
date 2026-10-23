import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';

/// Global defaults for the planner Setup accordion's Contingency fields
/// (issue #3552): the what-if depth and time deviation a new plan starts
/// with, overridable per plan without changing this default.
class PlannerContingencyDefaultsSection extends ConsumerWidget {
  const PlannerContingencyDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;

    // TurnPressureRule.off never reaches this dropdown - it is the per-plan
    // "explicitly off despite the default" choice (issue #3552), meaningless
    // as the default itself, which is just null/"None" here - but the
    // switch must stay exhaustive.
    String ruleLabel(domain.TurnPressureRule? rule) => switch (rule) {
      null || domain.TurnPressureRule.off => l10n.plannerCanvas_turnRule_none,
      domain.TurnPressureRule.allUsable =>
        l10n.plannerCanvas_turnRule_allUsable,
      domain.TurnPressureRule.halves => l10n.plannerCanvas_turnRule_halves,
      domain.TurnPressureRule.thirds => l10n.plannerCanvas_turnRule_thirds,
      domain.TurnPressureRule.custom => l10n.plannerCanvas_turnRule_custom,
    };

    return Card(
      child: Column(
        children: [
          PlannerDefaultTile(
            label: context.l10n.plannerCanvas_contingency_depthDelta,
            valueText: units.formatDepth(settings.plannerDeviationDepthDelta),
            initialValue: units.convertDepth(
              settings.plannerDeviationDepthDelta,
            ),
            unitSymbol: units.depthSymbol,
            // 0 is a valid "no deviation" default, same as the per-plan
            // field (contingency_settings_section.dart, min: 0).
            accept: PlannerDefaultTile.nonNegative,
            onSaved: (entered) => notifier.setPlannerDeviationDepthDelta(
              units.depthToMeters(entered),
            ),
          ),
          const Divider(height: 1),
          PlannerDefaultTile(
            label: context.l10n.plannerCanvas_contingency_timeDelta,
            valueText:
                '${settings.plannerDeviationTimeMinutes} '
                '${context.l10n.divePlanner_label_minutesUnit}',
            initialValue: settings.plannerDeviationTimeMinutes.toDouble(),
            unitSymbol: context.l10n.divePlanner_label_minutesUnit,
            integer: true,
            accept: PlannerDefaultTile.nonNegative,
            onSaved: (entered) =>
                notifier.setPlannerDeviationTimeMinutes(entered.round()),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: LabelWithControl(
              label: Text(l10n.plannerCanvas_contingency_turnRule),
              control: DropdownButton<domain.TurnPressureRule?>(
                value: settings.plannerTurnPressureRule,
                underline: const SizedBox.shrink(),
                items: [
                  for (final rule in <domain.TurnPressureRule?>[
                    null,
                    domain.TurnPressureRule.allUsable,
                    domain.TurnPressureRule.halves,
                    domain.TurnPressureRule.thirds,
                    domain.TurnPressureRule.custom,
                  ])
                    DropdownMenuItem(value: rule, child: Text(ruleLabel(rule))),
                ],
                onChanged: notifier.setPlannerTurnPressureRule,
              ),
            ),
          ),
          if (settings.plannerTurnPressureRule ==
              domain.TurnPressureRule.custom) ...[
            const Divider(height: 1),
            PlannerDefaultTile(
              label: l10n.plannerCanvas_contingency_turnFraction,
              valueText: (settings.plannerTurnPressureFraction ?? (1 / 3))
                  .toStringAsFixed(2),
              initialValue: settings.plannerTurnPressureFraction ?? (1 / 3),
              unitSymbol: '',
              accept: (v) => v > 0 && v <= 1,
              onSaved: notifier.setPlannerTurnPressureFraction,
            ),
          ],
        ],
      ),
    );
  }
}
