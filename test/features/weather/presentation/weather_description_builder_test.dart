import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/widgets/weather_description_builder.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<AppLocalizations> _l10n(WidgetTester tester, Locale locale) async {
  late AppLocalizations captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

const _metric = UnitFormatter(AppSettings());
const _fahrenheit = UnitFormatter(
  AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
);

void main() {
  testWidgets('maps WMO codes to their localized label', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    expect(wmoCodeLabel(l10n, 0), 'Clear sky');
    expect(wmoCodeLabel(l10n, 3), 'Overcast');
    expect(wmoCodeLabel(l10n, 45), 'Fog');
    expect(wmoCodeLabel(l10n, 61), 'Rain');
    expect(wmoCodeLabel(l10n, 71), 'Snow');
    expect(wmoCodeLabel(l10n, 95), 'Thunderstorm');
    expect(wmoCodeLabel(l10n, 99), 'Thunderstorm with hail');
  });

  testWidgets('returns null for an absent or unknown code', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    expect(wmoCodeLabel(l10n, null), isNull);
    expect(wmoCodeLabel(l10n, 7), isNull);
  });

  testWidgets('converts temperature to the diver unit', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));

    final metric = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _metric,
      weatherCode: 0,
      airTempCelsius: 24,
    );
    expect(metric, contains('24'));

    final imperial = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _fahrenheit,
      weatherCode: 0,
      airTempCelsius: 24,
    );
    // The old builder hardcoded "24C" regardless of the diver's setting.
    expect(imperial, contains('75'));
    expect(imperial, isNot(contains('24C')));
  });

  testWidgets('follows the locale', (tester) async {
    final en = await _l10n(tester, const Locale('en'));
    final enText = buildLocalizedWeatherDescription(
      l10n: en,
      units: _metric,
      weatherCode: 0,
    );

    final de = await _l10n(tester, const Locale('de'));
    final deText = buildLocalizedWeatherDescription(
      l10n: de,
      units: _metric,
      weatherCode: 0,
    );

    expect(enText, isNotNull);
    expect(deText, isNotNull);
    // Both resolve; once translated they differ. Until then de falls back to
    // en, so this asserts only that the lookup is locale-driven at all.
    expect(deText, wmoCodeLabel(de, 0));
  });

  testWidgets('a stored description wins over generated text', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _metric,
      weatherCode: 0,
      airTempCelsius: 24,
      storedDescription: 'Glassy, no wind',
    );
    expect(result, 'Glassy, no wind');
  });

  testWidgets('an empty stored description does not win', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _metric,
      weatherCode: 0,
      storedDescription: '',
    );
    expect(result, 'Clear sky');
  });

  testWidgets('falls back to cloud cover when no code is present', (
    tester,
  ) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _metric,
      cloudCover: CloudCover.clear,
    );
    expect(result, isNotNull);
    expect(result, isNotEmpty);
  });

  testWidgets('describes wind with its direction', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _metric,
      weatherCode: 0,
      windSpeedMs: 3.0,
      windDirection: CurrentDirection.north,
    );
    expect(result, contains('light breeze'));
    expect(result, contains('from'));
  });

  testWidgets('omits direction when there is none', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: _metric,
      weatherCode: 0,
      windSpeedMs: 3.0,
      windDirection: CurrentDirection.none,
    );
    expect(result, contains('light breeze'));
    expect(result, isNot(contains('from')));
  });

  testWidgets('returns null when there is nothing to say', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    expect(
      buildLocalizedWeatherDescription(l10n: l10n, units: _metric),
      isNull,
    );
  });
}
