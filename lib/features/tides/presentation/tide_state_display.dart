import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized name for a [TideState].
///
/// [TideState.displayName] stays hardcoded English on purpose (data
/// interchange); this drives on-screen UI so the same value honors the active
/// locale (issue #1608).
///
/// The switch is exhaustive by enum value, so adding a value is a compile error
/// until its localization key is wired in.
extension TideStateDisplay on TideState {
  String localizedName(AppLocalizations l10n) => switch (this) {
    TideState.rising => l10n.enum_tideState_rising,
    TideState.falling => l10n.enum_tideState_falling,
    TideState.slackHigh => l10n.enum_tideState_slackHigh,
    TideState.slackLow => l10n.enum_tideState_slackLow,
  };
}
