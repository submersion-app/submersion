import 'package:meta/meta.dart';

import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

/// One compiled query, in the two spellings its consumers need.
@immutable
class CompiledQuery {
  /// A boolean expression over [rootAlias], or empty for "match all".
  final String where;
  final List<Object?> params;

  /// Every table the expression reads (root, relation targets, junctions,
  /// tables a field or template declares), for change ticks and
  /// `readsFrom`.
  final Set<String> tablesTouched;
  final String table;
  final String idColumn;
  final String rootAlias;

  const CompiledQuery({
    required this.where,
    required this.params,
    required this.tablesTouched,
    required this.table,
    required this.idColumn,
    required this.rootAlias,
  });

  bool get isEmpty => where.isEmpty;

  /// `SELECT alias.id FROM table alias [WHERE where]`, for `id IN (...)`
  /// consumers. Binds the same [params].
  String idSubquery() =>
      'SELECT $rootAlias.$idColumn FROM $table $rootAlias'
      '${isEmpty ? '' : ' WHERE $where'}';
}

/// Compiles a VALIDATED tree (spec Unit 4). Anything the validator would
/// reject throws [QueryCompileError], which is a programming error, not
/// user input. Every value is a bind parameter; only registry fragments and
/// aliases are interpolated.
CompiledQuery compileQuery(
  QueryNode? node,
  QueryEntity root,
  QueryRegistry registry, {
  String rootAlias = 'r0',
}) {
  final ctx = _Ctx(registry)..tables.add(root.table);
  final where = node == null ? '' : ctx.emit(node, root, rootAlias);
  return CompiledQuery(
    where: where,
    params: List.unmodifiable(ctx.params),
    tablesTouched: Set.unmodifiable(ctx.tables),
    table: root.table,
    idColumn: root.idColumn,
    rootAlias: rootAlias,
  );
}

class _Ctx {
  final QueryRegistry registry;
  final params = <Object?>[];
  final tables = <String>{};
  int _aliasCounter = 0;

  _Ctx(this.registry);

  String nextAlias() => 'r${++_aliasCounter}';

  String emit(QueryNode n, QueryEntity entity, String alias) => switch (n) {
    AndNode(:final children) =>
      '(${children.map((c) => emit(c, entity, alias)).join(' AND ')})',
    OrNode(:final children) =>
      '(${children.map((c) => emit(c, entity, alias)).join(' OR ')})',
    NotNode(:final child) => '(NOT ${emit(child, entity, alias)})',
    TextNode(:final words) => _text(words, entity, alias),
    ScopedNode(:final path, :final inner) => _scoped(
      path,
      inner,
      entity,
      alias,
    ),
    ConditionNode(:final path, :final op, :final value) => _condition(
      path,
      op,
      value,
      entity,
      alias,
    ),
  };

  String _text(List<String> words, QueryEntity entity, String alias) {
    if (entity.textSearchSql.isEmpty) {
      throw QueryCompileError(
        '${entity.table} declares no text search columns',
      );
    }
    tables.addAll(entity.textSearchTables);
    final perWord = <String>[];
    for (final w in words) {
      final term = '%${escapeLike(w)}%';
      final alts = <String>[];
      for (final t in entity.textSearchSql) {
        alts.add(substituteRow(t, alias));
        for (var i = 0; i < countPlaceholders(t); i++) {
          params.add(term);
        }
      }
      perWord.add('(${alts.join(' OR ')})');
    }
    return '(${perWord.join(' AND ')})';
  }

  /// Wraps [inner] (a function of the leaf alias) in one EXISTS per hop.
  /// A null [inner] is a bare existence test.
  String _hops(
    List<QueryRelation> hops,
    String fromAlias,
    String Function(String leafAlias)? inner,
  ) {
    if (hops.isEmpty) return inner!(fromAlias);
    final rel = hops.first;
    final target = registry.entityFor(rel.target);
    tables.add(target.table);
    tables.addAll(rel.tables);
    final to = nextAlias();
    final join = substituteJoin(rel.joinSql, fromAlias, to);
    final rest = hops.length == 1 && inner == null
        ? ''
        : ' AND ${_hops(hops.sublist(1), to, inner)}';
    return 'EXISTS (SELECT 1 FROM ${target.table} $to WHERE $join$rest)';
  }

  String _scoped(
    FieldPath path,
    QueryNode inner,
    QueryEntity entity,
    String alias,
  ) {
    final res = _resolve(path, entity);
    final rel = res.terminalRelation;
    if (rel == null) {
      throw QueryCompileError('scoped path $path must end in a relation');
    }
    final leaf = registry.entityFor(rel.target);
    return '(${_hops(res.hops, alias, (a) => emit(inner, leaf, a))})';
  }

  String _condition(
    FieldPath path,
    QueryOp op,
    QueryValue? value,
    QueryEntity entity,
    String alias,
  ) {
    final res = _resolve(path, entity);
    final field = res.field;
    if (field == null) {
      return _relationCondition(res, op, value, alias, path);
    }
    tables.addAll(field.tables);
    // A field predicate is already parenthesised; only a hop chain needs
    // its own pair around the EXISTS.
    final body = _hops(
      res.hops,
      alias,
      (a) => _fieldPredicate(field, op, value, a),
    );
    return res.hops.isEmpty ? body : '($body)';
  }

