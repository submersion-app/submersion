import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';

DiverWeightEntry _mapRow(DiverWeightEntryRow row) {
  return DiverWeightEntry(
    id: row.id,
    diverId: row.diverId,
    measuredAt: DateTime.fromMillisecondsSinceEpoch(row.measuredAt),
    weightKg: row.weightKg,
    heightCm: row.heightCm,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

/// CRUD for dated diver body-mass entries (`diver_weight_entries`, v104).
///
/// An HLC-synced entity: every write goes through
/// SyncRepository.markRecordPending / logDeletion with entityType
/// 'diverWeightEntries'.
class DiverWeightEntryRepository {
  DiverWeightEntryRepository([AppDatabase? db]) : _dbOverride = db;

  final AppDatabase? _dbOverride;
  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiverWeightEntryRepository);

  /// Emits whenever the table changes so providers can refresh after a sync
  /// or any other write.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diverWeightEntries));

  /// All entries for [diverId], newest measurement first.
  Future<List<DiverWeightEntry>> getEntriesForDiver(String diverId) async {
    final rows =
        await (_db.select(_db.diverWeightEntries)
              ..where((t) => t.diverId.equals(diverId))
              ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)]))
            .get();
    return rows.map(_mapRow).toList();
  }

  /// The newest entry by measurement date, or null.
  Future<DiverWeightEntry?> latestEntry(String diverId) async {
    final rows = await getEntriesForDiver(diverId);
    return rows.isEmpty ? null : rows.first;
  }

  /// The entry measured closest to [at] (either side), or null. Entry
  /// counts are tiny, so the nearest is picked in Dart.
  Future<DiverWeightEntry?> entryNearest(String diverId, DateTime at) async {
    final rows = await getEntriesForDiver(diverId);
    if (rows.isEmpty) return null;
    DiverWeightEntry best = rows.first;
    var bestDelta = (best.measuredAt.difference(at)).abs();
    for (final row in rows.skip(1)) {
      final delta = (row.measuredAt.difference(at)).abs();
      if (delta < bestDelta) {
        best = row;
        bestDelta = delta;
      }
    }
    return best;
  }

  Future<DiverWeightEntry> createEntry(DiverWeightEntry entry) async {
    try {
      final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.diverWeightEntries)
          .insert(
            DiverWeightEntriesCompanion(
              id: Value(id),
              diverId: Value(entry.diverId),
              measuredAt: Value(entry.measuredAt.millisecondsSinceEpoch),
              weightKg: Value(entry.weightKg),
              heightCm: Value(entry.heightCm),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diverWeightEntries',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return entry.copyWith(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create diver weight entry',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateEntry(DiverWeightEntry entry) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diverWeightEntries,
      )..where((t) => t.id.equals(entry.id))).write(
        DiverWeightEntriesCompanion(
          measuredAt: Value(entry.measuredAt.millisecondsSinceEpoch),
          weightKg: Value(entry.weightKg),
          heightCm: Value(entry.heightCm),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diverWeightEntries',
        recordId: entry.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update diver weight entry: ${entry.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await (_db.delete(
        _db.diverWeightEntries,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diverWeightEntries',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete diver weight entry: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
