import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_default_number_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Global defaults for the DPV Team Setup-accordion fields that are diver
/// policy rather than mission-specific (issue #3552): the scooter battery
/// reserve and walking speed a new DPV mission starts with, overridable per
/// mission without changing this default.
class PlannerDpvTeamDefaultsSection extends ConsumerWidget {
  const PlannerDpvTeamDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = MissionUnits(UnitFormatter(settings));
    final notifier = ref.read(settingsProvider.notifier);

    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(context.l10n.plannerMission_settings_batteryReserve),
            trailing: Text(
              '${(settings.plannerBatteryReserveFraction * 100).round()}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title: context.l10n.plannerMission_settings_batteryReserve,
                  initialValue: settings.plannerBatteryReserveFraction * 100,
                  unitSymbol: '%',
                  integer: true,
                ),
              );
              if (entered == null ||
                  !entered.isFinite ||
                  entered <= 0 ||
                  entered > 100) {
                return;
              }
              notifier.setPlannerBatteryReserveFraction(entered / 100);
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(context.l10n.plannerMission_settings_walkSpeed),
            trailing: Text(
              '${units.speedDisplay(settings.plannerWalkSpeedMps).round()} '
              '${units.speedSymbol}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final entered = await showDialog<double>(
                context: context,
                builder: (_) => PlannerDefaultNumberDialog(
                  title: context.l10n.plannerMission_settings_walkSpeed,
                  initialValue: units.speedDisplay(
                    settings.plannerWalkSpeedMps,
                  ),
                  unitSymbol: units.speedSymbol,
                  integer: true,
                ),
              );
              if (entered == null || !entered.isFinite || entered <= 0) {
                return;
              }
              notifier.setPlannerWalkSpeedMps(units.speedMps(entered));
            },
          ),
        ],
      ),
    );
  }
}
