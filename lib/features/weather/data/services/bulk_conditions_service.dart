import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

/// How far along a bulk conditions run is.
class BulkConditionsProgress {
  const BulkConditionsProgress({required this.completed, required this.total});

  final int completed;
  final int total;
}

/// What a bulk conditions run did.
///
/// Every candidate dive lands in exactly one bucket, so
/// `filled + unavailable + unchanged` is the number of dives processed. A
/// cancelled run processes fewer dives than it had candidates.
class BulkConditionsResult {
  const BulkConditionsResult({
    required this.filled,
    required this.unavailable,
    required this.unchanged,
    required this.total,
    required this.cancelled,
  });

  /// Dives that received at least one value.
  final int filled;

  /// Dives whose place and date the archive had nothing for.
  final int unavailable;

  /// Dives the archive answered for, but with nothing that fit a gap.
  final int unchanged;

  /// Candidates found at the start of the run.
  final int total;

  final bool cancelled;

  int get processed => filled + unavailable + unchanged;
}

/// Rebuilds a stored dive time as a local [DateTime] with the same wall-clock
/// components.
///
/// Dive times are persisted as a wall clock flagged UTC (a dive logged at 09:00
/// reads back as `09:00Z`), but the archive mapper picks its sample by absolute
/// difference against timestamps it parses without a zone, which Dart returns
/// as local. Handing it the stored value directly would shift the chosen hour
/// by the machine's UTC offset, so the components are rebuilt locally first.
/// This is what the single-dive fetch on the edit page does implicitly, by
/// building its target from the date and time pickers.
DateTime diveWallClockToLocal(DateTime stored) =>
    DateTime(stored.year, stored.month, stored.day, stored.hour, stored.minute);

/// Key for the one-response-per-place-per-day cache.
///
/// Coordinates are rounded to about a metre before keying: two dives at the
/// same site carry byte-identical coordinates, and rounding keeps floating
/// point noise from splitting them into two requests.
typedef _FetchKey = ({String date, String latitude, String longitude});

/// Fills missing conditions across the whole logbook from the historical
/// weather archive.
///
/// Never overwrites anything: each dive is written through
/// [DiveRepository.fillDiveConditions], which leaves populated columns out of
/// the UPDATE entirely.
class BulkConditionsService {
  BulkConditionsService({
    required DiveRepository diveRepository,
    required WeatherService weatherService,
    this.requestDelay = const Duration(milliseconds: 150),
  }) : _diveRepository = diveRepository,
       _weatherService = weatherService;

  final DiveRepository _diveRepository;
  final WeatherService _weatherService;

  /// Paced between requests so a large logbook does not trip the archive's
  /// rate limit. Only applied when a request actually goes out; dives served
  /// from the cache are not delayed.
  final Duration requestDelay;

  /// How many dives a run would attempt. Does not contact the network, and
  /// counts in the database rather than materialising the candidate list: the
  /// confirm dialog wants the number, not the dives.
  Future<int> countCandidates({String? diverId}) =>
      _diveRepository.countDivesNeedingConditions(diverId: diverId);

  /// Fetches and fills conditions for every dive that still has a gap.
  ///
  /// [onProgress] fires once per dive processed. [isCancelled] is polled
  /// before each dive; a cancelled run keeps everything it has already
  /// written and reports `cancelled: true`.
  Future<BulkConditionsResult> run({
    String? diverId,
    void Function(BulkConditionsProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final candidates = await _diveRepository.getDivesNeedingConditions(
      diverId: diverId,
    );

    // One archive response can serve every dive made at the same place on the
    // same day, which on a two-tank morning or a liveaboard is most of them.
    final cache = <_FetchKey, WeatherData?>{};

    var filled = 0;
    var unavailable = 0;
    var unchanged = 0;
    var cancelled = false;

    for (final candidate in candidates) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }

      final key = _keyFor(candidate);
      final WeatherData? weather;
      if (cache.containsKey(key)) {
        weather = cache[key];
      } else {
        weather = await _fetch(candidate);
        cache[key] = weather;
        // The pacing exists to space out the NEXT request. A run cancelled
        // while this one was in flight has no next request, so waiting would
        // only make the button feel unresponsive.
        if (requestDelay > Duration.zero && !(isCancelled?.call() ?? false)) {
          await Future<void>.delayed(requestDelay);
        }
      }

      if (weather == null) {
        unavailable++;
      } else {
        final wrote = await _diveRepository.fillDiveConditions(
          candidate.id,
          windSpeed: weather.windSpeed,
          windDirection: weather.windDirection,
          cloudCover: weather.cloudCover,
          precipitation: weather.precipitation,
          humidity: weather.humidity,
          weatherCode: weather.weatherCode,
          airTemp: weather.airTemp,
          surfacePressure: weather.surfacePressure,
          source: WeatherSource.openMeteo,
          fetchedAt: DateTime.now(),
        );
        if (wrote) {
          filled++;
        } else {
          unchanged++;
        }
      }

      onProgress?.call(
        BulkConditionsProgress(
          completed: filled + unavailable + unchanged,
          total: candidates.length,
        ),
      );
    }

    return BulkConditionsResult(
      filled: filled,
      unavailable: unavailable,
      unchanged: unchanged,
      total: candidates.length,
      cancelled: cancelled,
    );
  }

  _FetchKey _keyFor(ConditionsCandidate candidate) => (
    date:
        '${candidate.dateTime.year}-'
        '${candidate.dateTime.month}-${candidate.dateTime.day}',
    latitude: candidate.latitude.toStringAsFixed(5),
    longitude: candidate.longitude.toStringAsFixed(5),
  );

  /// One dive's fetch. A failure here is per-day, not per-run: [WeatherService]
  /// already degrades every network and parse failure to null and logs it, so
  /// the archive being unhelpful about one place and date is reported as
  /// unavailable rather than stranding the rest of the logbook. No second
  /// catch here: it would be unreachable, and swallowing a genuinely
  /// unexpected error would only hide it.
  Future<WeatherData?> _fetch(ConditionsCandidate candidate) {
    final wallClock = diveWallClockToLocal(candidate.dateTime);
    return _weatherService.fetchWeather(
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      date: DateTime(wallClock.year, wallClock.month, wallClock.day),
      entryTime: wallClock,
    );
  }
}
