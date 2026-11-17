import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_sql.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

/// What a diver sees of an entry another diver owns (issue #4527).
///
/// A diver's editing sitting is one entry about the record it was opened
/// on, whoever owns the other records it wrote. Another diver who sees one
/// of those records (their own, or one shared with them, by the rules of
/// `VisibilityFilter`) sees the entry too, but only its rows about such
/// records, and titled with one of them: the sitting's own record may be
/// private to its owner.
abstract final class ChangeLogSharedView {
  /// Whether the record named by the SQL expressions [table] and [id] is one
  /// [diverId] sees anywhere else in the app ([VisibilityFilter]): their
  /// own, shared with them or with everyone, or in a site library they
  /// belong to, and not one they hid.
  static ChangeLogSql _visible(String table, String id, String diverId) {
    final site = VisibilityFilter.sqlFragment(
      tableAlias: 'vs',
      diverId: diverId,
      conjunction: '',
      kind: SharedItemKind.site,
    );
    final trip = VisibilityFilter.sqlFragment(
      tableAlias: 'vt',
      diverId: diverId,
      conjunction: '',
      kind: SharedItemKind.trip,
    );
    final gear = VisibilityFilter.equipmentSqlFragment(
      tableAlias: 've',
      diverId: diverId,
      conjunction: '',
    );
    return (
      sql:
          "(($table = 'dive_sites' AND $id IN (SELECT vs.id FROM dive_sites vs "
          'WHERE ${site.whereClause})) '
          "OR ($table = 'trips' AND $id IN (SELECT vt.id FROM trips vt "
          'WHERE ${trip.whereClause})) '
          "OR ($table = 'equipment' AND $id IN (SELECT ve.id FROM equipment ve "
          'WHERE ${gear.whereClause})))',
      variables: [...site.variables, ...trip.variables, ...gear.variables],
    );
  }

  /// Whether the record [rows] (an event, or an entry) is about is one
  /// [diverId] sees: a site, trip or item of gear that is theirs or that
  /// they may see.
  static ChangeLogSql seenRoot(String rows, String diverId) =>
      _visible('$rows.root_table', '$rows.root_id', diverId);

  /// The table of the record [diverId] sees an entry [operations] under, as
  /// [asSeenBy] titles it, or NULL when it is not restricted for them: its
  /// own record if they see that, else the first they see.
  static ChangeLogSql shownTable(String operations, String diverId) {
    final seen = seenRoot('se', diverId);
    return (
      sql:
          '(CASE WHEN $operations.diver_id IS NULL '
          'OR $operations.diver_id = ? THEN NULL ELSE '
          '(SELECT se.root_table FROM change_log_events se '
          'WHERE se.operation_id = $operations.id AND ${seen.sql} '
          'ORDER BY (se.root_table = $operations.root_table '
          'AND se.root_id = $operations.root_id) DESC, se.id LIMIT 1) END)',
      variables: [Variable<Object>(diverId), ...seen.variables],
    );
  }

  /// [operations] as [diverId] reads them: an entry another diver owns
  /// keeps only the records of it [diverId] sees, and is titled with one of
  /// them, its own record if they see that. An entry with no such record,
  /// a summary for one, is left whole.
  static Future<List<ChangeLogOperation>> asSeenBy(
    AppDatabase db,
    List<ChangeLogOperation> operations,
    String diverId,
  ) async {
    final others = [
      for (final operation in operations)
        if (operation.diverId != null && operation.diverId != diverId)
          operation.id,
    ];
    if (others.isEmpty) return operations;
    final shown = await _shownRoots(db, others, diverId);
    if (shown.isEmpty) return operations;

    // Each restricted entry's records, and its own among them if they are
    // seen: then it keeps its title, else it takes the first record's name.
    final views = {
      for (final operation in operations)
        if (shown[operation.id] case final roots?)
          operation.id: (roots: roots, own: _ownRootIn(operation, roots)),
    };
    final names = await _names(db, {
      for (final view in views.values)
        if (view.own == null) view.roots.first,
    });
    return [
      for (final operation in operations)
        if (views[operation.id] case (:final roots, :final own)?)
          operation.restrictedTo(
            roots,
            root: own ?? roots.first,
            label: own == null ? names[roots.first] : operation.rootLabel,
          )
        else
          operation,
    ];
  }

  /// The records each of [operationIds] changed that [diverId] sees, in the
  /// order the entry first changed them.
  static Future<Map<String, Set<ChangeLogRoot>>> _shownRoots(
    AppDatabase db,
    List<String> operationIds,
    String diverId,
  ) async {
    final seen = seenRoot('e', diverId);
    final rows = await db
        .customSelect(
          'SELECT e.operation_id, e.root_table, e.root_id, MIN(e.id) AS first '
          'FROM change_log_events e '
          'WHERE e.operation_id IN (${changeLogMarks(operationIds.length)}) '
          'AND ${seen.sql} '
          'GROUP BY e.operation_id, e.root_table, e.root_id ORDER BY first',
          variables: [
            ...operationIds.map(Variable<Object>.new),
            ...seen.variables,
          ],
        )
        .get();
    final shown = <String, Set<ChangeLogRoot>>{};
    for (final row in rows) {
      (shown[row.read<String>('operation_id')] ??= {}).add((
        table: row.read<String>('root_table'),
        id: row.read<String>('root_id'),
      ));
    }
    return shown;
  }

  /// The entry's own record when it is one of [shown].
  static ChangeLogRoot? _ownRootIn(
    ChangeLogOperation operation,
    Set<ChangeLogRoot> shown,
  ) {
    final table = operation.rootTable;
    final id = operation.rootId;
    if (table == null || id == null) return null;
    final own = (table: table, id: id);
    return shown.contains(own) ? own : null;
  }

  /// The name of each of [roots], one query per table.
  static Future<Map<ChangeLogRoot, String?>> _names(
    AppDatabase db,
    Set<ChangeLogRoot> roots,
  ) async {
    final names = <ChangeLogRoot, String?>{};
    for (final table in {for (final root in roots) root.table}) {
      final ids = [
        for (final root in roots)
          if (root.table == table) root.id,
      ];
      final rows = await db
          .customSelect(
            'SELECT id, name FROM $table WHERE id IN (${changeLogMarks(ids.length)})',
            variables: [...ids.map(Variable<Object>.new)],
          )
          .get();
      for (final row in rows) {
        names[(table: table, id: row.read<String>('id'))] = row
            .readNullable<String>('name');
      }
    }
    return names;
  }
}
