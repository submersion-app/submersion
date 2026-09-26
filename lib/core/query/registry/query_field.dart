import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';

enum FieldType { number, text, bool, enumName, date, id }

/// How a date column stores its instant, which decides what "the calendar
/// day D" binds to.
enum DateFrame {
  /// A wall clock flagged as UTC (`dives.dive_date_time`): day D is
  /// `DateTime.utc(D)`.
  wallClockUtc,

  /// A local instant stored as `millisecondsSinceEpoch` (trips,
  /// certifications, courses): day D is the device's local midnight.
  localInstant,
}

enum FieldDimension {
  depth,
  temperature,
  pressure,
  weight,
  volume,
  minutes,
  percent,
  count,
  none,
}

const Set<QueryOp> kOrderingOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.lt,
  QueryOp.lte,
  QueryOp.gt,
  QueryOp.gte,
  QueryOp.between,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
};
const Set<QueryOp> kTextOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.contains,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
};
const Set<QueryOp> kMembershipOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
};
const Set<QueryOp> kBoolOps = {QueryOp.eq, QueryOp.neq};

/// One queryable field of an entity.
///
/// [sql] and [emptySql] are written against the placeholder `{r}`, the alias
/// of the entity's row at whatever nesting depth the compiler reaches it.
@immutable
class QueryField {
  final String key;
  final List<String> aliases;
  final FieldType type;
  final FieldDimension dimension;
  final String sql;
  final String emptySql;
  final Set<QueryOp>? _ops;
  final String labelKey;

  /// The operators this field accepts; the type's default unless declared.
  Set<QueryOp> get ops => _ops ?? _defaultOps(type);

  /// Stored names, for [FieldType.enumName]. The builder localizes them.
  final List<String>? enumValues;

  /// What each enum name binds as, when the column does not store the name
  /// itself (weekday stores 0..6). Defaults to the name.
  final Map<String, Object>? enumSqlValues;

  /// For [FieldType.bool] fields that are predicates rather than columns:
  /// the SQL for `= true` and for `= false`. When set, [sql] is unused.
  final ({String whenTrue, String whenFalse})? boolSql;

  /// Validation range in storage units, inclusive.
  final ({double min, double max})? sanity;

  /// For [FieldType.date]: the frame the column stores.
  final DateFrame dateFrame;

  /// Tables this field's SQL reads besides the entity's own (dive_weights
  /// inside weight's emptySql, the profile tables inside deco), for ticks.
  final List<String> tables;

  const QueryField({
    required this.key,
    this.aliases = const [],
    required this.type,
    this.dimension = FieldDimension.none,
    required this.sql,
    required this.emptySql,
    required this.labelKey,
    Set<QueryOp>? ops,
    this.enumValues,
    this.enumSqlValues,
    this.boolSql,
    this.sanity,
    this.dateFrame = DateFrame.wallClockUtc,
    this.tables = const [],
  }) : _ops = ops;

  static Set<QueryOp> _defaultOps(FieldType type) => switch (type) {
    FieldType.number || FieldType.date => kOrderingOps,
    FieldType.text => kTextOps,
    FieldType.enumName || FieldType.id => kMembershipOps,
    FieldType.bool => kBoolOps,
  };

  bool matches(String keyOrAlias) =>
      key == keyOrAlias || aliases.contains(keyOrAlias);
}
