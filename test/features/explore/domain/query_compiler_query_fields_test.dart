import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Every field the prompt offers the model lowers to something. The fields
/// with no plain filter axis become conditions in the query tree, and a
/// second clause on a field whose axis is taken ANDs instead of widening it.
void main() {
  const units = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );

  CompiledQuery compile(List<Map<String, Object?>> clauses) =>
      QueryCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': clauses,
        }),
        CompilerContext(
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
    expect(
      q.filter.query,
      cond('avgDepth', QueryOp.gte, const NumberValue(15, null)),
    );
  });

  test('air temperature between two values is two bounds', () {
    final q = compile([
      clause('airTemp', 'between', [-20, 5]),
    ]);
    expect(q.unplaced, isEmpty);
    expect(
      q.filter.query,
      AndNode([
        cond('airTemp', QueryOp.gte, const NumberValue(-20, null)),
        cond('airTemp', QueryOp.lte, const NumberValue(5, null)),
      ]),
    );
  });

  test('an exact dive number bounds both sides', () {
    final q = compile([clause('diveNumber', 'eq', 100)]);
    expect(
      q.filter.query,
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
      q.filter.query,
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
      q.filter.query,
      ConditionNode(
        FieldPath(['types', 'name']),
        QueryOp.eq,
        const StringValue('Night'),
      ),
    );
  });

  test('a second water-type clause ANDs instead of widening the axis', () {
    final q = compile([
      clause('waterType', 'eq', 'salt'),
      clause('waterType', 'not', ['salt']),
    ]);
    // The first clause owns the plain axis; the second is its own
    // condition, so the two together match nothing, as the chips say.
    expect(q.filter.waterTypes, [WaterType.salt]);
    expect(
      q.filter.query,
      NotNode(
        cond('waterType', QueryOp.inList, ListValue(const [EnumValue('salt')])),
      ),
    );
  });

  test('a second weekday clause ANDs in the registry weekday names', () {
    final q = compile([
      clause('weekday', 'in', ['sat', 'sun']),
      clause('weekday', 'eq', 'sun'),
    ]);
    expect(q.filter.weekdays, [6, 7]);
    expect(
      q.filter.query,
      cond('weekday', QueryOp.inList, ListValue(const [EnumValue('sunday')])),
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
      q.filter.query,
      OrNode([
        ConditionNode(
          FieldPath(['types', 'name']),
          QueryOp.eq,
          const StringValue('Wreck'),
        ),
        ConditionNode(
          FieldPath(['types', 'name']),
          QueryOp.eq,
          const StringValue('Night'),
        ),
      ]),
    );
  });

  test('exactly a depth or temperature is the half unit either side', () {
    final q = compile([clause('avgDepth', 'eq', 15)]);
    expect(
      q.filter.query,
      AndNode([
        cond('avgDepth', QueryOp.gte, const NumberValue(14.5, null)),
        cond('avgDepth', QueryOp.lte, const NumberValue(15.5, null)),
      ]),
    );
    // The chip still shows the number the diver said.
    expect((q.chips.single.payload as ClauseChip).value, 15);
    final depth = compile([clause('depth', 'eq', 30)]).filter;
    expect((depth.minDepth, depth.maxDepth), (29.5, 30.5));
  });

  test('the half unit is in the unit the diver used', () {
    final q = compile([
      {...clause('depth', 'eq', 100), 'unit': 'ft'},
    ]);
    // 99.5 ft to 100.5 ft, in metres.
    expect(q.filter.minDepth, closeTo(30.33, 0.01));
    expect(q.filter.maxDepth, closeTo(30.63, 0.01));
  });

  test('exactly a count stays exact', () {
    final q = compile([clause('rating', 'eq', 4)]);
    expect(q.filter.minRating, 4);
    expect(
      q.filter.query,
      cond('rating', QueryOp.lte, const NumberValue(4, null)),
    );
  });

  test('range limits are the query registry sanity bounds', () {
    // The registry allows 400 m; Explore used to stop at 350.
    expect(compile([clause('depth', 'gt', 380)]).unplaced, isEmpty);
    expect(
      compile([clause('depth', 'gt', 450)]).unplaced.single.reason,
      'outOfRange',
    );
  });
}
