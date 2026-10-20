import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
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
        ],
      ),
    );
  }
}
