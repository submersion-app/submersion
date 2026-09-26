import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

@immutable
class QueryEntity {
  final QuerySubject subject;
  final String table;
  final String idColumn;

  /// The per-diver column, or null for a table shared across divers. The
  /// CALLER applies the scope, never the compiler.
  final String? diverScopeColumn;
  final List<QueryField> fields;
  final List<QueryRelation> relations;

  /// What a bare text word searches, as SQL templates over `{r}` with one
  /// or more `?` each; every `?` binds the LIKE term.
  final List<String> textSearchSql;

  /// Tables [textSearchSql] reads besides the entity's own.
  final List<String> textSearchTables;

  const QueryEntity({
    required this.subject,
    required this.table,
    this.idColumn = 'id',
    this.diverScopeColumn,
    this.fields = const [],
    this.relations = const [],
    this.textSearchSql = const [],
    this.textSearchTables = const [],
  });

  QueryField? field(String keyOrAlias) =>
      fields.where((f) => f.matches(keyOrAlias)).firstOrNull;

  QueryRelation? relation(String keyOrAlias) =>
      relations.where((r) => r.matches(keyOrAlias)).firstOrNull;

  /// Every name a path segment may use here, for suggestions.
  Iterable<String> get segmentNames => [
    for (final f in fields) ...[f.key, ...f.aliases],
    for (final r in relations) ...[r.key, ...r.aliases],
  ];
}
