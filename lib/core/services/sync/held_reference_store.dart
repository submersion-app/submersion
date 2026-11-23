import 'package:drift/drift.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/held_reference_schema.dart';
import 'package:submersion/core/services/sync/held_references.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_record_overlay.dart';

final _log = LoggerService.forClass(HeldReferenceStore);

/// A peer's copy of a row this device holds a link for, as the payload
/// carried it, before the merge overlays it onto the local row.
class IncomingCopy {
  const IncomingCopy({required this.hlc, required this.keys});

  /// The copy's row clock.
  final String? hlc;

  /// The wire (JSON) keys the copy carried.
  final Set<String> keys;
}

/// The peers' copies of held rows seen during one apply, by row id. The
/// merge overlays a copy onto the local row before writing it, so by then a
/// key the peer left out reads the same as one it sent as null; these
/// notes, taken from the payload itself, tell the two apart.
class IncomingCopies {
  const IncomingCopies._(this._byRow);

  static const none = IncomingCopies._({});

  final Map<String, List<IncomingCopy>> _byRow;

  bool get isEmpty => _byRow.isEmpty;

  /// These notes and [copy] of [rowId].
  IncomingCopies adding(String rowId, IncomingCopy copy) => IncomingCopies._({
    ..._byRow,
    rowId: [...?_byRow[rowId], copy],
  });

  /// The copy of [rowId] whose clock is [hlc], if one was seen.
  IncomingCopy? find(String rowId, String? hlc) {
    for (final copy in _byRow[rowId] ?? const <IncomingCopy>[]) {
      if (copy.hlc == hlc) return copy;
    }
    return null;
  }
}

/// Puts held links back into this device's exported rows.
class HeldExportFilter {
  const HeldExportFilter(this._byTable);

  static const none = HeldExportFilter({});

  /// SQL table to (primary key columns, row id to held wire values).
  final Map<
    String,
    ({List<String> keyColumns, Map<String, Map<String, Object>> values})
  >
  _byTable;

  bool get isEmpty => _byTable.isEmpty;

  bool covers(String table) => _byTable.containsKey(table);

  /// [row], a wire row of [table], carrying each link this device still
  /// holds as the value it held; [row] itself when it has none. The row goes
  /// out as if the repair had never cleared it, so a receiver that has the
  /// parent keeps the link, and one that does not holds it in turn.
  Map<String, dynamic> withHeldValues(String table, Map<String, dynamic> row) {
    final entry = _byTable[table];
    if (entry == null) return row;
    final rowId = heldRowId(table, {
      for (final column in entry.keyColumns) column: row[columnJsonKey(column)],
    });
    final values = entry.values[rowId];
    if (values == null) return row;
    return {...row, ...values};
  }
}

/// Reads and writes this device's held references (issue #4954). Every
/// method runs inside the apply's deferred-FK transaction, so a hold and the
/// repair that made it commit or roll back together.
class HeldReferenceStore {
  HeldReferenceStore(this._db, {String? Function(String table)? entityTypeOf})
    : _entityTypeOf = entityTypeOf ?? _noEntityType;

  final GeneratedDatabase _db;

  /// The wire entity type whose rows live in an SQL table, or null for a
  /// table that does not sync. Tombstones are logged by entity type and
  /// record id, so this is what [_isTombstoned] matches them by.
  final String? Function(String table) _entityTypeOf;

  static String? _noEntityType(String table) => null;

  HeldSchema get _schema => HeldSchema.of(_db);

  /// Everything held. The repair alone needs the orphans.
  Future<HeldReferences> load() async => HeldReferences(
    links: await loadLinks(),
    orphans: await _decoded(
      heldOrphansSettingsKey,
      HeldReferences.decodeOrphans,
    ),
  );

  /// The held links alone: what every apply and export reads.
  Future<Map<String, HeldLink>> loadLinks() =>
      _decoded(heldLinksSettingsKey, HeldReferences.decodeLinks);

