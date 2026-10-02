import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import 'explore_query_parts.dart';

/// Every field the prompt offers the model lowers to something. The fields
/// with no plain filter axis become conditions in the query tree, and a
/// second clause on a field whose axis is taken ANDs instead of widening it.
void main() {
  const units = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );

  ExploreCompilation compile(List<Map<String, Object?>> clauses) =>
      ExploreCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': clauses,
        }),
        ExploreCompilerContext(
          units: units,
          names: NameIndex.empty,
          now: DateTime(2026, 9, 28),
        ),
      );

  Map<String, Object?> clause(String field, String op, Object value) => {
    'field': field,
    'op': op,
    'value': value,
    'text': '$field $op $value',
  };

  ConditionNode cond(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);

  test('average depth is an inclusive bound in the query tree', () {
    final q = compile([clause('avgDepth', 'gt', 15)]);
    expect(q.unplaced, isEmpty);
    expect(q.chips, hasLength(1));
    expect(q.query, cond('avgDepth', QueryOp.gte, const NumberValue(15, null)));
  });

  test('air temperature between two values is two bounds', () {
    final q = compile([
      clause('airTemp', 'between', [-20, 5]),
    ]);
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond('airTemp', QueryOp.gte, const NumberValue(-20, null)),
        cond('airTemp', QueryOp.lte, const NumberValue(5, null)),
      ]),
    );
  });

  test('an exact dive number bounds both sides', () {
    final q = compile([clause('diveNumber', 'eq', 100)]);
    expect(
      q.query,
      AndNode([
        cond('diveNumber', QueryOp.gte, const NumberValue(100, null)),
        cond('diveNumber', QueryOp.lte, const NumberValue(100, null)),
      ]),
    );
  });

  test('dive mode, entry method and current are enum conditions', () {
    final q = compile([
      clause('diveMode', 'eq', 'ccr'),
      clause('entryMethod', 'in', ['boat', 'giantStride']),
      clause('currentStrength', 'not', ['strong']),
    ]);
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond('diveMode', QueryOp.inList, ListValue(const [EnumValue('ccr')])),
        cond(
          'entryMethod',
          QueryOp.inList,
          ListValue(const [EnumValue('boat'), EnumValue('giantStride')]),
        ),
        NotNode(
          cond(
            'currentStrength',
            QueryOp.inList,
            ListValue(const [EnumValue('strong')]),
          ),
        ),
      ]),
    );
  });

  test('a dive type is an exact name match through the types junction', () {
    final q = compile([clause('diveType', 'eq', 'Night')]);
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      ConditionNode(
        FieldPath(['types', 'name']),
        QueryOp.inList,
        ListValue(const [StringValue('Night')]),
      ),
    );
  });

  test('a second water-type clause ANDs instead of widening the axis', () {
    final q = compile([
      clause('waterType', 'eq', 'salt'),
      clause('waterType', 'not', ['salt']),
    ]);
    // Each clause is its own condition, so the two together match
    // nothing, as the chips say.
    expect(
      q.query,
      AndNode([
        cond('waterType', QueryOp.inList, ListValue(const [EnumValue('salt')])),
        NotNode(
          cond(
            'waterType',
            QueryOp.inList,
            ListValue(const [EnumValue('salt')]),
          ),
        ),
      ]),
    );
  });

  test('a second weekday clause ANDs in the registry weekday names', () {
    final q = compile([
      clause('weekday', 'in', ['sat', 'sun']),
      clause('weekday', 'eq', 'sun'),
    ]);
    expect(
      q.query,
      AndNode([
        cond(
          'weekday',
          QueryOp.inList,
          ListValue(const [EnumValue('saturday'), EnumValue('sunday')]),
        ),
        cond('weekday', QueryOp.inList, ListValue(const [EnumValue('sunday')])),
      ]),
    );
  });

  test('air temperature allows ice-diving values', () {
    expect(compile([clause('airTemp', 'lt', -25)]).unplaced, isEmpty);
    expect(
      compile([clause('airTemp', 'lt', -60)]).unplaced.single.reason,
      'outOfRange',
    );
  });

  test('several dive types match any of them', () {
    final q = compile([
      clause('diveType', 'in', ['Wreck', 'Night']),
    ]);
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      ConditionNode(
        FieldPath(['types', 'name']),
        QueryOp.inList,
        ListValue(const [StringValue('Wreck'), StringValue('Night')]),
      ),
    );
  });

  test('exactly a depth or temperature is the half unit either side', () {
    final q = compile([clause('avgDepth', 'eq', 15)]);
    expect(
      q.query,
      AndNode([
        cond('avgDepth', QueryOp.gte, const NumberValue(14.5, null)),
        cond('avgDepth', QueryOp.lte, const NumberValue(15.5, null)),
      ]),
    );
    // The chip still shows the number the diver said.
    expect((q.chips.single.payload as ClauseChip).value, 15);
    final depth = compile([clause('depth', 'eq', 30)]);
    expect(
      (
        boundOf(depth, 'depth', QueryOp.gte),
        boundOf(depth, 'depth', QueryOp.lte),
      ),
      (29.5, 30.5),
    );
  });

  test('the half unit is in the unit the diver used', () {
    final q = compile([
      {...clause('depth', 'eq', 100), 'unit': 'ft'},
    ]);
    // 99.5 ft to 100.5 ft, in metres.
    expect(boundOf(q, 'depth', QueryOp.gte), closeTo(30.33, 0.01));
    expect(boundOf(q, 'depth', QueryOp.lte), closeTo(30.63, 0.01));
  });

  test('exactly a count stays exact', () {
    final q = compile([clause('rating', 'eq', 4)]);
    expect(
      q.query,
      AndNode([
        cond('rating', QueryOp.gte, const NumberValue(4, null)),
        cond('rating', QueryOp.lte, const NumberValue(4, null)),
      ]),
    );
  });

  test('range limits are the query registry sanity bounds', () {
    // The registry allows 400 m; Explore used to stop at 350.
    expect(compile([clause('depth', 'gt', 380)]).unplaced, isEmpty);
    expect(
      compile([clause('depth', 'gt', 450)]).unplaced.single.reason,
      'outOfRange',
    );
    expect(
      compile([
        clause('depth', 'between', [10, 450]),
      ]).unplaced.single.reason,
      'outOfRange',
    );
    // "Exactly" at a bound: the band reaches past it, the number does not.
    expect(compile([clause('depth', 'eq', 0)]).unplaced, isEmpty);
  });

  group('the derived fields', () {
    test('SAC is a rate grounded from the unit said', () {
      final q = compile([
        {...clause('sac', 'gt', 21.76), 'unit': 'psi_min'},
      ]);
      expect(q.unplaced, isEmpty);
      final bound = (q.query! as ConditionNode).value as NumberValue;
      expect(bound.value, closeTo(1.5, 0.01));
    });

    test('exactly a SAC is a tenth either side', () {
      final q = compile([clause('sac', 'eq', 1.2)]);
      expect(
        q.query,
        AndNode([
          cond('sac', QueryOp.gte, const NumberValue(1.15, null)),
          cond('sac', QueryOp.lte, const NumberValue(1.25, null)),
        ]),
      );
    });

    test('trend, change, stop, excursion and length', () {
      final q = compile([
        clause('sacTrend', 'eq', 'rising'),
        clause('sacChange', 'gt', 10),
        clause('finalStop', 'eq', 'unstable'),
        clause('finalStopExcursion', 'gt', 1),
        clause('finalStopDuration', 'gte', 3),
      ]);
      expect(q.unplaced, isEmpty);
      expect(
        q.query,
        AndNode([
          cond(
            'sacTrend',
            QueryOp.inList,
            ListValue(const [EnumValue('rising')]),
          ),
          cond('sacChange', QueryOp.gte, const NumberValue(10, null)),
          cond(
            'finalStop',
            QueryOp.inList,
            ListValue(const [EnumValue('unstable')]),
          ),
          cond('finalStopExcursion', QueryOp.gte, const NumberValue(1, null)),
          cond('finalStopDuration', QueryOp.gte, const NumberValue(3, null)),
        ]),
      );
    });

    test('a finding is a rule of any of the dive findings', () {
      final rule = ConditionNode(
        FieldPath(['findings', 'rule']),
        QueryOp.inList,
        ListValue(const [EnumValue('rapidAscent')]),
      );
      expect(compile([clause('finding', 'eq', 'rapidAscent')]).query, rule);
      expect(
        compile([
          clause('finding', 'not', ['rapidAscent']),
        ]).query,
        NotNode(rule),
      );
    });

    (double, double) bounds(ExploreCompilation q) {
      final and = q.query! as AndNode;
      double v(int i) =>
          ((and.children[i] as ConditionNode).value as NumberValue).value;
      return (v(0), v(1));
    }

    test('exactly a SAC in psi/min is a real band, half a psi either side', () {
      final q = ExploreCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': [clause('sac', 'eq', 20)],
        }),
        ExploreCompilerContext(
          units: const UnitPrefs(
            depth: DepthUnit.feet,
            temperature: TemperatureUnit.fahrenheit,
            pressure: PressureUnit.psi,
            weight: WeightUnit.pounds,
            volume: VolumeUnit.cubicFeet,
          ),
          names: NameIndex.empty,
          now: DateTime(2026, 9, 28),
        ),
      );
      final (lo, hi) = bounds(q);
      // 19.5 to 20.5 psi/min: 1.344 to 1.413 bar/min, not one rounded value.
      expect(lo, closeTo(1.344, 0.001));
      expect(hi, closeTo(1.413, 0.001));
    });

    test('SAC said in psi without per minute is psi per minute', () {
      final q = compile([
        {...clause('sac', 'gt', 20), 'unit': 'psi'},
      ]);
      final bound = (q.query! as ConditionNode).value as NumberValue;
      expect(bound.value, closeTo(1.379, 0.001));
    });

    test('a volume rate on SAC is refused, not read as pressure', () {
      final q = compile([
        {...clause('sac', 'gt', 15), 'unit': 'l_min'},
      ]);
      expect(q.unplaced.single.reason, 'invalid');
      expect(q.query, isNull);
    });

    test('a unit of the wrong kind is refused on any measured field', () {
      // Reading 20 c as 20 m, or 15 m as 15 degrees, would search for the
      // wrong thing without saying so.
      for (final bad in [
        {...clause('depth', 'gt', 20), 'unit': 'c'},
        {...clause('waterTemp', 'lt', 15), 'unit': 'm'},
        {...clause('bottomTime', 'gt', 40), 'unit': 'bar'},
      ]) {
        final q = compile([bad]);
        expect(q.unplaced.single.reason, 'invalid', reason: '$bad');
      }
      // The right kind still grounds.
      expect(
        compile([
          {...clause('depth', 'gt', 60), 'unit': 'ft'},
        ]).unplaced,
        isEmpty,
      );
      expect(
        compile([
          {...clause('bottomTime', 'gt', 40), 'unit': 'min'},
        ]).unplaced,
        isEmpty,
      );
    });

    test('a change below minus 100 percent is out of range', () {
      expect(
        compile([clause('sacChange', 'lt', -150)]).unplaced.single.reason,
        'outOfRange',
      );
    });
  });
}
