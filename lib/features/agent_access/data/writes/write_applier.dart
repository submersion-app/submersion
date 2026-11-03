import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';

/// A record an apply made.
class CreatedRecord {
  const CreatedRecord({
    required this.operation,
    required this.entity,
    required this.id,
  });

  final int operation;
  final String entity;
  final String id;
}

/// What an apply did. [operations] holds one change log operation per diver
/// touched, each revertable on its own.
class WriteResult {
  const WriteResult({
    required this.operations,
    required this.countsByEntity,
    required this.countsByDiver,
    required this.created,
    this.clientName,
  });

  final List<({String operationId, String? diverId})> operations;
  final Map<String, int> countsByEntity;
  final Map<String, int> countsByDiver;
  final List<CreatedRecord> created;

  /// The change log keeps no client name, so this is where it is reported.
  final String? clientName;

  Map<String, Object?> toJson() => {
    'client': ?clientName,
    'operations': [
      for (final o in operations)
        {'operation_id': o.operationId, 'diver_id': o.diverId},
    ],
    'counts': {'by_entity': countsByEntity, 'by_diver': countsByDiver},
    'created': [
      for (final c in created)
        {'operation': c.operation, 'entity': c.entity, 'id': c.id},
    ],
  };
}

/// Runs a plan: all of it or none. Every write goes through a repository, so
/// validation, sync stamping and change notifications stay theirs.
class WriteApplier {
  static const _log = LoggerService('AgentAccess');

  WriteApplier({
    required WriteCatalog catalog,
    required ChangeLogRepository changeLog,
    required WriteConfirmer confirmer,
    required bool Function() confirmEnabled,
    void Function(Iterable<String>) afterDiveWrites = refreshAfterRuleWrites,
    Future<void> Function(Iterable<Document>)? rearmDocuments,
    DocumentRepository? documents,
  }) : _catalog = catalog,
       _changeLog = changeLog,
       _confirmer = confirmer,
       _confirmEnabled = confirmEnabled,
       _afterDiveWrites = afterDiveWrites,
       _rearmDocuments = rearmDocuments,
       _documents = documents ?? DocumentRepository();

  final WriteCatalog _catalog;
  final ChangeLogRepository _changeLog;
  final WriteConfirmer _confirmer;
  final bool Function() _confirmEnabled;
  final void Function(Iterable<String>) _afterDiveWrites;
  final Future<void> Function(Iterable<Document>)? _rearmDocuments;
  final DocumentRepository _documents;

  Future<WriteResult> apply(AppDatabase db, WritePlan plan) async {
    await _ensureCurrent(db, plan);
    if (_confirmEnabled()) {
      final allowed = await _confirmer.confirm(WriteConfirmation.of(plan));
      if (!allowed) {
        throw const AgentToolException(
          AgentToolErrorCode.notConfirmed,
          'The diver did not allow this change. Nothing was changed.',
        );
      }
    }
    final written = await SyncCoordinator.run(() => _writeOrRestore(db, plan));
    SyncEventBus.notifyLocalChange();
    _afterDiveWrites({
      for (final item in plan.items)
        if (item.entity == 'dives' && item.kind == ChangeKind.update) item.id!,
      for (final record in written.created)
        if (record.entity == 'dives') record.id,
    });
    // The settler files another diver's records under `operation:diver`, and
    // a revert straight after this needs the entries settled anyway.
    await _changeLog.settleAll();
    return WriteResult(
      operations: await _operations(db, written.operationId),
      countsByEntity: plan.countsByEntity,
      countsByDiver: plan.countsByDiver,
      created: written.created,
      clientName: plan.clientName,
    );
  }

  /// A delete cancels its documents' reminders as it goes, which a rollback
  /// cannot undo, so they are armed again when the plan fails.
  Future<({String operationId, List<CreatedRecord> created})> _writeOrRestore(
    AppDatabase db,
    WritePlan plan,
  ) async {
    final documents = await _documentsDeletedBy(plan);
    try {
      return await _write(db, plan);
    } catch (_) {
      await _rearmDocuments?.call(documents);
      rethrow;
    }
  }

  Future<List<Document>> _documentsDeletedBy(WritePlan plan) async {
    final found = <Document>[];
    for (final item in plan.items) {
      if (item.kind != ChangeKind.delete) continue;
      final entry = _catalog.named(item.entity)!;
      for (final owner in await entry.deletedDocumentOwners(item.id!)) {
        found.addAll(await _documents.getForOwner(owner));
      }
    }
    return found;
  }

