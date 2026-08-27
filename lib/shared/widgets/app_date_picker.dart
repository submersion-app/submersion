import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Shows the Material date picker with manual-entry parsing and hints that
/// honor the diver's [DateFormatPreference] (#765).
///
/// A bare [showDatePicker] derives its input-mode format from the ambient
/// [MaterialLocalizations] locale (en-US on an English UI), so a user whose
/// Submersion date format is DD/MM/YYYY was still forced to type
/// MM/DD/YYYY. The picker locale below is chosen purely for its compact
/// date format; for the dotted format that means German dialog chrome,
/// which matches the audience that uses it.
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
  DateFormatPreference format;
  if (dateFormat != null) {
    format = dateFormat;
  } else {
    format = _resolveFormat(context);
  }
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDatePickerMode: initialDatePickerMode,
    locale: _pickerLocaleFor(format),
    fieldHintText: _fieldHintFor(format),
  );
}

/// Shows the Material date *range* picker with manual-entry parsing and hints
/// that honor the diver's [DateFormatPreference] (#964).
///
/// The range dialog reads its compact date format from the same ambient
/// [MaterialLocalizations] as the single-date dialog, so it needs the same
/// locale override; see [showAppDatePicker] for why the locale is the only
/// lever Flutter exposes.
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  DateFormatPreference? dateFormat,
}) {
  final format = dateFormat ?? _resolveFormat(context);
  final hint = _fieldHintFor(format);
  return showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: _pickerLocaleFor(format),
    fieldStartHintText: hint,
    fieldEndHintText: hint,
  );
}

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

/// Locale whose compact date format matches [format] for typing.
Locale _pickerLocaleFor(DateFormatPreference format) => switch (format) {
  DateFormatPreference.mmddyyyy => const Locale('en', 'US'),
  DateFormatPreference.ddmmyyyy => const Locale('en', 'GB'),
  DateFormatPreference.yyyymmdd => const Locale('en', 'CA'),
  DateFormatPreference.ddmmyyyyDots => const Locale('de'),
  // Text-month display formats have no compact input analogue; use the
  // matching month-first / day-first numeric locale.
  DateFormatPreference.mmmDYYYY => const Locale('en', 'US'),
  DateFormatPreference.dMMMYYYY => const Locale('en', 'GB'),
};

String? _fieldHintFor(DateFormatPreference format) => switch (format) {
  DateFormatPreference.mmddyyyy ||
  DateFormatPreference.ddmmyyyy ||
  DateFormatPreference.yyyymmdd ||
  DateFormatPreference.ddmmyyyyDots => format.displayName.toLowerCase(),
  // Let Material supply its own numeric hint for text-month preferences.
  DateFormatPreference.mmmDYYYY || DateFormatPreference.dMMMYYYY => null,
};
