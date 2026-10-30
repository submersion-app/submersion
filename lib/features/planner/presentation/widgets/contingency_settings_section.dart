import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Contingency configuration: deviation deltas and the turn-pressure rule.
class ContingencySettingsSection extends ConsumerStatefulWidget {
  const ContingencySettingsSection({super.key});

  @override
  ConsumerState<ContingencySettingsSection> createState() =>
      _ContingencySettingsSectionState();
}

class _ContingencySettingsSectionState
    extends ConsumerState<ContingencySettingsSection> {
  late final TextEditingController _fractionController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(divePlanNotifierProvider);
    _fractionController = TextEditingController(
      text: formatRoundedForInput(state.turnPressureFraction ?? (1 / 3), 2),
    );
  }

  @override
  void dispose() {
    _fractionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(divePlanNotifierProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final l10n = context.l10n;

    // domain.TurnPressureRule.off is the explicit "no tracking" choice
    // (reuses the pre-existing "None" wording); a `null` rule is the unset
    // state and shows the diver's Settings default instead (issue #3552),
    // which may itself resolve to "None".
    String concreteRuleLabel(domain.TurnPressureRule rule) => switch (rule) {
      domain.TurnPressureRule.off => l10n.plannerCanvas_turnRule_none,
      domain.TurnPressureRule.allUsable =>
        l10n.plannerCanvas_turnRule_allUsable,
      domain.TurnPressureRule.halves => l10n.plannerCanvas_turnRule_halves,
      domain.TurnPressureRule.thirds => l10n.plannerCanvas_turnRule_thirds,
      domain.TurnPressureRule.custom => l10n.plannerCanvas_turnRule_custom,
    };
    final settingsDefaultRule = ref.watch(plannerTurnPressureRuleProvider);
    String ruleLabel(domain.TurnPressureRule? rule) => rule == null
        ? l10n.divePlanner_label_defaultWithValue(
            settingsDefaultRule == null
                ? l10n.plannerCanvas_turnRule_none
                : concreteRuleLabel(settingsDefaultRule),
          )
        : concreteRuleLabel(rule);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.plannerCanvas_contingency_title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          // One field per row, like every other PlanNumberField in the Setup
          // accordion: pairing two in a Row (as this used to) overflows at
          // the accordion's usual narrow widths - the field's fixed-width
          // box and unit alone already approach the row's whole budget.
          PlanNumberField(
            label: l10n.plannerCanvas_contingency_depthDelta,
            value: state.deviationDepthDelta != null
                ? units.convertDepth(state.deviationDepthDelta!)
                : null,
            hintValue: units.convertDepth(
              ref.watch(plannerDeviationDepthDeltaProvider),
            ),
            suffixText: units.depthSymbol,
            min: 0,
            onChanged: (value) => notifier.updateContingencies(
              depthDelta: value != null ? units.depthToMeters(value) : null,
              clearDepthDelta: value == null,
            ),
          ),
          PlanNumberField(
            label: l10n.plannerCanvas_contingency_timeDelta,
            value: state.deviationTimeMinutes?.toDouble(),
            hintValue: ref
                .watch(plannerDeviationTimeMinutesProvider)
                .toDouble(),
            suffixText: l10n.divePlanner_label_minutesUnit,
            isInteger: true,
            min: 0,
            onChanged: (value) => notifier.updateContingencies(
              timeMinutes: value?.round(),
              clearTimeMinutes: value == null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<domain.TurnPressureRule?>(
                  initialValue: state.turnPressureRule,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.plannerCanvas_contingency_turnRule,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final rule in <domain.TurnPressureRule?>[
                      null,
                      ...domain.TurnPressureRule.values,
                    ])
                      DropdownMenuItem(
                        value: rule,
                        child: Text(
                          ruleLabel(rule),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (rule) => rule == null
                      ? notifier.updateContingencies(clearTurnRule: true)
                      : notifier.updateContingencies(turnRule: rule),
                ),
              ),
              if (state.turnPressureRule == domain.TurnPressureRule.custom) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: NumberField(
                    controller: _fractionController,
                    decoration: InputDecoration(
                      labelText: l10n.plannerCanvas_contingency_turnFraction,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (read) {
                      if (read is! NumberValue) return;
                      final parsed = read.value;
                      if (parsed <= 0 || parsed > 1) return;
                      notifier.updateContingencies(turnFraction: parsed);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
