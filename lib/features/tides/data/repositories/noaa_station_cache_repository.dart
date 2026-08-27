import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';

enum NoaaStationCacheStatus { ok, unavailable }

/// One cached NOAA harmonic station.
class CachedNoaaStation {
  final String stationId;
  final String name;
  final double latitude;
  final double longitude;
  final Map<String, TideConstituent> constituents;
  final double? datumOffsetMllw;
  final NoaaStationCacheStatus status;
  final DateTime fetchedAt;

  const CachedNoaaStation({
    required this.stationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.constituents,
    required this.datumOffsetMllw,
    required this.status,
    required this.fetchedAt,
  });
}

/// Reads and writes the NOAA station constituent cache in the local
/// cache database. TTL policy lives in the resolver, not here.
class NoaaStationCacheRepository {
  final LocalCacheDatabase _db;
  final DateTime Function() _now;

  NoaaStationCacheRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<CachedNoaaStation?> read(String stationId) async {
    final row = await (_db.select(
      _db.noaaTideStations,
    )..where((t) => t.stationId.equals(stationId))).getSingleOrNull();
    if (row == null) return null;

    // A malformed row (corruption, partial write) must behave like a
    // cache miss so the resolver silently refetches and overwrites it,
    // rather than erroring the tide UI.
    final constituents = <String, TideConstituent>{};
    try {
      (json.decode(row.constituentsJson) as Map<String, dynamic>).forEach((
        name,
        c,
      ) {
        constituents[name] = TideConstituent(
          name: name,
          amplitude: ((c as Map<String, dynamic>)['amplitude'] as num)
              .toDouble(),
          phase: (c['phase'] as num).toDouble(),
        );
      });
    } catch (e) {
      developer.log(
        'Corrupt cached constituents for station ${row.stationId}: $e',
        name: 'NoaaStationCacheRepository',
      );
      return null;
    }

    return CachedNoaaStation(
      stationId: row.stationId,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
      constituents: constituents,
      datumOffsetMllw: row.datumOffsetMllw,
      status: row.status == NoaaStationCacheStatus.ok.name
          ? NoaaStationCacheStatus.ok
          : NoaaStationCacheStatus.unavailable,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        row.fetchedAt,
        isUtc: true,
      ),
    );
  }

  Future<void> write({
    required String stationId,
    required String name,
    required double latitude,
    required double longitude,
    required Map<String, TideConstituent> constituents,
    double? datumOffsetMllw,
    required NoaaStationCacheStatus status,
  }) async {
    final constituentsJson = json.encode({
      for (final e in constituents.entries)
        e.key: {'amplitude': e.value.amplitude, 'phase': e.value.phase},
    });
    await _db
        .into(_db.noaaTideStations)
        .insertOnConflictUpdate(
          NoaaTideStationsCompanion.insert(
            stationId: stationId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            constituentsJson: Value(constituentsJson),
            datumOffsetMllw: Value(datumOffsetMllw),
            status: status.name,
            fetchedAt: _now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }
}
