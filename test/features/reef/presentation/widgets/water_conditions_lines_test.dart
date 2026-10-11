import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_lines.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _celsius = UnitFormatter(AppSettings());
const _fahrenheit = UnitFormatter(
  AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
);

ReefHealth _health({double? sst = 30.1, double? anomaly = 0.8}) => ReefHealth(
  sst: sst,
  sstAnomaly: anomaly,
  degreeHeatingWeeks: 4.2,
  alertLevel: BleachingAlertLevel.watch,
  observedAt: DateTime.utc(2023, 9, 1, 12),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  WaterConditionsLines build(
    ReefHealth health, {
    UnitFormatter units = _celsius,
    bool reefPossible = true,
  }) => buildWaterConditionsLines(
    l10n: l10n,
    units: units,
    health: health,
    reefPossible: reefPossible,
  );

  group('buildWaterConditionsLines', () {
    test('lists stress, then temperature, then anomaly', () {
      expect(build(_health()).readings, [
        'Bleaching watch',
        'Degree Heating Weeks 4.2 C-weeks',
        'Sea surface 30.1°C',
        'Anomaly +0.8°C',
      ]);
    });

    test('keeps the observation date apart from the readings', () {
      final lines = build(_health());
      expect(lines.observedOn, 'As of Sep 1, 2023');
      expect(lines.all.last, lines.observedOn);
      expect(lines.all, hasLength(5));
    });

    test('drops the coral framing where no reef is possible', () {
      expect(build(_health(), reefPossible: false).readings, [
        'Sea surface 30.1°C',
        'Anomaly +0.8°C',
      ]);
    });

    test('formats temperatures like every other reading', () {
      // Whole degrees drop their zero decimal, as formatTemperature does.
      expect(build(_health(sst: 28.0)).readings, contains('Sea surface 28°C'));
      expect(
        build(_health(), units: _fahrenheit).readings,
        contains('Sea surface 86.2°F'),
      );
    });

    test('uses the locale decimal separator', () async {
      await initializeDateFormatting('de');
      Intl.defaultLocale = 'de';
      final readings = build(_health()).readings;
      expect(readings, contains('Sea surface 30,1°C'));
      expect(readings, contains('Anomaly +0,8°C'));
      expect(readings, contains('Degree Heating Weeks 4,2 C-weeks'));
    });

    test('converts the anomaly as a delta, not a reading', () {
      // 0.5 C warmer is 0.9 F warmer; as a reading it would be 32.9 F.
      expect(
        build(_health(anomaly: 0.5), units: _fahrenheit).readings,
        contains('Anomaly +0.9°F'),
      );
    });

    test('signs a negative anomaly once', () {
      expect(build(_health(anomaly: -1.0)).readings, contains('Anomaly -1°C'));
    });

    test('leaves an anomaly that rounds to zero unsigned', () {
      expect(build(_health(anomaly: -0.02)).readings, contains('Anomaly 0°C'));
      expect(build(_health(anomaly: 0.02)).readings, contains('Anomaly 0°C'));
    });

    test('omits readings the satellite did not report', () {
      final readings = build(_health(sst: null, anomaly: null)).readings;
      expect(readings.any((l) => l.startsWith('Sea surface')), isFalse);
      expect(readings.any((l) => l.startsWith('Anomaly')), isFalse);
    });
  });

  group('hasWaterConditionsReadings', () {
    final bare = ReefHealth(observedAt: DateTime.utc(2023, 9, 1, 12));

    test('agrees with the builder on whether any reading survives', () {
      for (final (health, reefPossible) in [
        (bare, true),
        (bare.copyWith(sst: 28), false),
        (bare.copyWith(sstAnomaly: -0.3), false),
        (bare.copyWith(alertLevel: BleachingAlertLevel.watch), true),
        (bare.copyWith(alertLevel: BleachingAlertLevel.watch), false),
        (bare.copyWith(degreeHeatingWeeks: 2), true),
        (bare.copyWith(degreeHeatingWeeks: 2), false),
      ]) {
        expect(
          hasWaterConditionsReadings(health, reefPossible: reefPossible),
          build(health, reefPossible: reefPossible).readings.isNotEmpty,
          reason: '$health, reefPossible: $reefPossible',
        );
      }
    });
  });

  group('reefPossibleFor', () {
    test('is true until habitat rules a reef out', () {
      expect(reefPossibleFor(null), isTrue);
      expect(reefPossibleFor(const ReefPart.unavailable()), isTrue);
      expect(
        reefPossibleFor(const ReefPart.ok(ReefHabitat(onReef: true))),
        isTrue,
      );
      expect(reefPossibleFor(const ReefPart.empty()), isFalse);
    });
  });
}
