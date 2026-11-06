import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart';
import 'package:submersion/features/settings/presentation/first_day_of_week_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// Issue #4232: how the first day of the week is named and resolved.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('de');
  });

  group('weekdayName', () {
    test('names a weekday in the given language', () {
      expect(weekdayName(DateTime.monday, 'en'), 'Monday');
      expect(weekdayName(DateTime.sunday, 'de'), 'Sonntag');
    });

    test('falls back to the language for a regional locale', () {
      expect(weekdayName(DateTime.saturday, 'de_LI'), 'Samstag');
    });
  });

  group('firstDayOfWeekLabel', () {
    test('names each option', () {
      expect(firstDayOfWeekLabel(en, FirstDayOfWeek.auto), 'Automatic');
      expect(firstDayOfWeekLabel(en, FirstDayOfWeek.monday), 'Monday');
      expect(firstDayOfWeekLabel(en, FirstDayOfWeek.sunday), 'Sunday');
      expect(firstDayOfWeekLabel(de, FirstDayOfWeek.saturday), 'Samstag');
    });
  });

  group('firstDayOfWeekSummary', () {
    test('automatic names the day it resolves to', () {
      expect(
        firstDayOfWeekSummary(en, FirstDayOfWeek.auto, DateTime.sunday),
        'Automatic (Sunday)',
      );
      expect(
        firstDayOfWeekSummary(de, FirstDayOfWeek.auto, DateTime.monday),
        'Automatisch (Montag)',
      );
    });

    test('automatic without a resolved day reads plainly', () {
      expect(firstDayOfWeekSummary(en, FirstDayOfWeek.auto, null), 'Automatic');
    });

    test('an explicit day ignores the resolved one', () {
      expect(
        firstDayOfWeekSummary(en, FirstDayOfWeek.monday, DateTime.sunday),
        'Monday',
      );
    });
  });

  group('firstDayOfWeekLabeler', () {
    test('labels a stored name and leaves an unknown one raw', () {
      expect(firstDayOfWeekLabeler(en, 'sunday'), 'Sunday');
      expect(firstDayOfWeekLabeler(en, 'auto'), 'Automatic');
      expect(firstDayOfWeekLabeler(en, 'thursday'), isNull);
    });
  });

  group('firstWeekdayProvider', () {
    int? resolve(FirstDayOfWeek setting, String? region) {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(AppSettings(firstDayOfWeek: setting)),
          ),
          deviceRegionProvider.overrideWithValue(region),
        ],
      );
      addTearDown(container.dispose);
      return container.read(firstWeekdayProvider);
    }

    test('automatic follows the device region', () {
      expect(resolve(FirstDayOfWeek.auto, 'CH'), DateTime.monday);
      expect(resolve(FirstDayOfWeek.auto, 'US'), DateTime.sunday);
      expect(resolve(FirstDayOfWeek.auto, null), isNull);
    });

    test('an explicit day wins over the region', () {
      expect(resolve(FirstDayOfWeek.saturday, 'CH'), DateTime.saturday);
    });
  });
}
