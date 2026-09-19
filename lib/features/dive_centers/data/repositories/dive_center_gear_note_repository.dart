import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

/// CRUD for a dive center's rental gear notes (issue #2075). Mirrors
/// WeightPresetRepository: HLC-stamped writes, a change stream for the
/// providers, and per-row sync bookkeeping after the write.
class DiveCenterGearNoteRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveCenterGearNoteRepository);

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveCenterGearNotes));

  /// The center's notes, newest observation first.
  Future<List<DiveCenterGearNote>> getForCenter(String centerId) async {
    final rows =
        await (_db.select(_db.diveCenterGearNotes)
              ..where((t) => t.diveCenterId.equals(centerId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.notedAt),
                (t) => OrderingTerm.desc(t.createdAt),
              ]))
            .get();
    return rows.map(fromRow).toList();
  }

  Future<DiveCenterGearNote?> getById(String id) async {
    final row = await (_db.select(
      _db.diveCenterGearNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : fromRow(row);
  }

  /// Insert [note]; an empty id is replaced with a fresh uuid.
  Future<DiveCenterGearNote> create(DiveCenterGearNote note) async {
    try {
      final id = note.id.isEmpty ? _uuid.v4() : note.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.diveCenterGearNotes)
          .insert(
            DiveCenterGearNotesCompanion(
              id: Value(id),
              diveCenterId: Value(note.diveCenterId),
              gearType: Value(note.gearType.name),
              label: Value(_trimmedOrNull(note.label)),
              size: Value(_trimmedOrNull(note.size)),
              verdict: Value(note.verdict.name),
              leadAdjustmentKg: Value(note.leadAdjustmentKg),
              volumeLiters: Value(note.volumeLiters),
              note: Value(note.note.trim()),
              diveId: Value(note.diveId),
              notedAt: Value(note.notedAt.millisecondsSinceEpoch),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveCenterGearNotes',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return (await getById(id))!;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create rental gear note for ${note.diveCenterId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> update(DiveCenterGearNote note) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diveCenterGearNotes,
      )..where((t) => t.id.equals(note.id))).write(
        DiveCenterGearNotesCompanion(
          gearType: Value(note.gearType.name),
          label: Value(_trimmedOrNull(note.label)),
          size: Value(_trimmedOrNull(note.size)),
          verdict: Value(note.verdict.name),
          leadAdjustmentKg: Value(note.leadAdjustmentKg),
          volumeLiters: Value(note.volumeLiters),
          note: Value(note.note.trim()),
          diveId: Value(note.diveId),
          notedAt: Value(note.notedAt.millisecondsSinceEpoch),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveCenterGearNotes',
        recordId: note.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update rental gear note ${note.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.diveCenterGearNotes,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'diveCenterGearNotes',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete rental gear note $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String? _trimmedOrNull(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static DiveCenterGearNote fromRow(
    DiveCenterGearNoteRow row,
  ) => DiveCenterGearNote(
    id: row.id,
    diveCenterId: row.diveCenterId,
    gearType: DiveCenterGearNote.gearTypeFromName(row.gearType),
    label: row.label,
    size: row.size,
    verdict: DiveCenterGearNote.verdictFromName(row.verdict),
    leadAdjustmentKg: row.leadAdjustmentKg,
    volumeLiters: row.volumeLiters,
    note: row.note,
    diveId: row.diveId,
    notedAt: DateTime.fromMillisecondsSinceEpoch(row.notedAt, isUtc: true),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
