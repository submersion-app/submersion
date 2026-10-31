import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';

/// Manual saves on one record this close together are one entry.
const Duration kChangeLogManualGroupWindow = Duration(seconds: 5);

/// Turns raw trigger events into the operations the diver sees (issue
/// #3922). Runs on its own, never inside a save, so a failure here cannot
/// affect one; unsettled events are simply tried again.
class ChangeLogSettler {
  ChangeLogSettler(this._db)
    : _specs = {for (final spec in changeLogSpecsFor(_db)) spec.table: spec};

  final AppDatabase _db;
  final Map<String, ChangeLogTableSpec> _specs;

  /// Settles up to [batch] events, oldest first, and returns how many.
  Future<int> settle({int batch = 500}) async {
    final settled = await _db.transaction(
      () => _SettlePass(_db, _specs).run(batch),
    );
    if (settled > 0) {
      _db.notifyUpdates({
        TableUpdate.onTable(_db.changeLogOperations, kind: UpdateKind.update),
      });
    }
    return settled;
  }
}

typedef _Root = ({String table, String id});

class _Event {
  _Event(Map<String, Object?> row)
    : id = row['id']! as int,
      operationId = row['operation_id'] as String?,
      table = row['table_name']! as String,
      recordId = row['record_id']! as String,
      action = row['action']! as String,
      changedAt = row['changed_at']! as int;

  final int id;
  final String? operationId;
  final String table;
  final String recordId;
  final String action;
  final int changedAt;
}

/// An operation while it is being settled. Written back when the pass ends.
class _Operation {
  _Operation({
    required this.id,
    required this.source,
    required this.label,
    required this.diverId,
    required this.rootTable,
    required this.rootId,
    required this.rootLabel,
    required this.rootOrdinal,
    required this.startedAt,
    required this.endedAt,
    required this.hasEvents,
  });

  _Operation.fromRow(Map<String, Object?> row)
    : this(
        id: row['id']! as String,
        source: row['source']! as String,
        label: row['label'] as String?,
        diverId: row['diver_id'] as String?,
        rootTable: row['root_table'] as String?,
        rootId: row['root_id'] as String?,
        rootLabel: row['root_label'] as String?,
        rootOrdinal: row['root_ordinal'] as int?,
        startedAt: row['started_at']! as int,
        endedAt: row['ended_at']! as int,
        hasEvents: (row['event_count']! as int) > 0,
      );

  final String id;
  final String source;
  final String? label;
  String? diverId;
  String? rootTable;
  String? rootId;
  String? rootLabel;
  int? rootOrdinal;
  int startedAt;
  int endedAt;

  /// False until the first event, which is what tells "no root yet" from
  /// "touched several roots", both of which leave [rootId] null.
  bool hasEvents;

  /// A save with no scope. A labelled bulk action is manual too, but it is
  /// over when it ends, so the next save does not join it.
  bool get isPlainSave =>
      source == ChangeLogSource.manual.name && label == null;

  bool hasRoot(_Root root) => rootTable == root.table && rootId == root.id;
}

class _SettlePass {
  _SettlePass(this._db, this._specs);

  final AppDatabase _db;
  final Map<String, ChangeLogTableSpec> _specs;

  final _operations = <String, _Operation>{};
  final _latestManual = <_Root, _Operation>{};
  final _columns = <String, Object?>{};

