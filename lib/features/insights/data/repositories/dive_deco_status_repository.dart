import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// The local deco verdict cache (`dive_deco_status`, v362): whether each
/// dive with no recorded deco signal had a deco obligation, as the dive
/// analysis last judged it under its own diver's settings (issue #4461). The
/// `deco` query field reads it. Written only through [replaceFor], which
/// writes nothing when nothing changed, so a steady filtered list does not
/// re-query.
class DiveDecoStatusRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(DiveDecoStatusRepository);

  /// Ids bound per `IN (...)` list, well under SQLite's variable limit, so
  /// a whole logbook's verdicts stay one valid write.
  static const _chunk = 900;

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
  /// [keepWrittenAfter] protects rows written after the pass that produced
  /// [byId] began (a refresh of an import's dives meanwhile): that pass knew
  /// nothing of them, so it neither deletes nor overwrites them.
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
      for (final chunk in _chunks(within.toList(growable: false)))
        ...await (_db.select(
          _db.diveDecoStatus,
        )..where((t) => t.diveId.isIn(chunk))).get(),
    ];
    final existing = {for (final r in rows) r.diveId: r.hadDeco};
    final kept = {
      if (keepWrittenAfter != null)
        for (final r in rows)
          if (r.computedAt > keepWrittenAfter) r.diveId,
    };
    final live = await _liveDiveIds(byId.keys.toList(growable: false));
    final stale = [
      for (final id in existing.keys)
        if (!live.contains(id) && !kept.contains(id)) id,
    ];
    final changed = {
      for (final e in byId.entries)
        if (live.contains(e.key) &&
            !kept.contains(e.key) &&
            existing[e.key] != e.value)
          e.key: e.value,
    };
    if (stale.isEmpty && changed.isEmpty) return;
    await _db.batch((b) {
      for (final chunk in _chunks(stale)) {
        b.deleteWhere(_db.diveDecoStatus, (t) => t.diveId.isIn(chunk));
      }
      for (final e in changed.entries) {
        b.insert(
          _db.diveDecoStatus,
          DiveDecoStatusCompanion.insert(
            diveId: e.key,
            hadDeco: e.value,
            computedAt: computedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<Set<String>> _liveDiveIds(List<String> ids) async {
    final live = <String>{};
    for (final chunk in _chunks(ids)) {
      final rows =
          await (_db.selectOnly(_db.dives)
                ..addColumns([_db.dives.id])
                ..where(_db.dives.id.isIn(chunk)))
              .get();
      live.addAll([for (final r in rows) r.read(_db.dives.id)!]);
    }
    return live;
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    for (var start = 0; start < ids.length; start += _chunk) {
      yield ids.sublist(
        start,
        start + _chunk < ids.length ? start + _chunk : ids.length,
      );
    }
  }
}
