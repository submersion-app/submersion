import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Fill history of physical cylinders (spec section 10.2), keyed by passport
/// id. Registered for sync like the transmitter registry: every write marks
/// the row pending, every delete logs a tombstone.
class CylinderFillRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String entity = 'cylinderFills';

  Stream<void> watchFillsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.cylinderFills));

  Future<CylinderFill> create(CylinderFill fill) async {
    final withId = fill.id.isEmpty ? fill.copyWith(id: _uuid.v4()) : fill;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.cylinderFills)
        .insert(_companion(withId, now: now, createdAt: now));
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: withId.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return withId.copyWith(
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> update(CylinderFill fill) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.id.equals(fill.id))).write(_companion(fill, now: now));
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: fill.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.cylinderFills)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Future<CylinderFill?> getById(String id) async {
    final row = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Every fill of one cylinder, newest first: those linked to its gear row,
  /// and those under its passport id that no other live cylinder owns
  /// (unlinked, or linked to a row since deleted). Reading both keeps a fill
  /// on the page when the id changes under it; the ownership test keeps
  /// another cylinder's history off it when two rows share an id.
  Future<List<CylinderFill>> getForCylinder({
    required String? passportId,
    required String equipmentId,
  }) async {
    final rows =
        await (_db.select(_db.cylinderFills)
              ..where(
                (t) => passportId == null
                    ? t.equipmentId.equals(equipmentId)
                    : t.passportId.equals(passportId) |
                          t.equipmentId.equals(equipmentId),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.filledAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final owned = await _ownedElsewhere(rows, equipmentId);
    return rows.where((r) => !owned.contains(r.id)).map(_fromRow).toList();
  }

  /// Ids of [rows] linked to a live cylinder other than [equipmentId].
  Future<Set<String>> _ownedElsewhere(
    List<CylinderFillRow> rows,
    String equipmentId,
  ) async {
    final others = {
      for (final r in rows)
        if (r.equipmentId case final id? when id != equipmentId) id,
    };
    if (others.isEmpty) return const {};
    final live =
        await (_db.selectOnly(_db.equipment)
              ..addColumns([_db.equipment.id])
              ..where(_db.equipment.id.isIn(others)))
            .map((r) => r.read(_db.equipment.id)!)
            .get();
    final liveSet = live.toSet();
    return {
      for (final r in rows)
        if (r.equipmentId case final id? when liveSet.contains(id)) r.id,
    };
  }

  /// Station names from logged fills, most recently used first, each once,
  /// for the fill sheet's suggestions.
  Future<List<String>> recentStationNames({int limit = 8}) =>
      _recentDistinct(_db.cylinderFills.stationName, limit);

  /// Analyzers from logged fills, most recently used first, each once; the
  /// first is what the fill sheet remembers.
  Future<List<String>> recentAnalyzers({int limit = 8}) =>
      _recentDistinct(_db.cylinderFills.analyzer, limit);

  Future<List<String>> _recentDistinct(
    GeneratedColumn<String> column,
    int limit,
  ) async {
    final rows =
        await (_db.selectOnly(_db.cylinderFills)
              ..addColumns([column])
              ..where(column.isNotNull())
              ..orderBy([OrderingTerm.desc(_db.cylinderFills.filledAt)]))
            .get();
    final seen = <String>[];
    for (final row in rows) {
      final value = row.read(column)?.trim();
      if (value == null || value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      if (seen.length == limit) break;
    }
    return seen;
  }

  /// Moves the fills of [equipmentId] logged under passport id [from] to
  /// [to], staging each for sync. Fills under [from] with no gear link, or
  /// another cylinder's link, are left alone. Returns how many moved.
  Future<int> rekeyPassport({
    required String from,
    required String to,
    required String equipmentId,
  }) async {
    if (from == to) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows =
        await (_db.select(_db.cylinderFills)..where(
              (t) =>
                  t.passportId.equals(from) & t.equipmentId.equals(equipmentId),
            ))
            .get();
    if (rows.isEmpty) return 0;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.id.isIn(rows.map((r) => r.id).toList()))).write(
      CylinderFillsCompanion(passportId: Value(to), updatedAt: Value(now)),
    );
    for (final row in rows) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
    return rows.length;
  }

  /// Points the fills of [passportId] that no other live cylinder owns at
  /// [equipmentId] and stages each for sync. Returns how many rows changed.
  Future<int> relinkToEquipment({
    required String passportId,
    required String equipmentId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.passportId.equals(passportId))).get();
    // Adopt only fills no other live cylinder owns: unlinked ones, and ones
    // whose row was deleted. A second cylinder that shares the id keeps its
    // own history.
    final owned = await _ownedElsewhere(rows, equipmentId);
    final stale = rows
        .where((r) => r.equipmentId != equipmentId && !owned.contains(r.id))
        .toList();
    if (stale.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(
        _db.cylinderFills,
      )..where((t) => t.id.isIn(stale.map((r) => r.id).toList()))).write(
        CylinderFillsCompanion(
          equipmentId: Value(equipmentId),
          updatedAt: Value(now),
        ),
      );
    });
    for (final row in stale) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
    return stale.length;
  }

  /// Clears the gear link on the fills of a cylinder being deleted and
  /// stages each row, so peers receive the cleared link rather than relying
  /// on SQLite's set-null. Mirrors TransmitterRepository.
  Future<void> unlinkFromDeletedEquipment(String equipmentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    if (rows.isEmpty) return;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.equipmentId.equals(equipmentId))).write(
      CylinderFillsCompanion(
        equipmentId: const Value(null),
        updatedAt: Value(now),
      ),
    );
    for (final row in rows) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
  }

  CylinderFill _fromRow(CylinderFillRow r) => CylinderFill(
    id: r.id,
    diverId: r.diverId,
    passportId: r.passportId,
    equipmentId: r.equipmentId,
    filledAt: DateTime.fromMillisecondsSinceEpoch(r.filledAt),
    o2Percent: r.o2Percent,
    hePercent: r.hePercent,
    pressureBar: r.pressureBar,
    temperatureC: r.temperatureC,
    analyzer: r.analyzer,
    stationName: r.stationName,
    stationKey: r.stationKey,
    signedRecord: r.signedRecord,
    source: FillSource.fromName(r.source),
    notes: r.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );

  CylinderFillsCompanion _companion(
    CylinderFill f, {
    required int now,
    int? createdAt,
  }) => CylinderFillsCompanion(
    id: Value(f.id),
    diverId: Value(f.diverId),
    passportId: Value(f.passportId),
    equipmentId: Value(f.equipmentId),
    filledAt: Value(f.filledAt.millisecondsSinceEpoch),
    o2Percent: Value(f.o2Percent),
    hePercent: Value(f.hePercent),
    pressureBar: Value(f.pressureBar),
    temperatureC: Value(f.temperatureC),
    analyzer: Value(f.analyzer),
    stationName: Value(f.stationName),
    stationKey: Value(f.stationKey),
    signedRecord: Value(f.signedRecord),
    source: Value(f.source.name),
    notes: Value(f.notes),
    createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
    updatedAt: Value(now),
  );
}
