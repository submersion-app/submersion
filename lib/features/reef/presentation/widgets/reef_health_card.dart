import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One row of the reef section: thermal stress and bleaching risk.
///
/// Degree Heating Weeks is rendered next to the alert level, never behind a
/// tap. The level is an instantaneous classification while the damage it
/// implies is cumulative, so a reef mid-mortality can read "Bleaching Watch".
class ReefHealthCard extends ConsumerWidget {
  final ReefPart<ReefHealth> part;

  const ReefHealthCard({super.key, required this.part});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (part.status == ReefDataStatus.unavailable) {
      return ListTile(
        leading: Icon(Icons.thermostat, color: scheme.primary),
        title: Text(
          context.l10n.reef_health_title,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(context.l10n.reef_health_unavailable),
        dense: true,
      );
    }
    if (part.status == ReefDataStatus.empty) {
      return ListTile(
        leading: Icon(Icons.thermostat, color: scheme.primary),
        title: Text(
          context.l10n.reef_health_title,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(context.l10n.reef_health_noData),
        dense: true,
      );
    }

    final health = part.value!;
    final tempUnit = ref.watch(temperatureUnitProvider);

    final lines = <String>[];
    final level = health.alertLevel;
    if (level != null) lines.add(_levelLabel(context, level));
    if (health.degreeHeatingWeeks != null) {
      lines.add(
        context.l10n.reef_health_degreeHeatingWeeks(
          health.degreeHeatingWeeks!.toStringAsFixed(1),
        ),
      );
    }
    if (health.sst != null) {
      final value = TemperatureUnit.celsius.convert(health.sst!, tempUnit);
      lines.add(
        context.l10n.reef_health_seaSurface(
          '${value.toStringAsFixed(1)}${tempUnit.symbol}',
        ),
      );
    }
    // NOAA publishes one composite per UTC day, stamped at 12:00Z. Converting
    // to local time would shift that stamp into the next or previous calendar
    // day at the extremes of the timezone range, reporting an observation date
    // the dataset never had.
    lines.add(
      context.l10n.reef_health_asOf(
        DateFormat.yMMMd().format(health.observedAt.toUtc()),
      ),
    );

    return ListTile(
      leading: Icon(Icons.thermostat, color: scheme.primary),
      title: Text(
        context.l10n.reef_health_title,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(lines.join('\n')),
      isThreeLine: true,
      dense: true,
    );
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
