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

  /// The diver's own rows first, in their sort order, then rows no diver
  /// owns. Unowned rows are shared by every diver, so they sit in a block
  /// of their own rather than in any one diver's numbering.
  Future<List<SavedQuery>> getAll({String? subject, String? diverId}) async {
    final query = _db.select(_db.savedQueries)
      ..orderBy([
        (t) => OrderingTerm.asc(t.diverId.isNull()),
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

  /// Numbers the owned rows of [orderedIds] 0..n-1 in the order given, in
  /// one transaction, then marks each rewritten row pending once. Rows no
  /// diver owns are skipped: every diver sees them, so one diver's drag
  /// must not renumber (or stamp) them, and [getAll] lists them after the
  /// owned block, so they never tie with it.
  Future<void> reorder(List<String> orderedIds) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final owned = {
        for (final row in await (_db.select(
          _db.savedQueries,
        )..where((t) => t.id.isIn(orderedIds) & t.diverId.isNotNull())).get())
          row.id,
      };
      await _db.transaction(() async {
        final ids = orderedIds.where(owned.contains).toList();
        for (var i = 0; i < ids.length; i++) {
          await (_db.update(
            _db.savedQueries,
          )..where((t) => t.id.equals(ids[i]))).write(
            SavedQueriesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          );
        }
      });
      for (final id in orderedIds.where(owned.contains)) {
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

  /// The highest sort_order among [diverId]'s own rows for [subject], so a
  /// new row lands last in their block (unowned rows list after it).
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
