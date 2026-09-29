import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_chips.dart';

/// One removable chip per top-level condition, for any list (#2365).
void main() {
  final rating = ConditionNode(
    FieldPath(['rating']),
    QueryOp.gte,
    const NumberValue(3, null),
  );
  final difficulty = ConditionNode(
    FieldPath(['difficulty']),
    QueryOp.eq,
    const EnumValue('advanced'),
  );

  test('each chip carries its label and the query left without it', () {
    final chips = entityQueryChips(
      siteQueryEntity,
      AndNode([rating, difficulty]),
      kMetricPrefs,
    );
    expect(chips.map((c) => c.label), ['rating >= 3', 'difficulty = advanced']);
    expect(chips.map((c) => c.rest), [difficulty, rating]);
  });

  test('removing the only condition leaves no query', () {
    final chips = entityQueryChips(siteQueryEntity, rating, kMetricPrefs);
    expect(chips.single.rest, isNull);
  });

  test('no query, no chips', () {
    expect(entityQueryChips(siteQueryEntity, null, kMetricPrefs), isEmpty);
  });
}
