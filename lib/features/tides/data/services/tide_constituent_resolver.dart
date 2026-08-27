import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';
import 'package:submersion/features/tides/data/services/tide_data_service.dart';

enum TideDataSourceKind { noaaStation, fesModel }

/// Provenance of a resolved tide calculator, shown in the tide UI.
class TideDataSource {
  final TideDataSourceKind kind;
  final String? stationId;
  final String? stationName;
  final double? distanceKm;

  /// True when station heights reference MLLW (datum offset applied),
  /// false when they reference mean sea level.
  final bool mllwDatum;

  const TideDataSource.fesModel()
    : kind = TideDataSourceKind.fesModel,
      stationId = null,
      stationName = null,
      distanceKm = null,
      mllwDatum = false;

  const TideDataSource.noaaStation({
    required this.stationId,
    required this.stationName,
    required this.distanceKm,
    required this.mllwDatum,
  }) : kind = TideDataSourceKind.noaaStation;
}

/// A tide calculator plus where its constituents came from.
class ResolvedTideData {
  final TideCalculator calculator;
  final TideDataSource source;

  const ResolvedTideData({required this.calculator, required this.source});
}

/// Resolves harmonic constituents for a coordinate in priority order:
/// cached NOAA station within [NoaaStationIndex] snap range, then a
/// one-time NOAA fetch, then FES2022 grid interpolation, then null.
/// All failures are silent: the caller always gets the best available
/// tier or null, never an error.
class TideConstituentResolver {
  static const staleAfter = Duration(days: 365);
  static const retryUnavailableAfter = Duration(days: 30);

  final NoaaStationIndex? _stationIndex;
  final NoaaStationService _stationService;
  final NoaaStationCacheRepository _cache;
  final TideDataService _fesService;
  final DateTime Function() _now;

  TideConstituentResolver({
    required NoaaStationIndex? stationIndex,
    required NoaaStationService stationService,
    required NoaaStationCacheRepository cache,
    required TideDataService fesService,
    DateTime Function()? now,
  }) : _stationIndex = stationIndex,
       _stationService = stationService,
       _cache = cache,
       _fesService = fesService,
       _now = now ?? DateTime.now;

  Future<ResolvedTideData?> resolve(double latitude, double longitude) async {
    final station = await _resolveStation(latitude, longitude);
    if (station != null) return station;

    final fesCalculator = await _fesService.getCalculatorForLocation(
      latitude,
      longitude,
    );
    if (fesCalculator != null) {
      return ResolvedTideData(
        calculator: fesCalculator,
        source: const TideDataSource.fesModel(),
      );
    }
    return null;
  }

  Future<ResolvedTideData?> _resolveStation(
    double latitude,
    double longitude,
  ) async {
    final nearby = _stationIndex?.nearest(latitude, longitude);
    if (nearby == null) return null;

    final cached = await _cache.read(nearby.id);
    final age = cached == null
        ? null
        : _now().toUtc().difference(cached.fetchedAt);

    final useCached =
        cached != null &&
        ((cached.status == NoaaStationCacheStatus.ok && age! < staleAfter) ||
            (cached.status == NoaaStationCacheStatus.unavailable &&
                age! < retryUnavailableAfter));

    if (!useCached) {
      final result = await _stationService.fetchStation(nearby.id);
      switch (result.status) {
        case NoaaFetchStatus.ok:
          final data = result.data!;
          await _cache.write(
            stationId: nearby.id,
            name: nearby.name,
            latitude: nearby.latitude,
            longitude: nearby.longitude,
            constituents: data.constituents,
            datumOffsetMllw: data.datumOffsetMllw,
            status: NoaaStationCacheStatus.ok,
          );
          return _fromStation(nearby, data.constituents, data.datumOffsetMllw);
        case NoaaFetchStatus.unavailable:
          await _cache.write(
            stationId: nearby.id,
            name: nearby.name,
            latitude: nearby.latitude,
            longitude: nearby.longitude,
            constituents: const {},
            status: NoaaStationCacheStatus.unavailable,
          );
          return null;
        case NoaaFetchStatus.failed:
          // Transient: keep whatever we have, even stale.
          break;
      }
    }

    if (cached != null && cached.status == NoaaStationCacheStatus.ok) {
      return _fromStation(nearby, cached.constituents, cached.datumOffsetMllw);
    }
    return null;
  }

  ResolvedTideData _fromStation(
    NearbyStation nearby,
    Map<String, TideConstituent> constituents,
    double? datumOffsetMllw,
  ) {
    return ResolvedTideData(
      calculator: TideCalculator(
        constituents: constituents,
        z0: datumOffsetMllw ?? 0.0,
      ),
      source: TideDataSource.noaaStation(
        stationId: nearby.id,
        stationName: nearby.name,
        distanceKm: nearby.distanceKm,
        mllwDatum: datumOffsetMllw != null,
      ),
    );
  }
}
