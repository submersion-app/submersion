import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// Fixed namespace for deterministic trip-day-weather ids (UUIDv5).
/// Never change: the ids already stored depend on it.
const String kTripDayWeatherNamespace = '3f1c8a52-9e47-4d6b-8b3a-16c9d0f27e45';

/// The calendar day of [date] as epoch milliseconds at UTC midnight.
///
/// The day is the identity of a weather row, so this is what turns a
/// DateTime into one. Shared rather than reimplemented per caller: the row
/// id, the repository's storage key, and the map key reads come back under
/// all have to agree, and three copies of the same two lines would drift.
///
/// UTC, not local midnight, and the distinction is the whole point. A local
/// `DateTime(y, m, d)` has a different epoch value in every timezone, so two
/// devices looking at the same trip day would derive different keys, and
/// therefore different row ids, and never converge: each would store and
/// refetch its own copy of the day. Divers cross timezones by definition, and
/// one diver flying home is enough to trigger it.
///
/// The calendar fields are taken as given rather than converted. `toUtc()`
/// would shift a late evening onto the following day; the trip story already
/// hands over a date whose y/m/d is the day it means, matching the app's
/// wall-clock-as-UTC convention for dive timestamps.
int tripDayMillis(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;

/// The instant [dayMillis] denotes, read in UTC.
///
/// The only correct way to read a stored day back. `fromMillisecondsSinceEpoch`
/// without `isUtc` returns a LOCAL DateTime, so re-extracting y/m/d from it
/// reads the calendar fields in the device's frame: on any negative UTC
/// offset, UTC midnight is the previous evening locally, and the day walks
/// backwards on every round trip.
///
/// It reads the value it is given and normalizes nothing, so it is the
/// inverse of [tripDayMillis] only for a value [tripDayMillis] produced. A
/// stored `date` is not guaranteed to be one: rows written before this branch
/// derived ids can carry a time component, and the repository deliberately
/// calls this on those raw values. Run the result back through
/// [tripDayMillis] whenever you need the normalized day rather than the
/// instant as stored.
DateTime tripDayDate(int dayMillis) =>
    DateTime.fromMillisecondsSinceEpoch(dayMillis, isUtc: true);

/// Deterministic row id for one trip day.
///
/// The day is the identity, so the id must be derived from it rather than
/// minted per device. Two devices that both fetch the same day would
/// otherwise insert two rows, and the unique (trip_id, date) index turns the
/// second one into an inbound-sync failure rather than a merge: the
/// serializer upserts by primary key, so a differing id misses the conflict
/// target entirely and hits the index instead. That throws inside the merge
/// transaction and aborts the whole sync pull.
///
/// [dayMillis] must already be the normalized UTC-midnight day key; pass it
/// through [tripDayMillis]. Local midnight would defeat the purpose: its epoch
/// value differs in every timezone, so the derived id would too and the two
/// devices this exists to converge would not.
String tripDayWeatherRowId({required String tripId, required int dayMillis}) =>
    const Uuid().v5(kTripDayWeatherNamespace, '$tripId|$dayMillis');

/// Stored historical weather for one trip day.
///
/// Written only for days whose dives supply no weather of their own; a day
/// with dive-logged weather renders that instead, because it is what the
/// diver actually recorded.
///
/// Metric throughout (celsius, m/s, bar). Conversion to the diver's units
/// happens at display time.
class TripDayWeather extends Equatable {
  final String id;
  final String tripId;

  /// The calendar day this describes.
  ///
  /// Read as calendar fields, not as an instant: identity is
  /// `tripDayMillis(date)`, which takes y/m/d and pins them to UTC midnight.
  /// UTC because the day is part of the row identity, and a local-midnight
  /// instant has a different epoch value in every timezone, so two devices
  /// would key the same trip day differently and never converge. See
  /// [tripDayMillis].
  ///
  /// So `isUtc` is not enforced here, and varies by provenance: the
  /// repository hands back a normalized UTC-midnight instant, while a row
  /// built from a freshly fetched day carries the backfill target's local
  /// `DateTime(y, m, d)`. Both name the same day and derive the same key, and
  /// no path that stores, keys, or looks a row up reads anything else.
  ///
  /// Except `==`. DateTime compares its epoch value and `isUtc`, and this
  /// field is in [props], so two entities for the same day compare unequal
  /// across provenance. Compare day keys, or normalize both sides, rather
  /// than the entities.
  final DateTime date;

  /// The coordinates the lookup used.
  final double latitude;
  final double longitude;

  final double? airTemp; // celsius
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? windSpeed; // m/s
  final CurrentDirection? windDirection;
  final double? humidity; // 0-100
  final double? surfacePressure; // bar

  /// Raw WMO weather code (0 clear, 61 rain, 95 thunderstorm, ...), kept so
  /// the description can be rendered in the diver's locale at display time.
  final int? weatherCode;

  final WeatherSource weatherSource;
  final DateTime fetchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripDayWeather({
    required this.id,
    required this.tripId,
    required this.date,
    required this.latitude,
    required this.longitude,
    this.airTemp,
    this.cloudCover,
    this.precipitation,
    this.windSpeed,
    this.windDirection,
    this.humidity,
    this.surfacePressure,
    this.weatherCode,
    this.weatherSource = WeatherSource.openMeteo,
    required this.fetchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when the day header's badge would actually show something.
  ///
  /// Wind, humidity, and pressure are stored but never drawn, so a row
  /// carrying only those renders as nothing and would suppress the retry that
  /// a later archive update would satisfy.
  ///
  /// Delegates to [TripStoryDayWeather.isRenderable] so the rule that decides
  /// what is worth storing is the same one that decides what the header can
  /// draw, and the same one the backfill uses to judge a day's dive weather.
  bool get hasRenderableWeather => toStoryWeather().isRenderable;

  /// The compact view model the day header consumes.
  TripStoryDayWeather toStoryWeather() => TripStoryDayWeather(
    airTemp: airTemp,
    cloudCover: cloudCover,
    precipitation: precipitation,
  );

  TripDayWeather copyWith({
    String? id,
    String? tripId,
    DateTime? date,
    double? latitude,
    double? longitude,
    Object? airTemp = _undefined,
    Object? cloudCover = _undefined,
    Object? precipitation = _undefined,
    Object? windSpeed = _undefined,
    Object? windDirection = _undefined,
    Object? humidity = _undefined,
    Object? surfacePressure = _undefined,
    Object? weatherCode = _undefined,
    WeatherSource? weatherSource,
    DateTime? fetchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripDayWeather(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      airTemp: airTemp == _undefined ? this.airTemp : airTemp as double?,
      cloudCover: cloudCover == _undefined
          ? this.cloudCover
          : cloudCover as CloudCover?,
      precipitation: precipitation == _undefined
          ? this.precipitation
          : precipitation as Precipitation?,
      windSpeed: windSpeed == _undefined
          ? this.windSpeed
          : windSpeed as double?,
      windDirection: windDirection == _undefined
          ? this.windDirection
          : windDirection as CurrentDirection?,
      humidity: humidity == _undefined ? this.humidity : humidity as double?,
      surfacePressure: surfacePressure == _undefined
          ? this.surfacePressure
          : surfacePressure as double?,
      weatherCode: weatherCode == _undefined
          ? this.weatherCode
          : weatherCode as int?,
      weatherSource: weatherSource ?? this.weatherSource,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    date,
    latitude,
    longitude,
    airTemp,
    cloudCover,
    precipitation,
    windSpeed,
    windDirection,
    humidity,
    surfacePressure,
    weatherCode,
    weatherSource,
    fetchedAt,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
