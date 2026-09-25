import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';

/// The stored shape of a query (saved queries, PR 2 of #2365). Bump when a
/// node or value shape changes; [queryNodeFromJson] refuses newer versions
/// rather than guessing.
const int kQueryJsonVersion = 1;

Map<String, Object?> queryNodeToJson(QueryNode node) => {
  'version': kQueryJsonVersion,
  'node': _node(node),
};

Map<String, Object?> _node(QueryNode n) => switch (n) {
  AndNode(:final children) => {'t': 'and', 'c': children.map(_node).toList()},
  OrNode(:final children) => {'t': 'or', 'c': children.map(_node).toList()},
  NotNode(:final child) => {'t': 'not', 'c': _node(child)},
  ConditionNode(:final path, :final op, :final value) => {
    't': 'cond',
    'path': path.segments,
    'op': op.name,
    'value': value == null ? null : _value(value),
  },
  ScopedNode(:final path, :final inner) => {
    't': 'scoped',
    'path': path.segments,
    'inner': _node(inner),
  },
  TextNode(:final words) => {'t': 'text', 'words': words},
};

Map<String, Object?> _value(QueryValue v) => switch (v) {
  NumberValue(:final value, :final typedUnit) => {
    'k': 'num',
    'v': value,
    if (typedUnit != null) 'u': typedUnit.name,
  },
  StringValue(:final value) => {'k': 'str', 'v': value},
  BoolValue(:final value) => {'k': 'bool', 'v': value},
  EnumValue(:final name) => {'k': 'enum', 'v': name},
  DateValue(:final day) => {'k': 'date', 'v': _day(day)},
  DateRangeValue(:final start, :final end) => {
    'k': 'range',
    's': _day(start),
    'e': _day(end),
  },
  ListValue(:final items) => {'k': 'list', 'v': items.map(_value).toList()},
  RefValue(:final id, :final label) => {'k': 'ref', 'id': id, 'label': label},
};

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

QueryNode queryNodeFromJson(Map<String, Object?> json) {
  final version = json['version'];
  if (version is! int || version > kQueryJsonVersion || version < 1) {
    throw QueryJsonException('unsupported query version $version');
  }
  final node = json['node'];
  if (node is! Map) {
    throw const QueryJsonException('missing node');
  }
  return _readNode(_readMap(node));
}

QueryNode _readNode(Map<String, Object?> m) {
  switch (m['t']) {
    case 'and':
      return AndNode(_readList(m['c']).map(_readMap).map(_readNode).toList());
    case 'or':
      return OrNode(_readList(m['c']).map(_readMap).map(_readNode).toList());
    case 'not':
      return NotNode(_readNode(_readMap(m['c'])));
    case 'cond':
      final op = QueryOp.values.where((o) => o.name == m['op']).firstOrNull;
      if (op == null) throw QueryJsonException('unknown op ${m['op']}');
      final raw = m['value'];
      return ConditionNode(
        FieldPath(_readStrings(m['path'])),
        op,
        raw == null ? null : _readValue(_readMap(raw)),
      );
    case 'scoped':
      return ScopedNode(
        FieldPath(_readStrings(m['path'])),
        _readNode(_readMap(m['inner'])),
      );
    case 'text':
      return TextNode(_readStrings(m['words']));
    default:
      throw QueryJsonException('unknown node type ${m['t']}');
  }
}

QueryValue _readValue(Map<String, Object?> m) {
  switch (m['k']) {
    case 'num':
      final v = m['v'];
      if (v is! num) throw const QueryJsonException('bad number');
      final u = m['u'];
      return NumberValue(
        v.toDouble(),
        u == null
            ? null
            : QueryUnit.values.firstWhere(
                (x) => x.name == u,
                orElse: () => throw QueryJsonException('unknown unit $u'),
              ),
      );
    case 'str':
      return StringValue(_str(m['v']));
    case 'bool':
      final v = m['v'];
      if (v is! bool) throw const QueryJsonException('bad bool');
      return BoolValue(v);
    case 'enum':
      return EnumValue(_str(m['v']));
    case 'date':
      return DateValue(_readDay(m['v']));
    case 'range':
      return DateRangeValue(_readDay(m['s']), _readDay(m['e']));
    case 'list':
      return ListValue(
        _readList(m['v']).map(_readMap).map(_readValue).toList(),
      );
    case 'ref':
      return RefValue(_str(m['id']), _str(m['label']));
    default:
      throw QueryJsonException('unknown value kind ${m['k']}');
  }
}

DateTime _readDay(Object? v) {
  final s = _str(v);
  final parts = s.split('-');
  if (parts.length != 3) throw QueryJsonException('bad day $s');
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null)) throw QueryJsonException('bad day $s');
  final day = DateTime(numbers[0]!, numbers[1]!, numbers[2]!);
  // DateTime normalizes an impossible day (2025-02-30 becomes March 2). A
  // corrupted or hand-edited saved query must fail, never change meaning.
  if (day.year != numbers[0] ||
      day.month != numbers[1] ||
      day.day != numbers[2]) {
    throw QueryJsonException('impossible day $s');
  }
  return day;
}

String _str(Object? v) {
  if (v is! String) throw QueryJsonException('expected a string, got $v');
  return v;
}

List<Object?> _readList(Object? v) {
  if (v is! List) throw QueryJsonException('expected a list, got $v');
  return v.cast<Object?>();
}

Map<String, Object?> _readMap(Object? v) {
  if (v is! Map) throw QueryJsonException('expected a map, got $v');
  return v.cast<String, Object?>();
}

List<String> _readStrings(Object? v) => _readList(v).map(_str).toList();
