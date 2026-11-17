import 'package:drift/drift.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_shared_view.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_sql.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

const int _settleBatch = 500;

/// How long one settle pass may hold the database.
const Duration _settleBudget = Duration(milliseconds: 100);

/// How much of an entry a preview reads. An entry about one record is small.
const int _previewEvents = 200;

/// Reads the change log (issue #3922). The raw value columns keep their
/// SQLite type, so everything here goes through `customSelect` and
/// `row.data` rather than the generated row classes.
class ChangeLogRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(ChangeLogRepository);

  /// Emits whenever an entry is added, changed or removed.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.changeLogOperations));

  /// Settles everything waiting. A failure is logged and tried again later.
  ///
  /// Each pass is one transaction that ends after [budget], so a long
  /// backlog (the first sync of a library) does not hold the database
  /// while the rest of the app waits on it (#4186). Every event a pass
  /// takes is settled or deleted, so passes run until one finds nothing.
  ///
  /// A call while a settle runs joins it rather than starting another: each
  /// pass announces its entries, the open feed rebuilds on that and settles
  /// again in the rebuild, and a backlog of many passes started a loop per
  /// pass.
  Future<void> settleAll({Duration budget = _settleBudget}) {
    final db = _db;
    final running = _settling;
    if (running != null && identical(running.db, db)) return running.run;
    late final Future<void> run;
    run = _settleAll(budget).whenComplete(() {
      if (identical(_settling?.run, run)) _settling = null;
    });
    _settling = (db: db, run: run);
    return run;
  }

  /// The settle running now and the database it settles, shared by every
  /// repository: a call joins it only on the same database.
  static ({AppDatabase db, Future<void> run})? _settling;

  Future<void> _settleAll(Duration budget) async {
    try {
      final settler = ChangeLogSettler(_db);
      while (await settler.settle(batch: _settleBatch, budget: budget) > 0) {
        await Future<void>.delayed(Duration.zero);
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Could not settle the change log',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Entries [diverId] may see, newest first. Ordered by event id rather
  /// than time, because the device clock can move backwards.
  Future<List<ChangeLogOperation>> getFeed({
    required String diverId,
    required ChangeLogFilter filter,
    ChangeLogPageCursor? after,
    int limit = 50,
  }) async {
    final visible = _visibleTo(diverId);
    final where = <String>[
      '(o.event_count > 0 OR o.summary_count IS NOT NULL)',
      visible.sql,
    ];
    final variables = <Variable<Object>>[...visible.variables];

    if (filter.isRecord) {
      // An entry about the record (an editing sitting on it, issue #4527)
      // belongs in its History even when every record it changed was
      // another one, such as a document filed under a dive.
      where.add(
        '(o.id IN (SELECT operation_id FROM change_log_events '
        'WHERE root_table = ? AND root_id = ?) '
        'OR (o.root_table = ? AND o.root_id = ?))',
      );
      for (final _ in const [0, 1]) {
        variables
          ..add(Variable<Object>(filter.rootTable!))
          ..add(Variable<Object>(filter.rootId!));
      }
    }
    if (filter.rootTables.isNotEmpty) {
      final tables = filter.rootTables.toList();
      final marks = changeLogMarks(tables.length);
      // An entry another diver owns is filtered by the record it is shown
      // under for this diver ([ChangeLogSharedView]), not the one it is
      // about.
      final shown = ChangeLogSharedView.shownTable('o', diverId);
      where.add(
        'COALESCE(${shown.sql} IN ($marks), '
        '(o.root_table IN ($marks) OR (o.root_table IS NULL AND EXISTS ('
        'SELECT 1 FROM change_log_events e WHERE e.operation_id = o.id '
        'AND e.root_table IN ($marks)))))',
      );
      variables.addAll(shown.variables);
      for (final _ in const [0, 1, 2]) {
        variables.addAll(tables.map(Variable<Object>.new));
      }
    }
    if (filter.sources.isNotEmpty) {
      final marks = changeLogMarks(filter.sources.length);
      where.add('o.source IN ($marks)');
      variables.addAll(
        filter.sources.map((source) => Variable<Object>(source.name)),
      );
    }
    if (after != null) {
      where.add('(o.last_event_id < ? OR (o.last_event_id = ? AND o.id < ?))');
      variables
        ..add(Variable<Object>(after.lastEventId))
        ..add(Variable<Object>(after.lastEventId))
        ..add(Variable<Object>(after.id));
    }

    final rows = await _db
        .customSelect(
          'SELECT o.* FROM change_log_operations o '
          'WHERE ${where.join(' AND ')} '
          'ORDER BY o.last_event_id DESC, o.id DESC LIMIT ?',
          variables: [...variables, Variable<Object>(limit)],
          readsFrom: {_db.changeLogOperations},
        )
        .get();
    return ChangeLogSharedView.asSeenBy(_db, [
      for (final row in rows) _operation(row.data),
    ], diverId);
  }

  /// The active diver's own entries, entries with no owner, and entries
  /// about, or that changed, a record they see ([ChangeLogSharedView]). The
  /// last is looked for among other divers' entries only, so it never reads
  /// the diver's own history.
  static ChangeLogSql _visibleTo(String diverId) {
    final about = ChangeLogSharedView.seenRoot('o', diverId);
    final seen = ChangeLogSharedView.seenRoot('e', diverId);
    return (
      sql:
          '(o.diver_id = ? OR o.diver_id IS NULL OR ${about.sql} '
          'OR o.id IN (SELECT e.operation_id FROM change_log_events e '
          'JOIN change_log_operations eo ON eo.id = e.operation_id '
          'WHERE eo.diver_id <> ? AND ${seen.sql}))',
      variables: [
        Variable<Object>(diverId),
        ...about.variables,
        Variable<Object>(diverId),
        ...seen.variables,
      ],
    );
  }

  /// The entry as [diverId] sees it, if they may see it now.
  Future<ChangeLogOperation?> getVisibleOperation(
    String id,
    String diverId,
  ) async {
    final visible = _visibleTo(diverId);
    final row = await _db
        .customSelect(
          'SELECT o.* FROM change_log_operations o '
          'WHERE o.id = ? AND ${visible.sql}',
          variables: [Variable<String>(id), ...visible.variables],
          readsFrom: {_db.changeLogOperations},
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (await ChangeLogSharedView.asSeenBy(_db, [
      _operation(row.data),
    ], diverId)).single;
  }

  /// How many of [operationId]'s records the entry's page can list, of
  /// [onlyRoots] if given ([ChangeLogOperation.shownRoots]).
  Future<int> countEvents(
    String operationId, {
    Set<ChangeLogRoot>? onlyRoots,
  }) async {
    final listed = _listedEvent('change_log_events');
    final under = _under(onlyRoots);
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM change_log_events WHERE operation_id = ? '
          'AND ${listed.sql} ${under.sql}',
          variables: [
            Variable<String>(operationId),
            ...listed.variables,
            ...under.variables,
          ],
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// `AND` an event's root is one of [roots], or nothing when null.
  static ChangeLogSql _under(Set<ChangeLogRoot>? roots) {
    if (roots == null) return (sql: '', variables: const []);
    final each = List.filled(
      roots.length,
      '(root_table = ? AND root_id = ?)',
    ).join(' OR ');
    return (
      sql: 'AND (${roots.isEmpty ? '0' : each})',
      variables: [
        for (final root in roots) ...[
          Variable<Object>(root.table),
          Variable<Object>(root.id),
        ],
      ],
    );
  }

  Future<ChangeLogOperation?> getOperation(String id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM change_log_operations WHERE id = ?',
          variables: [Variable<String>(id)],
          readsFrom: {_db.changeLogOperations},
        )
        .getSingleOrNull();
    return row == null ? null : _operation(row.data);
  }

  /// [operationId]'s records, oldest first, those under [onlyRoots] if
  /// given ([ChangeLogOperation.shownRoots]). Machine rows are kept only to
  /// restore a deleted record, so they are left out unless asked for, all
  /// but the columns of [changeLogShownMachineColumns] a diver changes.
  Future<List<ChangeLogEvent>> getEvents(
    String operationId, {
    bool includeMachineRows = false,
    int? limit,
    Set<ChangeLogRoot>? onlyRoots,
  }) async {
    final listed = includeMachineRows
        ? null
        : _listedEvent('change_log_events');
    final under = _under(onlyRoots);
    final rows = await _db
        .customSelect(
          'SELECT * FROM change_log_events WHERE operation_id = ? '
          '${listed == null ? '' : 'AND ${listed.sql} '}${under.sql} '
          'ORDER BY id ${limit == null ? '' : 'LIMIT ?'}',
          variables: [
            Variable<String>(operationId),
            ...?listed?.variables,
            ...under.variables,
            if (limit != null) Variable<int>(limit),
          ],
        )
        .get();
    if (rows.isEmpty) return const [];

    final fields = await _fieldsByEvent(
      operationId,
      lastEventId: rows.last.read<int>('id'),
      includeMachineRows: includeMachineRows,
    );
    return [
      for (final row in rows)
        _event(row.data, fields[row.read<int>('id')] ?? const []),
    ];
  }

  static final List<String> _machineTables = [
    for (final entry in changeLogTables.entries)
      if (entry.value == ChangeLogClass.deleteCopyOnly) entry.key,
  ];

  /// `table.column` for each of [changeLogShownMachineColumns].
  static final List<String> _shownMachineColumns = [
    for (final entry in changeLogShownMachineColumns.entries)
      for (final column in entry.value) '${entry.key}.$column',
  ];

  /// Whether a field [fields].column_name of an event [events] is one of
  /// [changeLogShownMachineColumns].
  static ChangeLogSql _shownField(String events, String fields) => (
    sql:
        "($events.table_name || '.' || $fields.column_name) "
        'IN (${changeLogMarks(_shownMachineColumns.length)})',
    variables: [..._shownMachineColumns.map(Variable<Object>.new)],
  );

  /// Whether a field [fields].column_name of an event [events] is listed:
  /// any field of a logged table, and only the shown columns of a machine
  /// table.
  static ChangeLogSql _listedField(String events, String fields) {
    final shown = _shownField(events, fields);
    return (
      sql:
          '($events.table_name NOT IN (${changeLogMarks(_machineTables.length)}) '
          'OR ${shown.sql})',
      variables: [
        ..._machineTables.map(Variable<Object>.new),
        ...shown.variables,
      ],
    );
  }

  /// Whether an event [events] is listed: every event of a logged table, and
  /// a machine table's update that changed one of its shown columns.
  static ChangeLogSql _listedEvent(String events) {
    final shown = _shownField(events, 'lf');
    return (
      sql:
          '($events.table_name NOT IN (${changeLogMarks(_machineTables.length)}) '
          "OR ($events.action = 'U' AND EXISTS (SELECT 1 FROM "
          'change_log_fields lf WHERE lf.event_id = $events.id '
          'AND ${shown.sql})))',
      variables: [
        ..._machineTables.map(Variable<Object>.new),
        ...shown.variables,
      ],
    );
  }

  Future<Map<int, List<ChangeLogFieldChange>>> _fieldsByEvent(
    String operationId, {
    required int lastEventId,
    required bool includeMachineRows,
  }) async {
    final listed = includeMachineRows ? null : _listedField('e', 'f');
    final rows = await _db
        .customSelect(
          'SELECT f.*, e.table_name FROM change_log_fields f '
          'JOIN change_log_events e ON e.id = f.event_id '
          'WHERE e.operation_id = ? AND e.id <= ? '
          '${listed == null ? '' : 'AND ${listed.sql} '}'
          'ORDER BY f.event_id, f.column_name',
          variables: [
            Variable<String>(operationId),
            Variable<int>(lastEventId),
            ...?listed?.variables,
          ],
        )
        .get();
    final fields = <int, List<ChangeLogFieldChange>>{};
    for (final row in rows) {
      (fields[row.read<int>('event_id')] ??= []).add(_field(row.data));
    }
    return fields;
  }

  /// The first [perOperation] changed fields of each of [operations], and
  /// how many each has, net of repeat saves to one field. For entries about
  /// one record, which hold few events.
  ///
  /// Only fields of the entry's own record count. An editing sitting is
  /// about its record whatever else it wrote (issue #4527), and its row is
  /// titled with that record, so another record's field there (a site's
  /// altitude under a dive) would read as the record's own. The entry's
  /// page lists them all. An entry restricted to what a diver sees
  /// ([ChangeLogOperation.shownRoots]) is titled with a record they see, so
  /// it previews that record's fields.
  Future<Map<String, ChangeLogPreview>> getPreviewFields(
    List<ChangeLogOperation> operations, {
    int perOperation = 2,
  }) async {
    if (operations.isEmpty) return const {};
    final fields = <String, List<ChangeLogFieldChange>>{};
    final totals = <String, int>{};
    for (final operation in operations) {
      final id = operation.id;
      final net = [
        for (final change in netFieldChanges(
          await getEvents(id, limit: _previewEvents),
        ))
          if (_isUnder(change.event, operation)) change,
      ];
      if (net.isEmpty) continue;
      fields[id] = [for (final change in net.take(perOperation)) change.field];
      totals[id] = net.length;
    }

    final rooted = [
      for (final operation in operations)
        if (operation.rootTable != null && operation.rootId != null) operation,
    ];
    final rootEvent = List.filled(
      rooted.length,
      '(e.operation_id = ? AND e.table_name = ? AND e.record_id = ?)',
    ).join(' OR ');
    final actions = rooted.isEmpty
        ? const <QueryRow>[]
        : await _db
              .customSelect(
                'SELECT e.operation_id, e.action FROM change_log_events e '
                'WHERE $rootEvent ORDER BY e.id',
                variables: [
                  for (final operation in rooted) ...[
                    Variable<String>(operation.id),
                    Variable<String>(operation.rootTable!),
                    Variable<String>(operation.rootId!),
                  ],
                ],
              )
              .get();
    // That the record arrived or went outranks any edit around it.
    final rootActions = <String, ChangeLogAction>{};
    for (final row in actions) {
      final action = ChangeLogAction.fromCode(row.read<String>('action'));
      if (action != ChangeLogAction.update) {
        rootActions[row.read<String>('operation_id')] = action;
      }
    }

    return {
      for (final id in {...fields.keys, ...rootActions.keys})
        id: ChangeLogPreview(
          fields: fields[id] ?? const [],
          total: totals[id] ?? 0,
          rootAction: rootActions[id],
        ),
    };
  }

  /// Whether [event] changed the record [operation] is about or one of its
  /// children. An entry with no record, or an event settled without one,
  /// keeps every field.
  static bool _isUnder(ChangeLogEvent event, ChangeLogOperation operation) =>
      operation.rootTable == null ||
      event.rootTable == null ||
      (event.rootTable == operation.rootTable &&
          event.rootId == operation.rootId);

  /// How many records each of [operationIds] touched, counting a dive and
  /// its tanks as one.
  Future<Map<String, int>> getRecordCounts(List<String> operationIds) async {
    if (operationIds.isEmpty) return const {};
    final marks = changeLogMarks(operationIds.length);
    final rows = await _db
        .customSelect(
          "SELECT operation_id, COUNT(DISTINCT root_table || '|' || root_id) "
          'AS records FROM change_log_events '
          'WHERE operation_id IN ($marks) GROUP BY operation_id',
          variables: [...operationIds.map(Variable<String>.new)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('operation_id'): row.read<int>('records'),
    };
  }

  /// Looks up the records that [fields] point at, by [changeLogReferenceKey].
  /// A name is a nicety, so a failure leaves that value as it is.
  Future<Map<String, List<ConflictReference>>> resolveReferences(
    Iterable<ChangeLogFieldChange> fields,
  ) async {
    final resolver = ConflictReferenceResolver(SyncDataSerializer());
    final references = <String, List<ConflictReference>>{};
    for (final field in fields) {
      final entity = changeLogEntityType(field.table);
      final key = columnJsonKey(field.column);
      for (final value in [field.oldValue, field.newValue]) {
        if (value is! String) continue;
        final at = changeLogReferenceKey(entity, key, value);
        if (references.containsKey(at)) continue;
        try {
          final resolved = await resolver.resolve(entity, {key: value});
          if (resolved.isNotEmpty) references[at] = resolved;
        } catch (error) {
          _log.warning('Could not resolve $key: $error');
        }
      }
    }
    return references;
  }

  /// One event with its fields, without reading the rest of its operation.
  Future<ChangeLogEvent?> getEvent(int id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM change_log_events WHERE id = ? '
          'AND operation_id IS NOT NULL',
          variables: [Variable<int>(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final fields = await _db
        .customSelect(
          'SELECT f.*, e.table_name FROM change_log_fields f '
          'JOIN change_log_events e ON e.id = f.event_id '
          'WHERE f.event_id = ? ORDER BY f.column_name',
          variables: [Variable<int>(id)],
        )
        .get();
    return _event(row.data, [for (final r in fields) _field(r.data)]);
  }

  /// How the triggers see [table]. Declared by drift, so it never changes.
  ChangeLogTableSpec? specOf(String table) => (_specs ??= {
    for (final spec in changeLogSpecsFor(_db)) spec.table: spec,
  })[table];

  static Map<String, ChangeLogTableSpec>? _specs;

  /// The columns [table] really has in this file, which may be fewer than
  /// drift declares.
  Future<Set<String>> liveColumns(String table) async {
    final rows = await _db
        .customSelect(
          'SELECT name FROM pragma_table_info(?)',
          variables: [Variable<String>(table)],
        )
        .get();
    return {for (final row in rows) row.read<String>('name')};
  }

  /// Columns of [table] that may be null but default to a value. A delete
  /// copy leaves nulls out, so a restore has to write these null itself or
  /// the default would take their place.
  Future<Set<String>> nullableDefaultedColumns(String table) async {
    final rows = await _db
        .customSelect(
          'SELECT name FROM pragma_table_info(?) '
          'WHERE "notnull" = 0 AND dflt_value IS NOT NULL',
          variables: [Variable<String>(table)],
        )
        .get();
    return {for (final row in rows) row.read<String>('name')};
  }

  /// What [column] of the record holds now, or null with no such record.
  Future<Object?> liveValue(
    String table,
    String recordId,
    String column,
  ) async {
    final spec = specOf(table);
    if (spec == null) return null;
    final match = changeLogKeyMatch(spec, recordId);
    final row = await _db
        .customSelect(
          'SELECT "$column" AS v FROM "$table" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingleOrNull();
    return row?.data['v'];
  }

  /// Whether the record still exists, for offering a link to it.
  Future<bool> recordExists(String table, String id) async {
    final spec = specOf(table);
    if (spec == null) return false;
    final match = changeLogKeyMatch(spec, id);
    final row = await _db
        .customSelect(
          'SELECT 1 FROM "$table" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingleOrNull();
    return row != null;
  }

  /// What each of [roots] is called now, as a reference. A record that has
  /// gone comes back marked missing.
  Future<Map<ChangeLogRoot, ConflictReference>> describeRoots(
    Iterable<ChangeLogRoot> roots,
  ) async {
    final resolver = ConflictReferenceResolver(SyncDataSerializer());
    final names = <ChangeLogRoot, ConflictReference>{};
    for (final root in roots) {
      try {
        names[root] = await resolver.describe(
          changeLogEntityType(root.table),
          root.id,
        );
      } catch (error) {
        _log.warning('Could not name ${root.table}: $error');
      }
    }
    return names;
  }

  /// Roughly what the log's values take up in the database.
  Future<int> storageBytes() async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(CAST(old_value AS BLOB))), 0) '
          '+ COALESCE(SUM(LENGTH(CAST(new_value AS BLOB))), 0) AS bytes '
          'FROM change_log_fields',
        )
        .getSingle();
    return row.read<int>('bytes');
  }

  /// Removes [diverId]'s entries, and returns how many. Entries with no
  /// owner stay, because they are every diver's.
  Future<int> clearForDiver(String diverId) async {
    await settleAll();
    return _db.transaction(() async {
      const owned =
          'SELECT e.id FROM change_log_events e '
          'JOIN change_log_operations o ON o.id = e.operation_id '
          'WHERE o.diver_id = ?';
      await _db.customStatement(
        'DELETE FROM change_log_fields WHERE event_id IN ($owned)',
        [diverId],
      );
      await _db.customStatement(
        'DELETE FROM change_log_events WHERE id IN ($owned)',
        [diverId],
      );
      return _db.customUpdate(
        'DELETE FROM change_log_operations WHERE diver_id = ?',
        variables: [Variable<String>(diverId)],
        updates: {_db.changeLogOperations},
        updateKind: UpdateKind.delete,
      );
    });
  }

  ChangeLogEvent _event(
    Map<String, Object?> row,
    List<ChangeLogFieldChange> fields,
  ) => ChangeLogEvent(
    id: row['id']! as int,
    operationId: row['operation_id']! as String,
    table: row['table_name']! as String,
    recordId: row['record_id']! as String,
    action: ChangeLogAction.fromCode(row['action']! as String),
    changedAt: DateTime.fromMillisecondsSinceEpoch(row['changed_at']! as int),
    schemaVersion: row['schema_version']! as int,
    rootTable: row['root_table'] as String?,
    rootId: row['root_id'] as String?,
    fields: fields,
  );

  ChangeLogFieldChange _field(Map<String, Object?> row) => ChangeLogFieldChange(
    table: row['table_name']! as String,
    column: row['column_name']! as String,
    oldValue: row['old_value'],
    newValue: row['new_value'],
  );

  ChangeLogOperation _operation(Map<String, Object?> row) => ChangeLogOperation(
    id: row['id']! as String,
    source: ChangeLogSource.values.firstWhere(
      (source) => source.name == row['source'],
      orElse: () => ChangeLogSource.manual,
    ),
    label: row['label'] as String?,
    deviceId: row['device_id'] as String?,
    diverId: row['diver_id'] as String?,
    rootTable: row['root_table'] as String?,
    rootId: row['root_id'] as String?,
    rootLabel: row['root_label'] as String?,
    rootOrdinal: row['root_ordinal'] as int?,
    startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int),
    endedAt: DateTime.fromMillisecondsSinceEpoch(row['ended_at']! as int),
    lastEventId: row['last_event_id'] as int?,
    eventCount: row['event_count']! as int,
    summaryCount: row['summary_count'] as int?,
    revertOfId: row['revert_of_id'] as String?,
    revertedById: row['reverted_by_id'] as String?,
  );
}
