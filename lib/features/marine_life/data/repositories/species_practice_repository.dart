import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';
import 'package:submersion/features/marine_life/domain/species_revamp_ids.dart';

/// Each diver's ID practice record per species (issue #5027), keyed by
/// [speciesPracticeId]. Last write wins across devices.
class SpeciesPracticeRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(SpeciesPracticeRepository);

  static const entityType = 'speciesPractice';

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onAllTables([_db.speciesPractice]));

  /// [diverId]'s practice records by species id.
  Future<Map<String, PracticeState>> statesFor(String diverId) async {
    final rows = await (_db.select(
      _db.speciesPractice,
    )..where((t) => t.diverId.equals(diverId))).get();
    return {
      for (final r in rows)
        r.speciesId: PracticeState(
          speciesId: r.speciesId,
          box: r.box,
          dueAt: _time(r.dueAt),
          rightCount: r.rightCount,
          wrongCount: r.wrongCount,
          lastPractisedAt: r.lastPractisedAt == null
              ? null
              : _time(r.lastPractisedAt!),
        ),
    };
  }

  /// Stores [state] as [diverId]'s record for its species.
  Future<void> save(String diverId, PracticeState state) async {
    try {
      final now = clock.now().millisecondsSinceEpoch;
      final id = speciesPracticeId(diverId, state.speciesId);
      final existing = await (_db.select(
        _db.speciesPractice,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      await _db
          .into(_db.speciesPractice)
          .insertOnConflictUpdate(
            SpeciesPracticeCompanion(
              id: Value(id),
              diverId: Value(diverId),
              speciesId: Value(state.speciesId),
              box: Value(state.box),
              dueAt: Value(state.dueAt.millisecondsSinceEpoch),
              rightCount: Value(state.rightCount),
              wrongCount: Value(state.wrongCount),
              lastPractisedAt: Value(
                state.lastPractisedAt?.millisecondsSinceEpoch,
              ),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save a species practice record',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Instants are stored as epoch milliseconds; read them back in UTC.
  DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
