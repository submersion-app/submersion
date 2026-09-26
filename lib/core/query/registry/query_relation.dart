import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';

/// Metadata for the guard tests; the compiler treats every shape the same.
enum RelationShape { fk, child, junction, custom }

/// A hop from one entity's row to rows of [target].
///
/// A relation is also how a row is named: `site = "Salt Pier"` is the
/// relation `site` with `=` and a [RefValue], compiled as the hop with
/// `{to}.id = ?` inside. There is no separate ref field type.
///
/// [joinSql] is the correlation predicate between the two rows, written
/// against `{from}` (the row we are on) and `{to}` (the target row). The
/// compiler emits `EXISTS (SELECT 1 FROM target_table {to} WHERE joinSql
/// AND inner)`, so a junction hop writes its own nested EXISTS over the
/// junction table inside [joinSql].
@immutable
class QueryRelation {
  final String key;
  final List<String> aliases;
  final QuerySubject target;
  final RelationShape shape;
  final String joinSql;
  final bool isMany;
  final String labelKey;

  /// Overrides `NOT EXISTS` for `:none` when a legacy scalar also counts as
  /// "has one" (the dive's `buddy` text beside `dive_buddies`).
  final String? emptySql;

  /// Tables [joinSql] or [emptySql] read besides the target (a junction).
  final List<String> tables;

  const QueryRelation({
    required this.key,
    this.aliases = const [],
    required this.target,
    required this.shape,
    required this.joinSql,
    required this.isMany,
    required this.labelKey,
    this.emptySql,
    this.tables = const [],
  });

  bool matches(String keyOrAlias) =>
      key == keyOrAlias || aliases.contains(keyOrAlias);
}
