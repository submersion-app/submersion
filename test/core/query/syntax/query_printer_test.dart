import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final metric = QueryPrinter(fixtureRegistry, fixtureDives, kMetricPrefs);
  final imperial = QueryPrinter(
    fixtureRegistry,
    fixtureDives,
    const UnitPrefs(
      depth: DepthUnit.feet,
      temperature: TemperatureUnit.fahrenheit,
      pressure: PressureUnit.psi,
      weight: WeightUnit.pounds,
      volume: VolumeUnit.cubicFeet,
    ),
  );

  test('an empty query prints as empty text', () {
    expect(metric.print(null), '');
  });

  test('numbers print in the diver unit, or with the typed suffix', () {
    final bare = ConditionNode(
      const FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30.48, null),
    );
    expect(metric.print(bare), 'depth > 30.48');
    expect(imperial.print(bare), 'depth > 100');
    final typed = ConditionNode(
      const FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30.48, QueryUnit.ft),
    );
    expect(metric.print(typed), 'depth > 100ft');
  });

  test('numbers keep their typed precision and shed float noise', () {
    expect(formatQueryNumber(100.123), '100.123');
    expect(formatQueryNumber(18.5), '18.5');
    expect(formatQueryNumber(30), '30');
    expect(formatQueryNumber(100.12300000000001), '100.123');
    expect(formatQueryNumber(0.1 + 0.2), '0.3');
    final typed = ConditionNode(
      const FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(100.123 / 3.28084, QueryUnit.ft),
    );
    expect(metric.print(typed), 'depth > 100.123ft');
  });

  test('operators, presence, lists, between, scoped, text', () {
    expect(
      metric.print(
        ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
      ),
      'weights:none',
    );
    expect(
      metric.print(
        ConditionNode(const FieldPath(['rating']), QueryOp.isSet, null),
      ),
      'rating:any',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['waterType']),
          QueryOp.inList,
          const ListValue([EnumValue('salt'), EnumValue('fresh')]),
        ),
      ),
      'waterType in [salt, fresh]',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.between,
          const ListValue([NumberValue(18, null), NumberValue(30, null)]),
        ),
      ),
      'depth between 18 and 30',
    );
    expect(
      metric.print(
        ScopedNode(
          const FieldPath(['gear']),
          ConditionNode(
            const FieldPath(['type']),
            QueryOp.eq,
            const EnumValue('wetsuit'),
          ),
        ),
      ),
      'gear[type = wetsuit]',
    );
    expect(metric.print(const TextNode(['night', 'dive'])), '"night dive"');
    expect(metric.print(const TextNode(['manta'])), 'manta');
  });

  test('minimal parentheses and explicit AND', () {
    final tree = OrNode([
      AndNode([
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
        NotNode(
          OrNode([
            ConditionNode(
              const FieldPath(['favorite']),
              QueryOp.eq,
              const BoolValue(true),
            ),
            ConditionNode(
              const FieldPath(['rating']),
              QueryOp.gte,
              const NumberValue(4, null),
            ),
          ]),
        ),
      ]),
      ConditionNode(
        const FieldPath(['notes']),
        QueryOp.contains,
        const StringValue('night dive'),
      ),
    ]);
    expect(
      metric.print(tree),
      'depth > 30 AND NOT (favorite = true OR rating >= 4) '
      'OR notes ~ "night dive"',
    );
    expect(
      metric.print(
        AndNode([
          OrNode([
            ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
            ConditionNode(
              const FieldPath(['waterTemp']),
              QueryOp.isEmpty,
              null,
            ),
          ]),
          ConditionNode(const FieldPath(['rating']), QueryOp.isSet, null),
        ]),
      ),
      '(weights:none OR waterTemp:none) AND rating:any',
    );
  });

  test('dates and refs', () {
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['date']),
          QueryOp.gte,
          DateValue(DateTime(2025, 1, 15)),
        ),
      ),
      'date >= 2025-01-15',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['date']),
          QueryOp.inList,
          DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31)),
        ),
      ),
      'date in 2025',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['date']),
          QueryOp.inList,
          DateRangeValue(DateTime(2025, 3, 1), DateTime(2025, 3, 31)),
        ),
      ),
      'date in 2025-03',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['date']),
          QueryOp.inList,
          DateRangeValue(DateTime(2025, 3, 1), DateTime(2025, 3, 10)),
        ),
      ),
      'date in "2025-03-01 to 2025-03-10"',
    );
    expect(
      metric.print(
        ConditionNode(const FieldPath(['site']), QueryOp.eq, kFixtureSite),
      ),
      'site = "Salt Pier"',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['site']),
          QueryOp.eq,
          const RefValue('x', 'Bob\'s "Reef" \\ Wall'),
        ),
      ),
      r'site = "Bob'
      "'"
      r's \"Reef\" \\ Wall"',
    );
  });

  test('a text value that is a keyword or has spaces is quoted', () {
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['notes']),
          QueryOp.eq,
          const StringValue('and'),
        ),
      ),
      'notes = "and"',
    );
    expect(
      metric.print(
        ConditionNode(
          const FieldPath(['notes']),
          QueryOp.eq,
          const StringValue('2025-03-14'),
        ),
      ),
      'notes = "2025-03-14"',
    );
  });
}
