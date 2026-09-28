import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Every problem in [node], for the editor to show at once. The compiler is
/// only called on a tree this returns nothing for.
///
/// The parser rejects most of these while reading text; this is for trees
/// the rule builder or a lowering makes, and it is what the compiler trusts.
List<QueryError> validateQuery(
  QueryNode? node,
  QueryEntity root,
  QueryRegistry registry,
) {
  if (node == null) return const [];
  final out = <QueryError>[];
  _walk(node, root, registry, out, 0);
  return out;
}

/// [depth] is the number of relation hops the enclosing scoped groups
/// already crossed, so nesting counts against [kMaxPathHops] like a path.
void _walk(
  QueryNode n,
  QueryEntity scope,
  QueryRegistry registry,
  List<QueryError> out,
  int depth,
) {
  switch (n) {
    case AndNode(:final children):
    case OrNode(:final children):
      if (children.isEmpty) {
        out.add(const QueryError(QueryErrorCode.emptyGroup));
      }
      for (final c in children) {
        _walk(c, scope, registry, out, depth);
      }
    case NotNode(:final child):
      _walk(child, scope, registry, out, depth);
    case TextNode(:final words):
      if (words.isEmpty) out.add(const QueryError(QueryErrorCode.emptyText));
      if (scope.textSearchSql.isEmpty) {
        out.add(
          QueryError(
            QueryErrorCode.textNotSearchable,
            args: {'table': scope.table},
          ),
        );
      }
    case ScopedNode(:final path, :final inner):
      final res = resolvePath(registry, scope, path);
      if (res.error != null) {
        out.add(res.error!);
        return;
      }
      if (res.terminalRelation == null) {
        out.add(
          QueryError(
            QueryErrorCode.scopeNeedsRelation,
            path: path,
            args: {'path': '$path'},
          ),
        );
        return;
      }
      final total = depth + res.hops.length;
      if (total > kMaxPathHops) {
        out.add(
          QueryError(
            QueryErrorCode.tooManyHops,
            path: path,
            args: {'max': '$kMaxPathHops'},
          ),
        );
        return;
      }
      _walk(
        inner,
        registry.entityFor(res.terminalRelation!.target),
        registry,
        out,
        total,
      );
    case ConditionNode(:final path, :final op, :final value):
      final res = resolvePath(registry, scope, path);
      if (res.error != null) {
        out.add(res.error!);
        return;
      }
      if (depth + res.hops.length > kMaxPathHops) {
        out.add(
          QueryError(
            QueryErrorCode.tooManyHops,
            path: path,
            args: {'max': '$kMaxPathHops'},
          ),
        );
        return;
      }
      final field = res.field;
      if (field == null) {
        _checkRelationOp(path, op, value, out);
        return;
      }
      if (!field.ops.contains(op)) {
        out.add(
          QueryError(
            QueryErrorCode.opNotForField,
            path: path,
            args: {'op': op.name, 'field': field.key},
          ),
        );
        return;
      }
      if (op == QueryOp.isEmpty &&
          (field.enumValues?.contains('none') ?? false)) {
        out.add(
          QueryError(
            QueryErrorCode.noneAmbiguous,
            path: path,
            args: {'field': field.key},
          ),
        );
        return;
      }
      if (value == null) return;
      _checkValue(path, field, op, value, out);
  }
}

void _checkRelationOp(
  FieldPath path,
  QueryOp op,
  QueryValue? value,
  List<QueryError> out,
) {
  final name = path.segments.last;
  switch (op) {
    case QueryOp.isEmpty:
    case QueryOp.isSet:
      return;
    case QueryOp.eq:
    case QueryOp.neq:
      if (value is! RefValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsReference,
            path: path,
            args: {'name': name},
          ),
        );
      }
    case QueryOp.inList:
      if (value is! ListValue || value.items.isEmpty) {
        out.add(QueryError(QueryErrorCode.emptyList, path: path));
      } else if (value.items.any((v) => v is! RefValue)) {
        out.add(
          QueryError(
            QueryErrorCode.expectsReferences,
            path: path,
            args: {'name': name},
          ),
        );
      }
    default:
      out.add(
        QueryError(
          QueryErrorCode.relationNeedsRefOp,
          path: path,
          args: {'path': '$path'},
        ),
      );
  }
}

void _checkValue(
  FieldPath path,
  QueryField field,
  QueryOp op,
  QueryValue value,
  List<QueryError> out,
) {
  if (op == QueryOp.between) {
    if (value is! ListValue || value.items.length != 2) {
      out.add(QueryError(QueryErrorCode.betweenNeedsTwo, path: path));
      return;
    }
    for (final v in value.items) {
      _checkValue(path, field, QueryOp.eq, v, out);
    }
    return;
  }
  if (op == QueryOp.inList) {
    if (value is DateRangeValue && field.type == FieldType.date) return;
    if (value is! ListValue) {
      out.add(QueryError(QueryErrorCode.inNeedsList, path: path));
      return;
    }
    if (value.items.isEmpty) {
      out.add(QueryError(QueryErrorCode.emptyList, path: path));
      return;
    }
    for (final v in value.items) {
      _checkValue(path, field, QueryOp.eq, v, out);
    }
    return;
  }
  switch (field.type) {
    case FieldType.number:
      if (value is! NumberValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsNumber,
            path: path,
            args: {'field': field.key},
          ),
        );
        return;
      }
      final unitless = const {
        FieldDimension.none,
        FieldDimension.percent,
        FieldDimension.count,
      }.contains(field.dimension);
      final unit = value.typedUnit;
      if (unit != null && unitless) {
        out.add(
          QueryError(
            QueryErrorCode.noUnitAllowed,
            path: path,
            args: {'field': field.key},
          ),
        );
      } else if (unit != null && dimensionOfUnit(unit) != field.dimension) {
        out.add(
          QueryError(
            QueryErrorCode.wrongUnitDimension,
            path: path,
            args: {'unit': unit.suffix, 'dimension': field.dimension.name},
          ),
        );
      }
      final s = field.sanity;
      if (s != null && (value.value < s.min || value.value > s.max)) {
        out.add(
          QueryError(
            QueryErrorCode.outOfRange,
            path: path,
            args: {'field': field.key},
          ),
        );
      }
    case FieldType.text:
    case FieldType.id:
      if (value is! StringValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsText,
            path: path,
            args: {'field': field.key},
          ),
        );
      }
    case FieldType.bool:
      if (value is! BoolValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsBool,
            path: path,
            args: {'field': field.key},
          ),
        );
      }
    case FieldType.enumName:
      if (value is! EnumValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsEnumValue,
            path: path,
            args: {'field': field.key},
          ),
        );
      } else if (!(field.enumValues ?? const []).contains(value.name)) {
        out.add(
          QueryError(
            QueryErrorCode.notEnumValue,
            path: path,
            args: {'text': value.name, 'field': field.key},
          ),
        );
      }
    case FieldType.date:
      // A period is only meaningful under `in`; every other op takes one
      // day (the parser lowers a period to its edge day for those).
      if (value is DateRangeValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsSingleDay,
            path: path,
            args: {'field': field.key},
          ),
        );
      } else if (value is! DateValue) {
        out.add(
          QueryError(
            QueryErrorCode.expectsDate,
            path: path,
            args: {'field': field.key},
          ),
        );
      }
  }
}
