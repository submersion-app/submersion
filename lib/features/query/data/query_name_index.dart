import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// A snapshot of every referenceable row's id and label (#2365).
///
/// The parser resolves `site = "Salt Pier"` through [resolve]; the builder's
/// ref picker lists [entries]; a saved query checks its ids through
/// [labelOf]. A snapshot, not a live query, so parsing stays synchronous;
/// the provider reloads it when any of its tables changes.
class QueryNameIndex implements NameResolver, NameEntries {
  const QueryNameIndex(this._entries);

  static const empty = QueryNameIndex({});

  final Map<QuerySubject, List<RefValue>> _entries;

  List<RefValue> entries(QuerySubject kind) => _entries[kind] ?? const [];

  @override
  Iterable<RefValue> refEntries(QuerySubject kind) => entries(kind);

  String? labelOf(QuerySubject kind, String id) {
    for (final r in entries(kind)) {
      if (r.id == id) return r.label;
    }
    return null;
  }

  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final wanted = text.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final r in entries(kind)) {
      if (r.label.trim().toLowerCase() == wanted) return r;
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) =>
      suggestNames(text, entries(kind).map((r) => r.label));
}

/// Loads a [QueryNameIndex] from the registry's ref-target tables.
class QueryNameIndexLoader {
  QueryNameIndexLoader(this._db);

  final AppDatabase _db;

  /// The subjects a relation can point at by name.
  static const refSubjects = [
    QuerySubject.sites,
    QuerySubject.siteTypes,
    QuerySubject.trips,
    QuerySubject.centers,
    QuerySubject.computers,
    QuerySubject.courses,
    QuerySubject.buddies,
    QuerySubject.tags,
    QuerySubject.diveTypes,
    QuerySubject.equipment,
    QuerySubject.species,
  ];

  /// The tables a change tick must follow: the ref tables, and the share
  /// table that makes another diver's equipment visible.
  static Set<String> get tables => {
    for (final s in refSubjects) appQueryRegistry.entityFor(s).table,
    'equipment_shares',
  };

  /// Every row the diver can see: their own, rows with no owner, and rows
  /// another diver shares, by the rules `VisibilityFilter` applies to the
  /// lists (#2046): an `is_shared` flag on sites and trips, an
  /// `equipment_shares` row for equipment. A subject with no diver column
  /// (species) is global. Table and column names come from the registry's
  /// declared constants; the diver id is bound.
  Future<QueryNameIndex> load({String? diverId}) async {
    final out = <QuerySubject, List<RefValue>>{};
    for (final subject in refSubjects) {
      final entity = appQueryRegistry.entityFor(subject);
      final nameSql = entity.field('name')!.sql.replaceAll('{r}', 't');
      final scope = entity.diverScopeColumn;
      final visible = <String>[];
      final variables = <Variable<Object>>[];
      if (scope != null) {
        if (diverId != null) {
          visible.add('t.$scope = ?');
          variables.add(Variable<String>(diverId));
        }
        visible.add('t.$scope IS NULL');
        switch (subject) {
          case QuerySubject.sites || QuerySubject.trips:
            visible.add('t.is_shared = 1');
          case QuerySubject.equipment when diverId != null:
            visible.add(
              't.${entity.idColumn} IN (SELECT equipment_id '
              'FROM equipment_shares WHERE diver_id = ?)',
            );
            variables.add(Variable<String>(diverId));
          default:
            break;
        }
      }
      final where = visible.isEmpty ? '' : 'WHERE ${visible.join(' OR ')}';
      final rows = await _db
          .customSelect(
            'SELECT t.${entity.idColumn} AS id, $nameSql AS label '
            'FROM ${entity.table} t $where ORDER BY label',
            variables: variables,
          )
          .get();
      out[subject] = [
        for (final r in rows)
          if (r.read<String?>('label') case final label? when label.isNotEmpty)
            RefValue(r.read<String>('id'), label),
      ];
    }
    return QueryNameIndex(out);
  }
}
