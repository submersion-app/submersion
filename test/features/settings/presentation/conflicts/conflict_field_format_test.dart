import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Unit coverage for the conflict dialog's value formatter (#1031, #694). The
/// dialog used to print stored values verbatim, which showed a metric depth to
/// an imperial diver and an epoch integer to everyone.
void main() {
  late AppLocalizations l10n;
  String? savedLocale;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // UnitFormatter builds bare DateFormats, which resolve against
    // Intl.defaultLocale, a process global. Pinned so the year cannot render
    // in another locale's digits; restored for the next file in the isolate.
    await initializeDateFormatting('en');
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDownAll(() => Intl.defaultLocale = savedLocale);

  ConflictField field(FieldKind kind, {ConflictEnumLabeler? enumLabel}) =>
      ConflictField((_) => 'x', kind, enumLabel: enumLabel);

  String fmt(
    UnitFormatter units,
    FieldKind kind,
    Object? value, {
    ConflictEnumLabeler? enumLabel,
  }) => formatConflictValue(
    l10n: l10n,
    units: units,
    field: field(kind, enumLabel: enumLabel),
    value: value,
  );

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      temperatureUnit: TemperatureUnit.fahrenheit,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );

  test('null is Not set for every kind', () {
    for (final kind in FieldKind.values) {
      expect(fmt(metric, kind, null), 'Not set', reason: kind.name);
    }
  });

  group('metric diver', () {
    test('renders a depth in metres with its symbol', () {
      expect(fmt(metric, FieldKind.depth, 30.48), '30.5m');
    });

    test('renders a stored duration as hours and minutes', () {
      expect(fmt(metric, FieldKind.durationSeconds, 2700), '45min');
      expect(fmt(metric, FieldKind.durationSeconds, 4500), '1h 15m');
    });

    test('keeps a sub-minute duration distinguishable', () {
      // Rounding these to "0min" would make two different stored values look
      // identical, which is exactly the choice the dialog exists to support.
      expect(fmt(metric, FieldKind.durationSeconds, 30), '30s');
      expect(fmt(metric, FieldKind.durationSeconds, 45), '45s');
      expect(fmt(metric, FieldKind.durationSeconds, 0), '0s');
    });

    test('a negative duration shows itself', () {
      expect(fmt(metric, FieldKind.durationSeconds, -30), '-30s');
    });

    test('renders a flag as words', () {
      expect(fmt(metric, FieldKind.boolean, true), 'Yes');
      expect(fmt(metric, FieldKind.boolean, false), 'No');
    });

    test('leaves a plain column alone', () {
      expect(fmt(metric, FieldKind.number, 12), '12');
      expect(
        fmt(metric, FieldKind.longText, 'Strong current'),
        'Strong current',
      );
    });
  });

  test("converts to the diver's own units rather than the stored ones", () {
    expect(fmt(imperial, FieldKind.depth, 30.48), '100.0ft');
    expect(fmt(imperial, FieldKind.pressure, 200.0), '2901 psi');
    expect(fmt(imperial, FieldKind.temperature, 20.0), '68°F');
  });

  test('measurements follow the diver units', () {
    expect(fmt(metric, FieldKind.depth, 30.48), metric.formatDepth(30.48));
    expect(fmt(imperial, FieldKind.depth, 30.48), imperial.formatDepth(30.48));
    expect(fmt(imperial, FieldKind.weight, 4.0), imperial.formatWeight(4.0));
    expect(fmt(imperial, FieldKind.volume, 12.0), imperial.formatVolume(12.0));
    expect(
      fmt(imperial, FieldKind.temperature, 26.0),
      imperial.formatTemperature(26.0),
    );
    expect(fmt(metric, FieldKind.speed, 1.2), metric.formatSpeed(1.2));
    expect(fmt(metric, FieldKind.windSpeed, 5.0), metric.formatWindSpeed(5.0));
    expect(
      fmt(metric, FieldKind.altitude, 300.0),
      metric.formatAltitude(300.0),
    );
    expect(fmt(metric, FieldKind.heightCm, 180.0), metric.formatHeight(180.0));
    expect(fmt(metric, FieldKind.ascentRate, 9.0), metric.formatDepthRate(9.0));
    expect(
      fmt(metric, FieldKind.distance, 850.0),
      metric.formatDistance(850.0),
    );
    expect(
      fmt(imperial, FieldKind.geoDistance, 2500.0),
      imperial.formatGeoDistance(2500.0),
    );
  });

  test('a barometric pressure renders the way the dive screen shows it', () {
    expect(
      fmt(metric, FieldKind.surfacePressure, 1.013),
      metric.formatSurfacePressure(1.013),
    );
  });

  test('a gas rate in litres per minute follows the volume unit', () {
    expect(fmt(imperial, FieldKind.rmv, 18.0), imperial.formatRmv(18.0));
  });

  test('ratios, coordinates and partial pressure', () {
    expect(fmt(metric, FieldKind.percent, 32.0), '32%');
    expect(fmt(metric, FieldKind.percent, 32.5), '32.5%');
    expect(fmt(metric, FieldKind.fraction, 0.25), '25%');
    expect(fmt(metric, FieldKind.partialPressure, 1.4), '1.40 bar');
    expect(fmt(metric, FieldKind.latitude, 25.5), metric.formatLatitude(25.5));
    expect(
      fmt(metric, FieldKind.longitude, -80.1),
      metric.formatLongitude(-80.1),
    );
  });

  test('durations in other stored units', () {
    expect(fmt(metric, FieldKind.durationMinutes, 90), '1h 30m');
    expect(fmt(metric, FieldKind.durationHours, 1.5), '1h 30m');
  });

  test(
    'enum values go through the labeler, unknown values print as stored',
    () {
      String? labeler(AppLocalizations l, String s) =>
          s == 'boat' ? 'Boat' : null;
      expect(
        fmt(metric, FieldKind.enumValue, 'boat', enumLabel: labeler),
        'Boat',
      );
      expect(
        fmt(metric, FieldKind.enumValue, 'jetpack', enumLabel: labeler),
        'jetpack',
      );
    },
  );

  test('opaque payloads never print raw', () {
    expect(fmt(metric, FieldKind.opaque, '{"a":1}'), 'Changed');
  });

  test('a value of the wrong type renders instead of throwing', () {
    expect(fmt(metric, FieldKind.depth, '30'), '30');
    expect(fmt(metric, FieldKind.boolean, 1), 'Yes');
    expect(fmt(metric, FieldKind.boolean, 0), 'No');
    expect(fmt(metric, FieldKind.dateTime, 'not a date'), 'not a date');
    expect(fmt(metric, FieldKind.wallClock, 'not a date'), 'not a date');
    expect(fmt(metric, FieldKind.durationSeconds, 'abc'), 'abc');
  });

  group('dates', () {
    test('a dateTime accepts epoch millis and ISO strings', () {
      final when = DateTime(2026, 3, 28, 10);
      final expected = metric.formatDateTime(when, l10n: l10n);
      expect(
        fmt(metric, FieldKind.dateTime, when.millisecondsSinceEpoch),
        expected,
      );
      expect(fmt(metric, FieldKind.dateTime, when.toIso8601String()), expected);
    });

    test('renders epoch millis as a date', () {
      final formatted = fmt(metric, FieldKind.dateTime, 1786556582600);
      expect(formatted, isNot(contains('1786556582600')));
      expect(formatted, contains('2026'));
    });

    test('dates a pre-1973 moment, whose epoch millis are negative', () {
      // The clock-offset detector warns about dives "dated before 1950", so a
      // negative diveDateTime is a real value, not a corruption to print raw.
      final formatted = fmt(metric, FieldKind.dateTime, -144720000000);
      expect(formatted, isNot(contains('-144720000000')));
      expect(formatted, contains('1965'));
    });

    test('a wall clock shows the stored digits in every zone', () {
      // Dive times are the dive computer's clock flagged UTC. Decoding them
      // as local would shift 09:40 by the device's offset (#2805).
      final stored = DateTime.utc(2026, 9, 12, 9, 40);
      final formatted = fmt(
        metric,
        FieldKind.wallClock,
        stored.millisecondsSinceEpoch,
      );
      expect(formatted, metric.formatDateTime(stored, l10n: l10n));
      expect(formatted, contains('9:40'));
    });

    test('an ISO instant with a zone renders in local time', () {
      final instant = DateTime.utc(2026, 3, 28, 10);
      final local = DateTime.fromMillisecondsSinceEpoch(
        instant.millisecondsSinceEpoch,
      );
      expect(
        fmt(metric, FieldKind.dateTime, instant.toIso8601String()),
        metric.formatDateTime(local, l10n: l10n),
      );
    });

    test('a date is the local day the app wrote', () {
      // Trips, certifications and service dates are written from a local
      // DateTime and read back with a local decode, so late evening stays on
      // its own day rather than moving to the UTC one.
      final evening = DateTime(2026, 3, 28, 23, 30);
      expect(
        fmt(metric, FieldKind.date, evening.millisecondsSinceEpoch),
        metric.formatDate(evening),
      );
    });

    test('a UTC day is the stored calendar day in every zone', () {
      // A few columns (a trip day's weather) hold UTC midnight. Decoding that
      // as local shows the previous day anywhere west of UTC.
      final day = DateTime.utc(2026, 3, 28);
      expect(
        fmt(metric, FieldKind.utcDate, day.millisecondsSinceEpoch),
        metric.formatDate(day),
      );
    });

    test('a time of day is minutes after midnight', () {
      expect(
        fmt(metric, FieldKind.timeOfDay, 450),
        metric.formatMinutesOfDay(450),
      );
    });
  });

  test('an epoch beyond what DateTime holds prints as stored', () {
    // A corrupt or unit-confused timestamp must not take the dialog down.
    expect(
      fmt(metric, FieldKind.dateTime, 9000000000000000),
      '9000000000000000',
    );
    expect(
      fmt(metric, FieldKind.wallClock, -9000000000000000),
      '-9000000000000000',
    );
    expect(
      fmt(metric, FieldKind.epochSeconds, 10000000000000),
      '10000000000000',
    );
  });

  test('decimals use the locale separator, like the rest of the app', () {
    final saved = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = saved);
    expect(fmt(metric, FieldKind.partialPressure, 1.4), '1,40 bar');
    expect(fmt(metric, FieldKind.percent, 32.5), '32,5%');
    expect(fmt(metric, FieldKind.fraction, 0.255), '25,5%');
    expect(fmt(metric, FieldKind.number, 35.5), '35,5');
    expect(fmt(metric, FieldKind.number, 12), '12');
  });

  test('unknown kind formats by runtime type', () {
    expect(fmt(metric, FieldKind.unknown, true), 'Yes');
    expect(fmt(metric, FieldKind.unknown, 12), '12');
  });
}
