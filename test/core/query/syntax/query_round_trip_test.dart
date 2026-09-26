import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

/// parse(print(ast)) == ast over generated trees, in both unit systems.
void main() {
  const names = MapNameResolver({
    QuerySubject.sites: {'Salt Pier': 'site-1', 'Bob\'s "Reef"': 'site-2'},
  });
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  QueryValue number(Random r, UnitPrefs prefs) {
    // Up to three decimals, the precision a diver plausibly types.
    final raw = r.nextInt(400) + (r.nextBool() ? 0 : r.nextInt(1000) / 1000);
    final unit = r.nextInt(3) == 0
        ? (r.nextBool() ? QueryUnit.m : QueryUnit.ft)
        : null;
    return NumberValue(
      groundToStorage(raw, unit, FieldDimension.depth, prefs),
      unit,
    );
  }

  QueryNode leaf(Random r, UnitPrefs prefs) {
    switch (r.nextInt(12)) {
      case 0:
        return ConditionNode(
          const FieldPath(['depth']),
          QueryOp.gt,
          number(r, prefs),
        );
      case 1:
        return ConditionNode(
          const FieldPath(['depth']),
          QueryOp.between,
          ListValue([number(r, prefs), number(r, prefs)]),
        );
      case 2:
        return ConditionNode(
          const FieldPath(['weights']),
          QueryOp.isEmpty,
          null,
        );
      case 3:
        return ConditionNode(
          const FieldPath(['notes']),
          QueryOp.contains,
          const StringValue('night dive'),
        );
      case 4:
        return ConditionNode(
          const FieldPath(['waterType']),
          QueryOp.inList,
          const ListValue([EnumValue('salt'), EnumValue('fresh')]),
        );
      case 5:
        return ConditionNode(
          const FieldPath(['site']),
          QueryOp.eq,
          const RefValue('site-2', 'Bob\'s "Reef"'),
        );
      case 6:
        return ConditionNode(
          const FieldPath(['date']),
          QueryOp.inList,
          DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31)),
        );
      case 7:
        return ConditionNode(
          const FieldPath(['date']),
          QueryOp.lt,
          DateValue(DateTime(2025, 6, 3)),
        );
      case 8:
        return ScopedNode(
          const FieldPath(['gear']),
          ConditionNode(
            const FieldPath(['type']),
            QueryOp.neq,
            const EnumValue('bcd'),
          ),
        );
      case 9:
        return ConditionNode(
          const FieldPath(['buddies', 'certifications', 'level']),
          QueryOp.eq,
          const StringValue('rescue'),
        );
      case 10:
        return const TextNode(['manta']);
      default:
        return ConditionNode(
          const FieldPath(['favorite']),
          QueryOp.eq,
          const BoolValue(true),
        );
    }
  }

  QueryNode tree(Random r, int depth, UnitPrefs prefs) {
    if (depth == 0 || r.nextInt(3) == 0) return leaf(r, prefs);
    switch (r.nextInt(3)) {
      case 0:
        return AndNode([tree(r, depth - 1, prefs), tree(r, depth - 1, prefs)]);
      case 1:
        return OrNode([tree(r, depth - 1, prefs), tree(r, depth - 1, prefs)]);
      default:
        return NotNode(tree(r, depth - 1, prefs));
    }
  }

  for (final (label, prefs) in [
    ('metric', kMetricPrefs),
    ('imperial', imperial),
  ]) {
    test('parse(print(ast)) == ast, $label, 300 trees', () {
      final r = Random(20260925);
      final printer = QueryPrinter(fixtureRegistry, fixtureDives, prefs);
      final parser = QueryParser(
        fixtureRegistry,
        fixtureDives,
        ParseContext(prefs: prefs, now: DateTime(2026, 9, 25), names: names),
      );
      for (var i = 0; i < 300; i++) {
        final ast = tree(r, 3, prefs);
        final text = printer.print(ast);
        final back = parser.parse(text);
        expect(
          back,
          isA<ParseOk>(),
          reason: 'could not re-parse "$text": $back',
        );
        expect((back as ParseOk).node, equals(ast), reason: 'from "$text"');
      }
    });
  }
}
