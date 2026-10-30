import 'package:flutter/material.dart';

import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Global defaults for the planner Setup accordion's Deco/Rates fields
/// (issue #3552): the descent and ascent rates a new plan starts with,
/// overridable per plan without changing this default.
class PlannerRatesDefaultsSection extends ConsumerWidget {
  const PlannerRatesDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final notifier = ref.read(settingsProvider.notifier);
    final suffix = units.depthRateSymbol;

    Widget rateTile({
      required String label,
      required double meters,
      required ValueChanged<double> onChanged,
    }) {
      return PlannerDefaultTile(
        label: label,
        valueText: units.formatDepthRate(meters, decimals: 0),
        initialValue: units.convertDepth(meters),
        unitSymbol: suffix,
        integer: true,
        onSaved: (entered) => onChanged(units.depthToMeters(entered)),
      );
    }

    Widget minutesTile({
      required String label,
      required int seconds,
      required ValueChanged<int> onChanged,
    }) {
      final minutesUnit = context.l10n.divePlanner_label_minutesUnit;
      return PlannerDefaultTile(
        label: label,
        valueText: '${(seconds / 60).round()} $minutesUnit',
        initialValue: (seconds / 60).round().toDouble(),
        unitSymbol: minutesUnit,
        integer: true,
        onSaved: (entered) => onChanged((entered * 60).round()),
      );
    }

    return Card(
      child: Column(
        children: [
          rateTile(
            label: context.l10n.plannerCanvas_rates_descent,
            meters: settings.plannerDescentRate,
            onChanged: notifier.setPlannerDescentRate,
          ),
          const Divider(height: 1),
          rateTile(
            label: context.l10n.plannerCanvas_rates_ascent,
            meters: settings.plannerAscentRate,
            onChanged: notifier.setPlannerAscentRate,
          ),
          const Divider(height: 1),
          rateTile(
            label: context.l10n.plannerCanvas_rates_intermediateAscent,
            meters: settings.plannerIntermediateAscentRate,
            onChanged: notifier.setPlannerIntermediateAscentRate,
          ),
          const Divider(height: 1),
          rateTile(
            label: context.l10n.plannerCanvas_rates_shallowAscent,
            meters: settings.plannerShallowAscentRate,
            onChanged: notifier.setPlannerShallowAscentRate,
          ),
          const Divider(height: 1),
          rateTile(
            label: context.l10n.settings_decompression_rates_finalAscent,
            meters: settings.plannerFinalAscentRate,
            onChanged: notifier.setPlannerFinalAscentRate,
          ),
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            title: Text(context.l10n.divePlanner_label_airBreaks),
            value: settings.plannerAirBreakO2Seconds != null,
            onChanged: (enabled) {
              if (enabled) {
                const policy = AirBreakPolicy();
                notifier.setPlannerAirBreakPolicy(
                  o2Seconds: policy.o2Seconds,
                  breakSeconds: policy.breakSeconds,
                );
              } else {
                notifier.setPlannerAirBreakPolicy();
              }
            },
          ),
          if (settings.plannerAirBreakO2Seconds != null) ...[
            const Divider(height: 1),
            minutesTile(
              label: context.l10n.divePlanner_label_airBreaksOnO2,
              seconds: settings.plannerAirBreakO2Seconds!,
              onChanged: notifier.setPlannerAirBreakO2Seconds,
            ),
            const Divider(height: 1),
            minutesTile(
              label: context.l10n.divePlanner_label_airBreaksBreak,
              seconds: settings.plannerAirBreakBreakSeconds ?? 0,
              onChanged: notifier.setPlannerAirBreakBreakSeconds,
            ),
          ],
        ],
      ),
    );
  }
}
