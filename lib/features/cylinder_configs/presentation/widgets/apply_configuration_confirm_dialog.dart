import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before a configuration replaces specs on cylinders already on the
/// dive (issue #2563). Resolves true only when the diver confirms.
///
/// [tanks] is the dive's cylinder list as the editor shows it, so each
/// change is labelled with the tank number the diver sees on the page.
Future<bool> confirmCylinderOverwrites(
  BuildContext context, {
  required String configName,
  required List<OverwriteTank> overwrites,
  required List<DiveTank> tanks,
  required UnitFormatter units,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ApplyConfigurationConfirmDialog(
      configName: configName,
      overwrites: overwrites,
      tanks: tanks,
      units: units,
    ),
  );
  return confirmed ?? false;
}

/// Lists every spec a configuration would replace, one group per cylinder.
class ApplyConfigurationConfirmDialog extends StatelessWidget {
  const ApplyConfigurationConfirmDialog({
    super.key,
    required this.configName,
    required this.overwrites,
    required this.tanks,
    required this.units,
  });

  final String configName;
  final List<OverwriteTank> overwrites;
  final List<DiveTank> tanks;
  final UnitFormatter units;

  List<String> _changeLines(BuildContext context, OverwriteTank change) {
    final l10n = context.l10n;
    final tank = tanks.where((t) => t.id == change.tankId).firstOrNull;
    final fromPressure = tank?.workingPressure;
    final toPressure = change.workingPressureBar?.to ?? fromPressure;

    String line(String field, String from, String to) =>
        l10n.cylinderConfigs_overwriteChange(field, from, to);

    return [
      if (change.volumeL case final volume?)
        line(
          l10n.cylinderConfigs_fieldVolume,
          // Volume shows in cubic feet through the working pressure, so each
          // side is formatted with the pressure it will be paired with.
          units.formatTankVolume(volume.from, fromPressure),
          units.formatTankVolume(volume.to, toPressure),
        ),
      if (change.workingPressureBar case final pressure?)
        line(
          l10n.cylinderConfigs_fieldWorkingPressure,
          units.formatPressure(pressure.from),
          units.formatPressure(pressure.to),
        ),
      if (change.tankMaterial case final material?)
        line(
          l10n.cylinderConfigs_fieldMaterial,
          material.from.localizedName(l10n),
          material.to.localizedName(l10n),
        ),
      if (change.tankName case final name?)
        line(l10n.cylinderConfigs_label, name.from, name.to),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.cylinderConfigs_overwriteTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cylinderConfigs_overwriteBody(configName)),
            for (final change in overwrites) ...[
              const SizedBox(height: 12),
              Text(
                l10n.cylinderConfigs_overwriteTank(
                  tanks.indexWhere((t) => t.id == change.tankId) + 1,
                  change.tankRole.localizedName(l10n),
                ),
                style: theme.textTheme.titleSmall,
              ),
              for (final line in _changeLines(context, change))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(line),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.cylinderConfigs_overwriteKeepsGas,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cylinderConfigs_overwriteConfirm),
        ),
      ],
    );
  }
}
