import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

/// A child table whose rows carry their own id and name an item in
/// [column]. [unique] are the other columns of a unique key that includes
/// [column]: a row the surviving item already has under them is the same
/// link twice, so the folded item's copy is dropped rather than moved.
typedef _IdChild = ({
  String table,
  String column,
  String entity,
  List<String> unique,
});

const List<_IdChild> _idChildren = [
  (
    table: 'service_schedules',
    column: 'equipment_id',
    entity: 'serviceSchedules',
    unique: [],
  ),
  (
    table: 'service_records',
    column: 'equipment_id',
    entity: 'serviceRecords',
    unique: [],
  ),
  (
    table: 'equipment_observations',
    column: 'equipment_id',
    entity: 'equipmentObservations',
    unique: [],
  ),
  (
    table: 'equipment_location_moves',
    column: 'equipment_id',
    entity: 'equipmentLocationMoves',
    unique: [],
  ),
  (
    table: 'equipment_ownership_events',
    column: 'equipment_id',
    entity: 'equipmentOwnershipEvents',
    unique: [],
  ),
  (table: 'incidents', column: 'equipment_id', entity: 'incidents', unique: []),
  (
    table: 'equipment_tags',
    column: 'equipment_id',
    entity: 'equipmentTags',
    unique: ['tag_id'],
  ),
  (
    table: 'equipment_shares',
    column: 'equipment_id',
    entity: 'equipmentShares',
    unique: ['diver_id'],
  ),
  (
    table: 'trip_equipment',
    column: 'equipment_id',
    entity: 'tripEquipment',
    unique: ['trip_id'],
  ),
  (
    table: 'equipment_attributes',
    column: 'equipment_id',
    entity: 'equipmentAttributes',
    unique: ['attr_key', 'is_custom'],
  ),
  (
    table: 'equipment_components',
    column: 'parent_equipment_id',
    entity: 'equipmentComponents',
    unique: ['component_equipment_id'],
  ),
  (
    table: 'equipment_components',
    column: 'component_equipment_id',
    entity: 'equipmentComponents',
    unique: ['parent_equipment_id'],
  ),
  // Parts fitted to the item, as their own gear.
  (
    table: 'equipment',
    column: 'parent_equipment_id',
    entity: 'equipment',
    unique: [],
  ),
];

/// A junction keyed by ([left], equipment_id), synced under the record id
/// `left|equipment_id`, so a moved row is a new record and the old one a
/// deletion.
typedef _JunctionChild = ({String table, String left, String entity});

const List<_JunctionChild> _junctionChildren = [
  (table: 'equipment_set_items', left: 'set_id', entity: 'equipmentSetItems'),
  (table: 'dive_plan_equipment', left: 'plan_id', entity: 'divePlanEquipment'),
  (table: 'dive_equipment', left: 'dive_id', entity: 'diveEquipment'),
];

/// Junctions whose `via_equipment_id` names the assembly a part came
/// through. SET NULL on delete, so without the move a part would fall loose
/// here while a peer kept pointing at the deleted item.
const List<_JunctionChild> _viaChildren = [
  (table: 'dive_plan_equipment', left: 'plan_id', entity: 'divePlanEquipment'),
  (table: 'dive_equipment', left: 'dive_id', entity: 'diveEquipment'),
];

/// Folds Equipment item `fromId` into `intoId` and deletes it (issue #3676):
/// merging two dive computers leaves the duplicate's item with no device,
/// and a computer's item is its one entry, so the diver would otherwise see
/// the same computer twice.
///
/// Everything the diver kept on the item moves: service records and
/// schedules, check-ins, location history, ownership events, incidents,
/// parts, tags, shares, trip packing, attributes, equipment sets, dive plan
/// gear, documents and media. A link the surviving item already has (the
/// same tag, share, trip or attribute) is dropped, tombstoned. Fields the
/// surviving item leaves blank take the folded item's values, and both sets
/// of notes are kept. What is left (derived findings, device-local markers)
/// goes with the item through [EquipmentRepository.deleteEquipment], which
/// tombstones it. Each moved row is staged, so peers move it too.
class EquipmentItemFold {
  EquipmentItemFold({
    SyncRepository? syncRepository,
    EquipmentRepository? equipmentRepository,
    MediaRepository? mediaRepository,
  }) : _syncRepository = syncRepository ?? SyncRepository(),
       _equipmentRepository = equipmentRepository,
       _mediaRepository = mediaRepository;

  static final _log = LoggerService.forClass(EquipmentItemFold);

