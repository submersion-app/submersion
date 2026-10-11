import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Satellite water conditions as display lines.
///
/// Shared by the site page's water-conditions card and the dive page's
/// Environment card, so both say the same thing in the same words.
class WaterConditionsLines {
  /// Stress classification (reefs only), sea surface temperature and anomaly,
  /// in that order. Readings the satellite did not report are absent.
  final List<String> readings;

  /// The "As of" line with the satellite observation date, which a host may style
  /// apart from the readings since it qualifies them rather than adding one.
  final String observedOn;

  const WaterConditionsLines({
    required this.readings,
    required this.observedOn,
  });

  /// Every line, the observation date last.
  List<String> get all => [...readings, observedOn];
}

/// True unless habitat definitively answered "no reef here".
///
/// Null (still resolving) and unavailable both count as possible: an offline
/// habitat provider must never hide an active bleaching alert.
bool reefPossibleFor(ReefPart<ReefHabitat>? habitat) =>
    habitat == null || habitat.status != ReefDataStatus.empty;

/// Whether [buildWaterConditionsLines] would produce any reading for
/// [health], so a host can skip a heading that would sit over nothing but
/// the observation date. Mirrors the builder's own gating.
bool hasWaterConditionsReadings(
  ReefHealth health, {
  required bool reefPossible,
}) =>
    health.sst != null ||
    health.sstAnomaly != null ||
    (reefPossible &&
        (health.alertLevel != null || health.degreeHeatingWeeks != null));

/// [health] as display lines in the diver's units and locale.
///
/// Sea surface temperature and its anomaly are valid anywhere in the ocean;
/// the bleaching alert level and Degree Heating Weeks are coral framing and
/// are included only while [reefPossible]. When included, Degree Heating
/// Weeks follows the alert level directly: the level is an instantaneous
/// classification while the damage it implies is cumulative, so a reef
/// mid-mortality can read "Bleaching Watch".
WaterConditionsLines buildWaterConditionsLines({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required ReefHealth health,
  required bool reefPossible,
}) {
  final readings = <String>[];
  if (reefPossible) {
    final level = health.alertLevel;
    if (level != null) readings.add(_levelLabel(l10n, level));
    if (health.degreeHeatingWeeks case final dhw?) {
      // Celsius-weeks have no imperial equivalent, so this stays unconverted;
      // only the decimal separator follows the locale.
      readings.add(
        l10n.reef_health_degreeHeatingWeeks(formatFixedForDisplay(dhw, 1)),
      );
    }
  }
  if (health.sst case final sst?) {
    readings.add(l10n.reef_health_seaSurface(units.formatTemperature(sst)));
  }
  if (health.sstAnomaly case final anomaly?) {
    readings.add(l10n.water_conditions_anomaly(_signedDelta(units, anomaly)));
  }
  // NOAA publishes one composite per UTC day, stamped at 12:00Z. Converting
  // to local time would shift that stamp into the next or previous calendar
  // day at the extremes of the timezone range, reporting an observation
  // date the dataset never had.
  return WaterConditionsLines(
    readings: readings,
    observedOn: l10n.reef_health_asOf(
      units.formatDate(health.observedAt.toUtc()),
    ),
  );
}

/// [celsiusDelta] as a signed difference: "+0.8°C", "-1°C".
///
/// The sign follows the rounded figure, so an anomaly too small to show reads
/// "0°C" rather than "+0°C" or "-0°C". The magnitude goes through
/// [UnitFormatter.formatTemperatureDelta], which scales a difference without
/// the Fahrenheit offset.
String _signedDelta(UnitFormatter units, double celsiusDelta) {
  // One precision for both the sign test and the figure, so they agree.
  const decimals = 1;
  final scaled = TemperatureUnit.celsius.convertDelta(
    celsiusDelta,
    units.settings.temperatureUnit,
  );
  final shown = double.parse(scaled.abs().toStringAsFixed(decimals));
  final sign = shown == 0 ? '' : (scaled > 0 ? '+' : '-');
  final magnitude = units.formatTemperatureDelta(
    celsiusDelta.abs(),
    decimals: decimals,
  );
  return '$sign$magnitude';
}

String _levelLabel(AppLocalizations l10n, BleachingAlertLevel level) =>
    switch (level) {
      BleachingAlertLevel.noStress => l10n.reef_health_levelNoStress,
      BleachingAlertLevel.watch => l10n.reef_health_levelWatch,
      BleachingAlertLevel.warning => l10n.reef_health_levelWarning,
      BleachingAlertLevel.alertLevel1 => l10n.reef_health_levelAlert1,
      BleachingAlertLevel.alertLevel2 => l10n.reef_health_levelAlert2,
      BleachingAlertLevel.alertLevel3 => l10n.reef_health_levelAlert3,
      BleachingAlertLevel.alertLevel4 => l10n.reef_health_levelAlert4,
      BleachingAlertLevel.alertLevel5 => l10n.reef_health_levelAlert5,
    };
