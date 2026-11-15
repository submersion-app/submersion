import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

// The values edited on the dive page's Environment card, each in the unit it
// is stored in. Emptying one clears it.

final String _card = DiveDetailSectionId.environment.name;

/// Air temperature, in Celsius.
final diveAirTempField = EditField<Dive, double?>(
  id: 'airTemp',
  cardId: _card,
  read: (dive) => dive.airTemp,
  write: (dive, value) =>
      dive.copyWith(airTemp: value, clearAirTemp: value == null),
);

/// Wind speed, in metres per second.
final diveWindSpeedField = EditField<Dive, double?>(
  id: 'windSpeed',
  cardId: _card,
  read: (dive) => dive.windSpeed,
  write: (dive, value) =>
      dive.copyWith(windSpeed: value, clearWindSpeed: value == null),
);

final diveWindDirectionField = EditField<Dive, CurrentDirection?>(
  id: 'windDirection',
  cardId: _card,
  read: (dive) => dive.windDirection,
  write: (dive, value) =>
      dive.copyWith(windDirection: value, clearWindDirection: value == null),
);

final diveCloudCoverField = EditField<Dive, CloudCover?>(
  id: 'cloudCover',
  cardId: _card,
  read: (dive) => dive.cloudCover,
  write: (dive, value) =>
      dive.copyWith(cloudCover: value, clearCloudCover: value == null),
);

final divePrecipitationField = EditField<Dive, Precipitation?>(
  id: 'precipitation',
  cardId: _card,
  read: (dive) => dive.precipitation,
  write: (dive, value) =>
      dive.copyWith(precipitation: value, clearPrecipitation: value == null),
);

/// Relative humidity, 0 to 100.
final diveHumidityField = EditField<Dive, double?>(
  id: 'humidity',
  cardId: _card,
  read: (dive) => dive.humidity,
  write: (dive, value) =>
      dive.copyWith(humidity: value, clearHumidity: value == null),
);

/// The weather in the diver's own words. Stored trimmed; blank is no value,
/// and words that differ only in the space around them are the same, as for
/// [diveSurfaceConditionsField].
final diveWeatherDescriptionField = EditField<Dive, String?>(
  id: 'weatherDescription',
  cardId: _card,
  read: (dive) => dive.weatherDescription,
  write: (dive, value) {
    final words = trimmedOrNull(value);
    return dive.copyWith(
      weatherDescription: words,
      clearWeatherDescription: words == null,
    );
  },
  equals: (a, b) => trimmedOrNull(a) == trimmedOrNull(b),
);

/// Where the weather values came from. Set by [applyFetchedWeather].
final diveWeatherSourceField = EditField<Dive, WeatherSource?>(
  id: 'weatherSource',
  cardId: _card,
  read: (dive) => dive.weatherSource,
  write: (dive, value) =>
      dive.copyWith(weatherSource: value, clearWeatherSource: value == null),
);

/// The forecast's WMO weather code. The read card writes its description
/// from it, in the diver's language. Set by [applyFetchedWeather].
final diveWeatherCodeField = EditField<Dive, int?>(
  id: 'weatherCode',
  cardId: _card,
  read: (dive) => dive.weatherCode,
  write: (dive, value) =>
      dive.copyWith(weatherCode: value, clearWeatherCode: value == null),
);

/// When the weather values were fetched. Set by [applyFetchedWeather].
final diveWeatherFetchedAtField = EditField<Dive, DateTime?>(
  id: 'weatherFetchedAt',
  cardId: _card,
  read: (dive) => dive.weatherFetchedAt,
  write: (dive, value) => dive.copyWith(
    weatherFetchedAt: value,
    clearWeatherFetchedAt: value == null,
  ),
);

final diveCurrentDirectionField = EditField<Dive, CurrentDirection?>(
  id: 'currentDirection',
  cardId: _card,
  read: (dive) => dive.currentDirection,
  write: (dive, value) => dive.copyWith(
    currentDirection: value,
    clearCurrentDirection: value == null,
  ),
);

final diveCurrentStrengthField = EditField<Dive, CurrentStrength?>(
  id: 'currentStrength',
  cardId: _card,
  read: (dive) => dive.currentStrength,
  write: (dive, value) => dive.copyWith(
    currentStrength: value,
    clearCurrentStrength: value == null,
  ),
);

/// Swell height, in metres.
final diveSwellHeightField = EditField<Dive, double?>(
  id: 'swellHeight',
  cardId: _card,
  read: (dive) => dive.swellHeight,
  write: (dive, value) =>
      dive.copyWith(swellHeight: value, clearSwellHeight: value == null),
);

/// Surface conditions, as the diver's own words. Stored trimmed; blank is
/// no value, and words that differ only in the space around them are the
/// same.
final diveSurfaceConditionsField = EditField<Dive, String?>(
  id: 'surfaceConditions',
  cardId: _card,
  read: (dive) => dive.surfaceConditions,
  write: (dive, value) {
    final words = trimmedOrNull(value);
    return dive.copyWith(
      surfaceConditions: words,
      clearSurfaceConditions: words == null,
    );
  },
  equals: (a, b) => trimmedOrNull(a) == trimmedOrNull(b),
);

/// The dive's own entry method. A dive with none shows its site's, but that
/// is not stored on the dive.
final diveEntryMethodField = EditField<Dive, EntryMethod?>(
  id: 'entryMethod',
  cardId: _card,
  read: (dive) => dive.entryMethod,
  write: (dive, value) =>
      dive.copyWith(entryMethod: value, clearEntryMethod: value == null),
);

