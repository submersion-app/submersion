import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Contingency configuration: deviation deltas and the turn-pressure rule.
class ContingencySettingsSection extends ConsumerStatefulWidget {
  const ContingencySettingsSection({super.key});

  @override
  ConsumerState<ContingencySettingsSection> createState() =>
      _ContingencySettingsSectionState();
}

class _ContingencySettingsSectionState
    extends ConsumerState<ContingencySettingsSection> {
  late final TextEditingController _depthController;
  late final TextEditingController _timeController;
  late final TextEditingController _fractionController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(divePlanNotifierProvider);
    final units = UnitFormatter(ref.read(settingsProvider));
    _depthController = TextEditingController(
      text: formatRoundedForInput(
        units.convertDepth(state.deviationDepthDelta),
        0,
      ),
    );
    _timeController = TextEditingController(
      text: formatDecimalForInput(state.deviationTimeMinutes.toDouble()),
    );
    _fractionController = TextEditingController(
      text: formatRoundedForInput(state.turnPressureFraction ?? (1 / 3), 2),
    );
  }

  @override
  void dispose() {
    _depthController.dispose();
    _timeController.dispose();
    _fractionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(divePlanNotifierProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final l10n = context.l10n;

    String ruleLabel(domain.TurnPressureRule? rule) => switch (rule) {
      null => l10n.plannerCanvas_turnRule_none,
      domain.TurnPressureRule.allUsable =>
        l10n.plannerCanvas_turnRule_allUsable,
      domain.TurnPressureRule.halves => l10n.plannerCanvas_turnRule_halves,
      domain.TurnPressureRule.thirds => l10n.plannerCanvas_turnRule_thirds,
      domain.TurnPressureRule.custom => l10n.plannerCanvas_turnRule_custom,
    };

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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _depthController,
                  decoration: InputDecoration(
                    labelText:
                        '${l10n.plannerCanvas_contingency_depthDelta} '
                        '(${units.depthSymbol})',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (text) {
                    final parsed = parseUserDecimal(text);
                    if (parsed == null || parsed <= 0) return;
                    final factor = units.convertDepth(1.0);
                    notifier.updateContingencies(
                      depthDelta: factor > 0 ? parsed / factor : parsed,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: l10n.plannerCanvas_contingency_timeDelta,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (text) {
                    final parsed = parseUserInt(text);
                    if (parsed == null || parsed <= 0) return;
                    notifier.updateContingencies(timeMinutes: parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<domain.TurnPressureRule?>(
                  initialValue: state.turnPressureRule,
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
                        child: Text(ruleLabel(rule)),
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
                  child: TextFormField(
                    controller: _fractionController,
                    decoration: InputDecoration(
                      labelText: l10n.plannerCanvas_contingency_turnFraction,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (text) {
                      final parsed = parseUserDecimal(text);
                      if (parsed == null || parsed <= 0 || parsed > 1) return;
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
