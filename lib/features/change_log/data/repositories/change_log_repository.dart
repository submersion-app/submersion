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
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

const int _settleBatch = 500;

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
  Future<void> settleAll() async {
    try {
      final settler = ChangeLogSettler(_db);
      while (await settler.settle(batch: _settleBatch) == _settleBatch) {
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
    final where = <String>[
      '(o.event_count > 0 OR o.summary_count IS NOT NULL)',
      _visibleTo,
    ];
    final variables = <Variable<Object>>[
      for (var i = 0; i < 4; i++) Variable<Object>(diverId),
    ];

    if (filter.isRecord) {
      where.add(
        'o.id IN (SELECT operation_id FROM change_log_events '
        'WHERE root_table = ? AND root_id = ?)',
      );
      variables
        ..add(Variable<Object>(filter.rootTable!))
        ..add(Variable<Object>(filter.rootId!));
    }
    if (filter.rootTables.isNotEmpty) {
      final tables = filter.rootTables.toList();
      final marks = List.filled(tables.length, '?').join(', ');
      where.add(
        '(o.root_table IN ($marks) OR (o.root_table IS NULL AND EXISTS ('
        'SELECT 1 FROM change_log_events e WHERE e.operation_id = o.id '
        'AND e.root_table IN ($marks))))',
      );
      for (final _ in const [0, 1]) {
        variables.addAll(tables.map(Variable<Object>.new));
      }
    }
    if (filter.sources.isNotEmpty) {
      final marks = List.filled(filter.sources.length, '?').join(', ');
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
    return rows.map((row) => _operation(row.data)).toList();
  }

  /// The active diver's own entries, entries with no owner, and entries
  /// about a record shared with them. Takes the diver id four times.
  static const _visibleTo =
      '(o.diver_id = ? OR o.diver_id IS NULL '
      "OR (o.root_table = 'dive_sites' AND EXISTS (SELECT 1 FROM site_shares s "
      'WHERE s.site_id = o.root_id AND s.diver_id = ?)) '
      "OR (o.root_table = 'equipment' AND EXISTS (SELECT 1 FROM "
      'equipment_shares s WHERE s.equipment_id = o.root_id '
      'AND s.diver_id = ?)) '
      "OR (o.root_table = 'trips' AND EXISTS (SELECT 1 FROM trip_shares s "
      'WHERE s.trip_id = o.root_id AND s.diver_id = ?)))';

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

  /// [operationId]'s records, oldest first. Machine rows are kept only to
  /// restore a deleted record, so they are left out unless asked for.
  Future<List<ChangeLogEvent>> getEvents(
    String operationId, {
    bool includeMachineRows = false,
    int? limit,
  }) async {
    final hidden = includeMachineRows ? const <String>[] : _machineTables;
    final marks = List.filled(hidden.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT * FROM change_log_events WHERE operation_id = ? '
          '${hidden.isEmpty ? '' : 'AND table_name NOT IN ($marks) '}'
          'ORDER BY id ${limit == null ? '' : 'LIMIT $limit'}',
          variables: [
            Variable<String>(operationId),
            ...hidden.map(Variable<String>.new),
          ],
        )
        .get();
    if (rows.isEmpty) return const [];

    final fields = await _fieldsByEvent(
      operationId,
      lastEventId: rows.last.read<int>('id'),
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

  Future<Map<int, List<ChangeLogFieldChange>>> _fieldsByEvent(
    String operationId, {
    required int lastEventId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT f.*, e.table_name FROM change_log_fields f '
          'JOIN change_log_events e ON e.id = f.event_id '
          'WHERE e.operation_id = ? AND e.id <= ? '
          'ORDER BY f.event_id, f.column_name',
          variables: [
            Variable<String>(operationId),
            Variable<int>(lastEventId),
          ],
        )
        .get();
    final fields = <int, List<ChangeLogFieldChange>>{};
    for (final row in rows) {
      (fields[row.read<int>('event_id')] ??= []).add(_field(row.data));
    }
    return fields;
  }

  /// The first [perOperation] changed fields of each of [operationIds], and
  /// how many each has.
  Future<Map<String, ChangeLogPreview>> getPreviewFields(
    List<String> operationIds, {
    int perOperation = 2,
  }) async {
    if (operationIds.isEmpty) return const {};
    final marks = List.filled(operationIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT * FROM (SELECT e.operation_id, e.table_name, f.column_name, '
          'f.old_value, f.new_value, '
          'ROW_NUMBER() OVER (PARTITION BY e.operation_id '
          'ORDER BY e.id, f.column_name) AS n, '
          'COUNT(*) OVER (PARTITION BY e.operation_id) AS total '
          'FROM change_log_events e '
          'JOIN change_log_fields f ON f.event_id = e.id '
          "WHERE e.action = 'U' AND e.operation_id IN ($marks)) "
          'WHERE n <= ? ORDER BY operation_id, n',
          variables: [
            ...operationIds.map(Variable<String>.new),
            Variable<int>(perOperation),
          ],
        )
        .get();

    final fields = <String, List<ChangeLogFieldChange>>{};
    final totals = <String, int>{};
    for (final row in rows) {
      final id = row.read<String>('operation_id');
      (fields[id] ??= []).add(_field(row.data));
      totals[id] = row.read<int>('total');
    }

    final actions = await _db
        .customSelect(
          'SELECT e.operation_id, e.action FROM change_log_events e '
          'JOIN change_log_operations o ON o.id = e.operation_id '
          'WHERE e.operation_id IN ($marks) AND e.table_name = o.root_table '
          'AND e.record_id = o.root_id ORDER BY e.id',
          variables: [...operationIds.map(Variable<String>.new)],
        )
        .get();
    final rootActions = {
      for (final row in actions)
        row.read<String>('operation_id'): ChangeLogAction.fromCode(
          row.read<String>('action'),
        ),
    };

    return {
      for (final id in {...fields.keys, ...rootActions.keys})
        id: ChangeLogPreview(
          fields: fields[id] ?? const [],
          total: totals[id] ?? 0,
          rootAction: rootActions[id],
        ),
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

  /// Whether the record still exists, for offering a link to it.
  Future<bool> recordExists(String table, String id) async {
    final specs = changeLogSpecsFor(_db);
    final spec = specs.where((s) => s.table == table).firstOrNull;
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
