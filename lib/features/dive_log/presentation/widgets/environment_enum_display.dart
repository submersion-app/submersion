import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display names for the weather and dive-condition enums shown in
/// the dive Environment section (detail view and edit form).
///
/// The `displayName` field on each enum stays English on purpose: it feeds
/// data interchange (CSV/Excel export, the field extractor) where a stable,
/// locale-independent value is wanted. These getters drive on-screen UI so the
/// same values honor the active locale, resolving issue #622.
///
/// Each switch is exhaustive by enum value, so adding a new value is a compile
/// error until its localization key is wired in.
extension CurrentDirectionDisplay on CurrentDirection {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CurrentDirection.north => l10n.enum_currentDirection_north,
    CurrentDirection.northEast => l10n.enum_currentDirection_northEast,
    CurrentDirection.east => l10n.enum_currentDirection_east,
    CurrentDirection.southEast => l10n.enum_currentDirection_southEast,
    CurrentDirection.south => l10n.enum_currentDirection_south,
    CurrentDirection.southWest => l10n.enum_currentDirection_southWest,
    CurrentDirection.west => l10n.enum_currentDirection_west,
    CurrentDirection.northWest => l10n.enum_currentDirection_northWest,
    CurrentDirection.variable => l10n.enum_currentDirection_variable,
    CurrentDirection.none => l10n.enum_currentDirection_none,
  };
}

extension CurrentStrengthDisplay on CurrentStrength {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CurrentStrength.none => l10n.enum_currentStrength_none,
    CurrentStrength.light => l10n.enum_currentStrength_light,
    CurrentStrength.moderate => l10n.enum_currentStrength_moderate,
    CurrentStrength.strong => l10n.enum_currentStrength_strong,
  };
}

extension CloudCoverDisplay on CloudCover {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CloudCover.clear => l10n.enum_cloudCover_clear,
    CloudCover.partlyCloudy => l10n.enum_cloudCover_partlyCloudy,
    CloudCover.mostlyCloudy => l10n.enum_cloudCover_mostlyCloudy,
    CloudCover.overcast => l10n.enum_cloudCover_overcast,
  };
}

extension PrecipitationDisplay on Precipitation {
  String localizedName(AppLocalizations l10n) => switch (this) {
    Precipitation.none => l10n.enum_precipitation_none,
    Precipitation.drizzle => l10n.enum_precipitation_drizzle,
    Precipitation.lightRain => l10n.enum_precipitation_lightRain,
    Precipitation.rain => l10n.enum_precipitation_rain,
    Precipitation.heavyRain => l10n.enum_precipitation_heavyRain,
    Precipitation.snow => l10n.enum_precipitation_snow,
    Precipitation.sleet => l10n.enum_precipitation_sleet,
    Precipitation.hail => l10n.enum_precipitation_hail,
  };
}

extension EntryMethodDisplay on EntryMethod {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EntryMethod.shore => l10n.enum_entryMethod_shore,
    EntryMethod.boat => l10n.enum_entryMethod_boat,
    EntryMethod.backRoll => l10n.enum_entryMethod_backRoll,
    EntryMethod.giantStride => l10n.enum_entryMethod_giantStride,
    EntryMethod.seatedEntry => l10n.enum_entryMethod_seatedEntry,
    EntryMethod.ladder => l10n.enum_entryMethod_ladder,
    EntryMethod.platform => l10n.enum_entryMethod_platform,
    EntryMethod.jetty => l10n.enum_entryMethod_jetty,
    EntryMethod.other => l10n.enum_entryMethod_other,
  };
}
