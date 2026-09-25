import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart'
    show kQueryKeywords;
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Integers print bare; other values print with up to two decimals, trailing
/// zeros trimmed. Two decimals is what every unit field in the app shows.
String formatQueryNumber(double v) {
  final rounded = (v * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  var s = rounded.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

final RegExp _plainWord = RegExp(r'^[^\s"()\[\],:~=<>!&|-]+$');
final RegExp _isoLike = RegExp(r'^\d{4}(-\d{2}){0,2}$');

/// Emits exactly one canonical text per tree, which the parser reads back
/// to an equal tree.
class QueryPrinter {
  final QueryRegistry registry;
  final QueryEntity root;
  final UnitPrefs prefs;
  QueryPrinter(this.registry, this.root, this.prefs);

  String print(QueryNode? node) => node == null ? '' : _node(node, root);

  String _node(QueryNode n, QueryEntity scope) => switch (n) {
    // A nested AND inside AND (or OR inside OR) keeps its parentheses, so
    // the parser rebuilds the same tree shape instead of flattening it.
    AndNode(:final children) =>
      children
          .map(
            (c) => c is OrNode || c is AndNode
                ? '(${_node(c, scope)})'
                : _node(c, scope),
          )
          .join(' AND '),
    OrNode(:final children) =>
      children
          .map((c) => c is OrNode ? '(${_node(c, scope)})' : _node(c, scope))
          .join(' OR '),
    NotNode(:final child) => switch (child) {
      AndNode() || OrNode() => 'NOT (${_node(child, scope)})',
      _ => 'NOT ${_node(child, scope)}',
    },
    ScopedNode(:final path, :final inner) =>
      '$path[${_node(inner, _target(path, scope))}]',
    TextNode(:final words) =>
      words.length == 1 && _bareWordSafe(words.first)
          ? words.first
          : _quote(words.join(' ')),
    ConditionNode(:final path, :final op, :final value) => _condition(
      path,
      op,
      value,
      scope,
    ),
  };

  QueryEntity _target(FieldPath path, QueryEntity scope) {
    final res = resolvePath(registry, scope, path);
    return registry.entityFor(res.terminalRelation!.target);
  }

  /// A bare word that names a field would still parse as text (no operator
  /// follows), so it is safe unquoted; keywords, numbers and dates are not.
  bool _bareWordSafe(String w) =>
      _plainWord.hasMatch(w) &&
      !kQueryKeywords.contains(w.toLowerCase()) &&
      !_isoLike.hasMatch(w) &&
      double.tryParse(w) == null;

  String _condition(
    FieldPath path,
    QueryOp op,
    QueryValue? value,
    QueryEntity scope,
  ) {
    final res = resolvePath(registry, scope, path);
    final field = res.field;
    switch (op) {
      case QueryOp.isEmpty:
        return '$path:none';
      case QueryOp.isSet:
        return '$path:any';
      case QueryOp.inList:
        if (value is DateRangeValue) return '$path in ${_dateRange(value)}';
        final items = (value as ListValue).items;
        if (field == null) {
          final refs = items.map((v) => _quote((v as RefValue).label));
          return '$path in [${refs.join(', ')}]';
        }
        return '$path in [${items.map((v) => _value(v, field)).join(', ')}]';
      case QueryOp.between:
        final items = (value as ListValue).items;
        return '$path between ${_value(items[0], field!)} '
            'and ${_value(items[1], field)}';
      default:
        final sym = switch (op) {
          QueryOp.eq => '=',
          QueryOp.neq => '!=',
          QueryOp.lt => '<',
          QueryOp.lte => '<=',
          QueryOp.gt => '>',
          QueryOp.gte => '>=',
          QueryOp.contains => '~',
          _ => throw StateError('unreachable'),
        };
        if (field == null) {
          return '$path $sym ${_quote((value as RefValue).label)}';
        }
        return '$path $sym ${_value(value!, field)}';
    }
  }

  String _value(QueryValue v, QueryField field) => switch (v) {
    NumberValue(:final value, :final typedUnit) => () {
      final (shown, unit) = storageToDisplay(
        value,
        typedUnit,
        field.dimension,
        prefs,
      );
      return '${formatQueryNumber(shown)}${unit?.suffix ?? ''}';
    }(),
    StringValue(:final value) => _word(value),
    BoolValue(:final value) => value ? 'true' : 'false',
    EnumValue(:final name) => name,
    DateValue(:final day) => _day(day),
    DateRangeValue() => _dateRange(v),
    ListValue(:final items) =>
      '[${items.map((i) => _value(i, field)).join(', ')}]',
    RefValue(:final label) => _quote(label),
  };

  String _dateRange(DateRangeValue r) {
    final s = r.start;
    final e = r.end;
    if (s.month == 1 &&
        s.day == 1 &&
        e.month == 12 &&
        e.day == 31 &&
        s.year == e.year) {
      return '${s.year}';
    }
    if (s.day == 1 &&
        s.year == e.year &&
        s.month == e.month &&
        DateTime(e.year, e.month + 1, 0).day == e.day) {
      return '${s.year}-${_two(s.month)}';
    }
    return _quote('${_day(s)} to ${_day(e)}');
  }

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
  String _two(int n) => n.toString().padLeft(2, '0');

  /// A word prints bare only when the tokenizer would read it back as ONE
  /// word token that the parser would not mistake for a keyword, number or
  /// date.
  String _word(String s) => _bareWordSafe(s) ? s : _quote(s);

  String _quote(String s) =>
      '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
