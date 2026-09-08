import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized name and altitude range for an [AltitudeGroup].
///
/// [AltitudeGroup.displayName] / [AltitudeGroup.rangeDescription] stay
/// hardcoded English on purpose: they feed data interchange. These getters
/// drive on-screen UI so the same values honor the active locale (issue
/// #1608).
///
/// Each switch is exhaustive by enum value, so adding a value is a compile
/// error until its localization key is wired in.
extension AltitudeGroupDisplay on AltitudeGroup {
  String localizedName(AppLocalizations l10n) => switch (this) {
    AltitudeGroup.seaLevel => l10n.enum_altitudeGroup_seaLevel,
    AltitudeGroup.group1 => l10n.enum_altitudeGroup_group1,
    AltitudeGroup.group2 => l10n.enum_altitudeGroup_group2,
    AltitudeGroup.group3 => l10n.enum_altitudeGroup_group3,
    AltitudeGroup.extreme => l10n.enum_altitudeGroup_extreme,
  };

  String localizedRange(AppLocalizations l10n) => switch (this) {
    AltitudeGroup.seaLevel => l10n.enum_altitudeGroup_seaLevel_range,
    AltitudeGroup.group1 => l10n.enum_altitudeGroup_group1_range,
    AltitudeGroup.group2 => l10n.enum_altitudeGroup_group2_range,
    AltitudeGroup.group3 => l10n.enum_altitudeGroup_group3_range,
    AltitudeGroup.extreme => l10n.enum_altitudeGroup_extreme_range,
  };
}
