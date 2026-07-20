import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

class PreDiveSessionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(PreDiveSessionRepository);

  static const _sessionEntity = 'preDiveSessions';
  static const _itemEntity = 'preDiveSessionItems';

  Stream<void> watchSessionsChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.preDiveSessions,
      _db.preDiveSessionItems,
    ]),
  );

  /// Inserts the session plus its item snapshots in one transaction. Items
  /// arrive with blank id/sessionId (from SessionItemComposer); ids are
  /// assigned here. Sync bookkeeping runs after the transaction commits.
  Future<domain.PreDiveSession> startSession({
    required domain.PreDiveChecklistTemplate template,
    required List<domain.PreDiveSessionItem> items,
    String? diverId,
    String? diveId,
    String? tripId,
    String? equipmentSetId,
    String? equipmentSetName,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final itemIds = <String>[];
      await _db.transaction(() async {
        await _db
            .into(_db.preDiveSessions)
            .insert(
              PreDiveSessionsCompanion(
                id: Value(sessionId),
                diverId: Value(diverId),
                templateId: Value(template.id.isEmpty ? null : template.id),
                templateName: Value(template.name),
                strictOrder: Value(template.strictOrder),
                diveId: Value(diveId),
                tripId: Value(tripId),
                startedAt: Value(now),
                status: Value(domain.PreDiveSessionStatus.inProgress.name),
                equipmentSetId: Value(equipmentSetId),
                equipmentSetName: Value(equipmentSetName),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        for (final item in items) {
          final itemId = _uuid.v4();
          itemIds.add(itemId);
          await _db
              .into(_db.preDiveSessionItems)
              .insert(
                PreDiveSessionItemsCompanion(
                  id: Value(itemId),
                  sessionId: Value(sessionId),
                  section: Value(item.section),
                  title: Value(item.title),
                  notes: Value(item.notes),
                  sortOrder: Value(item.sortOrder),
                  itemType: Value(item.itemType.name),
                  valueLabel: Value(item.valueLabel),
                  valueUnit: Value(item.valueUnit),
                  valueMin: Value(item.valueMin),
                  valueMax: Value(item.valueMax),
                  isRequired: Value(item.isRequired),
                  state: Value(item.state.name),
                  note: Value(item.note),
                  completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
                  equipmentId: Value(item.equipmentId),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
      });
      await _syncRepository.markRecordPending(
        entityType: _sessionEntity,
        recordId: sessionId,
        localUpdatedAt: now,
      );
      for (final id in itemIds) {
        await _syncRepository.markRecordPending(
          entityType: _itemEntity,
          recordId: id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      return (await getSessionById(sessionId))!;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to start pre-dive session',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.PreDiveSession?> getSessionById(String id) async {
    try {
      final row = await (_db.select(
        _db.preDiveSessions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _mapSession(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive session $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<domain.PreDiveSessionItem>> getItemsForSession(
    String sessionId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.preDiveSessionItems)
                ..where((t) => t.sessionId.equals(sessionId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapItem).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive session items',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<domain.PreDiveSession>> getAllSessions({String? diverId}) async {
    try {
      final query = _db.select(_db.preDiveSessions)
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
      }
      final rows = await query.get();
      return rows.map(_mapSession).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive sessions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.PreDiveSession?> getActiveSession({String? diverId}) async {
    try {
      final query = _db.select(_db.preDiveSessions)
        ..where(
          (t) => t.status.equals(domain.PreDiveSessionStatus.inProgress.name),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
        ..limit(1);
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
      }
      final row = await query.getSingleOrNull();
      return row == null ? null : _mapSession(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get active pre-dive session',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.PreDiveSession?> getSessionForDive(String diveId) async {
    try {
      final row =
          await (_db.select(_db.preDiveSessions)
                ..where((t) => t.diveId.equals(diveId))
                ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
                ..limit(1))
              .getSingleOrNull();
      return row == null ? null : _mapSession(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive session for dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sessions not yet linked to a dive, any status. Diver filter is
  /// exact-match (null means unscoped sessions only) so the auto-linker
  /// never crosses diver boundaries.
  Future<List<domain.PreDiveSession>> getUnlinkedSessions({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.preDiveSessions)
        ..where((t) => t.diveId.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
      if (diverId == null) {
        query.where((t) => t.diverId.isNull());
      } else {
        query.where((t) => t.diverId.equals(diverId));
      }
      final rows = await query.get();
      return rows.map(_mapSession).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get unlinked pre-dive sessions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mutates one item's run state. completedAt is stamped at tap time when
  /// leaving pending and cleared when resetting to pending. Value/note
  /// parameters are only written when provided so partial updates preserve
  /// stored values.
  Future<void> updateItemState({
    required String sessionId,
    required String itemId,
    required domain.PreDiveItemState state,
    double? valueNumber,
    String? valueText,
    String? note,
  }) async {
    try {
      await _assertMutable(sessionId);
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.preDiveSessionItems)
            ..where((t) => t.id.equals(itemId) & t.sessionId.equals(sessionId)))
          .write(
            PreDiveSessionItemsCompanion(
              state: Value(state.name),
              completedAt: Value(
                state == domain.PreDiveItemState.pending ? null : now,
              ),
              valueNumber: valueNumber == null
                  ? const Value.absent()
                  : Value(valueNumber),
              valueText: valueText == null
                  ? const Value.absent()
                  : Value(valueText),
              note: note == null ? const Value.absent() : Value(note),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: _itemEntity,
        recordId: itemId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update pre-dive session item',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> completeSession(String id) =>
      _finishSession(id, domain.PreDiveSessionStatus.completed);

  Future<void> abortSession(String id) =>
      _finishSession(id, domain.PreDiveSessionStatus.aborted);

  Future<void> _finishSession(
    String id,
    domain.PreDiveSessionStatus status,
  ) async {
    try {
      await _assertMutable(id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.preDiveSessions,
      )..where((t) => t.id.equals(id))).write(
        PreDiveSessionsCompanion(
          status: Value(status.name),
          completedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: _sessionEntity,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to finish pre-dive session $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Linking is metadata, not audit content, so it is allowed on locked
  /// sessions.
  Future<void> linkToDive(String sessionId, String diveId) =>
      _writeDiveLink(sessionId, diveId);

  Future<void> unlinkFromDive(String sessionId) =>
      _writeDiveLink(sessionId, null);

  Future<void> _writeDiveLink(String sessionId, String? diveId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.preDiveSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        PreDiveSessionsCompanion(diveId: Value(diveId), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: _sessionEntity,
        recordId: sessionId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update pre-dive session dive link',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final items = await getItemsForSession(id);
      await (_db.delete(
        _db.preDiveSessionItems,
      )..where((t) => t.sessionId.equals(id))).go();
      for (final item in items) {
        await _syncRepository.logDeletion(
          entityType: _itemEntity,
          recordId: item.id,
        );
      }
      await (_db.delete(
        _db.preDiveSessions,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: _sessionEntity,
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete pre-dive session $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Audit-record integrity: no mutation once a session leaves inProgress.
  Future<void> _assertMutable(String sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) {
      throw StateError('Pre-dive session $sessionId does not exist');
    }
    if (session.isLocked) {
      throw StateError('Pre-dive session $sessionId is locked');
    }
  }

  domain.PreDiveSession _mapSession(PreDiveSession row) =>
      domain.PreDiveSession(
        id: row.id,
        diverId: row.diverId,
        templateId: row.templateId,
        templateName: row.templateName,
        strictOrder: row.strictOrder,
        diveId: row.diveId,
        tripId: row.tripId,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row.startedAt),
        completedAt: row.completedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.completedAt!),
        status: domain.PreDiveSessionStatus.parse(row.status),
        equipmentSetId: row.equipmentSetId,
        equipmentSetName: row.equipmentSetName,
        notes: row.notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );

  domain.PreDiveSessionItem _mapItem(PreDiveSessionItem row) =>
      domain.PreDiveSessionItem(
        id: row.id,
        sessionId: row.sessionId,
        section: row.section,
        title: row.title,
        notes: row.notes,
        sortOrder: row.sortOrder,
        itemType: domain.PreDiveItemType.parse(row.itemType),
        valueLabel: row.valueLabel,
        valueUnit: row.valueUnit,
        valueMin: row.valueMin,
        valueMax: row.valueMax,
        isRequired: row.isRequired,
        state: domain.PreDiveItemState.parse(row.state),
        valueNumber: row.valueNumber,
        valueText: row.valueText,
        note: row.note,
        completedAt: row.completedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.completedAt!),
        equipmentId: row.equipmentId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
