import 'dart:ui' show Locale;

import 'package:intl/intl.dart';
import 'package:submersion/core/utils/locale_number_symbols.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Formats a byte count for display in the active language.
///
/// Bytes are not a diver-facing unit, so this deliberately ignores the active
/// diver's unit settings: a megabyte is a megabyte in metric and imperial
/// alike. Sizes are a floor, since a source that reports no size counts zero.
String formatBytes(int bytes) {
  final (number, unit) = _byteParts(bytes);
  return byteSizeLabel(number, unit);
}

/// Joins a size's [number], written with Dart's '.' decimal point, to its
/// [unit] key (`B`, `KB`, `MB`, `GB` or `TB`) the way the active language
/// writes them: the decimal mark follows the locale and the unit takes the
/// language's own symbol, so French reads `12,5 Mo`.
///
/// Every size the app shows goes through here, so they all read alike. The
/// language is `Intl.defaultLocale`, which `lib/app.dart` keeps in step with
/// the app's own, as the number helpers in `locale_number_symbols.dart` do.
String byteSizeLabel(String number, String unit) =>
    _strings().common_byteSize(localiseNumberSeparators(number), unit);

AppLocalizations _strings() {
  final language = Intl.getCurrentLocale().split(RegExp('[-_]')).first;
  final locale = Locale(language);
  return lookupAppLocalizations(
    AppLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
  );
}

/// The number, rounded and with Dart's '.' decimal point, and its unit key.
(String, String) _byteParts(int bytes) {
  if (bytes <= 0) return ('0', 'B');
  if (bytes < 1024) return ('$bytes', 'B');
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return (value.toStringAsFixed(value >= 10 ? 0 : 1), units[unit]);
}