  Future<Map<String, T>> _decoded<T>(
    String key,
    Map<String, T> Function(String? value) decode,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT value FROM settings WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    try {
      return decode(row?.read<String?>('value'));
    } on Object catch (e, stackTrace) {
      // A hold that cannot be read restores nothing; the rows keep the
      // repair's result, as they did before holds existed.
      _log.warning(
        'Unreadable held references dropped',
        error: e,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  /// Writes [held], touching only the part that differs from [previous].
  Future<void> save(
    HeldReferences held, {
    required HeldReferences previous,
  }) async {
    final links = held.encodeLinks();
    if (links != previous.encodeLinks()) {
      await _write(heldLinksSettingsKey, held.links.isEmpty ? null : links);
    }
    final orphans = held.encodeOrphans();
    if (orphans != previous.encodeOrphans()) {
      await _write(
        heldOrphansSettingsKey,
        held.orphans.isEmpty ? null : orphans,
      );
    }
  }

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      await _db.customStatement('DELETE FROM settings WHERE key = ?', [key]);
      return;
    }
    await _db.customStatement(
      'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, '
      'updated_at = excluded.updated_at',
      [key, value, DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// Forgets everything held. For a replace of the whole library: the rows
  /// the holds describe belonged to the copy being discarded.
  Future<void> discard() async {
    await _write(heldLinksSettingsKey, null);
    await _write(heldOrphansSettingsKey, null);
  }

  /// [notes] with the copies in [records], wire rows of [table], of rows
  /// this device holds a link for.
  Future<IncomingCopies> noteIncoming(
    IncomingCopies notes,
    String table,
    Iterable<Map<String, dynamic>> records,
  ) async {
    final rowIds = {
      for (final link in (await loadLinks()).values)
        if (link.table == table) link.rowId,
    };
    if (rowIds.isEmpty) return notes;
    var noted = notes;
    final keyColumns = await _schema.keyColumns(table);
    for (final record in records) {
      final rowId = heldRowId(table, {
        for (final column in keyColumns) column: record[columnJsonKey(column)],
      });
      if (!rowIds.contains(rowId)) continue;
      final hlc = record['hlc'];
      noted = noted.adding(
        rowId,
        IncomingCopy(
          hlc: hlc is String ? hlc : null,
          keys: record.keys.toSet(),
        ),
      );
    }
    return noted;
  }

  /// The filter that sends this device's held links with the values they
  /// held: a link still cleared here goes out as it was before the repair.
  Future<HeldExportFilter> exportFilter() async {
    final links = await loadLinks();
    if (links.isEmpty) return HeldExportFilter.none;
    final byTable =
        <
          String,
          ({List<String> keyColumns, Map<String, Map<String, Object>> values})
        >{};
    for (final link in links.values) {
      try {
        final row = await _readRow(link.table, link.key, [link.column]);
        if (row == null || row.data[link.column] != null) continue;
        final entry = byTable[link.table] ??= (
          keyColumns: await _schema.keyColumns(link.table),
          values: {},
        );
        (entry.values[link.rowId] ??= {})[columnJsonKey(link.column)] =
            link.parent.value;
      } on Object catch (e, stackTrace) {
        // A hold this build cannot read (its table or column was renamed
        // since) adds nothing to the export; the next apply drops it.
        _log.warning(
          'Held ${link.table} link skipped in export',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return HeldExportFilter(byTable);
  }

  /// Holds the link [fk] of [table]'s row [rowid] before the repair clears
  /// it. A link to a parent this device knows was deleted is not held: the
  /// clear is the deletion, and every device makes the same one.
  Future<HeldReferences> holdLink(
    HeldReferences held,
    String table,
    int rowid,
    HeldForeignKey fk,
  ) async {
    final row = await _readByRowid(table, rowid);
    final value = row?[fk.from];
    if (row == null ||
        value == null ||
        await _isTombstoned(fk.parent, {fk.to: value})) {
      return held;
    }
    final link = HeldLink(
      table: table,
      key: await _keyOf(table, row),
      column: fk.from,
      parent: HeldParent(table: fk.parent, column: fk.to, value: value),
      hlc: row['hlc'] as String?,
    );
    return HeldReferences(
      links: {...held.links, link.id: link},
      orphans: held.orphans,
    );
  }

  /// Holds [table]'s row [rowid], and every row its delete cascades to,
  /// before the repair deletes it for lack of the parent [fk] names. Links
  /// the delete clears (`ON DELETE SET NULL`) are held as links to it.
  Future<HeldReferences> holdOrphan(
    HeldReferences held,
    String table,
    int rowid,
    HeldForeignKey fk,
  ) async {
    final row = await _readByRowid(table, rowid);
    final value = row?[fk.from];
    if (row == null ||
        value == null ||
        await _isTombstoned(fk.parent, {fk.to: value})) {
      return held;
    }
    final captured = await _capture(table, rowid, row, _Captured.none);
    final orphan = HeldOrphan(
      table: table,
      key: await _keyOf(table, row),
      parent: HeldParent(table: fk.parent, column: fk.to, value: value),
      rows: captured.rows,
    );
    return HeldReferences(
      links: {...held.links, for (final link in captured.links) link.id: link},
      orphans: {...held.orphans, orphan.id: orphan},
    );
  }

  /// Gives back every held row whose parent now exists, and drops the holds
  /// a later write settled. Returns what is still held and the tables it
  /// wrote. Marks nothing pending and stamps no clock: the peer that wrote
  /// the row still holds it as restored, so this only brings this device
  /// back in line with it.
  Future<({HeldReferences held, Set<String> tables})> restoreArrived(
    HeldReferences held,
    IncomingCopies notes,
  ) async {
    if (held.isEmpty) return (held: held, tables: <String>{});
    final tables = <String>{};
    final orphans = {...held.orphans};
    // An orphan can wait for another orphan (a NO ACTION child of a deleted
    // row), so this repeats until a pass restores nothing.
    var restoredAny = true;
    while (restoredAny) {
      restoredAny = false;
      for (final orphan in orphans.values.toList()) {
        final outcome = await _guarded(
          orphan.table,
          () => _settleOrphan(orphan),
        );
        if (outcome == _Outcome.keep) continue;
        orphans.remove(orphan.id);
        if (outcome == _Outcome.restored) {
          restoredAny = true;
          tables.addAll(orphan.rows.map((r) => r.table));
        }
      }
    }
    final localNode = await _localNodeId();
    final links = <String, HeldLink>{};
    for (final link in held.links.values) {
      final settled = await _guarded(
        link.table,
        () => _settleLink(link, notes, localNode),
        dropped: (outcome: _Outcome.drop, link: link),
      );
      switch (settled.outcome) {
        case _Outcome.keep:
          links[link.id] = settled.link;
        case _Outcome.restored:
          tables.add(link.table);
        case _Outcome.drop:
          break;
      }
    }
    return (
      held: HeldReferences(links: links, orphans: orphans),
      tables: tables,
    );
  }

  /// [settle], or [dropped] when it throws: a hold this build cannot act on
  /// (its table or column was renamed or dropped by a later schema) is let
  /// go rather than failing every apply after it.
  Future<T> _guarded<T>(
    String table,
    Future<T> Function() settle, {
    T? dropped,
  }) async {
    try {
      return await settle();
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Held $table reference dropped: it no longer fits this database',
        error: e,
        stackTrace: stackTrace,
      );
      return dropped ?? (_Outcome.drop as T);
    }
  }

  /// Whether to keep holding [link] (and as what), or that it was written
  /// back, or that a later write settled it.
  Future<({_Outcome outcome, HeldLink link})> _settleLink(
    HeldLink link,
    IncomingCopies notes,
    String? localNode,
  ) async {
    final hasClock = await _schema.hasClock(link.table);
    final row = await _readRow(link.table, link.key, [
      link.column,
      if (hasClock) 'hlc',
    ]);
    // Gone, or set again by a write since: nothing left to give back.
    if (row == null || row.data[link.column] != null) {
      return (outcome: _Outcome.drop, link: link);
    }
    var kept = link;
    final hlc = hasClock ? row.data['hlc'] as String? : null;
    if (hlc != link.hlc) {
      if (_isMintedBy(hlc, localNode)) {
        // This device's own edit: its export carried the held value, so the
        // other devices still hold the link.
        kept = link.withHlc(hlc);
      } else {
        // Another device's copy. One that carried the column decides it
        // (a copy naming the same missing parent is held again by the repair
        // after this); one that left it out, from a build that does not know
        // the column, does not. A write no note explains is taken as
        // deciding it.
        final copy = notes.find(link.rowId, hlc);
        if (copy == null || copy.keys.contains(columnJsonKey(link.column))) {
          return (outcome: _Outcome.drop, link: link);
        }
        kept = link.withHlc(hlc);
      }
    }
    if (!await _exists(link.parent.table, {
      link.parent.column: link.parent.value,
    })) {
      // Only a parent that is missing can be gone for good.
      return await _isTombstoned(link.parent.table, {
            link.parent.column: link.parent.value,
          })
          ? (outcome: _Outcome.drop, link: link)
          : (outcome: _Outcome.keep, link: kept);
    }
    final where = _where(link.key);
    await _db.customStatement(
      'UPDATE "${link.table}" SET "${link.column}" = ? WHERE ${where.sql}',
      [link.parent.value, ...where.args],
    );
    return (outcome: _Outcome.restored, link: kept);
  }

  Future<_Outcome> _settleOrphan(HeldOrphan orphan) async {
    // A copy that arrived since decides the row.
    if (await _exists(orphan.table, orphan.key)) return _Outcome.drop;
    final root = orphan.rows.isEmpty ? orphan.key : orphan.rows.first.values;
    if (await _isTombstoned(orphan.table, root)) return _Outcome.drop;
    if (!await _exists(orphan.parent.table, {
      orphan.parent.column: orphan.parent.value,
    })) {
      // Only a parent that is missing can be gone for good.
      return await _isTombstoned(orphan.parent.table, {
            orphan.parent.column: orphan.parent.value,
          })
          ? _Outcome.drop
          : _Outcome.keep;
    }
    // All or nothing: a row that no longer fits (a unique key another row
    // took) keeps the whole orphan held, so nothing beneath it is lost.
    await _db.customStatement('SAVEPOINT $_restoreSavepoint');
    try {
      for (final row in orphan.rows) {
        final key = {
          for (final column in await _schema.keyColumns(row.table))
            column: row.values[column],
        };
        if (await _exists(row.table, key)) continue;
        if (await _isTombstoned(row.table, row.values)) continue;
        final columns = row.values.keys.toList();
        await _db.customStatement(
          'INSERT INTO "${row.table}" '
          '(${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')})',
          [for (final c in columns) row.values[c]],
        );
      }
      await _db.customStatement('RELEASE $_restoreSavepoint');
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not restore a held ${orphan.table} row; still held',
        error: e,
        stackTrace: stackTrace,
      );
      await _db.customStatement('ROLLBACK TO $_restoreSavepoint');
      await _db.customStatement('RELEASE $_restoreSavepoint');
      return _Outcome.keep;
    }
    return _Outcome.restored;
  }

  /// [so] with [row] and, depth first, every row an `ON DELETE CASCADE`
  /// from it reaches, each after its parent. A link `ON DELETE SET NULL`
  /// clears joins the links instead. Visited rows guard against a cycle.
  Future<_Captured> _capture(
    String table,
    int rowid,
    Map<String, Object?> row,
    _Captured so,
  ) async {
    final visit = '$table|$rowid';
    if (so.visited.contains(visit)) return so;
    var captured = _Captured(
      rows: [
        ...so.rows,
        HeldRow(table: table, values: row),
      ],
      links: so.links,
      visited: {...so.visited, visit},
    );
    for (final fk in await _schema.childrenOf(table)) {
      final value = row[fk.to];
      if (value == null) continue;
      final children = await _db
          .customSelect(
            'SELECT rowid AS "$_rowidAlias", * FROM "${fk.table}" '
            'WHERE "${fk.from}" = ?',
            variables: [_variable(value)],
          )
          .get();
      for (final child in children) {
        final childRowid = child.data[_rowidAlias] as int;
        final values = _withoutRowidAlias(child.data);
        if (fk.onDelete == 'CASCADE') {
          captured = await _capture(fk.table, childRowid, values, captured);
        } else if (fk.onDelete == 'SET NULL') {
          final link = HeldLink(
            table: fk.table,
            key: await _keyOf(fk.table, values),
            column: fk.from,
            parent: HeldParent(table: table, column: fk.to, value: value),
            hlc: values['hlc'] as String?,
          );
          captured = _Captured(
            rows: captured.rows,
            links: [...captured.links, link],
            visited: captured.visited,
          );
        }
        // Any other action leaves the child naming a missing row, and the
        // repair's next pass holds it in turn.
      }
    }
    return captured;
  }

  static const _rowidAlias = '__held_rowid';
  static const _restoreSavepoint = 'held_orphan_restore';

  Map<String, Object?> _withoutRowidAlias(Map<String, Object?> data) => {
    for (final e in data.entries)
      if (e.key != _rowidAlias) e.key: e.value,
  };

  Future<Map<String, Object?>?> _readByRowid(String table, int rowid) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM "$table" WHERE rowid = ?',
          variables: [Variable.withInt(rowid)],
        )
        .getSingleOrNull();
    return row?.data;
  }

