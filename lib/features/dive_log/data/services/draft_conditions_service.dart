import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

/// Records [dive]'s tide at the position [at].
typedef DraftTideRecorder = Future<void> Function(Dive dive, GeoPoint at);

/// Weather and tide for drafts (issue #637), from where the diver went in:
/// a draft has no site yet, only the position the phone recorded. Fills only
/// what is empty, so nothing the diver typed is replaced.
class DraftConditionsService {
  DraftConditionsService({
    required DiveRepository dives,
    required DiveDraftRepository drafts,
    required WeatherService weather,
    required DraftTideRecorder recordTide,
    required Future<bool> Function(String diveId) hasTide,
    DateTime Function()? clock,
  }) : _dives = dives,
       _drafts = drafts,
       _weather = weather,
       _recordTide = recordTide,
       _hasTide = hasTide,
       _clock = clock ?? DateTime.now;

  final DiveRepository _dives;
  final DiveDraftRepository _drafts;
  final WeatherService _weather;
  final DraftTideRecorder _recordTide;
  final Future<bool> Function(String diveId) _hasTide;
  final DateTime Function() _clock;

  /// How long after its exit a draft still gets its conditions.
  static const lookBack = Duration(days: 7);

  /// The drafts tried this app session. Each is tried once a session, so an
  /// offline failure waits for the next app open rather than going out again
  /// on every dive change.
  final _tried = <String>{};

  static final _log = LoggerService.forClass(DraftConditionsService);

  /// Fills weather and tide for [diverId]'s drafts out of the water in the
  /// last [lookBack] that have an entry position. Never throws.
  Future<void> fillPending({required String? diverId}) async {
    if (diverId == null) return;
    final since = asWallClockUtc(_clock().toLocal()).subtract(lookBack);
    for (final draft in await _drafts.getDrafts(diverId: diverId)) {
      final at = draft.entryLocation;
      final exit = draft.exitTime;
      if (at == null || exit == null || exit.isBefore(since)) continue;
      if (!_tried.add(draft.id)) continue;
      try {
        await _fill(draft, at);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to fill conditions for a draft',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _fill(Dive draft, GeoPoint at) async {
    // Dive times are a wall clock flagged UTC; the weather request reads
    // them as the place's own time, as the site fill does.
    final entry = draft.entryTime ?? draft.dateTime;
    if (draft.weatherSource == null) {
      final weather = await _weather.fetchWeather(
        latitude: at.latitude,
        longitude: at.longitude,
        date: DateTime(entry.year, entry.month, entry.day),
        entryTime: entry,
      );
      if (weather != null) {
        await _dives.fillDiveConditions(
          draft.id,
          windSpeed: weather.windSpeed,
          windDirection: weather.windDirection,
          cloudCover: weather.cloudCover,
          precipitation: weather.precipitation,
          humidity: weather.humidity,
          weatherCode: weather.weatherCode,
          airTemp: weather.airTemp,
          surfacePressure: weather.surfacePressure,
          source: WeatherSource.openMeteo,
          fetchedAt: _clock(),
        );
      }
    }
    if (draft.waterType != WaterType.fresh && !await _hasTide(draft.id)) {
      await _recordTide(draft, at);
    }
  }
}
