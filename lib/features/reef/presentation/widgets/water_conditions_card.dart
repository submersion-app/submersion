import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
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

  /// Null while the habitat lookup is still resolving (dive detail page).
  final ReefPart<ReefHabitat>? habitat;

  final WaterType? waterType;

  const WaterConditionsCard({
    super.key,
    required this.health,
    this.habitat,
    this.waterType,
  });

  /// True unless habitat definitively answered "no reef here". An offline
  /// habitat provider must never hide an active bleaching alert.
  bool get _reefPossible =>
      habitat == null || habitat!.status != ReefDataStatus.empty;

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

    final data = health.value!;
    final tempUnit = ref.watch(temperatureUnitProvider);

    final lines = <String>[];
    if (_reefPossible) {
      final level = data.alertLevel;
      if (level != null) lines.add(_levelLabel(context, level));
      if (data.degreeHeatingWeeks != null) {
        lines.add(
          context.l10n.reef_health_degreeHeatingWeeks(
            data.degreeHeatingWeeks!.toStringAsFixed(1),
          ),
        );
      }
    }
    if (data.sst != null) {
      final value = TemperatureUnit.celsius.convert(data.sst!, tempUnit);
      lines.add(
        context.l10n.reef_health_seaSurface(
          '${value.toStringAsFixed(1)}${tempUnit.symbol}',
        ),
      );
    }
    if (data.sstAnomaly != null) {
      // The anomaly is a temperature difference, not a temperature: it
      // scales between units but never takes the Fahrenheit offset.
      final value = TemperatureUnit.celsius.convertDelta(
        data.sstAnomaly!,
        tempUnit,
      );
      final signed = value >= 0
          ? '+${value.toStringAsFixed(1)}'
          : value.toStringAsFixed(1);
      lines.add(
        context.l10n.water_conditions_anomaly('$signed${tempUnit.symbol}'),
      );
    }
    // NOAA publishes one composite per UTC day, stamped at 12:00Z. Converting
    // to local time would shift that stamp into the next or previous calendar
    // day at the extremes of the timezone range, reporting an observation
    // date the dataset never had.
    lines.add(
      context.l10n.reef_health_asOf(
        DateFormat.yMMMd().format(data.observedAt.toUtc()),
      ),
    );

    return tile(lines.join('\n'), isThreeLine: lines.length > 2);
  }

  String _levelLabel(BuildContext context, BleachingAlertLevel level) =>
      switch (level) {
        BleachingAlertLevel.noStress => context.l10n.reef_health_levelNoStress,
        BleachingAlertLevel.watch => context.l10n.reef_health_levelWatch,
        BleachingAlertLevel.warning => context.l10n.reef_health_levelWarning,
        BleachingAlertLevel.alertLevel1 => context.l10n.reef_health_levelAlert1,
        BleachingAlertLevel.alertLevel2 => context.l10n.reef_health_levelAlert2,
        BleachingAlertLevel.alertLevel3 => context.l10n.reef_health_levelAlert3,
        BleachingAlertLevel.alertLevel4 => context.l10n.reef_health_levelAlert4,
        BleachingAlertLevel.alertLevel5 => context.l10n.reef_health_levelAlert5,
      };
}