  Future<QueryRow?> _readRow(
    String table,
    Map<String, Object?> key,
    List<String> columns,
  ) {
    final where = _where(key);
    return _db
        .customSelect(
          'SELECT ${columns.map((c) => '"$c"').join(', ')} FROM "$table" '
          'WHERE ${where.sql}',
          variables: [for (final arg in where.args) _variable(arg)],
        )
        .getSingleOrNull();
  }

  Future<bool> _exists(String table, Map<String, Object?> key) async {
    final where = _where(key);
    final row = await _db
        .customSelect(
          'SELECT 1 FROM "$table" WHERE ${where.sql} LIMIT 1',
          variables: [for (final arg in where.args) _variable(arg)],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<Map<String, Object?>> _keyOf(
    String table,
    Map<String, Object?> row,
  ) async => {
    for (final column in await _schema.keyColumns(table)) column: row[column],
  };

  /// Whether some device deleted the row of [table] that [values] (SQL
  /// column values, its key at least) name: such a row never comes back.
  /// Matched by entity type and record id, as the deletion log keys it, so
  /// a composite-key row counts and an unrelated row sharing an id does not.
  Future<bool> _isTombstoned(String table, Map<String, Object?> values) async {
    final entityType = _entityTypeOf(table);
    if (entityType == null) return false;
    final String? recordId;
    try {
      recordId = syncRecordId(entityType, {
        for (final e in values.entries) columnJsonKey(e.key): e.value,
      });
    } on TypeError {
      // A key this build's record ids cannot be made from (not a string):
      // no tombstone can name it.
      return false;
    }
    if (recordId == null) return false;
    final row = await _db
        .customSelect(
          'SELECT 1 FROM deletion_log WHERE entity_type = ? AND record_id = ? '
          'LIMIT 1',
          variables: [
            Variable.withString(entityType),
            Variable.withString(recordId),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<String?> _localNodeId() async {
    final row = await _db
        .customSelect("SELECT device_id FROM sync_metadata WHERE id = 'global'")
        .getSingleOrNull();
    return row?.read<String?>('device_id');
  }

  static bool _isMintedBy(String? hlc, String? nodeId) {
    if (hlc == null || nodeId == null) return false;
    try {
      return Hlc.parse(hlc).nodeId == nodeId;
    } on FormatException {
      return false;
    }
  }

  static ({String sql, List<Object?> args}) _where(Map<String, Object?> key) {
    final columns = key.keys.toList()..sort();
    return (
      sql: columns.map((c) => '"$c" IS ?').join(' AND '),
      args: [for (final c in columns) key[c]],
    );
  }

  static Variable<Object> _variable(Object? value) => Variable<Object>(value);
}

enum _Outcome { keep, drop, restored }

/// The rows and links one orphan's capture has gathered so far.
class _Captured {
  const _Captured({
    required this.rows,
    required this.links,
    required this.visited,
  });

  static const none = _Captured(rows: [], links: [], visited: {});

  final List<HeldRow> rows;
  final List<HeldLink> links;

  /// `table|rowid` of each row already read.
  final Set<String> visited;
}
