import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/markdown/notes_markdown.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';

/// An annotation the dive edit page has linked in its Notes text but not
/// yet written, because every edit-page change lands on save (#4109).
class PendingAnnotation {
  const PendingAnnotation({
    required this.id,
    required this.timestamp,
    this.depth,
  });

  final String id;
  final int timestamp;
  final double? depth;
}

/// Writes annotations (#4109): the `dive_profile_events` row and the
/// `[words](annotation:id)` link in `dives.notes` move together, in one
/// transaction, and [reconcile] keeps the two agreeing after any Notes save.
class AnnotationRepository {
  AnnotationRepository({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _sync = syncRepository ?? SyncRepository();

  final AppDatabase? _dbOverride;
  final SyncRepository _sync;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(AnnotationRepository);

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Appends the link paragraph to the dive's Notes and inserts the event
  /// row. Returns the new annotation's id.
  Future<String> addAnnotation({
    required String diveId,
    required int timestamp,
    double? depth,
    required String words,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    // The row caches the words as the Notes render them: a mark the diver
    // typed (asterisks, backticks) is formatting there, not text.
    final link = annotationLinkMarkdown(words, id);
    final rendered = annotationWordsInNotes(link)[id] ?? words;
    try {
      await _db.transaction(() async {
        final current = await _notesOf(diveId);
        await _writeNotes(diveId, appendMarkdownParagraph(current, link), now);
        await _insertRow(
          id: id,
          diveId: diveId,
          timestamp: timestamp,
          depth: depth,
          words: rendered,
          now: now,
        );
      });
      SyncEventBus.notifyLocalChange();
      return id;
    } catch (e, stackTrace) {
      _log.error('Failed to add annotation', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Changes the time and depth of one annotation. The dive row is left
  /// alone: the event row's own clock carries the change.
  Future<void> moveAnnotation({
    required String id,
    required int timestamp,
    double? depth,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var moved = false;
    try {
      await _db.transaction(() async {
        // Gone meanwhile (removed on a peer): nothing to stamp or announce.
        final row = await (_db.select(
          _db.diveProfileEvents,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null) return;
        moved = true;
        await (_db.update(
          _db.diveProfileEvents,
        )..where((t) => t.id.equals(id))).write(
          DiveProfileEventsCompanion(
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
        await _sync.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: id,
          localUpdatedAt: now,
        );
      });
      if (moved) SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to move annotation', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Deletes the annotation and turns its link back into plain words. The
  /// dive is rewritten only when the Notes text changed.
  Future<void> removeAnnotation({
    required String diveId,
    required String id,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db.transaction(() async {
        final current = await _notesOf(diveId);
        final unlinked = unlinkAnnotation(current, id);
        if (unlinked != current) await _writeNotes(diveId, unlinked, now);
        await _deleteRow(id);
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to remove annotation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Brings the dive's annotation rows in line with [notes] after a save:
  /// inserts each of [create] that [notes] links (the rest are ignored),
  /// deletes every annotation row no link names, and refreshes the cached
  /// words of the rest. Never writes the Notes themselves.
  Future<void> reconcile({
    required String diveId,
    required String notes,
    List<PendingAnnotation> create = const [],
  }) async {
    final words = annotationWordsInNotes(notes);
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    try {
      await _db.transaction(() async {
        final existing = await _annotationRows(diveId);
        final existingIds = {for (final r in existing) r.id};
        for (final p in create) {
          final text = words[p.id];
          if (text == null || existingIds.contains(p.id)) continue;
          await _insertRow(
            id: p.id,
            diveId: diveId,
            timestamp: p.timestamp,
            depth: p.depth,
            words: text,
            now: now,
          );
          changed = true;
        }
        for (final row in existing) {
          final text = words[row.id];
          if (text == null) {
            await _deleteRow(row.id);
            changed = true;
          } else if (text != row.description) {
            await (_db.update(_db.diveProfileEvents)
                  ..where((t) => t.id.equals(row.id)))
                .write(DiveProfileEventsCompanion(description: Value(text)));
            await _sync.markRecordPending(
              entityType: 'diveProfileEvents',
              recordId: row.id,
              localUpdatedAt: now,
            );
            changed = true;
          }
        }
      });
      if (changed) SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to reconcile annotations',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The dive's annotation events in time order.
  Future<List<ProfileEvent>> annotationsForDive(String diveId) async {
    final rows = await _annotationRows(diveId);
    return rows.map(mapDiveProfileEventToProfileEvent).toList();
  }

  Future<List<DiveProfileEvent>> _annotationRows(String diveId) =>
      (_db.select(_db.diveProfileEvents)
            ..where(
              (t) =>
                  t.diveId.equals(diveId) &
                  t.eventType.equals(ProfileEventType.annotation.name),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<String> _notesOf(String diveId) async {
    final row = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    return row.notes;
  }

  Future<void> _writeNotes(String diveId, String notes, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(notes: Value(notes), updatedAt: Value(now)),
    );
    await _sync.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }

  Future<void> _insertRow({
    required String id,
    required String diveId,
    required int timestamp,
    required double? depth,
    required String words,
    required int now,
  }) async {
    await _db
        .into(_db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            timestamp: Value(timestamp),
            eventType: Value(ProfileEventType.annotation.name),
            severity: Value(ProfileEventType.annotation.defaultSeverity),
            source: Value(EventSource.user.name),
            description: Value(words),
            depth: Value(depth),
            createdAt: Value(now),
          ),
        );
    await _sync.markRecordPending(
      entityType: 'diveProfileEvents',
      recordId: id,
      localUpdatedAt: now,
    );
  }

  /// Deletes the row and tombstones it, only when it was still there: a
  /// stale popup or a repeated Remove must not publish tombstones for a row
  /// no peer has.
  Future<void> _deleteRow(String id) async {
    final deleted = await (_db.delete(
      _db.diveProfileEvents,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) return;
    await _sync.logDeletion(entityType: 'diveProfileEvents', recordId: id);
  }
}
