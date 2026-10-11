import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_lines.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Satellite water conditions: temperature, anomaly, and — on reefs — the
/// coral thermal-stress classification.
///
/// Sea surface temperature and its anomaly are valid anywhere in the ocean;
/// the bleaching alert level and Degree Heating Weeks are coral framing and
/// only shown while [habitat] has not ruled a reef out. When shown, Degree
/// Heating Weeks is rendered next to the alert level, never behind a tap: the
/// level is an instantaneous classification while the damage it implies is
/// cumulative, so a reef mid-mortality can read "Bleaching Watch".
class WaterConditionsCard extends ConsumerWidget {
  final ReefPart<ReefHealth> health;

  /// Null while the habitat lookup is still resolving; the stress lines then
  /// stay, the conservative default.
  final ReefPart<ReefHabitat>? habitat;

  final WaterType? waterType;

  const WaterConditionsCard({
    super.key,
    required this.health,
    this.habitat,
    this.waterType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget tile(String subtitle, {bool isThreeLine = false}) => ListTile(
      leading: Icon(Icons.thermostat, color: scheme.primary),
      title: Text(
        context.l10n.water_conditions_title,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(subtitle),
      isThreeLine: isThreeLine,
      dense: true,
    );

    if (waterType == WaterType.fresh) {
      return tile(context.l10n.water_conditions_freshwater);
    }
    if (health.status == ReefDataStatus.unavailable) {
      return tile(context.l10n.water_conditions_unavailable);
    }
    if (health.status == ReefDataStatus.empty) {
      return tile(context.l10n.water_conditions_noData);
    }

    final lines = buildWaterConditionsLines(
      l10n: context.l10n,
      units: UnitFormatter(ref.watch(settingsProvider)),
      health: health.value!,
      reefPossible: reefPossibleFor(habitat),
    ).all;

    return tile(lines.join('\n'), isThreeLine: lines.length > 2);
  }
}