  Future<({String operationId, List<CreatedRecord> created})> _write(
    AppDatabase db,
    WritePlan plan,
  ) => ChangeLogScope.run(
    db,
    source: ChangeLogSource.agent,
    label: plan.label,
    // A renewal cannot run until the transaction ends, and a large plan can
    // outlast the short lease.
    lease: kChangeLogLongLease,
    // The scope stays outside the transaction, as its documentation asks, and
    // holds the writes and nothing else, so a save the diver makes around it
    // is not filed here.
    body: () async {
      final created = <CreatedRecord>[];
      await db.transaction(() async {
        // The dialog can last minutes and a merge can land in the queue, so
        // what the diver allowed is checked once more, where a diver's own
        // save cannot come between the check and the write.
        await _ensureCurrent(db, plan);
        for (final item in plan.items) {
          await _writeItem(item, created);
        }
      });
      return (
        operationId: ChangeLogScope.currentOperationId!,
        created: created,
      );
    },
  );

  Future<void> _writeItem(PlanItem item, List<CreatedRecord> created) async {
    final entry = _catalog.named(item.entity)!;
    try {
      switch (item.kind) {
        case ChangeKind.create:
          final id = await entry.create(item.diverId!, item.values);
          created.add(
            CreatedRecord(
              operation: item.operation,
              entity: item.entity,
              id: id,
            ),
          );
        case ChangeKind.update:
          await entry.update(
            item.id!,
            item.diverId,
            RecordUpdate(values: item.values, relations: item.relations),
          );
        case ChangeKind.delete:
          await entry.delete(item.id!, item.diverId);
      }
    } on AgentToolException catch (refusal) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        '${refusal.message} Nothing was changed.',
        details: _where(item),
      );
    } catch (error, stackTrace) {
      // The error names SQL and values, which belong in the log, not a reply.
      _log.error(
        'Agent ${item.kind.name} of ${item.entity} failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'The ${item.kind.name} of this ${item.entity} record was refused. '
        'Nothing was changed.',
        details: _where(item),
      );
    }
  }

  Map<String, Object?> _where(PlanItem item) => {
    'operation': item.operation,
    'entity': item.entity,
    'id': item.id,
  };

  /// Refuses a plan that no longer describes the logbook.
  Future<void> _ensureCurrent(AppDatabase db, WritePlan plan) async {
    // A restore, storage move or demo switch replaces the database.
    if (!identical(DatabaseService.instance.databaseOrNull, db)) {
      throw const AgentToolException(
        AgentToolErrorCode.databaseUnavailable,
        'The logbook was replaced after this plan was made. Preview again.',
      );
    }
    final stale = <RecordMarker>[];
    for (final MapEntry(key: table, value: markers) in groupBy(
      plan.markers,
      (RecordMarker m) => m.table,
    ).entries) {
      final versions = await _versions(db, table, [
        for (final marker in markers) marker.id,
      ]);
      for (final marker in markers) {
        if (versions[marker.id] != marker.updatedAt ||
            await _linksMoved(marker) ||
            await _footprintMoved(marker)) {
          stale.add(marker);
        }
      }
    }
    if (stale.isEmpty) return;
    throw AgentToolException(
      AgentToolErrorCode.planStale,
      'These records changed after the preview, so nothing was applied. '
      'Read them and preview again.',
      details: {
        'records': [
          for (final marker in stale) {'table': marker.table, 'id': marker.id},
        ],
      },
    );
  }

  Future<Map<String, int>> _versions(
    AppDatabase db,
    String table,
    List<String> ids,
  ) async {
    final versions = <String, int>{};
    for (final chunk in seriesIdChunks(ids)) {
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT id, updated_at FROM $table WHERE id IN ($marks)',
            variables: [for (final id in chunk) Variable.withString(id)],
          )
          .get();
      for (final row in rows) {
        versions[row.read<String>('id')] = row.read<int>('updated_at');
      }
    }
    return versions;
  }

  Future<bool> _linksMoved(RecordMarker marker) async {
    for (final MapEntry(key: relation, value: links)
        in marker.relations.entries) {
      final now = await marker.readRelation!(relation);
      if (!const SetEquality<String>().equals(now, links)) return true;
    }
    return false;
  }

  Future<bool> _footprintMoved(RecordMarker marker) async {
    final read = marker.readFootprint;
    return read != null && await read() != marker.footprint;
  }

  Future<List<({String operationId, String? diverId})>> _operations(
    AppDatabase db,
    String operationId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT id, diver_id FROM change_log_operations '
          'WHERE id = ? OR id LIKE ?',
          variables: [
            Variable.withString(operationId),
            Variable.withString('$operationId:%'),
          ],
        )
        .get();
    return [
      for (final row in rows)
        (
          operationId: row.read<String>('id'),
          diverId: row.readNullable<String>('diver_id'),
        ),
    ];
  }
}
