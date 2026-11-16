import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// Keeps document expiry reminders in step with a revert (issue #4607). A
/// revert writes rows directly, past the side effects a save or delete on
/// the Documents page applies, so every revert comes through here instead:
/// the change log's Revert, the agent's revert_operation and the table
/// editor's and logbook's Undo alike.
class ChangeLogRevertDocuments {
  /// [rearm] re-arms documents' reminders from their rows as they are now
  /// (`DocumentMutations.rearmReminders`); without it, a revert only
  /// cancels the reminders of documents it removes.
  ChangeLogRevertDocuments({
    DocumentRepository? documents,
    Future<void> Function(Iterable<Document> documents)? rearm,
  }) : _documents = documents ?? DocumentRepository(),
       _rearm = rearm;

  static final _log = LoggerService.forClass(ChangeLogRevertDocuments);

  final DocumentRepository _documents;
  final Future<void> Function(Iterable<Document> documents)? _rearm;

  /// The documents [applying] will remove, read before the revert runs: a
  /// create's log entry holds no values, so only the row can say which
  /// diver the document belongs to and whether it is a medical clearance.
  Future<List<Document>> removing(List<ChangeLogRevertItem> applying) async {
    try {
      return [
        for (final item in applying)
          if (item.removesRecord && item.event.table == 'documents')
            ?await _documents.getById(item.event.recordId),
      ];
    } catch (e, stackTrace) {
      _log.warning(
        'Could not read the documents a revert removes',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// After [applied] committed: cancels the reminders of [removed], and
  /// re-arms the documents the revert restored or edited, from their rows.
  /// A removed medical clearance may have superseded another (#4541), so
  /// each diver who lost one has their clearances re-armed; the scheduler
  /// re-arms a diver's whole set from the database. A reminder failure
  /// never fails the revert: the next full reschedule repairs it.
  Future<void> afterRevert(
    List<ChangeLogRevertItem> applied,
    List<Document> removed,
  ) async {
    final removedIds = {for (final document in removed) document.id};
    await _documents.cancelRemindersFor(removedIds);
    final rearm = _rearm;
    if (rearm == null) return;
    try {
      final changed = {
        for (final item in applied)
          if (item.event.table == 'documents' &&
              !removedIds.contains(item.event.recordId))
            item.event.recordId,
      };
      final current = [for (final id in changed) ?await _documents.getById(id)];
      final settled = {
        for (final document in current)
          if (document.type == DocumentType.medicalClearance) document.diverId,
      };
      final lostClearance = {
        for (final document in removed)
          if (document.type == DocumentType.medicalClearance &&
              !settled.contains(document.diverId))
            document.diverId,
      };
      final rearming = [
        ...current,
        for (final diverId in lostClearance)
          ...(await _documents.getMedicalClearancesForDiver(diverId)).take(1),
      ];
      if (rearming.isNotEmpty) await rearm(rearming);
    } catch (e, stackTrace) {
      _log.warning(
        'Document reminders not re-armed after a revert',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
