import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

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
  _walk(node, root, registry, out);
  return out;
}

void _walk(
  QueryNode n,
  QueryEntity scope,
  QueryRegistry registry,
  List<QueryError> out,
) {
  switch (n) {
    case AndNode(:final children):
    case OrNode(:final children):
      for (final c in children) {
        _walk(c, scope, registry, out);
      }
    case NotNode(:final child):
      _walk(child, scope, registry, out);
    case TextNode():
      if (scope.textSearchSql.isEmpty) {
        out.add(
          QueryError('free text cannot be searched inside ${scope.table}'),
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
          QueryError('[...] needs a relation, "$path" is a field', path: path),
        );
        return;
      }
      _walk(
        inner,
        registry.entityFor(res.terminalRelation!.target),
        registry,
        out,
      );
    case ConditionNode(:final path, :final op, :final value):
      final res = resolvePath(registry, scope, path);
      if (res.error != null) {
        out.add(res.error!);
        return;
      }
      final field = res.field;
      if (field == null) {
        _checkRelationOp(path, op, value, out);
        return;
      }
      if (!field.ops.contains(op)) {
        out.add(
          QueryError('${op.name} cannot be used with ${field.key}', path: path),
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
        out.add(QueryError('$name expects a reference', path: path));
      }
    case QueryOp.inList:
      if (value is! ListValue || value.items.isEmpty) {
        out.add(QueryError('the list is empty', path: path));
      } else if (value.items.any((v) => v is! RefValue)) {
        out.add(QueryError('$name expects references', path: path));
      }
    default:
      out.add(
        QueryError(
          '"$path" is a relation; use =, in, :none, :any or [...]',
          path: path,
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
      out.add(QueryError('between needs two values', path: path));
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
      out.add(QueryError('in needs a list', path: path));
      return;
    }
    if (value.items.isEmpty) {
      out.add(QueryError('the list is empty', path: path));
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
        out.add(QueryError('${field.key} expects a number', path: path));
        return;
      }
      final unitless = const {
        FieldDimension.none,
        FieldDimension.percent,
        FieldDimension.count,
      }.contains(field.dimension);
      if (value.typedUnit != null && unitless) {
        out.add(QueryError('${field.key} takes no unit', path: path));
      }
      final s = field.sanity;
      if (s != null && (value.value < s.min || value.value > s.max)) {
        out.add(QueryError('${field.key} value is out of range', path: path));
      }
    case FieldType.text:
    case FieldType.id:
      if (value is! StringValue) {
        out.add(QueryError('${field.key} expects text', path: path));
      }
    case FieldType.bool:
      if (value is! BoolValue) {
        out.add(QueryError('${field.key} expects true or false', path: path));
      }
    case FieldType.enumName:
      if (value is! EnumValue) {
        out.add(
          QueryError('${field.key} expects one of its values', path: path),
        );
      } else if (!(field.enumValues ?? const []).contains(value.name)) {
        out.add(
          QueryError('"${value.name}" is not a ${field.key} value', path: path),
        );
      }
    case FieldType.date:
      if (value is! DateValue && value is! DateRangeValue) {
        out.add(QueryError('${field.key} expects a date', path: path));
      }
  }
}
