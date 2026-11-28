import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Where a dive is, for a Find species run (issue #4727): whether it still
/// exists, its site's point and where its computer logged the entry. Read
/// lean, without the profile, tanks and the rest a full dive read
/// hydrates, since a run asks again after every photo and video.
class DivePlaceRepository {
  DivePlaceRepository({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// [diveId]'s place. A point needs both its latitude and longitude, as in
  /// the full dive read.
  Future<({bool exists, GeoPoint? site, GeoPoint? entry})> placeOf(
    String diveId,
  ) async {
    final d = _db.dives;
    final s = _db.diveSites;
    final row =
        await (_db.selectOnly(d).join([
                leftOuterJoin(s, s.id.equalsExp(d.siteId)),
              ])
              ..addColumns([
                d.id,
                d.entryLatitude,
                d.entryLongitude,
                s.latitude,
                s.longitude,
              ])
              ..where(d.id.equals(diveId)))
            .getSingleOrNull();
    if (row == null) return (exists: false, site: null, entry: null);
    return (
      exists: true,
      site: _point(row.read(s.latitude), row.read(s.longitude)),
      entry: _point(row.read(d.entryLatitude), row.read(d.entryLongitude)),
    );
  }

  /// [placeOf] for many dives, a few statements in all (issue #5127): what
  /// counting a whole logbook before Find species asks. Every id is in the
  /// map; a dive that is gone has `exists: false`.
  Future<Map<String, ({bool exists, GeoPoint? site, GeoPoint? entry})>>
  placesOf(List<String> diveIds) async {
    final places = <String, ({bool exists, GeoPoint? site, GeoPoint? entry})>{
      for (final id in diveIds) id: (exists: false, site: null, entry: null),
    };
    if (diveIds.isEmpty) return places;
    final d = _db.dives;
    final s = _db.diveSites;
    for (final chunk in seriesIdChunks(diveIds)) {
      final rows =
          await (_db.selectOnly(d).join([
                  leftOuterJoin(s, s.id.equalsExp(d.siteId)),
                ])
                ..addColumns([
                  d.id,
                  d.entryLatitude,
                  d.entryLongitude,
                  s.latitude,
                  s.longitude,
                ])
                ..where(d.id.isIn(chunk)))
              .get();
      for (final row in rows) {
        places[row.read(d.id)!] = (
          exists: true,
          site: _point(row.read(s.latitude), row.read(s.longitude)),
          entry: _point(row.read(d.entryLatitude), row.read(d.entryLongitude)),
        );
      }
    }
    return places;
  }

  static GeoPoint? _point(double? latitude, double? longitude) =>
      latitude != null && longitude != null
      ? GeoPoint(latitude, longitude)
      : null;
}
