import 'package:intl/intl.dart';

/// The locale `intl` holds date data for that best matches [localeName]: the
/// full name, then its language alone, or null for intl's own default.
///
/// The same fallback `GlobalMaterialLocalizations` applies, so a date the app
/// formats itself reads like the ones Material formats. Pass the result
/// straight to a `DateFormat` constructor.
String? intlDateLocale(String localeName) {
  final canonical = Intl.canonicalizedLocale(localeName);
  if (DateFormat.localeExists(canonical)) return canonical;
  final language = canonical.split('_').first;
  if (DateFormat.localeExists(language)) return language;
  return null;
}
