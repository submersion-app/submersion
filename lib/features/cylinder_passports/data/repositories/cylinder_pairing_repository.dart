import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart'
    as rules;

/// A pairing would put a cylinder in two twin sets on one day. [clashes] are
/// the stored pairings it overlaps, so the screen can name them.
class PairingClash implements Exception {
  const PairingClash(this.clashes);

  final List<CylinderPairing> clashes;

  @override
  String toString() => 'PairingClash(${clashes.map((p) => p.id).join(', ')})';
}

/// Twin set pairings of two cylinders (issue #4242). Every read goes through
/// [resolvePairings], so two pairings stored offline on two devices still
/// show one partner. Registered for sync like the fill history: every write
/// marks the row pending, every delete logs a tombstone.
class CylinderPairingRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String entity = 'cylinderPairings';

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.cylinderPairings));

  /// Every pairing, resolved, newest first. A diver has tens of pairings at
  /// most, so every rule reads them all: resolving overlaps can chain across
  /// cylinders, and the whole set is the only exact view.
  Future<List<CylinderPairing>> getAll() async => rules.resolvePairings(
    (await _db.select(_db.cylinderPairings).get()).map(_fromRow),
  );

  /// The pairings [equipmentId] has been in, newest first.
  Future<List<CylinderPairing>> getForCylinder(String equipmentId) async => [
    for (final p in await getAll())
      if (p.involves(equipmentId)) p,
  ];

  /// The pairing [equipmentId] was in on the calendar day of [day].
  Future<CylinderPairing?> pairingOn(String equipmentId, DateTime day) async =>
      rules.pairingOn(await getAll(), equipmentId, day);

  /// Pairs [cylinderAId] with [cylinderBId] from the calendar day of
  /// [pairedOn]. A pairing of either cylinder that overlaps throws
  /// [PairingClash]; with [replace], an open one that started before
  /// [pairedOn] is ended on that day instead, and any other overlap still
  /// throws.
  Future<CylinderPairing> createPairing({
    required String cylinderAId,
    required String cylinderBId,
    required DateTime pairedOn,
    bool replace = false,
  }) async {
    if (cylinderAId == cylinderBId) {
      throw ArgumentError.value(cylinderBId, 'cylinderBId', 'same cylinder');
    }
    final start = calendarDay(pairedOn);
    final now = DateTime.now().millisecondsSinceEpoch;
    final pairing = await _db.transaction(() async {
      final clashes = rules.clashesWith(
        await getAll(),
        cylinderAId: cylinderAId,
        cylinderBId: cylinderBId,
        pairedOn: start,
      );
      final replaceable = [
        for (final c in clashes)
          if (c.isOpen && c.pairedOn.isBefore(start)) c,
      ];
      if (clashes.isNotEmpty &&
          (!replace || replaceable.length != clashes.length)) {
        throw PairingClash(clashes);
      }
      for (final c in replaceable) {
        await _writeEnd(c.id, start, now);
      }
      final created = CylinderPairing(
        id: _uuid.v4(),
        cylinderAId: cylinderAId,
        cylinderBId: cylinderBId,
        pairedOn: start,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
      await _db
          .into(_db.cylinderPairings)
          .insert(
            CylinderPairingsCompanion.insert(
              id: created.id,
              cylinderAId: cylinderAId,
              cylinderBId: cylinderBId,
              pairedOn: start.millisecondsSinceEpoch,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _markPending(created.id, now);
      return created;
    });
    SyncEventBus.notifyLocalChange();
    return pairing;
  }

  /// Ends pairing [id] on the calendar day of [unpairedOn]: the first day the
  /// cylinders are apart. An end on or before its start throws
  /// [ArgumentError]; one that overlaps a later pairing of either cylinder
  /// throws [PairingClash].
  Future<void> endPairing(String id, DateTime unpairedOn) async {
    final end = calendarDay(unpairedOn);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.cylinderPairings,
      )..where((t) => t.id.equals(id))).getSingle();
      final pairing = _fromRow(row);
      if (!end.isAfter(pairing.pairedOn)) {
        throw ArgumentError.value(unpairedOn, 'unpairedOn', 'not after start');
      }
      final clashes = rules.clashesWith(
        await getAll(),
        cylinderAId: pairing.cylinderAId,
        cylinderBId: pairing.cylinderBId,
        pairedOn: pairing.pairedOn,
        unpairedOn: end,
        ignoreId: id,
      );
      if (clashes.isNotEmpty) throw PairingClash(clashes);
      await _writeEnd(id, end, now);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes pairing [id], for one made by mistake. Fills and dives are not
  /// touched.
  Future<void> deletePairing(String id) async {
    await (_db.delete(
      _db.cylinderPairings,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _writeEnd(String id, DateTime end, int now) async {
    await (_db.update(
      _db.cylinderPairings,
    )..where((t) => t.id.equals(id))).write(
      CylinderPairingsCompanion(
        unpairedOn: Value(end.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _markPending(id, now);
  }

  Future<void> _markPending(String id, int now) => _syncRepository
      .markRecordPending(entityType: entity, recordId: id, localUpdatedAt: now);

  CylinderPairing _fromRow(CylinderPairingRow r) => CylinderPairing(
    id: r.id,
    cylinderAId: r.cylinderAId,
    cylinderBId: r.cylinderBId,
    pairedOn: DateTime.fromMillisecondsSinceEpoch(r.pairedOn, isUtc: true),
    unpairedOn: r.unpairedOn == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.unpairedOn!, isUtc: true),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