  String _relationCondition(
    PathResolution res,
    QueryOp op,
    QueryValue? value,
    String alias,
    FieldPath path,
  ) {
    final rel = res.terminalRelation!;
    final target = registry.entityFor(rel.target);
    switch (op) {
      case QueryOp.eq:
      case QueryOp.neq:
        params.add((value as RefValue).id);
        final hit = _hops(res.hops, alias, (a) => '$a.${target.idColumn} = ?');
        return op == QueryOp.eq ? '($hit)' : '(NOT $hit)';
      case QueryOp.inList:
        final items = (value as ListValue).items;
        for (final v in items) {
          params.add((v as RefValue).id);
        }
        final ph = List.filled(items.length, '?').join(', ');
        return '(${_hops(res.hops, alias, (a) => '$a.${target.idColumn} IN ($ph)')})';
      case QueryOp.isSet:
        return '(${_hops(res.hops, alias, null)})';
      case QueryOp.isEmpty:
        if (rel.emptySql != null && res.hops.length == 1) {
          tables.add(target.table);
          tables.addAll(rel.tables);
          return '(${substituteJoin(rel.emptySql!, alias, '_unused')})';
        }
        return '(NOT ${_hops(res.hops, alias, null)})';
      default:
        throw QueryCompileError('$op on relation $path');
    }
  }

  PathResolution _resolve(FieldPath path, QueryEntity entity) {
    final res = resolvePath(registry, entity, path);
    if (res.error != null) throw QueryCompileError(res.error!.message);
    return res;
  }

  String _fieldPredicate(
    QueryField f,
    QueryOp op,
    QueryValue? value,
    String alias,
  ) {
    final col = substituteRow(f.sql, alias);
    switch (op) {
      case QueryOp.isEmpty:
        return '(${substituteRow(f.emptySql, alias)})';
      case QueryOp.isSet:
        return '(NOT (${substituteRow(f.emptySql, alias)}))';
      case QueryOp.between:
        final items = (value as ListValue).items;
        return '(${_cmp(f, col, '>=', items[0])} '
            'AND ${_cmp(f, col, '<=', items[1])})';
      case QueryOp.inList:
        if (value is DateRangeValue) return _dateRange(col, value);
        final items = (value as ListValue).items;
        if (f.type == FieldType.text) {
          for (final v in items) {
            params.add((v as StringValue).value);
          }
          final ph = List.filled(items.length, 'LOWER(?)').join(', ');
          return '(LOWER($col) IN ($ph))';
        }
        for (final v in items) {
          params.add(_bind(f, v));
        }
        return '($col IN (${List.filled(items.length, '?').join(', ')}))';
      case QueryOp.contains:
        params.add('%${escapeLike((value as StringValue).value)}%');
        return "($col LIKE ? ESCAPE '\\')";
      case QueryOp.eq:
      case QueryOp.neq:
        return _equality(f, col, op, value!, alias);
      case QueryOp.lt:
      case QueryOp.lte:
      case QueryOp.gt:
      case QueryOp.gte:
        final sym = switch (op) {
          QueryOp.lt => '<',
          QueryOp.lte => '<=',
          QueryOp.gt => '>',
          _ => '>=',
        };
        return '(${_cmp(f, col, sym, value!)})';
    }
  }

  String _equality(
    QueryField f,
    String col,
    QueryOp op,
    QueryValue value,
    String alias,
  ) {
    final positive = op == QueryOp.eq;
    if (f.type == FieldType.bool) {
      final want = (value as BoolValue).value == positive;
      if (f.boolSql != null) {
        final sql = want ? f.boolSql!.whenTrue : f.boolSql!.whenFalse;
        return '(${substituteRow(sql, alias)})';
      }
      params.add(want ? 1 : 0);
      return '($col = ?)';
    }
    if (f.type == FieldType.date) {
      final day = (value as DateValue).day;
      params
        ..add(_ms(day))
        ..add(_ms(_plusDay(day)));
      final eq = '($col >= ? AND $col < ?)';
      return positive ? eq : '(NOT $eq)';
    }
    if (f.type == FieldType.text) {
      params.add((value as StringValue).value);
      return positive
          ? '(LOWER($col) = LOWER(?))'
          : '(LOWER($col) != LOWER(?))';
    }
    params.add(_bind(f, value));
    // SQL's `col != ?` is already false for NULL; the explicit test keeps
    // the intent readable in the plan and matches the golden.
    return positive ? '($col = ?)' : '(($col) IS NOT NULL AND $col != ?)';
  }

  String _cmp(QueryField f, String col, String sym, QueryValue v) {
    if (f.type == FieldType.date) {
      final day = (v as DateValue).day;
      // Half-open day bounds: `<= day` keeps the whole day, `> day` starts
      // the day after, mirroring DiveFilterState's endDateBoundMs.
      switch (sym) {
        case '<':
          params.add(_ms(day));
          return '$col < ?';
        case '<=':
          params.add(_ms(_plusDay(day)));
          return '$col < ?';
        case '>':
          params.add(_ms(_plusDay(day)));
          return '$col >= ?';
        default:
          params.add(_ms(day));
          return '$col >= ?';
      }
    }
    params.add(_bind(f, v));
    return '$col $sym ?';
  }

  String _dateRange(String col, DateRangeValue r) {
    params
      ..add(_ms(r.start))
      ..add(_ms(_plusDay(r.end)));
    return '($col >= ? AND $col < ?)';
  }

  Object? _bind(QueryField f, QueryValue v) => switch (v) {
    NumberValue(:final value) => value,
    StringValue(:final value) => value,
    BoolValue(:final value) => value ? 1 : 0,
    EnumValue(:final name) => f.enumSqlValues?[name] ?? name,
    RefValue(:final id) => id,
    DateValue(:final day) => _ms(day),
    DateRangeValue() ||
    ListValue() => throw QueryCompileError('cannot bind $v'),
  };

  int _ms(DateTime day) => wallClockUtcDayStart(day).millisecondsSinceEpoch;
  DateTime _plusDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
}
