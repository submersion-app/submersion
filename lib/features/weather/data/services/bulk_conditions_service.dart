import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

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
    // The raw hourly block is cached, not a mapped result, so each dive still
    // reads the sample for its own entry hour.
    final cache = <_FetchKey, Map<String, dynamic>?>{};

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
      final Map<String, dynamic>? hourly;
      if (cache.containsKey(key)) {
        hourly = cache[key];
      } else {
        hourly = await _fetch(candidate);
        cache[key] = hourly;
        // The pacing exists to space out the NEXT request. A run cancelled
        // while this one was in flight has no next request, so waiting would
        // only make the button feel unresponsive.
        if (requestDelay > Duration.zero && !(isCancelled?.call() ?? false)) {
          await Future<void>.delayed(requestDelay);
        }
      }

      // Dive times are a wall clock flagged UTC. The request asked for the
      // site's own timezone and the mapper matches on wall-clock fields, so
      // the stored value is handed on as is.
      final weather = hourly == null
          ? null
          : _weatherService.mapHourly(hourly, entryTime: candidate.dateTime);
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

  /// One place-and-day fetch. A failure here is per-day, not per-run:
  /// [WeatherService] already degrades every network and parse failure to
  /// null and logs it, so the archive being unhelpful about one place and date
  /// is reported as unavailable rather than stranding the rest of the logbook.
  /// No second catch here: it would be unreachable, and swallowing a genuinely
  /// unexpected error would only hide it.
  Future<Map<String, dynamic>?> _fetch(ConditionsCandidate candidate) {
    final wallClock = candidate.dateTime;
    return _weatherService.fetchHourly(
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      date: DateTime(wallClock.year, wallClock.month, wallClock.day),
    );
  }
}
