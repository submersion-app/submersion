import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/suunto_native_event.dart';
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
    ProfileEventType.lowNoDecoTime => l10n.enum_profileEvent_lowNoDecoTime,
    ProfileEventType.decompressionDive =>
      l10n.enum_profileEvent_decompressionDive,
    ProfileEventType.setpointChange => l10n.enum_profileEvent_setpointChange,
    ProfileEventType.bookmark => l10n.enum_profileEvent_bookmark,
    ProfileEventType.alert => l10n.enum_profileEvent_alert,
    ProfileEventType.note => l10n.enum_profileEvent_note,
  };
}

/// Localized label for a Suunto watch's own event (#1523).
extension SuuntoNativeEventDisplay on SuuntoNativeEvent {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SuuntoNativeEvent.lowPpo2Alarm =>
      l10n.enum_profileEvent_suunto_lowPpo2Alarm,
    SuuntoNativeEvent.highPpo2Alarm =>
      l10n.enum_profileEvent_suunto_highPpo2Alarm,
    SuuntoNativeEvent.tankPressureAlarm =>
      l10n.enum_profileEvent_suunto_tankPressureAlarm,
    SuuntoNativeEvent.gasTimeAlarm =>
      l10n.enum_profileEvent_suunto_gasTimeAlarm,
    SuuntoNativeEvent.ascentRateAlarm =>
      l10n.enum_profileEvent_suunto_ascentRateAlarm,
    SuuntoNativeEvent.cns100Alarm => l10n.enum_profileEvent_suunto_cns100Alarm,
    SuuntoNativeEvent.otu300Alarm => l10n.enum_profileEvent_suunto_otu300Alarm,
    SuuntoNativeEvent.decoStopBroken =>
      l10n.enum_profileEvent_suunto_decoStopBroken,
    SuuntoNativeEvent.deepStopBroken =>
      l10n.enum_profileEvent_suunto_deepStopBroken,
    SuuntoNativeEvent.safetyStopBroken =>
      l10n.enum_profileEvent_suunto_safetyStopBroken,
    SuuntoNativeEvent.highPpo2Warning =>
      l10n.enum_profileEvent_suunto_highPpo2Warning,
    SuuntoNativeEvent.cns80Warning =>
      l10n.enum_profileEvent_suunto_cns80Warning,
    SuuntoNativeEvent.otu250Warning =>
      l10n.enum_profileEvent_suunto_otu250Warning,
    SuuntoNativeEvent.tankPressureWarning =>
      l10n.enum_profileEvent_suunto_tankPressureWarning,
    SuuntoNativeEvent.gasTimeWarning =>
      l10n.enum_profileEvent_suunto_gasTimeWarning,
    SuuntoNativeEvent.tankPressureNotification =>
      l10n.enum_profileEvent_suunto_tankPressureNotification,
    SuuntoNativeEvent.gasTimeNotification =>
      l10n.enum_profileEvent_suunto_gasTimeNotification,
    SuuntoNativeEvent.decoStopReached =>
      l10n.enum_profileEvent_suunto_decoStopReached,
    SuuntoNativeEvent.deepStopReached =>
      l10n.enum_profileEvent_suunto_deepStopReached,
    SuuntoNativeEvent.safetyStopReached =>
      l10n.enum_profileEvent_suunto_safetyStopReached,
    SuuntoNativeEvent.ceilingBroken =>
      l10n.enum_profileEvent_suunto_ceilingBroken,
  };
}

/// The text a profile-chart marker shows for one event.
extension ProfileEventMarkerLabel on ProfileEvent {
  /// The watch's own wording when the event carries a Suunto native code
  /// (a tank-pressure alarm rather than "Low Gas Warning"), otherwise the
  /// event type's label.
  String markerLabel(AppLocalizations l10n) =>
      SuuntoNativeEvent.of(this)?.localizedName(l10n) ??
      eventType.localizedName(l10n);
}
