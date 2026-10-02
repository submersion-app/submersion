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
  /// "has one" (the dive's `buddy` text beside `dive_buddies`). The compiler
  /// uses it as written, so a relation with a [targetFilterSql] must apply
  /// that filter inside its own [emptySql] too, or `:none` and `:any` would
  /// count rows the filter hides.
  final String? emptySql;

  /// A condition on the target row alone, written against `{to}`, that
  /// every hop through this relation ANDs after [joinSql]: rows it rejects
  /// are invisible to every query, whatever the condition inside the hop.
  /// For a relation that should only ever see some of the child rows (live
  /// safety findings, not dismissed ones), where [joinSql] must stay the
  /// single equality the guards expect.
  final String? targetFilterSql;

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
    this.targetFilterSql,
    this.tables = const [],
  });

  bool matches(String keyOrAlias) =>
      key == keyOrAlias || aliases.contains(keyOrAlias);
}
