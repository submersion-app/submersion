import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label for a WMO weather code.
///
/// Open-Meteo returns only this numeric code -- it has no language parameter
/// and returns no prose. Mapping it here means the description follows the
/// diver's locale instead of being frozen in English at fetch time.
///
/// Returns null for an absent or unrecognised code so the caller can fall
/// back to the bucketed enums.
String? wmoCodeLabel(AppLocalizations l10n, int? code) {
  if (code == null) return null;
  if (code == 0) return l10n.weather_wmo_clear;
  if (code == 1) return l10n.weather_wmo_mainlyClear;
  if (code == 2) return l10n.weather_wmo_partlyCloudy;
  if (code == 3) return l10n.weather_wmo_overcast;
  if (code == 45 || code == 48) return l10n.weather_wmo_fog;
  if (code >= 51 && code <= 55) return l10n.weather_wmo_drizzle;
  if (code == 56 || code == 57) return l10n.weather_wmo_freezingDrizzle;
  if (code >= 61 && code <= 65) return l10n.weather_wmo_rain;
  if (code == 66 || code == 67) return l10n.weather_wmo_freezingRain;
  if (code >= 71 && code <= 75) return l10n.weather_wmo_snow;
  if (code == 77) return l10n.weather_wmo_snowGrains;
  if (code >= 80 && code <= 82) return l10n.weather_wmo_rainShowers;
  if (code == 85 || code == 86) return l10n.weather_wmo_snowShowers;
  if (code == 95) return l10n.weather_wmo_thunderstorm;
  if (code == 96 || code == 99) return l10n.weather_wmo_thunderstormHail;
  return null;
}

/// Beaufort-style wind descriptor for a speed in m/s.
String _windLabel(AppLocalizations l10n, double metersPerSecond) {
  if (metersPerSecond < 0.5) return l10n.weather_wind_calm;
  if (metersPerSecond < 3.4) return l10n.weather_wind_lightBreeze;
  if (metersPerSecond < 8.0) return l10n.weather_wind_moderateBreeze;
  if (metersPerSecond < 13.9) return l10n.weather_wind_strongBreeze;
  return l10n.weather_wind_highWind;
}

/// Build a weather description in the diver's locale and units.
///
/// A [storedDescription] -- text the diver typed, or that arrived with an
/// import -- is user data and is returned verbatim. Everything else is
/// rendered fresh on each build so it tracks the current locale and unit
/// settings rather than whatever was true when the weather was fetched.
///
/// Returns null when there is nothing to say, so the caller can omit the row.
String? buildLocalizedWeatherDescription({
  required AppLocalizations l10n,
  required UnitFormatter units,
  int? weatherCode,
  CloudCover? cloudCover,
  double? airTempCelsius,
  double? windSpeedMs,
  CurrentDirection? windDirection,
  Precipitation? precipitation,
  String? storedDescription,
}) {
  if (storedDescription != null && storedDescription.isNotEmpty) {
    return storedDescription;
  }

  final parts = <String>[];

  // The observed code is richer than the bucketed enum, so prefer it.
  final coded = wmoCodeLabel(l10n, weatherCode);
  if (coded != null) {
    parts.add(coded);
  } else if (cloudCover != null) {
    parts.add(cloudCover.localizedName(l10n));
  }

  if (airTempCelsius != null) {
    parts.add(units.formatTemperature(airTempCelsius));
  }

  if (windSpeedMs != null && windSpeedMs > 0) {
    final wind = _windLabel(l10n, windSpeedMs);
    if (windDirection != null && windDirection != CurrentDirection.none) {
      parts.add(
        l10n.weather_windFromDirection(wind, windDirection.localizedName(l10n)),
      );
    } else {
      parts.add(wind);
    }
  }

  // Only when the code is absent: a coded label such as "Rain showers"
  // already says this, and repeating it reads as noise.
  if (coded == null &&
      precipitation != null &&
      precipitation != Precipitation.none) {
    parts.add(precipitation.localizedName(l10n));
  }

  return parts.isEmpty ? null : parts.join(', ');
}
