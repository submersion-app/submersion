import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
          ListTile(
            dense: true,
            title: Text(context.l10n.plannerCanvas_contingency_depthDelta),
            trailing: Text(
              units.formatDepth(settings.plannerDeviationDepthDelta),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title: context.l10n.plannerCanvas_contingency_depthDelta,
                  initialValue: units.convertDepth(
                    settings.plannerDeviationDepthDelta,
                  ),
                  unitSymbol: units.depthSymbol,
                ),
              );
              // 0 is a valid "no deviation" default, same as the per-plan
              // field (contingency_settings_section.dart, min: 0).
              if (entered == null || !entered.isFinite || entered < 0) {
                return;
              }
              notifier.setPlannerDeviationDepthDelta(
                units.depthToMeters(entered),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(context.l10n.plannerCanvas_contingency_timeDelta),
            trailing: Text(
              '${settings.plannerDeviationTimeMinutes} '
              '${context.l10n.divePlanner_label_minutesUnit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title: context.l10n.plannerCanvas_contingency_timeDelta,
                  initialValue: settings.plannerDeviationTimeMinutes.toDouble(),
                  unitSymbol: context.l10n.divePlanner_label_minutesUnit,
                  integer: true,
                ),
              );
              // 0 is a valid "no deviation" default, same as the per-plan
              // field.
              if (entered == null || !entered.isFinite || entered < 0) {
                return;
              }
              notifier.setPlannerDeviationTimeMinutes(entered.round());
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(l10n.plannerCanvas_contingency_turnRule),
            trailing: DropdownButton<domain.TurnPressureRule?>(
              value: settings.plannerTurnPressureRule,
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
          if (settings.plannerTurnPressureRule ==
              domain.TurnPressureRule.custom) ...[
            const Divider(height: 1),
            ListTile(
              dense: true,
              title: Text(l10n.plannerCanvas_contingency_turnFraction),
              trailing: Text(
                settings.plannerTurnPressureFraction?.toStringAsFixed(2) ??
                    (1 / 3).toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () async {
                final entered = await showDialog<double>(
                  context: context,
                  builder: (_) => PlannerDefaultNumberDialog(
                    title: l10n.plannerCanvas_contingency_turnFraction,
                    initialValue:
                        settings.plannerTurnPressureFraction ?? (1 / 3),
                    unitSymbol: '',
                  ),
                );
                if (entered == null ||
                    !entered.isFinite ||
                    entered <= 0 ||
                    entered > 1) {
                  return;
                }
                notifier.setPlannerTurnPressureFraction(entered);
              },
            ),
          ],
        ],
      ),
    );
  }
}
