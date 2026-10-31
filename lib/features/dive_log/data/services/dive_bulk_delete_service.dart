import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

final _log = LoggerService.forClass(DiveBulkDeleteService);

/// What a bulk delete took, for [DiveBulkDeleteService.restore] to put back.
class DeletedDives {
  const DeletedDives({
    required this.dives,
    required this.operationId,
    required this.revisions,
    required this.documents,
  });

  /// The dives as they stood, newest first.
  final List<domain.Dive> dives;

  /// The delete's change log entry, which holds a copy of every row it took.
  /// Null with no database to log to.
  final String? operationId;

  /// The dives' profile revision nodes: `dive_profile_series_history` is
  /// outside the change log, so its entry cannot bring them back.
  final List<ProfileSeriesRevision> revisions;

  /// The dives' documents with their pages and tags. A revert restores the
  /// rows but not the reminders the delete cancelled (issue #2613).
  final List<DocumentSnapshotEntry> documents;
}

/// The logbook's Delete and its Undo (issue #4014).
///
/// A dive's domain object cannot rebuild it: it has no source records, raw
/// recordings or revisions, and flattens every profile into one. So the Undo
/// is a revert of the delete's change log entry, which already holds a copy
/// of each row the delete and its cascades took, and which also takes back
/// what the delete unlinked or reclaimed.
class DiveBulkDeleteService {
  DiveBulkDeleteService({
    required DiveRepository dives,
    required ChangeLogRepository changeLog,
    required ChangeLogRevertService revert,
    required Future<void> Function(List<DocumentSnapshotEntry>)
    restoreDocuments,
    required Future<void> Function(Iterable<Document>) rearmDocuments,
    ProfileSeriesRepository? series,
  }) : _dives = dives,
       _changeLog = changeLog,
       _revert = revert,
       _restoreDocuments = restoreDocuments,
       _rearmDocuments = rearmDocuments,
       _series = series ?? ProfileSeriesRepository();

  final DiveRepository _dives;
  final ChangeLogRepository _changeLog;
  final ChangeLogRevertService _revert;
  final Future<void> Function(List<DocumentSnapshotEntry>) _restoreDocuments;
  final Future<void> Function(Iterable<Document>) _rearmDocuments;
  final ProfileSeriesRepository _series;

  /// Deletes [ids]. The scope opened here is the one
  /// [DiveRepository.bulkDeleteDives] joins, so its entry is known.
  Future<DeletedDives> delete(List<String> ids) async {
    final dives = await _dives.getDivesByIds(ids);
    final revisions = await _series.getRevisionsForDives(ids);
    final documents = await DocumentRepository().captureForOwners(
      DocumentOwnerKind.dive,
      ids,
    );
    String? operationId;
    await ChangeLogScope.bulk(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.bulkDelete,
      body: () {
        operationId = ChangeLogScope.currentOperationId;
        return _dives.bulkDeleteDives(ids);
      },
    );
    return DeletedDives(
      dives: dives,
      operationId: operationId,
      revisions: [for (final nodes in revisions.values) ...nodes],
      documents: documents,
    );
  }

  Future<void> restore(DeletedDives deleted) async {
    await _revertDelete(deleted.operationId);
    await _series.restoreRevisions(deleted.revisions);
    await _rebuildMissingDives(deleted.dives);

    final db = DatabaseService.instance.database;
    final returned = await existingRowIds(db, db.documents, [
      for (final entry in deleted.documents) entry.document.id,
    ]);
    await _rearmDocuments([
      for (final entry in deleted.documents)
        if (returned.contains(entry.document.id)) entry.document,
    ]);
    await _restoreDocuments([
      for (final entry in deleted.documents)
        if (!returned.contains(entry.document.id)) entry,
    ]);
  }

  /// A failure costs only this route: logging never blocks work, so the
  /// entry may be missing or short, and [_rebuildMissingDives] covers that.
  Future<void> _revertDelete(String? operationId) async {
    if (operationId == null) return;
    try {
      await _changeLog.settleAll();
      final result = await _revert.execute(
        await _revert.planOperation(operationId),
      );
      if (result.kept > 0) {
        _log.warning('Undo left ${result.kept} deleted records behind');
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Could not revert a bulk dive delete',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The last resort for a delete the change log did not record, such as on
  /// a device whose triggers could not be installed: the dive comes back from
  /// its domain object, without what that object cannot carry.
  Future<void> _rebuildMissingDives(List<domain.Dive> dives) async {
    final db = DatabaseService.instance.database;
    final returned = await existingRowIds(db, db.dives, [
      for (final dive in dives) dive.id,
    ]);
    final missing = [
      for (final dive in dives)
        if (!returned.contains(dive.id)) dive,
    ];
    if (missing.isEmpty) return;
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.bulkEdit,
      body: () async {
        for (final dive in missing) {
          await _dives.createDive(dive);
        }
      },
    );
  }
}
