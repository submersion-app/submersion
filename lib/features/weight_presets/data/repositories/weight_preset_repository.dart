import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide DiveWeight;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// CRUD for the diver's reusable weighting rigs (issue #1609). Mirrors
/// [TankPresetRepository] / EquipmentSetRepository: HLC-stamped writes, a
/// change stream for list providers, and per-row sync bookkeeping after the
/// transaction commits.
class WeightPresetRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(WeightPresetRepository);

  Stream<void> watchWeightPresetsChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.weightPresets),
      TableUpdateQuery.onTable(_db.weightPresetEntries),
    ]),
  );

  /// The diver's presets, ordered, each with its entries. Returns nothing for
  /// a null diver (presets are always diver-scoped).
  Future<List<WeightPreset>> getPresets({String? diverId}) async {
    if (diverId == null) return const [];
    try {
      final presetRows =
          await (_db.select(_db.weightPresets)
                ..where((t) => t.diverId.equals(diverId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.displayName),
                ]))
              .get();
      if (presetRows.isEmpty) return const [];

      final entryRows =
          await (_db.select(_db.weightPresetEntries)
                ..where((t) => t.presetId.isIn(presetRows.map((p) => p.id)))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      final byPreset = <String, List<WeightPresetEntry>>{};
      for (final e in entryRows) {
        (byPreset[e.presetId] ??= []).add(_mapEntry(e));
      }

      return presetRows
          .map(
            (p) => WeightPreset(
              id: p.id,
              diverId: p.diverId,
              displayName: p.displayName,
              notes: p.notes,
              sortOrder: p.sortOrder,
              createdAt: DateTime.fromMillisecondsSinceEpoch(p.createdAt),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(p.updatedAt),
              entries: byPreset[p.id] ?? const [],
            ),
          )
          .toList();
    } catch (e, s) {
      _log.error('Failed to load weight presets', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Save a set of [DiveWeight] rows as a new named preset for [diverId].
  Future<WeightPreset> createFromWeights({
    required String diverId,
    required String displayName,
    required List<DiveWeight> weights,
    String notes = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortOrder = (await _maxSortOrder(diverId)) + 1;
    final entryIds = <String>[];

    await _db.transaction(() async {
      await _db
          .into(_db.weightPresets)
          .insert(
            WeightPresetsCompanion(
              id: Value(id),
              diverId: Value(diverId),
              displayName: Value(displayName.trim()),
              notes: Value(notes.trim()),
              sortOrder: Value(sortOrder),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      for (var i = 0; i < weights.length; i++) {
        final entryId = _uuid.v4();
        entryIds.add(entryId);
        await _db
            .into(_db.weightPresetEntries)
            .insert(
              WeightPresetEntriesCompanion(
                id: Value(entryId),
                presetId: Value(id),
                weightType: Value(weights[i].weightType.name),
                amountKg: Value(weights[i].amountKg),
                notes: Value(weights[i].notes),
                sortOrder: Value(i),
                createdAt: Value(now),
              ),
            );
      }
    });

    await _syncRepository.markRecordPending(
      entityType: 'weightPresets',
      recordId: id,
      localUpdatedAt: now,
    );
    for (final entryId in entryIds) {
      await _syncRepository.markRecordPending(
        entityType: 'weightPresetEntries',
        recordId: entryId,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();

    return (await getPresets(diverId: diverId)).firstWhere((p) => p.id == id);
  }

  /// Rename a preset / edit its notes. The entry list is left untouched.
  Future<void> renamePreset({
    required String id,
    required String displayName,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.weightPresets)..where((t) => t.id.equals(id))).write(
      WeightPresetsCompanion(
        displayName: Value(displayName.trim()),
        notes: notes == null ? const Value.absent() : Value(notes.trim()),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'weightPresets',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Delete a preset and its entries.
  ///
  /// Entries are a first-class synced child cascade-deleted by SQLite, but
  /// cascades emit no deletion-log entries, so each entry must be tombstoned
  /// explicitly or a peer will resurrect it. Done in one transaction with the
  /// preset deletion (mirrors EquipmentSetRepository.deleteSet): a failure
  /// part-way through would otherwise drop the preset locally while leaving
  /// some of its tombstones unwritten.
  Future<void> deletePreset(String id) async {
    await _db.transaction(() async {
      final entryRows = await (_db.select(
        _db.weightPresetEntries,
      )..where((t) => t.presetId.equals(id))).get();

      await (_db.delete(_db.weightPresets)..where((t) => t.id.equals(id))).go();

      await _syncRepository.logDeletion(
        entityType: 'weightPresets',
        recordId: id,
      );
      for (final e in entryRows) {
        await _syncRepository.logDeletion(
          entityType: 'weightPresetEntries',
          recordId: e.id,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<int> _maxSortOrder(String diverId) async {
    final row = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS m FROM weight_presets WHERE diver_id = ?',
          variables: [Variable.withString(diverId)],
        )
        .getSingleOrNull();
    return (row?.data['m'] as int?) ?? 0;
  }

  WeightPresetEntry _mapEntry(WeightPresetEntryRow row) => WeightPresetEntry(
    id: row.id,
    presetId: row.presetId,
    weightType: WeightType.values.firstWhere(
      (w) => w.name == row.weightType,
      orElse: () => WeightType.belt,
    ),
    amountKg: row.amountKg,
    notes: row.notes,
    sortOrder: row.sortOrder,
  );
}
