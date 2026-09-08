import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label for a [ProfileEventType] marker on the dive profile.
///
/// [ProfileEventType.displayName] stays hardcoded English on purpose: it feeds
/// data interchange (CSV/Excel export, the field extractor). This getter drives
/// the on-screen profile-chart markers so they honor the active locale
/// (issue #1608).
///
/// The switch is exhaustive by enum value, so adding a value is a compile error
/// until its localization key is wired in.
extension ProfileEventTypeDisplay on ProfileEventType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ProfileEventType.ascentStart => l10n.enum_profileEvent_ascentStart,
    ProfileEventType.safetyStopStart => l10n.enum_profileEvent_safetyStopStart,
    ProfileEventType.safetyStopEnd => l10n.enum_profileEvent_safetyStopEnd,
    ProfileEventType.decoStopStart => l10n.enum_profileEvent_decoStopStart,
    ProfileEventType.decoStopEnd => l10n.enum_profileEvent_decoStopEnd,
    ProfileEventType.gasSwitch => l10n.enum_profileEvent_gasSwitch,
    ProfileEventType.maxDepth => l10n.enum_profileEvent_maxDepth,
    ProfileEventType.ascentRateWarning =>
      l10n.enum_profileEvent_ascentRateWarning,
    ProfileEventType.ascentRateCritical =>
      l10n.enum_profileEvent_ascentRateCritical,
    ProfileEventType.decoViolation => l10n.enum_profileEvent_decoViolation,
    ProfileEventType.missedStop => l10n.enum_profileEvent_missedStop,
    ProfileEventType.lowGas => l10n.enum_profileEvent_lowGas,
    ProfileEventType.cnsWarning => l10n.enum_profileEvent_cnsWarning,
    ProfileEventType.cnsCritical => l10n.enum_profileEvent_cnsCritical,
    ProfileEventType.ppO2High => l10n.enum_profileEvent_ppO2High,
    ProfileEventType.ppO2Low => l10n.enum_profileEvent_ppO2Low,
    ProfileEventType.setpointChange => l10n.enum_profileEvent_setpointChange,
    ProfileEventType.bookmark => l10n.enum_profileEvent_bookmark,
    ProfileEventType.alert => l10n.enum_profileEvent_alert,
    ProfileEventType.note => l10n.enum_profileEvent_note,
  };
}