final diveExitMethodField = EditField<Dive, EntryMethod?>(
  id: 'exitMethod',
  cardId: _card,
  read: (dive) => dive.exitMethod,
  write: (dive, value) =>
      dive.copyWith(exitMethod: value, clearExitMethod: value == null),
);

/// Whether [dive]'s exit method follows its entry method when editing
/// begins: it is unset, or the same. This is what the dive form decides as
/// it loads a dive.
bool exitFollowsEntry(Dive dive) =>
    dive.exitMethod == null || dive.exitMethod == dive.entryMethod;

/// Sets the entry method, and the exit method with it while [exitFollows].
///
/// The exit mirrors the entry until the diver edits the exit directly. That
/// cannot be told from the two values (an exit the diver cleared, or chose
/// to match, looks the same as one never touched), so the editor remembers
/// it: [exitFollowsEntry] when it opens, false from the first direct edit.
void setEntryMethod(
  EditSession<Dive> session,
  EntryMethod? value, {
  required bool exitFollows,
}) {
  session.set(diveEntryMethodField, value);
  if (exitFollows) session.set(diveExitMethodField, value);
}

/// Whether the weather has been fetched again in this sitting.
bool _refetched(EditSession<Dive> session) =>
    session.valueOf(diveWeatherFetchedAtField) !=
    session.stored.weatherFetchedAt;

/// Call when the diver has edited the weather description themselves.
///
/// The read card writes the description of fetched weather from its
/// forecast and does not show the stored words, so words the diver typed
/// would be saved and never seen. Typing them makes the weather the diver's
/// own: the source becomes manual and the read card shows their words. The
/// other fetched values stay.
///
/// Taking the words out needs no such change: with none stored, the read
/// card writes the description from the forecast whatever the source. So
/// a description back to nothing, or to the stored words, puts the source
/// back as it was, unless the weather has been fetched again in this
/// sitting. Weather that was not fetched is left alone.
void weatherDescriptionEdited(EditSession<Dive> session) {
  final stored = session.stored;
  final words = session.valueOf(diveWeatherDescriptionField);
  final backToStored = diveWeatherDescriptionField.same(
    words,
    stored.weatherDescription,
  );
  if ((words == null || backToStored) && !_refetched(session)) {
    session.set(diveWeatherSourceField, stored.weatherSource);
    return;
  }
  if (words != null &&
      session.valueOf(diveWeatherSourceField) == WeatherSource.openMeteo) {
    session.set(diveWeatherSourceField, WeatherSource.manual);
  }
}

/// Call when the diver has picked a cloud cover or a precipitation.
///
/// The read card names the sky from the forecast's weather code before
/// either of them, and leaves precipitation out when there is a code. A sky
/// the diver changes would then be described as the forecast had it, so the
/// code goes: the read card describes the sky from the diver's values. The
/// other fetched values, and the source, stay.
///
/// Both set back as stored puts the code back, unless the weather has been
/// fetched again in this sitting, so the sitting is left clean.
void weatherSkyEdited(EditSession<Dive> session) {
  final stored = session.stored;
  final skyAsStored =
      session.valueOf(diveCloudCoverField) == stored.cloudCover &&
      session.valueOf(divePrecipitationField) == stored.precipitation;
  if (skyAsStored && !_refetched(session)) {
    session.set(diveWeatherCodeField, stored.weatherCode);
    return;
  }
  if (!skyAsStored) session.set(diveWeatherCodeField, null);
}

/// Writes a fetched forecast into the sitting, as the dive form does.
///
/// Wind, cloud cover, precipitation and humidity are replaced by whatever
/// came back, and left alone where the forecast has nothing. A description
/// replaces the stored one only when it has words. Air temperature and
/// surface pressure are filled only when the sitting has none, since the
/// diver's own reading is the better one. The source and [now] are stamped.
///
/// The forecast's weather code replaces the stored one, and clears it when
/// the forecast has none: the read card describes the weather from that
/// code, and an old one would describe weather this fetch has replaced.
/// (The dive form leaves the old code in place.)
///
/// Surface pressure belongs to the Altitude card, so filling it marks that
/// card as changed too.
void applyFetchedWeather(
  EditSession<Dive> session,
  WeatherData data, {
  required DateTime now,
}) {
  final windSpeed = data.windSpeed;
  if (windSpeed != null) session.set(diveWindSpeedField, windSpeed);
  final windDirection = data.windDirection;
  if (windDirection != null) {
    session.set(diveWindDirectionField, windDirection);
  }
  final cloudCover = data.cloudCover;
  if (cloudCover != null) session.set(diveCloudCoverField, cloudCover);
  final precipitation = data.precipitation;
  if (precipitation != null) {
    session.set(divePrecipitationField, precipitation);
  }
  final humidity = data.humidity;
  if (humidity != null) session.set(diveHumidityField, humidity);
  final description = data.description;
  if (description != null && description.isNotEmpty) {
    session.set(diveWeatherDescriptionField, description);
  }

  final airTemp = data.airTemp;
  if (airTemp != null && session.valueOf(diveAirTempField) == null) {
    session.set(diveAirTempField, airTemp);
  }
  final pressure = data.surfacePressure;
  if (pressure != null && session.valueOf(diveSurfacePressureField) == null) {
    session.set(diveSurfacePressureField, pressure);
  }

  session
    ..set(diveWeatherCodeField, data.weatherCode)
    ..set(diveWeatherSourceField, WeatherSource.openMeteo)
    ..set(diveWeatherFetchedAtField, now);
}
