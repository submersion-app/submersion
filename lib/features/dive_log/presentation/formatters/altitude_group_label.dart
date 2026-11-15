import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized name and altitude range for an [AltitudeGroup].
///
/// [AltitudeGroup.displayName] / [AltitudeGroup.rangeDescription] stay
/// hardcoded English on purpose: they feed data interchange. These getters
/// drive on-screen UI so the same values honor the active locale (issue
/// #1608).
///
/// The name's switch is exhaustive by enum value, so adding a value is a
/// compile error until its localization key is wired in.
extension AltitudeGroupDisplay on AltitudeGroup {
  String localizedName(AppLocalizations l10n) => switch (this) {
    AltitudeGroup.seaLevel => l10n.enum_altitudeGroup_seaLevel,
    AltitudeGroup.group1 => l10n.enum_altitudeGroup_group1,
    AltitudeGroup.group2 => l10n.enum_altitudeGroup_group2,
    AltitudeGroup.group3 => l10n.enum_altitudeGroup_group3,
    AltitudeGroup.extreme => l10n.enum_altitudeGroup_extreme,
  };

  /// The group's altitudes in the diver's unit only, with the number format
  /// every other altitude uses: "984-2,953 ft", or ">2,700 m" for the open
  /// top group.
  String localizedRange(AppLocalizations l10n, UnitFormatter units) {
    final low = units.formatAltitudeNumber(minAltitude);
    final unit = units.altitudeSymbol;
    if (maxAltitude.isInfinite) {
      return l10n.enum_altitudeGroup_range_above(low, unit);
    }
    return l10n.enum_altitudeGroup_range_between(
      low,
      units.formatAltitudeNumber(maxAltitude),
      unit,
    );
  }
}
