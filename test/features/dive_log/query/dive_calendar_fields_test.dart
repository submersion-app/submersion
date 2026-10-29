import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Issue #3127: `month` and `day` match the calendar date a dive was logged
/// on, so a calendar-days cell can open its dives.
void main() {
  ConditionNode eq(String field, double value) =>
      ConditionNode(FieldPath([field]), QueryOp.eq, NumberValue(value, null));

  List<QueryErrorCode> errors(QueryNode node) => [
    for (final e in validateQuery(node, diveQueryEntity, appQueryRegistry))
      e.code,
  ];

  test('month and day compile to the wall-clock date parts', () {
    final q = compileQuery(
      AndNode([eq('month', 5), eq('day', 6)]),
      diveQueryEntity,
      appQueryRegistry,
    );

    expect(q.where, contains("strftime('%m', r0.dive_date_time / 1000"));
    expect(q.where, contains("strftime('%d', r0.dive_date_time / 1000"));
    expect(q.params, [5, 6]);
  });

  test('the edges of each range are accepted', () {
    expect(errors(eq('month', 1)), isEmpty);
    expect(errors(eq('month', 12)), isEmpty);
    expect(errors(eq('day', 1)), isEmpty);
    expect(errors(eq('day', 31)), isEmpty);
  });

  test('values outside a calendar are rejected', () {
    expect(errors(eq('month', 0)), [QueryErrorCode.outOfRange]);
    expect(errors(eq('month', 13)), [QueryErrorCode.outOfRange]);
    expect(errors(eq('day', 0)), [QueryErrorCode.outOfRange]);
    expect(errors(eq('day', 32)), [QueryErrorCode.outOfRange]);
  });
}
