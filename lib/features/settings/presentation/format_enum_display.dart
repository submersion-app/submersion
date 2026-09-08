import 'package:submersion/core/constants/units.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label for [TimeFormat].
///
/// [TimeFormat.displayName] stays hardcoded English; this getter drives the
/// units settings so the "12-hour" / "24-hour" label honors the active locale
/// (issue #1608). The date-format notation ("DD/MM/YYYY") is deliberately left
/// as a universal notation, shown next to a live localized example.
extension TimeFormatDisplay on TimeFormat {
  String localizedName(AppLocalizations l10n) => switch (this) {
    TimeFormat.twelveHour => l10n.enum_timeFormat_twelveHour,
    TimeFormat.twentyFourHour => l10n.enum_timeFormat_twentyFourHour,
  };
}