  final SyncRepository _syncRepository;
  final EquipmentRepository? _equipmentRepository;
  final MediaRepository? _mediaRepository;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Folds `fromId` into `intoId`. Returns false, changing nothing, when
  /// either item is missing, they belong to different divers, or a dive
  /// computer or transmitter still stands for `fromId`.
  Future<bool> fold({required String fromId, required String intoId}) async {
    if (fromId == intoId) return false;
    final from = await _item(fromId);
    final into = await _item(intoId);
    if (from == null || into == null) return false;
    if (from.diverId != into.diverId) return false;
    if (await _hasDevice(fromId)) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _fillSurvivor(into, from, now);
      for (final child in _idChildren) {
        await _moveIdChild(child, fromId, intoId, now);
      }
      final dives = <String>{};
      for (final child in _viaChildren) {
        await _moveVia(child, fromId, intoId, now, touched: dives);
      }
      for (final child in _junctionChildren) {
        await _moveJunction(child, fromId, intoId, now, touched: dives);
      }
      await _restampDives(dives, now);
      await DocumentRepository().reassignOwner(DocumentOwnerKind.equipment, [
        fromId,
      ], intoId);
    });
    final mediaIds = [
      for (final r in await (_db.select(
        _db.media,
      )..where((t) => t.equipmentId.equals(fromId))).get())
        r.id,
    ];
    await (_mediaRepository ?? MediaRepository()).linkMediaToEquipment(
      mediaIds,
      intoId,
    );
    await (_equipmentRepository ?? EquipmentRepository()).deleteEquipment(
      fromId,
    );
    // Its service history now counts toward the surviving item's findings.
    scheduleConditionFindingsRefresh({intoId});
    SyncEventBus.notifyLocalChange();
    _log.info('Folded equipment $fromId into $intoId');
    return true;
  }

  Future<EquipmentData?> _item(String id) => (_db.select(
    _db.equipment,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> _hasDevice(String id) async {
    final computer =
        await (_db.select(_db.diveComputers)
              ..where((t) => t.equipmentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (computer != null) return true;
    final key =
        await (_db.select(_db.transmitters)
              ..where((t) => t.transmitterEquipmentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return key != null;
  }

  /// The surviving item takes what it leaves blank, and both sets of notes.
  Future<void> _fillSurvivor(
    EquipmentData into,
    EquipmentData from,
    int now,
  ) async {
    bool blank(String? v) => v == null || v.trim().isEmpty;
    final takePrice = into.purchasePrice == null && from.purchasePrice != null;
    final notes = _mergedNotes(into.notes, from.notes);
    final fill = EquipmentCompanion(
      brand: blank(into.brand) && !blank(from.brand)
          ? Value(from.brand)
          : const Value.absent(),
      model: blank(into.model) && !blank(from.model)
          ? Value(from.model)
          : const Value.absent(),
      serialNumber: blank(into.serialNumber) && !blank(from.serialNumber)
          ? Value(from.serialNumber)
          : const Value.absent(),
      purchaseDate: into.purchaseDate == null && from.purchaseDate != null
          ? Value(from.purchaseDate)
          : const Value.absent(),
      // Price and currency travel together: a price is meaningless in
      // another item's currency.
      purchasePrice: takePrice
          ? Value(from.purchasePrice)
          : const Value.absent(),
      purchaseCurrency: takePrice
          ? Value(from.purchaseCurrency)
          : const Value.absent(),
      notes: notes != into.notes ? Value(notes) : const Value.absent(),
    );
    if (fill == const EquipmentCompanion()) return;
    await (_db.update(_db.equipment)..where((t) => t.id.equals(into.id))).write(
      fill.copyWith(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipment',
      recordId: into.id,
      localUpdatedAt: now,
    );
  }

  static String _mergedNotes(String into, String from) {
    final kept = into.trim();
    final added = from.trim();
    if (added.isEmpty || added == kept) return into;
    if (kept.isEmpty) return from;
    return '$into\n\n$from';
  }

  Future<void> _moveIdChild(
    _IdChild child,
    String fromId,
    String intoId,
    int now,
  ) async {
    final cols = await _columnsOf(child.table);
    if (!cols.contains(child.column)) return;
    final rows = await _db
        .customSelect(
          'SELECT id${[for (final u in child.unique) ', $u'].join()} '
          'FROM ${child.table} WHERE ${child.column} = ?',
          variables: [Variable<String>(fromId)],
        )
        .get();
    final stamp = cols.contains('updated_at') ? ', updated_at = ?' : '';
    for (final row in rows) {
      final id = row.read<String>('id');
      // The survivor fitted inside the folded item cannot become its own
      // part: it is freed, staged, rather than left to SET NULL, which no
      // peer would hear of.
      if (child.table == 'equipment' && id == intoId) {
        await _db.customStatement(
          'UPDATE equipment SET parent_equipment_id = NULL, updated_at = ? '
          'WHERE id = ?',
          [now, id],
        );
        await _syncRepository.markRecordPending(
          entityType: 'equipment',
          recordId: id,
          localUpdatedAt: now,
        );
        continue;
      }
      if (await _survivorHas(child, row, intoId)) {
        await _db.customStatement('DELETE FROM ${child.table} WHERE id = ?', [
          id,
        ]);
        await _syncRepository.logDeletion(
          entityType: child.entity,
          recordId: id,
        );
        continue;
      }
      await _db.customStatement(
        'UPDATE ${child.table} SET ${child.column} = ?$stamp WHERE id = ?',
        [intoId, if (stamp.isNotEmpty) now, id],
      );
      await _syncRepository.markRecordPending(
        entityType: child.entity,
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  /// Whether the surviving item already has [row]'s link: the same values
  /// under [_IdChild.unique], or, for an assembly row, the surviving item
  /// itself at the other end, which would make it a part of itself.
  Future<bool> _survivorHas(_IdChild child, QueryRow row, String intoId) async {
    if (child.unique.isEmpty) return false;
    final values = [for (final u in child.unique) row.data[u]];
    if (child.table == 'equipment_components' && values.single == intoId) {
      return true;
    }
    final where = [
      '${child.column} = ?',
      for (final u in child.unique) '$u IS ?',
    ].join(' AND ');
    final hit = await _db
        .customSelect(
          'SELECT 1 FROM ${child.table} WHERE $where LIMIT 1',
          variables: [
            Variable<String>(intoId),
            for (final v in values) _variable(v),
          ],
        )
        .getSingleOrNull();
    return hit != null;
  }

  static Variable<Object> _variable(Object? v) => switch (v) {
    final int i => Variable<int>(i),
    final double d => Variable<double>(d),
    final bool b => Variable<bool>(b),
    final String s => Variable<String>(s),
    _ => const Variable(null),
  };

  /// Parts attached through the item now hang off the survivor.
  Future<void> _moveVia(
    _JunctionChild child,
    String fromId,
    String intoId,
    int now, {
    required Set<String> touched,
  }) async {
    if (!(await _columnsOf(child.table)).contains('via_equipment_id')) return;
    final rows = await _db
        .customSelect(
          'SELECT ${child.left} AS l, equipment_id FROM ${child.table} '
          'WHERE via_equipment_id = ?',
          variables: [Variable<String>(fromId)],
        )
        .get();
    for (final r in rows) {
      final left = r.read<String>('l');
      final equipmentId = r.read<String>('equipment_id');
      await _db.customStatement(
        'UPDATE ${child.table} SET via_equipment_id = ?, updated_at = ? '
        'WHERE ${child.left} = ? AND equipment_id = ?',
        [intoId, now, left, equipmentId],
      );
      await _syncRepository.markRecordPending(
        entityType: child.entity,
        recordId: '$left|$equipmentId',
        localUpdatedAt: now,
      );
      if (child.table == 'dive_equipment') touched.add(left);
    }
  }

  /// A dive's gear rides the dive (as the computer merge's own repoint
  /// does), so each dive whose gear changed is staged too.
  Future<void> _restampDives(Set<String> diveIds, int now) async {
    for (final id in diveIds) {
      await _db.customStatement(
        'UPDATE dives SET updated_at = ? WHERE id = ?',
        [now, id],
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _moveJunction(
    _JunctionChild child,
    String fromId,
    String intoId,
    int now, {
    required Set<String> touched,
  }) async {
    final cols = (await _columnsOf(child.table)).toList();
    if (!cols.contains(child.left) || !cols.contains('equipment_id')) return;
    final rows = await _db
        .customSelect(
          'SELECT ${child.left} AS l FROM ${child.table} '
          'WHERE equipment_id = ?',
          variables: [Variable<String>(fromId)],
        )
        .get();
    final copied = [
      for (final c in cols)
        switch (c) {
          'equipment_id' => '?',
          'updated_at' => '?',
          'hlc' => 'NULL',
          _ => c,
        },
    ];
    for (final row in rows) {
      final left = row.read<String>('l');
      // A row the survivor already has keeps the survivor's; otherwise the
      // folded item's row is copied under the survivor's id.
      await _db.customStatement(
        'INSERT OR IGNORE INTO ${child.table} (${cols.join(', ')}) '
        'SELECT ${copied.join(', ')} FROM ${child.table} '
        'WHERE ${child.left} = ? AND equipment_id = ?',
        [
          for (final c in cols)
            if (c == 'equipment_id') intoId else if (c == 'updated_at') now,
          left,
          fromId,
        ],
      );
      final inserted =
          (await _db.customSelect('SELECT changes() AS n').getSingle())
              .read<int>('n') >
          0;
      await _db.customStatement(
        'DELETE FROM ${child.table} WHERE ${child.left} = ? '
        'AND equipment_id = ?',
        [left, fromId],
      );
      await _syncRepository.logDeletion(
        entityType: child.entity,
        recordId: '$left|$fromId',
      );
      if (inserted) {
        await _syncRepository.markRecordPending(
          entityType: child.entity,
          recordId: '$left|$intoId',
          localUpdatedAt: now,
        );
      }
      if (child.table == 'dive_equipment') touched.add(left);
    }
  }

  Future<Set<String>> _columnsOf(String table) async => {
    for (final c in await _db.customSelect("PRAGMA table_info('$table')").get())
      c.read<String>('name'),
  };
}
