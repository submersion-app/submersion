import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';

/// Which equipment a diver may see or apply once items are shared between
/// profiles (issue #2046). `EquipmentRepository` exposes these through
/// one-line delegates, so its callers and mocks are unchanged.
class EquipmentVisibilityQueries {
  final AppDatabase _db;

  const EquipmentVisibilityQueries(this._db);

  /// Ids per statement. The visibility filter binds the diver twice on top
  /// of the chunk, so this stays well under SQLite's variable floor.
  static const int _chunk = 450;

  /// The members of a set, in [ids] order, that applying it gives
  /// [diverId]'s dive ([isSetMemberUsableBy]). Missing rows apply as they
  /// always have.
  Future<List<String>> usableSetMemberIds(
    List<String> ids,
    String diverId,
  ) async {
    final hidden = <String>{};
    for (final chunk in seriesIdChunks(ids.toSet().toList(), size: _chunk)) {
      final shared = _db.equipment.id.isInQuery(
        _db.selectOnly(_db.equipmentShares)
          ..addColumns([_db.equipmentShares.equipmentId])
          ..where(_db.equipmentShares.diverId.equals(diverId)),
      );
      final rows =
          await (_db.selectOnly(_db.equipment)
                ..addColumns([_db.equipment.id, _db.equipment.diverId, shared])
                ..where(_db.equipment.id.isIn(chunk)))
              .get();
      for (final r in rows) {
        final usable = isSetMemberUsableBy(
          ownerId: r.read(_db.equipment.diverId),
          diverId: diverId,
          sharedWithDiver: r.read(shared) ?? false,
        );
        if (!usable) hidden.add(r.read(_db.equipment.id)!);
      }
    }
    return [
      for (final id in ids)
        if (!hidden.contains(id)) id,
    ];
  }

  /// The subset of [ids] visible to [diverId] (owned or shared).
  Future<Set<String>> visibleIdsAmong(
    Iterable<String> ids,
    String diverId,
  ) async {
    final visible = <String>{};
    for (final chunk in seriesIdChunks(ids.toSet().toList(), size: _chunk)) {
      final query = _db.select(_db.equipment)..where((t) => t.id.isIn(chunk));
      VisibilityFilter.applyToEquipment(_db, query, diverId);
      visible.addAll((await query.get()).map((r) => r.id));
    }
    return visible;
  }

  /// Each of [diveIds]' diver; a dive with no diver maps to null and a
  /// missing dive is absent.
  Future<Map<String, String?>> diversOfDives(List<String> diveIds) async {
    final diverByDive = <String, String?>{};
    for (final chunk in seriesIdChunks(diveIds)) {
      final rows =
          await (_db.selectOnly(_db.dives)
                ..addColumns([_db.dives.id, _db.dives.diverId])
                ..where(_db.dives.id.isIn(chunk)))
              .get();
      for (final r in rows) {
        diverByDive[r.read(_db.dives.id)!] = r.read(_db.dives.diverId);
      }
    }
    return diverByDive;
  }
}
