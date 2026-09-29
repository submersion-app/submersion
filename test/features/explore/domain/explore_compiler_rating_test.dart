import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// The filter has only a minimum rating, so an upper bound is an exact
/// condition in the query tree. Every op the catalog accepts must filter
/// what its chip claims.
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

  ConditionNode atMost(double v) =>
      ConditionNode(FieldPath(['rating']), QueryOp.lte, NumberValue(v, null));

  test('at least keeps the plain minimum-rating axis', () {
    final q = compile('gte', 4);
    expect(q.filter.minRating, 4);
    expect(q.filter.query, isNull);
  });

  test('between bounds both ends', () {
    final q = compile('between', [3, 4]);
    expect(q.unplaced, isEmpty);
    expect(q.filter.minRating, 3);
    expect(q.filter.query, atMost(4));
  });

  test('exactly is both bounds', () {
    final q = compile('eq', 4);
    expect(q.filter.minRating, 4);
    expect(q.filter.query, atMost(4));
  });

  test('at most needs no minimum', () {
    final q = compile('lte', 3);
    expect(q.unplaced, isEmpty);
    expect(q.filter.minRating, isNull);
    expect(q.filter.query, atMost(3));
  });
}
