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

  /// The tables a change tick must follow.
  static Set<String> get tables => {
    for (final s in refSubjects) appQueryRegistry.entityFor(s).table,
  };

  /// Every row the diver can see: their own plus rows with no owner. A
  /// subject with no diver column (species) is global. Table and column
  /// names come from the registry's declared constants; the diver id is
  /// bound.
  Future<QueryNameIndex> load({String? diverId}) async {
    final out = <QuerySubject, List<RefValue>>{};
    for (final subject in refSubjects) {
      final entity = appQueryRegistry.entityFor(subject);
      final nameSql = entity.field('name')!.sql.replaceAll('{r}', 't');
      final scope = entity.diverScopeColumn;
      final where = scope == null
          ? ''
          : diverId == null
          ? 'WHERE t.$scope IS NULL'
          : 'WHERE (t.$scope = ? OR t.$scope IS NULL)';
      final rows = await _db
          .customSelect(
            'SELECT t.${entity.idColumn} AS id, $nameSql AS label '
            'FROM ${entity.table} t $where ORDER BY label',
            variables: [
              if (scope != null && diverId != null) Variable<String>(diverId),
            ],
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
