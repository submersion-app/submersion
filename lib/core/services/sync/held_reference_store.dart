import 'package:drift/drift.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/held_reference_schema.dart';
import 'package:submersion/core/services/sync/held_references.dart';
import 'package:submersion/core/services/sync/hlc.dart';

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
  final Map<String, List<IncomingCopy>> _byRow = {};

  void add(String rowId, IncomingCopy copy) => (_byRow[rowId] ??= []).add(copy);

  /// The copy of [rowId] whose clock is [hlc], if one was seen.
  IncomingCopy? find(String rowId, String? hlc) {
    for (final copy in _byRow[rowId] ?? const <IncomingCopy>[]) {
      if (copy.hlc == hlc) return copy;
    }
    return null;
  }

  void clear() => _byRow.clear();
}

/// Removes held link columns from this device's exported rows.
class HeldExportFilter {
  const HeldExportFilter(this._byTable);

  static const none = HeldExportFilter({});

  /// SQL table to (primary key columns, row id to wire keys left out).
  final Map<String, ({List<String> keyColumns, Map<String, Set<String>> keys})>
  _byTable;

  bool get isEmpty => _byTable.isEmpty;

  bool covers(String table) => _byTable.containsKey(table);

  /// [row], a wire row of [table], without the keys of a link this device
  /// still holds; [row] itself when it has none. The receiver then keeps its
  /// own value, as it does for any key a peer leaves out.
  Map<String, dynamic> strip(String table, Map<String, dynamic> row) {
    final entry = _byTable[table];
    if (entry == null) return row;
    final rowId = heldRowId(table, {
      for (final column in entry.keyColumns) column: row[columnJsonKey(column)],
    });
    final keys = entry.keys[rowId];
    if (keys == null) return row;
    return {
      for (final e in row.entries)
        if (!keys.contains(e.key)) e.key: e.value,
    };
  }
}

/// Reads and writes this device's held references (issue #4954). Every
/// method runs inside the apply's deferred-FK transaction, so a hold and the
/// repair that made it commit or roll back together.
class HeldReferenceStore {
  HeldReferenceStore(this._db);

  final GeneratedDatabase _db;

  HeldSchema get _schema => HeldSchema.of(_db);

  Future<HeldReferences> load() async {
    final row = await _db
        .customSelect(
          'SELECT value FROM settings WHERE key = ?',
          variables: [Variable.withString(heldReferencesSettingsKey)],
        )
        .getSingleOrNull();
    try {
      return HeldReferences.decode(row?.read<String?>('value'));
    } on Object catch (e, stackTrace) {
      // A hold that cannot be read restores nothing; the rows keep the
      // repair's result, as they did before holds existed.
      _log.warning(
        'Unreadable held references dropped',
        error: e,
        stackTrace: stackTrace,
      );
      return const HeldReferences();
    }
  }

  Future<void> save(HeldReferences held) async {
    if (held.isEmpty) {
      await _db.customStatement('DELETE FROM settings WHERE key = ?', [
        heldReferencesSettingsKey,
      ]);
      return;
    }
    await _db.customStatement(
      'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, '
      'updated_at = excluded.updated_at',
      [
        heldReferencesSettingsKey,
        held.encode(),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// Notes the copies in [records], wire rows of [table], of rows this
  /// device holds a link for.
  Future<void> noteIncoming(
    IncomingCopies notes,
    String table,
    Iterable<Map<String, dynamic>> records,
  ) async {
    final held = await load();
    final rowIds = {
      for (final link in held.links.values)
        if (link.table == table) link.rowId,
    };
    if (rowIds.isEmpty) return;
    final keyColumns = await _schema.keyColumns(table);
    for (final record in records) {
      final rowId = heldRowId(table, {
        for (final column in keyColumns) column: record[columnJsonKey(column)],
      });
      if (!rowIds.contains(rowId)) continue;
      final hlc = record['hlc'];
      notes.add(
        rowId,
        IncomingCopy(
          hlc: hlc is String ? hlc : null,
          keys: record.keys.toSet(),
        ),
      );
    }
  }

  /// The filter that keeps this device's held links off the wire: a link
  /// still cleared here goes out without its column.
  Future<HeldExportFilter> exportFilter() async {
    final held = await load();
    if (held.links.isEmpty) return HeldExportFilter.none;
    final byTable =
        <String, ({List<String> keyColumns, Map<String, Set<String>> keys})>{};
    for (final link in held.links.values) {
      final row = await _readRow(link.table, link.key, [link.column]);
      if (row == null || row.data[link.column] != null) continue;
      final entry = byTable[link.table] ??= (
        keyColumns: await _schema.keyColumns(link.table),
        keys: {},
      );
      (entry.keys[link.rowId] ??= {}).add(columnJsonKey(link.column));
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
    if (row == null || value == null || await _isTombstoned(value)) {
      return held;
    }
    final link = HeldLink(
      table: table,
      key: await _keyOf(table, row),
      column: fk.from,
      parent: HeldParent(table: fk.parent, column: fk.to, value: value),
      hlc: row['hlc'] as String?,
    );
    return HeldReferences(links: {...held.links, link.id: link});
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
    final localNode = await _localNodeId();
    final links = <String, HeldLink>{};
    for (final link in held.links.values) {
      final settled = await _settleLink(link, notes, localNode);
      switch (settled.outcome) {
        case _Outcome.keep:
          links[link.id] = settled.link;
        case _Outcome.restored:
          tables.add(link.table);
        case _Outcome.drop:
          break;
      }
    }
    return (held: HeldReferences(links: links), tables: tables);
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
    if (row == null ||
        row.data[link.column] != null ||
        await _isTombstoned(link.parent.value)) {
      return (outcome: _Outcome.drop, link: link);
    }
    var kept = link;
    final hlc = hasClock ? row.data['hlc'] as String? : null;
    if (hlc != link.hlc) {
      if (_isMintedBy(hlc, localNode)) {
        // This device's own edit: it left the column out of its export, so
        // the other devices still hold the link.
        kept = link.withHlc(hlc);
      } else {
        // Another device's copy. One that carried the column decides it; one
        // that left it out (a peer holding the same link) does not. A write
        // no note explains is taken as deciding it.
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
      return (outcome: _Outcome.keep, link: kept);
    }
    final where = _where(link.key);
    await _db.customStatement(
      'UPDATE "${link.table}" SET "${link.column}" = ? WHERE ${where.sql}',
      [link.parent.value, ...where.args],
    );
    return (outcome: _Outcome.restored, link: kept);
  }

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

  /// A parent some device deleted is never coming back.
  Future<bool> _isTombstoned(Object value) async {
    if (value is! String) return false;
    final row = await _db
        .customSelect(
          'SELECT 1 FROM deletion_log WHERE record_id = ? LIMIT 1',
          variables: [Variable.withString(value)],
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
