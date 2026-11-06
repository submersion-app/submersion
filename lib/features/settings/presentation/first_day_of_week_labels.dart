import 'package:intl/intl.dart';

import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A Monday, used only to name weekdays through [DateFormat].
final DateTime _referenceMonday = DateTime(2024, 1, 1);

/// The full name of [weekday] ([DateTime.weekday] numbering) in
/// [localeName], such as "Monday" or "Montag".
///
/// Falls back the way `GlobalMaterialLocalizations` does when `intl` has no
/// date data for the locale: language alone, then intl's default.
String weekdayName(int weekday, String localeName) {
  final day = _referenceMonday.add(Duration(days: weekday - 1));
  final canonical = Intl.canonicalizedLocale(localeName);
  final language = canonical.split('_').first;
  final locale = DateFormat.localeExists(canonical)
      ? canonical
      : DateFormat.localeExists(language)
      ? language
      : null;
  return DateFormat.EEEE(locale).format(day);
}

/// The label a [FirstDayOfWeek] option goes by in the app's language.
String firstDayOfWeekLabel(AppLocalizations l10n, FirstDayOfWeek value) =>
    switch (value) {
      FirstDayOfWeek.auto => l10n.settings_units_firstDayOfWeek_auto,
      FirstDayOfWeek.monday => weekdayName(DateTime.monday, l10n.localeName),
      FirstDayOfWeek.sunday => weekdayName(DateTime.sunday, l10n.localeName),
      FirstDayOfWeek.saturday => weekdayName(
        DateTime.saturday,
        l10n.localeName,
      ),
    };

/// The settings row value: an explicit day by name, or automatic with the
/// day the week starts on right now ("Automatic (Monday)"), [shownWeekday]
/// in [DateTime.weekday] numbering.
String firstDayOfWeekSummary(
  AppLocalizations l10n,
  FirstDayOfWeek value,
  int shownWeekday,
) {
  if (value != FirstDayOfWeek.auto) return firstDayOfWeekLabel(l10n, value);
  return l10n.settings_units_firstDayOfWeek_autoResolved(
    weekdayName(shownWeekday, l10n.localeName),
  );
}
