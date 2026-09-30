import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

typedef LoweredClause = ({
  List<QueryNode> nodes,
  ClauseChip? chip,
  String? error,
});

LoweredClause _fail(String error) =>
    (nodes: const [], chip: null, error: error);

/// One model clause as query nodes on its registry path (#2365 PR 5). The
/// model chose the words; units, bounds and values are decided here. [now]
/// anchors the date and days kinds.
LoweredClause lowerClause(
  QueryClause c,
  ExploreField? field,
  UnitPrefs units, {
  DateTime? now,
}) {
  if (field == null) return _fail('unknownField');
  if (!field.ops.contains(c.op)) return _fail('invalid');
  return switch (field.kind) {
    ExploreValueKind.number => _number(c, field, units),
    ExploreValueKind.flag => _flag(c, field),
    ExploreValueKind.enumName => _enum(c, field),
    ExploreValueKind.typeName => _typeName(c, field),
    ExploreValueKind.date => _date(c, field, now ?? DateTime.now()),
    ExploreValueKind.days => _days(c, field, now ?? DateTime.now()),
  };
}

/// A date field compared with a time phrase: before the period is before
/// its first day, after it is after its last, and eq is within it. A bare
/// number is a year.
LoweredClause _date(QueryClause c, ExploreField field, DateTime now) {
  final text = switch (c.value) {
    final String s => s,
    final num n => '${n.toInt()}',
    _ => null,
  };
  if (text == null) return _fail('invalid');
  final range = parseDateText(text, now: now);
  if (range == null) return _fail('unknownTime');
  final key = field.path.last;
  ConditionNode at(QueryOp op, DateTime d) =>
      ConditionNode(FieldPath([key]), op, DateValue(d));
  final nodes = <QueryNode>[
    ...switch (c.op) {
      ClauseOp.lt ||
      ClauseOp.lte => [if (range.start != null) at(QueryOp.lt, range.start!)],
      ClauseOp.gt ||
      ClauseOp.gte => [if (range.end != null) at(QueryOp.gt, range.end!)],
      _ => [
        if (range.start != null) at(QueryOp.gte, range.start!),
        if (range.end != null) at(QueryOp.lte, range.end!),
      ],
    },
  ];
  if (nodes.isEmpty) return _fail('invalid');
  return (
    nodes: nodes,
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: (start: range.start, end: range.end),
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

/// "Within N days" from today, inclusive: the date field on or before
/// today plus N. An overdue date is already before it, so it matches.
LoweredClause _days(QueryClause c, ExploreField field, DateTime now) {
  final raw = c.value;
  if (raw is! num) return _fail('invalid');
  if (raw < 0 || raw > 3650) return _fail('outOfRange');
  final days = raw.round();
  final until = DateTime(now.year, now.month, now.day + days);
  return (
    nodes: [
      ConditionNode(
        FieldPath([field.path.last]),
        QueryOp.lte,
        DateValue(until),
      ),
    ],
    chip: ClauseChip(
      field: field,
      op: ClauseOp.lte,
      value: days,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

List<String> _strings(Object raw) =>
    raw is List ? raw.whereType<String>().toList() : [if (raw is String) raw];

LoweredClause _flag(QueryClause c, ExploreField field) {
  final v = c.value;
  if (v != true && v != false) return _fail('invalid');
  final on = v == true;
  final QueryNode? node = switch (field.name) {
    'favorite' when on => ConditionNode(
      FieldPath(['favorite']),
      QueryOp.eq,
      const BoolValue(true),
    ),
    'deco' => ConditionNode(FieldPath(['deco']), QueryOp.eq, BoolValue(on)),
    'noBuddy' when on => ConditionNode(
      FieldPath(['buddies']),
      QueryOp.isEmpty,
      null,
    ),
    _ => null,
  };
  if (node == null) return _fail('invalid');
  return (
    nodes: [node],
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: on,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

LoweredClause _enum(QueryClause c, ExploreField field) {
  final values = _strings(c.value);
  if (values.isEmpty) return _fail('invalid');
  final allowed = field.enumValues!;
  if (values.any((v) => !allowed.contains(v))) return _fail('invalid');
  // The model's tokens (weekday: mon..sun) map onto the registry's names,
  // which run Monday first too.
  final tokens = field.tokens;
  final names = tokens == null
      ? values
      : [for (final v in values) field.field!.enumValues![tokens.indexOf(v)]];
  final QueryNode node = ConditionNode(
    FieldPath(field.path),
    QueryOp.inList,
    ListValue([for (final n in names) EnumValue(n)]),
  );
  // "Not" keeps the dives where the field was never recorded: the query
  // tree's NOT treats an unknown as not matching, where the complement of
  // the listed values would silently drop every blank dive.
  return (
    nodes: [c.op == ClauseOp.not ? NotNode(node) : node],
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: values,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

/// A dive type is the diver's own entity, named in their words: an exact
/// (case-insensitive) match on any of the names through the types junction.
LoweredClause _typeName(QueryClause c, ExploreField field) {
  final values = _strings(c.value);
  if (values.isEmpty) return _fail('invalid');
  return (
    nodes: [
      ConditionNode(
        FieldPath(field.path),
        QueryOp.inList,
        ListValue([for (final v in values) StringValue(v)]),
      ),
    ],
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: values,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

LoweredClause _number(QueryClause c, ExploreField field, UnitPrefs units) {
  if (!unitFits(field.dimension, c.unit)) return _fail('invalid');
  final rate = field.dimension == FieldDimension.pressureRate;
  // A rate keeps four decimals: psi/min bounds half a psi apart are only
  // 0.07 bar/min apart, and two decimals would round them together.
  double ground(num v) => double.parse(
    groundClause(
      v,
      c.unit,
      field.dimension,
      units,
    ).toStringAsFixed(rate ? 4 : 2),
  );
  double? lo;
  double? hi;
  Object chipValue;
  if (c.op == ClauseOp.between) {
    final raw = c.value;
    if (raw is! List || raw.length != 2 || raw.any((v) => v is! num)) {
      return _fail('invalid');
    }
    var a = ground(raw[0] as num);
    var b = ground(raw[1] as num);
    if (b < a) (a, b) = (b, a);
    if (!field.accepts(a) || !field.accepts(b)) return _fail('outOfRange');
    lo = a;
    hi = b;
    chipValue = [a, b];
  } else {
    final raw = c.value;
    if (raw is! num) return _fail('invalid');
    final v = ground(raw);
    chipValue = v;
    // The number said is what must be plausible; an "exactly" band may
    // reach half a unit past the bound.
    if (!field.accepts(v)) return _fail('outOfRange');
    switch (c.op) {
      case ClauseOp.lt:
        hi = field.strictCount ? v.ceilToDouble() - 1 : v;
      case ClauseOp.lte:
        hi = v;
      case ClauseOp.gt:
        lo = field.strictCount ? v.floorToDouble() + 1 : v;
      case ClauseOp.gte:
        lo = v;
      case ClauseOp.eq:
        // A measured value is almost never exactly the number said, so
        // "exactly 15 m" is the half unit either side of it in the unit the
        // diver used, the way it would be rounded. SAC is read to a tenth of
        // a bar or a whole psi, so "a SAC of 1.2" is 1.15 to 1.25 bar/min and
        // "20 psi/min" is 19.5 to 20.5. Counts stay exact.
        final half = switch (field.dimension) {
          FieldDimension.depth || FieldDimension.temperature => 0.5,
          FieldDimension.pressureRate =>
            rateUnitSaid(c.unit, units) == PressureUnit.psi ? 0.5 : 0.05,
          _ => 0.0,
        };
        lo = half == 0 ? v : ground(raw - half);
        hi = half == 0 ? v : ground(raw + half);
      default:
        return _fail('invalid');
    }
  }
  // Whole-number fields round inward, so a bound never reaches past what was
  // said: "under 3.5 stars" is at most 3, "at least 3.5" is at least 4.
  if (field.wholeNumbers) {
    lo = lo?.ceilToDouble();
    hi = hi?.floorToDouble();
    // "Exactly 3.5 stars" rounds to at least 4 and at most 3: no whole
    // number lies between, so say so rather than find nothing.
    if (lo != null && hi != null && lo > hi) return _fail('outOfRange');
  }
  final key = field.path.last;
  final bounds = <QueryNode>[
    if (lo != null)
      ConditionNode(FieldPath([key]), QueryOp.gte, NumberValue(lo, null)),
    if (hi != null)
      ConditionNode(FieldPath([key]), QueryOp.lte, NumberValue(hi, null)),
  ];
  // A child field (a tank's O2) scopes both bounds to one row, as the old
  // minO2Percent/maxO2Percent axis did.
  final nodes = field.path.length == 1
      ? bounds
      : <QueryNode>[
          ScopedNode(
            FieldPath(field.path.sublist(0, field.path.length - 1)),
            bounds.length == 1 ? bounds.single : AndNode(bounds),
          ),
        ];
  // A strict count reports the bound it applies: "more than 2" is 3.
  if (field.strictCount) {
    if (c.op == ClauseOp.gt) chipValue = lo!;
    if (c.op == ClauseOp.lt) chipValue = hi!;
  }
  // The chip reports the op the query ACTUALLY applies: every bound is
  // inclusive, so a strict "deeper than 20" shows as "at least 20".
  return (
    nodes: nodes,
    chip: ClauseChip(
      field: field,
      op: switch (c.op) {
        ClauseOp.gt => ClauseOp.gte,
        ClauseOp.lt => ClauseOp.lte,
        _ => c.op,
      },
      value: chipValue,
      dimension: field.dimension,
    ),
    error: null,
  );
}
