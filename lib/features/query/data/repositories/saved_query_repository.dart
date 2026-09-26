import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';

/// Saved queries (#2365, spec Unit 7): create, rename, replace the tree,
/// reorder, delete, each stamped for sync like the dive roles repository.
/// Reads are scoped to one diver plus rows with no owner.
class SavedQueryRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SavedQueryRepository);

  static const entityType = 'savedQueries';

  /// Emits whenever the `saved_queries` table changes, so the chip rows
  /// and the Manage page refresh after a sync or any other write.
  Stream<void> watchSavedQueriesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.savedQueries));

  Future<List<SavedQuery>> getAll({String? subject, String? diverId}) async {
    final query = _db.select(_db.savedQueries)
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
      ]);
    if (subject != null) query.where((t) => t.subject.equals(subject));
    query.where(
      (t) => diverId == null
          ? t.diverId.isNull()
          : t.diverId.equals(diverId) | t.diverId.isNull(),
    );
    return (await query.get()).map(_fromRow).toList();
  }

  Future<SavedQuery?> getById(String id) async {
    final row = await (_db.select(
      _db.savedQueries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<SavedQuery> create({
    required QuerySubject subject,
    required String name,
    required QueryNode node,
    required String diverId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSort = await _maxSortOrder(subject.name, diverId);
      await _db
          .into(_db.savedQueries)
          .insert(
            SavedQueriesCompanion(
              id: Value(id),
              diverId: Value(diverId),
              subject: Value(subject.name),
              name: Value(name.trim()),
              queryJson: Value(jsonEncode(queryNodeToJson(node))),
              sortOrder: Value(maxSort + 1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _stamp(id, now);
      _log.info('Saved query $id for diver $diverId');
      return (await getById(id))!;
    } catch (e, st) {
      _log.error('Failed to save query', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> rename(String id, String name) =>
      _update(id, SavedQueriesCompanion(name: Value(name.trim())));

  Future<void> updateQuery(String id, QueryNode node) => _update(
    id,
    SavedQueriesCompanion(queryJson: Value(jsonEncode(queryNodeToJson(node)))),
  );

  /// Rewrites sort_order so [orderedIds] run 0..n-1, in one transaction,
  /// then marks each row pending once.
  Future<void> reorder(List<String> orderedIds) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (_db.update(
            _db.savedQueries,
          )..where((t) => t.id.equals(orderedIds[i]))).write(
            SavedQueriesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          );
        }
      });
      for (final id in orderedIds) {
        await _syncRepository.markRecordPending(
          entityType: entityType,
          recordId: id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, st) {
      _log.error('Failed to reorder saved queries', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await (_db.delete(_db.savedQueries)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted saved query $id');
    } catch (e, st) {
      _log.error('Failed to delete saved query $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _update(String id, SavedQueriesCompanion patch) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.savedQueries)..where((t) => t.id.equals(id))).write(
        patch.copyWith(updatedAt: Value(now)),
      );
      await _stamp(id, now);
    } catch (e, st) {
      _log.error('Failed to update saved query $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _stamp(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<int> _maxSortOrder(String subject, String diverId) async {
    final result = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS max_order FROM saved_queries '
          'WHERE subject = ? AND diver_id = ?',
          variables: [Variable<String>(subject), Variable<String>(diverId)],
        )
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? -1;
  }

  SavedQuery _fromRow(SavedQueryRow row) => SavedQuery(
    id: row.id,
    diverId: row.diverId,
    subject: row.subject,
    name: row.name,
    queryJson: row.queryJson,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
