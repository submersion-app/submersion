import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_data_preview.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Unit coverage for the conflict preview's scalar formatter (#1031). The
/// dialog used to print every column's stored value verbatim, which showed a
/// metric depth to an imperial diver and an epoch integer to everyone.
void main() {
  late AppLocalizations l10n;
  String? savedLocale;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // UnitFormatter builds bare DateFormats, which resolve against
    // Intl.defaultLocale -- a process global. Unpinned, this file rides on
    // intl's implicit fallback: under ar_EG, fa, bn or ne the year renders in
    // Eastern digits and the assertions below stop matching. This is a pure
    // unit test with no MaterialApp, so the date symbols have to be loaded
    // before the global is assigned or intl throws LocaleDataException.
    await initializeDateFormatting('en');
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDownAll(() => Intl.defaultLocale = savedLocale);

  String format(UnitFormatter units, String key, Object value) =>
      formatConflictScalar(l10n, units, key, value);

  group('metric diver', () {
    const units = UnitFormatter(AppSettings());

    test('renders a depth in metres with its symbol', () {
      expect(format(units, 'maxDepth', 30.48), '30.5m');
    });

    test('renders a stored duration as hours and minutes', () {
      expect(format(units, 'bottomTime', 2700), '45min');
      expect(format(units, 'runtime', 4500), '1h 15m');
    });

    test('keeps a sub-minute duration distinguishable', () {
      // Rounding these to "0min" would make two different stored values look
      // identical, which is exactly the choice the dialog exists to support.
      expect(format(units, 'bottomTime', 30), '30s');
      expect(format(units, 'bottomTime', 45), '45s');
      expect(format(units, 'bottomTime', 0), '0s');
    });

    test('renders a flag as words', () {
      expect(format(units, 'isShared', true), 'Yes');
      expect(format(units, 'isShared', false), 'No');
    });

    test('leaves a plain column alone', () {
      expect(format(units, 'diveNumber', 12), '12');
      expect(format(units, 'notes', 'Strong current'), 'Strong current');
    });
  });

  test("converts to the diver's own units rather than the stored ones", () {
    const imperial = UnitFormatter(
      AppSettings(
        depthUnit: DepthUnit.feet,
        pressureUnit: PressureUnit.psi,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    );

    expect(format(imperial, 'maxDepth', 30.48), '100.0ft');
    expect(format(imperial, 'startPressure', 200.0), '2901 psi');
    expect(format(imperial, 'waterTemp', 20.0), '68°F');
  });

  group('epoch columns', () {
    const units = UnitFormatter(AppSettings());

    test('renders a time-named column holding Unix millis as a date', () {
      final formatted = format(units, 'createdAt', 1786556582600);
      expect(formatted, isNot(contains('1786556582600')));
      expect(formatted, contains('2026'));
    });

    test('dates a pre-1973 column, whose epoch millis are negative', () {
      // The app models these: the clock-offset detector warns about dives
      // "dated before 1950", so a negative diveDateTime is a real value and
      // not a corruption to be printed raw.
      final formatted = format(units, 'diveDateTime', -144720000000);
      expect(formatted, isNot(contains('-144720000000')));
      expect(formatted, contains('1965'));
    });

    test('leaves a time-named column too small to be Unix millis alone', () {
      // Every time-named column in today's schema really is an epoch value,
      // so this rule is defensive: it makes the formatter fail safe. A future
      // column holding a small count under a time-ish name renders as the
      // number it is rather than being dated to 1970.
      expect(format(units, 'surfaceIntervalTime', 300), '300');
      expect(format(units, 'holdTime', 90), '90');
      // Small and negative, the boundary the absolute-magnitude check adds.
      expect(format(units, 'holdTime', -90), '-90');
    });
  });
}
