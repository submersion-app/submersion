import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/compact_date_calendar_delegate.dart';

/// Shows the Material date picker with manual-entry parsing and hints that
/// honor the diver's [DateFormatPreference] (#765).
///
/// A bare [showDatePicker] derives its input-mode format from the ambient
/// [MaterialLocalizations] locale (en-US on an English UI), so a user whose
/// Submersion date format is DD/MM/YYYY was still forced to type MM/DD/YYYY.
///
/// The format is supplied through a [CalendarDelegate], which is scoped to
/// compact-date handling. This used to borrow a whole locale instead, which
/// re-resolves every localization for that locale and translated the dialog
/// along with the input format (#1510).
///
/// [dateFormat] is read from the settings provider when omitted; pass it
/// explicitly in tests. [initialDate] stays required but nullable so callers
/// with no date yet must say so deliberately rather than by omission.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  DateFormatPreference? dateFormat,
}) {
  final format = dateFormat ?? _resolveFormat(context);
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDatePickerMode: initialDatePickerMode,
    calendarDelegate: _compactDateDelegate(context, format),
  );
}

/// Shows the Material date *range* picker with manual-entry parsing and hints
/// that honor the diver's [DateFormatPreference] (#964).
///
/// The range dialog reads its compact date format from the same ambient
/// [MaterialLocalizations] as the single-date dialog, so it needs the same
/// delegate; see [showAppDatePicker].
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  DateFormatPreference? dateFormat,
}) {
  final format = dateFormat ?? _resolveFormat(context);
  return showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    calendarDelegate: _compactDateDelegate(context, format),
  );
}

/// Teaches a picker's manual-entry field to speak [format] while the rest of
/// the dialog keeps the app's language.
CompactDateCalendarDelegate _compactDateDelegate(
  BuildContext context,
  DateFormatPreference format,
) => CompactDateCalendarDelegate(
  pattern: _compactPatternFor(format),
  locale: Localizations.localeOf(context),
);

/// Reads the diver's date format when settings are reachable.
///
/// Reads only when the provider is already alive (always true in the
/// running app, which watches settings for units/theme). Instantiating it
/// here would drag in SharedPreferences/database dependencies that
/// widget-test harnesses of picker call sites do not provide; harnesses
/// without a ProviderScope at all get the app default (pre-#765 behavior).
///
/// Uses `listen: false` because the pickers are opened from event handlers
/// (onTap/onPressed), where the listening variant would trip Flutter's
/// "dependOnInheritedWidgetOfExactType() called outside of build" assertion.
DateFormatPreference _resolveFormat(BuildContext context) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } on StateError {
    return DateFormatPreference.mmmDYYYY;
  }
  return container.exists(settingsProvider)
      ? container.read(settingsProvider).dateFormat
      : DateFormatPreference.mmmDYYYY;
}

/// The all-numeric pattern the picker's text field types and parses.
///
/// Every arm reads a [DateFormatPreference.pattern] rather than repeating one,
/// so a preference whose pattern is edited carries the picker with it. The
/// text-month preferences are the only ones that cannot use their own: a
/// compact field has no room for `MMM`, so they borrow the numeric pattern
/// with the same field order.
///
/// Listed one preference per arm, with no wildcard, so adding a preference is
/// a compile error here rather than a silent fall-through to a pattern the
/// field cannot parse.
String _compactPatternFor(DateFormatPreference format) => switch (format) {
  DateFormatPreference.mmddyyyy ||
  DateFormatPreference.ddmmyyyy ||
  DateFormatPreference.yyyymmdd ||
  DateFormatPreference.ddmmyyyyDots => format.pattern,
  DateFormatPreference.mmmDYYYY => DateFormatPreference.mmddyyyy.pattern,
  DateFormatPreference.dMMMYYYY => DateFormatPreference.ddmmyyyy.pattern,
};
