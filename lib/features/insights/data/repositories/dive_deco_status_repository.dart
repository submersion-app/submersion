import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

int _lastDecoWriteStamp = 0;

/// A write stamp for the deco verdict cache's `computed_at`: epoch
/// microseconds, and always greater than the last one this process took.
/// A pass records one when it begins and leaves alone rows stamped after it
/// ([DiveDecoStatusRepository.replaceFor]'s `keepWrittenAfter`), so a stamp
/// that could tie with the wall clock would let a pass overwrite a verdict a
/// targeted refresh wrote in the same instant.
int nextDecoWriteStamp() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastDecoWriteStamp = now > _lastDecoWriteStamp
      ? now
      : _lastDecoWriteStamp + 1;
  return _lastDecoWriteStamp;
}

/// Per database, the stamp of the last write that judged each dive, kept
/// in memory because a deletion leaves no row to carry it: what lets
/// [DiveDecoStatusRepository.replaceFor]'s `keepWrittenAfter` protect a
/// verdict a newer write removed. Passes run in this process, so the record
/// spans every pass it has to order; a fresh database starts a fresh one.
final _lastWrites = Expando<Map<String, int>>('deco verdict writes');

/// The local deco verdict cache (`dive_deco_status`, v362): whether each
/// dive with no recorded deco signal had a deco obligation, as the dive
/// analysis last judged it under its own diver's settings (issue #4461). The
/// `deco` query field reads it. Written only through [replaceFor], which
/// writes nothing when nothing changed, so a steady filtered list does not
/// re-query.
class DiveDecoStatusRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(DiveDecoStatusRepository);

  /// Every stored verdict, by dive id.
  @visibleForTesting
  Future<Map<String, bool>> verdicts() async => {
    for (final r in await _db.select(_db.diveDecoStatus).get())
      r.diveId: r.hadDeco,
  };

  /// Makes the rows of [diveIds] hold exactly what [byId] says of them: a
  /// named dive with no verdict loses its row, new or changed verdicts are
  /// written, unchanged ones are left alone, and every other dive's row is
  /// left as it is. One transaction, and a verdict for a dive deleted since
  /// it was analyzed is skipped rather than failing the dives foreign key.
  ///
  /// [keepWrittenAfter] protects every dive a write judged after the pass
  /// that produced [byId] began (a refresh of an import's dives meanwhile),
  /// whether that write left a verdict or removed one: the pass knew nothing
  /// of it, so it neither deletes, overwrites nor re-inserts.
  Future<void> replaceFor(
    Map<String, bool> byId, {
    required Set<String> diveIds,
    required int computedAt,
    int? keepWrittenAfter,
  }) async {
    final named = {
      for (final e in byId.entries)
        if (diveIds.contains(e.key)) e.key: e.value,
    };
    try {
      await _db.transaction(
        () => _replace(named, computedAt, diveIds, keepWrittenAfter),
      );
    } catch (e, st) {
      _log.error(
        'Failed to write the deco verdict cache',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _replace(
    Map<String, bool> byId,
    int computedAt,
    Set<String> within,
    int? keepWrittenAfter,
  ) async {
    // Only the rows this write may touch: a targeted refresh of an
    // import's few dives need not read every verdict in the table.
    final rows = [
      for (final chunk in seriesIdChunks(within.toList(growable: false)))
        ...await (_db.select(
          _db.diveDecoStatus,
        )..where((t) => t.diveId.isIn(chunk))).get(),
    ];
    final existing = {for (final r in rows) r.diveId: r.hadDeco};
    final touched = _lastWrites[_db] ??= <String, int>{};
    // A row's own stamp, or the stamp of the write that removed it or found
    // it needed none: a deletion leaves no row to carry the newer stamp. A
    // row stamped later than any stamp this process has taken was written
    // under a clock since set back, not by a newer write: it protects nothing,
    // or a stale verdict would outlive every pass until the clock caught up.
    final kept = {
      if (keepWrittenAfter != null) ...[
        for (final r in rows)
          if (r.computedAt > keepWrittenAfter &&
              r.computedAt <= _lastDecoWriteStamp)
            r.diveId,
        for (final id in within)
          if ((touched[id] ?? 0) > keepWrittenAfter) id,
      ],
    };
    final stale = [
      for (final id in existing.keys)
        if (!byId.containsKey(id) && !kept.contains(id)) id,
    ];
    final changed = {
      for (final e in byId.entries)
        if (!kept.contains(e.key) && existing[e.key] != e.value) e.key: e.value,
    };
    // Every dive this write judged, written or not, as of [computedAt]: an
    // older pass must not undo it. Recorded only once the rows are written,
    // so a batch that fails (and rolls back) protects nothing it never wrote.
    void recordJudged() {
      for (final id in within) {
        if (!kept.contains(id)) touched[id] = computedAt;
      }
    }

    if (stale.isEmpty && changed.isEmpty) {
      recordJudged();
      return;
    }
    await _db.batch((b) {
      for (final chunk in seriesIdChunks(stale)) {
        b.deleteWhere(_db.diveDecoStatus, (t) => t.diveId.isIn(chunk));
      }
      for (final e in changed.entries) {
        // Written only while the dive still exists: one deleted since it
        // was analyzed is skipped, with no separate read of the dives table.
        b.customStatement(
          'INSERT OR REPLACE INTO dive_deco_status '
          '(dive_id, had_deco, computed_at) SELECT ?, ?, ? '
          'WHERE EXISTS (SELECT 1 FROM dives WHERE id = ?)',
          [e.key, e.value ? 1 : 0, computedAt, e.key],
        );
      }
    });
    recordJudged();
    // A raw statement reports no table, so the readers' tick is raised here.
    if (changed.isNotEmpty) {
      _db.notifyUpdates({
        TableUpdate.onTable(_db.diveDecoStatus, kind: UpdateKind.insert),
      });
    }
  }
}
