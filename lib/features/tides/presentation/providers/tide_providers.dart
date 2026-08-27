import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/data/services/tide_data_service.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/tide_record_heal.dart';

/// Provider for the [TideDataService] singleton.
final tideDataServiceProvider = Provider<TideDataService>((ref) {
  return TideDataService();
});

/// Provider for the [TideRecordRepository] singleton.
final tideRecordRepositoryProvider = Provider<TideRecordRepository>((ref) {
  return TideRecordRepository();
});

/// Provider for getting a tide record for a specific dive.
final tideRecordForDiveProvider = FutureProvider.family<TideRecord?, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(tideRecordRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  return repository.getTideRecordForDive(diveId);
});

/// Provider for a dive's tide record, lazily self-healing rows written
/// by the pre-2026 broken engine. When the stored record disagrees with
/// a fresh computation beyond the heal thresholds it is overwritten and
/// the new record returned. Converges: post-fix records match the fresh
/// computation and are never rewritten.
final healedTideRecordProvider =
    FutureProvider.family<
      TideRecord?,
      ({String diveId, GeoPoint? location, DateTime entryTime})
    >((ref, params) async {
      final repository = ref.watch(tideRecordRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      final stored = await repository.getTideRecordForDive(params.diveId);
      if (stored == null) return null;

      final location = params.location;
      if (location == null) return stored;

      final resolved = await ref.watch(
        resolvedTideDataProvider(location).future,
      );
      if (resolved == null) return stored;

      final status = await resolved.calculator.getStatusAsync(params.entryTime);
      final fresh = TideRecord.fromStatus(
        id: stored.id,
        diveId: params.diveId,
        status: status,
      );
      if (!tideRecordNeedsHeal(stored: stored, fresh: fresh)) return stored;

      return repository.createFromStatus(diveId: params.diveId, status: status);
    });

/// Provider for tide data metadata.
final tideMetadataProvider = FutureProvider<TideDataMetadata?>((ref) async {
  final service = ref.watch(tideDataServiceProvider);
  return service.getMetadata();
});

/// Provider for the NOAA station index (bundled asset).
final noaaStationIndexProvider = FutureProvider<NoaaStationIndex?>((ref) async {
  try {
    return await NoaaStationIndex.load();
  } catch (e) {
    return null; // Missing asset: resolver degrades to FES-only.
  }
});

/// Provider for the [NoaaStationService] singleton.
final noaaStationServiceProvider = Provider<NoaaStationService>((ref) {
  return NoaaStationService();
});

/// Provider for the [NoaaStationCacheRepository].
final noaaStationCacheRepositoryProvider = Provider<NoaaStationCacheRepository>(
  (ref) {
    return NoaaStationCacheRepository(
      LocalCacheDatabaseService.instance.database,
    );
  },
);

/// Provider for resolved tide data (calculator plus provenance) at a
/// location. Station tier when a cached or fetchable NOAA station is
/// within range, FES model tier otherwise, null when no data exists.
final resolvedTideDataProvider =
    FutureProvider.family<ResolvedTideData?, GeoPoint>((ref, location) async {
      final index = await ref.watch(noaaStationIndexProvider.future);
      final resolver = TideConstituentResolver(
        stationIndex: index,
        stationService: ref.watch(noaaStationServiceProvider),
        cache: ref.watch(noaaStationCacheRepositoryProvider),
        fesService: ref.watch(tideDataServiceProvider),
      );
      return resolver.resolve(location.latitude, location.longitude);
    });

/// Provider for the provenance of tide data at a location (badge UI).
final tideDataSourceProvider = FutureProvider.family<TideDataSource?, GeoPoint>(
  (ref, location) async {
    final resolved = await ref.watch(resolvedTideDataProvider(location).future);
    return resolved?.source;
  },
);

/// Provider for a [TideCalculator] at a specific location.
///
/// Usage:
/// ```dart
/// final calculatorAsync = ref.watch(tideCalculatorProvider(location));
/// ```
final tideCalculatorProvider = FutureProvider.family<TideCalculator?, GeoPoint>(
  (ref, location) async {
    final resolved = await ref.watch(resolvedTideDataProvider(location).future);
    return resolved?.calculator;
  },
);

/// Provider for checking if tide data is available at a location.
final hasTideDataProvider = FutureProvider.family<bool, GeoPoint>((
  ref,
  location,
) async {
  final resolved = await ref.watch(resolvedTideDataProvider(location).future);
  return resolved != null;
});

/// Provider for tide predictions at a location.
///
/// Returns predictions at 10-minute intervals, covering 6 hours before
/// and 24 hours after the current time. This allows charts to show
/// the previous tide extreme for context.
///
/// Uses background isolate computation to avoid blocking the UI thread.
final tidePredictionsProvider =
    FutureProvider.family<List<TidePrediction>, GeoPoint>((
      ref,
      location,
    ) async {
      final calculator = await ref.watch(
        tideCalculatorProvider(location).future,
      );
      if (calculator == null) return [];

      final now = DateTime.now();
      // Use async isolate-based computation for UI responsiveness
      return calculator.predictAsync(
        start: now.subtract(const Duration(hours: 6)),
        end: now.add(const Duration(hours: 24)),
        interval: const Duration(minutes: 10),
      );
    });

/// Provider for tide predictions over a custom time range.
///
/// Uses background isolate computation to avoid blocking the UI thread.
final tidePredictionsRangeProvider =
    FutureProvider.family<
      List<TidePrediction>,
      ({GeoPoint location, DateTime start, DateTime end})
    >((ref, params) async {
      final calculator = await ref.watch(
        tideCalculatorProvider(params.location).future,
      );
      if (calculator == null) return [];

      return calculator.predictAsync(
        start: params.start,
        end: params.end,
        interval: const Duration(minutes: 10),
      );
    });

/// Provider for tide extremes (high/low tides) at a location.
///
/// Returns extremes covering 6 hours before and 24 hours after the
/// current time. This allows charts to show the previous extreme
/// for context when displaying the current tide position.
///
/// Uses background isolate computation to avoid blocking the UI thread.
final tideExtremesProvider = FutureProvider.family<List<TideExtreme>, GeoPoint>(
  (ref, location) async {
    final calculator = await ref.watch(tideCalculatorProvider(location).future);
    if (calculator == null) return [];

    final now = DateTime.now();
    // Use async isolate-based computation for UI responsiveness
    return calculator.findExtremesAsync(
      start: now.subtract(const Duration(hours: 6)),
      end: now.add(const Duration(hours: 24)),
    );
  },
);

/// Provider for tide extremes over a custom time range.
///
/// Uses background isolate computation to avoid blocking the UI thread.
final tideExtremesRangeProvider =
    FutureProvider.family<
      List<TideExtreme>,
      ({GeoPoint location, DateTime start, DateTime end})
    >((ref, params) async {
      final calculator = await ref.watch(
        tideCalculatorProvider(params.location).future,
      );
      if (calculator == null) return [];

      return calculator.findExtremesAsync(start: params.start, end: params.end);
    });

/// Provider for current tide status at a location.
///
/// Uses background isolate computation to avoid blocking the UI thread.
/// This is one of the most expensive operations as it calculates extremes.
final currentTideStatusProvider = FutureProvider.family<TideStatus?, GeoPoint>((
  ref,
  location,
) async {
  final calculator = await ref.watch(tideCalculatorProvider(location).future);
  if (calculator == null) return null;

  // Use async isolate-based computation for UI responsiveness
  return calculator.getStatusAsync(DateTime.now());
});

/// Provider for current tide state (rising/falling/slack) at a location.
final currentTideStateProvider = FutureProvider.family<TideState?, GeoPoint>((
  ref,
  location,
) async {
  final calculator = await ref.watch(tideCalculatorProvider(location).future);
  if (calculator == null) return null;

  return calculator.getCurrentState(DateTime.now());
});

/// Provider for current tide height at a location.
final currentTideHeightProvider = FutureProvider.family<double?, GeoPoint>((
  ref,
  location,
) async {
  final calculator = await ref.watch(tideCalculatorProvider(location).future);
  if (calculator == null) return null;

  return calculator.calculateHeight(DateTime.now());
});

/// Provider for tide height at a specific time and location.
final tideHeightAtTimeProvider =
    FutureProvider.family<double?, ({GeoPoint location, DateTime time})>((
      ref,
      params,
    ) async {
      final calculator = await ref.watch(
        tideCalculatorProvider(params.location).future,
      );
      if (calculator == null) return null;

      return calculator.calculateHeight(params.time);
    });

/// Provider for tide state at a specific time and location.
final tideStateAtTimeProvider =
    FutureProvider.family<TideState?, ({GeoPoint location, DateTime time})>((
      ref,
      params,
    ) async {
      final calculator = await ref.watch(
        tideCalculatorProvider(params.location).future,
      );
      if (calculator == null) return null;

      return calculator.getCurrentState(params.time);
    });

/// Provider for tide data at a specific time (height + state).
///
/// Useful for recording tide information with dive logs.
final tideAtTimeProvider =
    FutureProvider.family<
      ({double height, TideState state})?,
      ({GeoPoint location, DateTime time})
    >((ref, params) async {
      final calculator = await ref.watch(
        tideCalculatorProvider(params.location).future,
      );
      if (calculator == null) return null;

      return calculator.getTideAtTime(params.time);
    });

/// Provider for the next upcoming tide extreme at a location.
final nextTideExtremeProvider = FutureProvider.family<TideExtreme?, GeoPoint>((
  ref,
  location,
) async {
  final status = await ref.watch(currentTideStatusProvider(location).future);
  return status?.nextExtreme;
});

/// Provider for estimated tidal range at a location.
final tidalRangeProvider = FutureProvider.family<double?, GeoPoint>((
  ref,
  location,
) async {
  final calculator = await ref.watch(tideCalculatorProvider(location).future);
  if (calculator == null) return null;

  return calculator.estimatedTidalRange;
});
