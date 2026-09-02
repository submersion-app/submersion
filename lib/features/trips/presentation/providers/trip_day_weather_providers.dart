import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/services/trip_day_weather_backfill.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

final tripDayWeatherRepositoryProvider = Provider<TripDayWeatherRepository>(
  (ref) => TripDayWeatherRepository(),
);

/// Stored weather for a trip, keyed by `tripDayMillis(date)`: the calendar
/// day at UTC midnight, not `date.millisecondsSinceEpoch`.
///
/// Stated precisely because getting it wrong is silent. A caller that keys a
/// lookup with local-midnight millis finds nothing on any device that is not
/// on UTC, and the day simply renders no badge.
///
/// Subscribes to the table tick, so a row written by the backfill or arriving
/// through sync re-renders the day headers without the widget knowing a fetch
/// ever happened.
final tripDayWeatherProvider =
    FutureProvider.family<Map<int, TripDayWeather>, String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripDayWeatherRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchWeatherChanges());
      return repository.getForTrip(tripId);
    });

/// Fills the gaps: fetches historical weather for trip days that have none
/// stored and no dive to supply it, then writes what it finds.
///
/// The story is its only reactive input, so assigning dives to a trip
/// re-evaluates what is still missing.
///
/// autoDispose is what makes the retry policy above true. A miss writes no
/// row precisely so the day is tried again later; a provider that outlived
/// the view would serve its completed state on every subsequent navigation
/// and a transient failure would stand until the app restarted. Disposing
/// with the view means returning to the trip runs the pass again, which skips
/// the days that succeeded and retries only the ones still missing. While the
/// view stays mounted the provider stays alive, so scrolling does not refetch.
// no-tick: a side-effecting pass, not a cached query. It renders nothing (the
// value is void), and subscribing to the weather tick would make every row it
// writes invalidate the pass that wrote it. Its rows reach the UI through
// [tripDayWeatherProvider], which does subscribe. A stale read costs nothing:
// a row it misses is simply not refetched, and a stored day is skipped anyway.
final tripDayWeatherBackfillProvider = FutureProvider.autoDispose
    .family<void, String>((ref, tripId) async {
      final story = await ref.watch(tripStoryProvider(tripId).future);
      final repository = ref.watch(tripDayWeatherRepositoryProvider);
      final service = ref.watch(weatherServiceProvider);

      final stored = await repository.getForTrip(tripId);
      final targets = TripDayWeatherBackfill.targetsFor(
        story: story,
        stored: stored,
      );
      if (targets.isEmpty) return;

      // Sequential on purpose: a two-week trip would otherwise open with a burst
      // of parallel requests, and rows landing one at a time let the day headers
      // fill in progressively.
      for (final target in targets) {
        final weather = await service.fetchWeather(
          latitude: target.latitude,
          longitude: target.longitude,
          date: target.date,
          entryTime: target.localNoon,
          useLocationTimezone: true,
        );
        // A miss writes nothing and is retried on the next view, which is what
        // makes this correct against the archive's few-day publication lag.
        if (weather == null) continue;

        final now = DateTime.now();
        final dayMillis = tripDayMillis(target.date);
        final row = TripDayWeather(
          // The repository derives this same id from (trip, day) and never takes
          // the caller's, so every device converges on one row. Derived here too
          // rather than left as a placeholder: an entity carrying an id that is
          // not its own reaches logs and any future validation as a lie.
          id: tripDayWeatherRowId(tripId: tripId, dayMillis: dayMillis),
          tripId: tripId,
          date: target.date,
          latitude: target.latitude,
          longitude: target.longitude,
          airTemp: weather.airTemp,
          cloudCover: weather.cloudCover,
          precipitation: weather.precipitation,
          windSpeed: weather.windSpeed,
          windDirection: weather.windDirection,
          humidity: weather.humidity,
          surfacePressure: weather.surfacePressure,
          weatherCode: weather.weatherCode,
          fetchedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        // A row the header could render nothing from is worse than no row: it
        // would suppress the retry that a later archive update would satisfy.
        if (!row.hasRenderableWeather) continue;

        await repository.upsert(row);
      }
    });
