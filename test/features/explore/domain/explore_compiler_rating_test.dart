import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import 'explore_query_parts.dart';

/// A rating clause is a pair of whole-star bounds on the dive's rating.
/// Every op Explore accepts must filter what its chip claims.
void main() {
  const units = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );

  ExploreCompilation compile(String op, Object value) =>
      ExploreCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': [
            {'field': 'rating', 'op': op, 'value': value, 'text': 'rated'},
          ],
        }),
        ExploreCompilerContext(
          units: units,
          names: NameIndex.empty,
          now: DateTime(2026, 9, 28),
        ),
      );

  test('at least is only a lower bound', () {
    final q = compile('gte', 4);
    expect(boundOf(q, 'rating', QueryOp.gte), 4);
    expect(boundOf(q, 'rating', QueryOp.lte), isNull);
  });

  test('between bounds both ends', () {
    final q = compile('between', [3, 4]);
    expect(q.unplaced, isEmpty);
    expect(boundOf(q, 'rating', QueryOp.gte), 3);
    expect(boundOf(q, 'rating', QueryOp.lte), 4);
  });

  test('exactly is both bounds', () {
    final q = compile('eq', 4);
    expect(boundOf(q, 'rating', QueryOp.gte), 4);
    expect(boundOf(q, 'rating', QueryOp.lte), 4);
  });

  test('at most needs no minimum', () {
    final q = compile('lte', 3);
    expect(q.unplaced, isEmpty);
    expect(boundOf(q, 'rating', QueryOp.gte), isNull);
    expect(boundOf(q, 'rating', QueryOp.lte), 3);
  });

  test('bounds round to whole stars', () {
    final q = compile('between', [2.6, 3.4]);
    expect(boundOf(q, 'rating', QueryOp.gte), 3);
    expect(boundOf(q, 'rating', QueryOp.lte), 3);
  });
}
