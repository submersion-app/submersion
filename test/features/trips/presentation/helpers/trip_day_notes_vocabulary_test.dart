import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_day_notes_vocabulary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  setUpAll(initializeDateFormatting);

  // Tuesday 3 November 2026 to Monday 9 November 2026; the 5th is a Thursday.
  final days = [
    for (var i = 0; i < 7; i++)
      TripNoteDay(date: DateTime(2026, 11, 3 + i), dayNumber: i + 1),
  ];
  final day3 = DateTime(2026, 11, 5);

  for (final code in ['en', 'de', 'hu', 'zh', 'ja', 'ar', 'he', 'fr']) {
    test('$code reads back the day label it writes', () {
      final l10n = lookupAppLocalizations(Locale(code));
      final vocabulary = tripDayNotesVocabularyFor(l10n);
      expect(
        dayNamedByHeading(l10n.trips_story_dayLabel(3), days, vocabulary),
        day3,
      );
    });
  }

  test('English is read under any language', () {
    final vocabulary = tripDayNotesVocabularyFor(
      lookupAppLocalizations(const Locale('de')),
    );
    expect(dayNamedByHeading('Day 3', days, vocabulary), day3);
    expect(dayNamedByHeading('Nov 5', days, vocabulary), day3);
  });

  test('common English abbreviations intl does not use are read', () {
    final vocabulary = tripDayNotesVocabularyFor(
      lookupAppLocalizations(const Locale('en')),
    );
    final september = [
      for (var i = 0; i < 7; i++)
        TripNoteDay(date: DateTime(2026, 9, 7 + i), dayNumber: i + 1),
    ];
    // 8 September 2026 is a Tuesday, the 9th a Wednesday, the 10th a Thursday.
    expect(
      dayNamedByHeading('Sept 8', september, vocabulary),
      DateTime(2026, 9, 8),
    );
    expect(
      dayNamedByHeading('Tues Sept 8', september, vocabulary),
      DateTime(2026, 9, 8),
    );
    expect(
      dayNamedByHeading('Weds 9 Sep', september, vocabulary),
      DateTime(2026, 9, 9),
    );
    expect(
      dayNamedByHeading('Thurs Sep 10', september, vocabulary),
      DateTime(2026, 9, 10),
    );
    expect(
      dayNamedByHeading('Thur Sep 10', september, vocabulary),
      DateTime(2026, 9, 10),
    );
  });

  test("the app's language gives month and weekday names", () {
    final vocabulary = tripDayNotesVocabularyFor(
      lookupAppLocalizations(const Locale('de')),
    );
    expect(dayNamedByHeading('5 November', days, vocabulary), day3);
    expect(dayNamedByHeading('Donnerstag 5 November', days, vocabulary), day3);
    expect(dayNamedByHeading('Do 5 Nov', days, vocabulary), day3);
    expect(dayNamedByHeading('Mittwoch 5 November', days, vocabulary), isNull);
  });
}
