import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/hypercapnia_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/ppo2_deco_bands_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Global defaults for the planner Setup accordion's Gas options (issue
/// #3552): SAC rates, the stressed-SAC and buddy factors, problem-solving
/// time and the best-mix END target a new plan starts with, overridable per
/// plan without changing this default. Also opens the per-O2-band deco
/// ppO2 limits and explicit-100%-O2-depth dialog (issue #3580): a planner
/// default, not a decompression algorithm setting, so it lives here rather
/// than on the Decompression page.
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
      return PlannerDefaultTile(
        label: label,
        valueText: units.formatRmv(litersPerMinute),
        initialValue: units.convertRmv(litersPerMinute),
        unitSymbol: units.rmvSymbol,
        onSaved: (entered) => onChanged(units.volumeToLiters(entered)),
      );
    }

    Widget factorTile({
      required String label,
      required double factor,
      required ValueChanged<double> onChanged,
    }) {
      return PlannerDefaultTile(
        label: label,
        valueText: '${factor.toStringAsFixed(1)}×',
        initialValue: factor,
        unitSymbol: '×',
        onSaved: onChanged,
      );
    }

    final minutesUnit = context.l10n.divePlanner_label_minutesUnit;

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
          PlannerDefaultTile(
            label: context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
            valueText: '${settings.plannerProblemSolvingMinutes} $minutesUnit',
            initialValue: settings.plannerProblemSolvingMinutes.toDouble(),
            unitSymbol: minutesUnit,
            integer: true,
            accept: PlannerDefaultTile.nonNegative,
            onSaved: (entered) =>
                notifier.setPlannerProblemSolvingMinutes(entered.round()),
          ),
          const Divider(height: 1),
          PlannerDefaultTile(
            label: context.l10n.divePlanner_gasOptions_gasSwitchStopSeconds,
            valueText:
                '${(settings.plannerGasSwitchStopSeconds / 60).round()} '
                '$minutesUnit',
            initialValue: (settings.plannerGasSwitchStopSeconds / 60)
                .roundToDouble(),
            unitSymbol: minutesUnit,
            integer: true,
            // 0 (no gas-switch stop) is the existing default and a valid
            // choice, same as the per-plan field.
            accept: PlannerDefaultTile.nonNegative,
            onSaved: (entered) =>
                notifier.setPlannerGasSwitchStopSeconds((entered * 60).round()),
          ),
          const Divider(height: 1),
          PlannerDefaultTile(
            label: context.l10n.divePlanner_gasOptions_bestMixEnd,
            valueText: units.formatDepth(
              settings.plannerBestMixEndMeters,
              decimals: 0,
            ),
            initialValue: units.convertDepth(settings.plannerBestMixEndMeters),
            unitSymbol: units.depthSymbol,
            integer: true,
            onSaved: (entered) => notifier.setPlannerBestMixEndMeters(
              units.depthToMeters(entered),
            ),
          ),
          const Divider(height: 1),
          PlannerDefaultTile(
            label: context.l10n.divePlanner_label_reserve,
            valueText: units.formatPressure(settings.plannerReservePressure),
            initialValue: units.convertPressure(
              settings.plannerReservePressure,
            ),
            unitSymbol: units.pressureSymbol,
            integer: true,
            onSaved: (entered) => notifier.setPlannerReservePressure(
              units.pressureToBar(entered),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(context.l10n.settings_decompression_ppO2BandsTitle),
            subtitle: Text(
              context.l10n.settings_decompression_ppO2BandsSubtitle,
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => showDialog(
              context: context,
              builder: (dialogContext) => PpO2DecoBandsDialog(
                initialBandsEnabled: settings.ppO2DecoBandsEnabled,
                initialBand1: settings.ppO2DecoBand1,
                initialBand2: settings.ppO2DecoBand2,
                initialBand3: settings.ppO2DecoBand3,
                initialMaxO2DepthEnabled: settings.maxO2DepthEnabled,
                initialMaxO2DepthMeters: settings.maxO2DepthMeters,
                initialFlatPpO2: settings.ppO2MaxDeco,
                units: units,
                onSave:
                    (
                      bandsEnabled,
                      band1,
                      band2,
                      band3,
                      maxO2DepthEnabled,
                      maxO2DepthMeters,
                    ) {
                      notifier.setPpO2DecoBandsConfig(
                        bandsEnabled: bandsEnabled,
                        band1: band1,
                        band2: band2,
                        band3: band3,
                        maxO2DepthEnabled: maxO2DepthEnabled,
                        maxO2DepthMeters: maxO2DepthMeters,
                      );
                    },
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.air),
            title: Text(context.l10n.settings_decompression_hypercapniaTitle),
            subtitle: Text(
              context.l10n.settings_decompression_hypercapniaSubtitle,
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => showDialog(
              context: context,
              builder: (dialogContext) => HypercapniaDialog(
                initialEnabled: settings.plannerHypercapniaEnabled,
                initialFactor: settings.plannerHypercapniaFactor,
                initialMinutes: settings.plannerHypercapniaMinutes,
                onSave: (enabled, factor, minutes) {
                  notifier.setPlannerHypercapniaConfig(
                    enabled: enabled,
                    factor: factor,
                    minutes: minutes,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
