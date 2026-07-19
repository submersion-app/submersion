import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #622: the dive Environment section rendered
/// weather/condition enum values in English regardless of the active locale
/// because the UI used the hardcoded English `displayName`. These extensions
/// resolve the same values through the localization table instead.
void main() {
  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    de = lookupAppLocalizations(const Locale('de'));
  });

  group('localizedName is non-empty for every value (exhaustiveness)', () {
    test('CloudCover', () {
      for (final v in CloudCover.values) {
        expect(v.localizedName(en), isNotEmpty);
        expect(v.localizedName(de), isNotEmpty);
      }
    });

    test('Precipitation', () {
      for (final v in Precipitation.values) {
        expect(v.localizedName(en), isNotEmpty);
        expect(v.localizedName(de), isNotEmpty);
      }
    });

    test('CurrentDirection', () {
      for (final v in CurrentDirection.values) {
        expect(v.localizedName(en), isNotEmpty);
        expect(v.localizedName(de), isNotEmpty);
      }
    });

    test('CurrentStrength', () {
      for (final v in CurrentStrength.values) {
        expect(v.localizedName(en), isNotEmpty);
        expect(v.localizedName(de), isNotEmpty);
      }
    });

    test('EntryMethod', () {
      for (final v in EntryMethod.values) {
        expect(v.localizedName(en), isNotEmpty);
        expect(v.localizedName(de), isNotEmpty);
      }
    });
  });

  group('English locale matches the English displayName (key wiring)', () {
    test('every value resolves to its displayName under en', () {
      for (final v in CloudCover.values) {
        expect(v.localizedName(en), v.displayName);
      }
      for (final v in Precipitation.values) {
        expect(v.localizedName(en), v.displayName);
      }
      for (final v in CurrentDirection.values) {
        expect(v.localizedName(en), v.displayName);
      }
      for (final v in CurrentStrength.values) {
        expect(v.localizedName(en), v.displayName);
      }
      for (final v in EntryMethod.values) {
        expect(v.localizedName(en), v.displayName);
      }
    });
  });

  group('German locale returns translated values (the #622 fix)', () {
    test('values resolve through the German localization table', () {
      // Compare against the generated getters rather than literal strings, so
      // the test verifies key wiring without breaking when translators refine
      // wording.
      expect(
        CloudCover.partlyCloudy.localizedName(de),
        de.enum_cloudCover_partlyCloudy,
      );
      expect(
        Precipitation.drizzle.localizedName(de),
        de.enum_precipitation_drizzle,
      );
      expect(
        CurrentDirection.south.localizedName(de),
        de.enum_currentDirection_south,
      );
    });

    test('German never falls back to the English displayName', () {
      // Every value that has a distinct German word must differ from English.
      // (Same-spelling words like "West" are intentionally excluded.)
      expect(
        CloudCover.overcast.localizedName(de),
        isNot(CloudCover.overcast.displayName),
      );
      expect(
        Precipitation.heavyRain.localizedName(de),
        isNot(Precipitation.heavyRain.displayName),
      );
      expect(
        CurrentStrength.strong.localizedName(de),
        isNot(CurrentStrength.strong.displayName),
      );
    });
  });
}
