import 'dart:ui';

import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The words a day heading in a trip's Notes may use (#4625): the app's
/// language and English, so a note written before a language switch keeps
/// its days.
///
/// The day label comes from `trips_story_dayLabel`, the label the day page
/// shows and the Add note action writes, so every language reads back what
/// it writes, whichever side of the number its words sit on.
TripDayNotesVocabulary tripDayNotesVocabularyFor(AppLocalizations l10n) {
  final english = lookupAppLocalizations(const Locale('en'));
  final languages = {l10n.localeName, english.localeName};
  final dayLabels = <({String prefix, String suffix})>{
    _labelAround(l10n),
    _labelAround(english),
  };

  final months = <String, int>{};
  final weekdays = <String, int>{};
  for (final locale in languages) {
    if (!DateFormat.localeExists(locale)) continue;
    for (final pattern in [DateFormat.MMMM(locale), DateFormat.MMM(locale)]) {
      for (var month = 1; month <= 12; month++) {
        months[_word(pattern.format(DateTime(2026, month)))] = month;
      }
    }
    for (final pattern in [DateFormat.EEEE(locale), DateFormat.E(locale)]) {
      // 2 November 2026 is a Monday.
      for (var offset = 0; offset < 7; offset++) {
        final date = DateTime(2026, 11, 2 + offset);
        weekdays[_word(pattern.format(date))] = date.weekday;
      }
    }
  }
  months.remove('');
  weekdays.remove('');
  // English abbreviations people write that intl's patterns do not use.
  months.putIfAbsent('sept', () => DateTime.september);
  weekdays
    ..putIfAbsent('tues', () => DateTime.tuesday)
    ..putIfAbsent('weds', () => DateTime.wednesday)
    ..putIfAbsent('thur', () => DateTime.thursday)
    ..putIfAbsent('thurs', () => DateTime.thursday);

  return TripDayNotesVocabulary(
    dayLabels: dayLabels.toList(),
    months: months,
    weekdays: weekdays,
  );
}

/// A number no label holds otherwise, to find where the label puts it.
const _marker = 987654;

({String prefix, String suffix}) _labelAround(AppLocalizations l10n) {
  final label = l10n.trips_story_dayLabel(_marker).toLowerCase();
  final at = label.indexOf('$_marker');
  return (
    prefix: label.substring(0, at).trim(),
    suffix: label.substring(at + '$_marker'.length).trim(),
  );
}

/// A month or weekday name as the scanner compares it: lowercase, with no
/// trailing period (`Nov.` and `Do.` are abbreviations).
String _word(String name) {
  final lower = name.trim().toLowerCase();
  return lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
}