  Future<int> run(int batch) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM change_log_events WHERE settled = 0 '
          'ORDER BY id LIMIT ?',
          variables: [Variable.withInt(batch)],
        )
        .get();
    for (final row in rows) {
      await _settle(_Event(row.data));
    }
    await _writeOperations();
    await _deleteEmptyOperations();
    return rows.length;
  }

  Future<void> _settle(_Event event) async {
    final root = await _rootOf(event);

    // Machine rows are kept only to bring back a deleted record. While the
    // record lives, a sweep replacing them is nothing the diver did.
    if (changeLogTables[event.table] == ChangeLogClass.deleteCopyOnly &&
        await _exists(root) &&
        !await _machineOwnerGone(event)) {
      await _deleteEvents([event.id]);
      return;
    }

    final owner = await _ownerOf(root);
    final operation = await _operationFor(event, root, owner);

    if (event.action == 'I' && await _foldReplace(event, operation)) {
      await _note(operation, event, root, owner);
      return;
    }
    if (event.action == 'D' && await _cancelInsert(event, operation)) return;

    await _db.customStatement(
      'UPDATE change_log_events SET operation_id = ?, settled = 1, '
      'root_table = ?, root_id = ? WHERE id = ?',
      [operation.id, root.table, root.id, event.id],
    );
    await _note(operation, event, root, owner);
  }

  /// Adds [event] to the in-memory [operation].
  Future<void> _note(
    _Operation operation,
    _Event event,
    _Root root,
    String? owner,
  ) async {
    operation.diverId ??= owner;
    if (!operation.hasEvents) {
      final label = await _labelOf(root);
      operation
        ..rootTable = root.table
        ..rootId = root.id
        ..rootLabel = label.label
        ..rootOrdinal = label.ordinal
        ..startedAt = event.changedAt
        ..hasEvents = true;
    } else if (!operation.hasRoot(root)) {
      operation
        ..rootTable = null
        ..rootId = null
        ..rootLabel = null
        ..rootOrdinal = null;
    }
    if (event.changedAt > operation.endedAt || operation.isPlainSave) {
      operation.endedAt = event.changedAt;
    }
    if (operation.isPlainSave) _latestManual[root] = operation;
  }

  /// The operation [event] belongs to, by its scope or by the manual window.
  Future<_Operation> _operationFor(
    _Event event,
    _Root root,
    String? owner,
  ) async {
    final scopeId = event.operationId;
    if (scopeId != null) {
      final scope = await _loadOperation(scopeId);
      if (scope != null) return _forOwner(scope, owner);
    }

    final latest = _latestManual[root] ?? await _loadLatestManual(root);
    if (latest != null) {
      final gap = event.changedAt - latest.endedAt;
      if (gap >= 0 && gap <= kChangeLogManualGroupWindow.inMilliseconds) {
        return latest;
      }
    }
    return _createManual(event);
  }

  /// A feed shows one diver's entries, so a scope that touched two divers'
  /// records, as a sync pull can, is filed as one operation each.
  Future<_Operation> _forOwner(_Operation scope, String? owner) async {
    if (owner == null || scope.diverId == null || scope.diverId == owner) {
      return scope;
    }
    final id = '${scope.id}:$owner';
    final existing = await _loadOperation(id);
    if (existing != null) return existing;

    await _db.customStatement(
      'INSERT INTO change_log_operations (id, source, label, device_id, '
      'diver_id, started_at, ended_at, closed, revert_of_id) '
      'SELECT ?, source, label, device_id, ?, started_at, ended_at, 1, '
      'revert_of_id FROM change_log_operations WHERE id = ?',
      [id, owner, scope.id],
    );
    return (await _loadOperation(id))!;
  }

  Future<_Operation?> _loadOperation(String id) async {
    final cached = _operations[id];
    if (cached != null) return cached;
    final row = await _db
        .customSelect(
          'SELECT * FROM change_log_operations WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return _operations[id] = _Operation.fromRow(row.data);
  }

  Future<_Operation?> _loadLatestManual(_Root root) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM change_log_operations WHERE source = ? '
          'AND label IS NULL AND root_table = ? AND root_id = ? '
          'ORDER BY last_event_id DESC LIMIT 1',
          variables: [
            Variable.withString(ChangeLogSource.manual.name),
            Variable.withString(root.table),
            Variable.withString(root.id),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final id = row.data['id']! as String;
    return _operations[id] ??= _Operation.fromRow(row.data);
  }

  Future<_Operation> _createManual(_Event event) async {
    final id = const Uuid().v4();
    await _db
        .into(_db.changeLogOperations)
        .insert(
          ChangeLogOperationsCompanion.insert(
            id: id,
            source: ChangeLogSource.manual.name,
            startedAt: event.changedAt,
            endedAt: event.changedAt,
            closed: const Value(true),
          ),
        );
    return (await _loadOperation(id))!;
  }

  /// With recursive triggers on, `INSERT OR REPLACE` arrives as a delete and
  /// an insert. When [event] is that insert, turns the pair into one update
  /// of the columns that really differ, or into nothing. The insert's values
  /// come from the live row, since an insert event carries none. Returns
  /// false when this is a real insert, or the row has since gone, in which
  /// case the later delete cancels it.
  Future<bool> _foldReplace(_Event event, _Operation operation) async {
    final delete = await _db
        .customSelect(
          'SELECT id FROM change_log_events WHERE operation_id = ? '
          "AND table_name = ? AND record_id = ? AND action = 'D' AND id < ? "
          'ORDER BY id DESC LIMIT 1',
          variables: [
            Variable.withString(operation.id),
            Variable.withString(event.table),
            Variable.withString(event.recordId),
            Variable.withInt(event.id),
          ],
        )
        .getSingleOrNull();
    if (delete == null) return false;
    final deleteId = delete.read<int>('id');

    final spec = _specs[event.table];
    if (spec == null) return false;
    final match = changeLogKeyMatch(spec, event.recordId);
    final live = await _db
        .customSelect(
          'SELECT * FROM "${spec.table}" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingleOrNull();
    if (live == null) return false;

    final copy = await _db
        .customSelect(
          'SELECT column_name, old_value FROM change_log_fields '
          'WHERE event_id = ?',
          variables: [Variable.withInt(deleteId)],
        )
        .get();
    final old = {
      for (final row in copy)
        row.data['column_name']! as String: row.data['old_value'],
    };

    final ignored = changeLogIgnoredColumns(spec.table);
    final changes = [
      for (final column in spec.columns)
        if (!ignored.contains(column) &&
            !const DeepCollectionEquality().equals(
              old[column],
              live.data[column],
            ))
          (column, old[column], live.data[column]),
    ];

    await _deleteEvents([deleteId]);
    if (changes.isEmpty) {
      await _deleteEvents([event.id]);
      return true;
    }
    for (final (column, before, after) in changes) {
      await _db.customStatement(
        'INSERT INTO change_log_fields '
        '(event_id, column_name, old_value, new_value) VALUES (?, ?, ?, ?)',
        [event.id, column, before, after],
      );
    }
    final root = await _rootOf(event);
    await _db.customStatement(
      "UPDATE change_log_events SET action = 'U', operation_id = ?, "
      'settled = 1, root_table = ?, root_id = ? WHERE id = ?',
      [operation.id, root.table, root.id, event.id],
    );
    return true;
  }

  /// A record created and deleted in one operation never happened as far as
  /// the diver is concerned, so its events all go. Returns false when
  /// [event] deletes a record that existed before the operation.
  Future<bool> _cancelInsert(_Event event, _Operation operation) async {
    final insert = await _db
        .customSelect(
          'SELECT id FROM change_log_events WHERE operation_id = ? '
          "AND table_name = ? AND record_id = ? AND action = 'I' AND id < ? "
          'ORDER BY id DESC LIMIT 1',
          variables: [
            Variable.withString(operation.id),
            Variable.withString(event.table),
            Variable.withString(event.recordId),
            Variable.withInt(event.id),
          ],
        )
        .getSingleOrNull();
    if (insert == null) return false;

    final between = await _db
        .customSelect(
          'SELECT id FROM change_log_events WHERE operation_id = ? '
          'AND table_name = ? AND record_id = ? AND id >= ? AND id <= ?',
          variables: [
            Variable.withString(operation.id),
            Variable.withString(event.table),
            Variable.withString(event.recordId),
            Variable.withInt(insert.read<int>('id')),
            Variable.withInt(event.id),
          ],
        )
        .get();
    await _deleteEvents([
      for (final row in between) row.read<int>('id'),
      event.id,
    ]);
    return true;
  }

  Future<void> _deleteEvents(List<int> ids) async {
    final marks = List.filled(ids.length, '?').join(', ');
    await _db.customStatement(
      'DELETE FROM change_log_fields WHERE event_id IN ($marks)',
      ids,
    );
    await _db.customStatement(
      'DELETE FROM change_log_events WHERE id IN ($marks)',
      ids,
    );
  }

  /// Walks [changeLogParents] from the event's record until a table has no
  /// parent, or a row has none.
  Future<_Root> _rootOf(_Event event) async {
    var table = event.table;
    var id = event.recordId;
    while (true) {
      final parent = changeLogParents[table];
      if (parent == null) break;
      final value = await _columnOf(table, id, parent.column);
      if (value is! String) break;
      table = parent.rootTable;
      id = value;
    }
    return (table: table, id: id);
  }

  Future<String?> _ownerOf(_Root root) async {
    if (root.table == 'divers') return root.id;
    return await _columnOf(root.table, root.id, 'diver_id') as String?;
  }

  Future<({String? label, int? ordinal})> _labelOf(_Root root) async {
    if (root.table == 'dives') {
      final site = await _columnOf('dives', root.id, 'site_id');
      return (
        label: site is String
            ? await _columnOf('dive_sites', site, 'name') as String?
            : null,
        ordinal: await _columnOf('dives', root.id, 'dive_number') as int?,
      );
    }
    final spec = _specs[root.table];
    for (final column in const ['name', 'title', 'label', 'display_name']) {
      if (spec != null && spec.columns.contains(column)) {
        final value = await _columnOf(root.table, root.id, column);
        return (label: value is String ? value : null, ordinal: null);
      }
    }
    return (label: null, ordinal: null);
  }

  /// Whether the row a machine row belongs to, other than its root, has gone.
  Future<bool> _machineOwnerGone(_Event event) async {
    final owners = changeLogMachineOwners[event.table];
    if (owners == null) return false;
    for (final MapEntry(key: column, value: table) in owners.entries) {
      final owner = await _columnOf(event.table, event.recordId, column);
      if (owner is String && !await _exists((table: table, id: owner))) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _exists(_Root root) async {
    final spec = _specs[root.table];
    if (spec == null) return false;
    final match = changeLogKeyMatch(spec, root.id);
    final row = await _db
        .customSelect(
          'SELECT 1 FROM "${spec.table}" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingleOrNull();
    return row != null;
  }

  /// One column of a record: from the row, or from the newest delete copy
  /// when the row has gone, so a deleted record still resolves.
  Future<Object?> _columnOf(String table, String id, String column) async {
    final spec = _specs[table];
    if (spec == null || !spec.columns.contains(column)) return null;
    final key = '$table|$id|$column';
    if (_columns.containsKey(key)) return _columns[key];

    final match = changeLogKeyMatch(spec, id);
    final live = await _db
        .customSelect(
          'SELECT "$column" AS v FROM "$table" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingleOrNull();
    if (live != null) return _columns[key] = live.data['v'];

    final copy = await _db
        .customSelect(
          'SELECT f.old_value AS v FROM change_log_events e '
          'JOIN change_log_fields f ON f.event_id = e.id '
          "WHERE e.table_name = ? AND e.record_id = ? AND e.action = 'D' "
          'AND f.column_name = ? ORDER BY e.id DESC LIMIT 1',
          variables: [
            Variable.withString(table),
            Variable.withString(id),
            Variable.withString(column),
          ],
        )
        .getSingleOrNull();
    return _columns[key] = copy?.data['v'];
  }

  Future<void> _writeOperations() async {
    for (final operation in _operations.values) {
      await _db.customStatement(
        'UPDATE change_log_operations SET diver_id = ?2, root_table = ?3, '
        'root_id = ?4, root_label = ?5, root_ordinal = ?6, started_at = ?7, '
        'ended_at = ?8, '
        'event_count = (SELECT COUNT(*) FROM change_log_events '
        'WHERE operation_id = ?1), '
        'last_event_id = (SELECT MAX(id) FROM change_log_events '
        'WHERE operation_id = ?1) '
        'WHERE id = ?1',
        [
          operation.id,
          operation.diverId,
          operation.rootTable,
          operation.rootId,
          operation.rootLabel,
          operation.rootOrdinal,
          operation.startedAt,
          operation.endedAt,
        ],
      );
    }
  }

  /// A finished operation that ended up with no events, and a job killed
  /// before it could finish that never wrote any. A summary has none by
  /// design.
  Future<void> _deleteEmptyOperations() async {
    final abandoned =
        DateTime.now().millisecondsSinceEpoch -
        const Duration(days: 1).inMilliseconds;
    await _db.customStatement(
      'DELETE FROM change_log_operations WHERE summary_count IS NULL '
      'AND (closed = 1 OR ended_at < ?) '
      'AND NOT EXISTS (SELECT 1 FROM change_log_events e '
      'WHERE e.operation_id = change_log_operations.id)',
      [abandoned],
    );
  }
}
