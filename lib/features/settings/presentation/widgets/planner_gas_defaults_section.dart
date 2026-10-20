import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Global defaults for the planner Setup accordion's Gas options (issue
/// #3552): SAC rates, the stressed-SAC and buddy factors, problem-solving
/// time and the best-mix END target a new plan starts with, overridable per
/// plan without changing this default.
class PlannerGasDefaultsSection extends ConsumerWidget {
  const PlannerGasDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final notifier = ref.read(settingsProvider.notifier);

    Widget rmvTile({
      required String label,
      required double litersPerMinute,
      required ValueChanged<double> onChanged,
    }) {
      return ListTile(
        dense: true,
        title: Text(label),
        trailing: Text(
          units.formatRmv(litersPerMinute),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () async {
          final entered = await showDialog<double>(
            context: context,
            builder: (_) => PlannerDefaultNumberDialog(
              title: label,
              initialValue: units.convertRmv(litersPerMinute),
              unitSymbol: units.rmvSymbol,
            ),
          );
          if (entered == null || !entered.isFinite || entered <= 0) return;
          onChanged(units.volumeToLiters(entered));
        },
      );
    }

    Widget factorTile({
      required String label,
      required double factor,
      required ValueChanged<double> onChanged,
    }) {
      return ListTile(
        dense: true,
        title: Text(label),
        trailing: Text(
          '${factor.toStringAsFixed(1)}×',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () async {
          final entered = await showDialog<double>(
            context: context,
            builder: (_) => PlannerDefaultNumberDialog(
              title: label,
              initialValue: factor,
              unitSymbol: '×',
            ),
          );
          if (entered == null || !entered.isFinite || entered <= 0) return;
          onChanged(entered);
        },
      );
    }

    return Card(
      child: Column(
        children: [
          rmvTile(
            label: context.l10n.divePlanner_gasOptions_sacBottom,
            litersPerMinute: settings.plannerSacBottom,
            onChanged: notifier.setPlannerSacBottom,
          ),
          const Divider(height: 1),
          rmvTile(
            label: context.l10n.divePlanner_gasOptions_sacDeco,
            litersPerMinute: settings.plannerSacDeco,
            onChanged: notifier.setPlannerSacDeco,
          ),
          const Divider(height: 1),
          factorTile(
            label: context.l10n.divePlanner_gasOptions_sacStressedFactor,
            factor: settings.plannerSacStressedFactor,
            onChanged: notifier.setPlannerSacStressedFactor,
          ),
          const Divider(height: 1),
          factorTile(
            label: context.l10n.divePlanner_gasOptions_sacFactor,
            factor: settings.plannerBuddyFactor,
            onChanged: notifier.setPlannerBuddyFactor,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(
              context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
            ),
            trailing: Text(
              '${settings.plannerProblemSolvingMinutes} '
              '${context.l10n.divePlanner_label_minutesUnit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title:
                      context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
                  initialValue: settings.plannerProblemSolvingMinutes
                      .toDouble(),
                  unitSymbol: context.l10n.divePlanner_label_minutesUnit,
                  integer: true,
                ),
              );
              if (entered == null || !entered.isFinite || entered < 0) {
                return;
              }
              notifier.setPlannerProblemSolvingMinutes(entered.round());
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(
              context.l10n.divePlanner_gasOptions_gasSwitchStopSeconds,
            ),
            trailing: Text(
              '${(settings.plannerGasSwitchStopSeconds / 60).round()} '
              '${context.l10n.divePlanner_label_minutesUnit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title:
                      context.l10n.divePlanner_gasOptions_gasSwitchStopSeconds,
                  initialValue: (settings.plannerGasSwitchStopSeconds / 60)
                      .roundToDouble(),
                  unitSymbol: context.l10n.divePlanner_label_minutesUnit,
                  integer: true,
                ),
              );
              // 0 (no gas-switch stop) is the existing default and a valid
              // choice, same as the per-plan field.
              if (entered == null || !entered.isFinite || entered < 0) {
                return;
              }
              notifier.setPlannerGasSwitchStopSeconds((entered * 60).round());
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(context.l10n.divePlanner_gasOptions_bestMixEnd),
            trailing: Text(
              units.formatDepth(settings.plannerBestMixEndMeters, decimals: 0),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title: context.l10n.divePlanner_gasOptions_bestMixEnd,
                  initialValue: units.convertDepth(
                    settings.plannerBestMixEndMeters,
                  ),
                  unitSymbol: units.depthSymbol,
                  integer: true,
                ),
              );
              if (entered == null || !entered.isFinite || entered <= 0) {
                return;
              }
              notifier.setPlannerBestMixEndMeters(units.depthToMeters(entered));
            },
          ),
        ],
      ),
    );
  }
}
