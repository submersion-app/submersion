import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';

import '../fixtures/fixture_registry.dart';

/// Issue #4398: a number carrying a display grain compares with the column
/// as the app rounds it, half a grain either side of the typed value.
void main() {
  CompiledQuery c(QueryOp op, QueryValue v) => compileQuery(
    ConditionNode(FieldPath(['depth']), op, v),
    fixtureDives,
    fixtureRegistry,
  );
  const shown = NumberValue(30, null, grain: 0.1);

  void expectParams(List<Object?> actual, List<double> expected) {
    expect(actual, hasLength(expected.length));
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], closeTo(expected[i], 1e-9), reason: 'param $i');
    }
  }

  test('a strict bound starts past everything shown as the value', () {
    final gt = c(QueryOp.gt, shown);
    expect(gt.where, '(r0.max_depth >= ?)');
    expectParams(gt.params, [30.05]);
    final lt = c(QueryOp.lt, shown);
    expect(lt.where, '(r0.max_depth < ?)');
    expectParams(lt.params, [29.95]);
  });

  test('an inclusive bound takes in everything shown as the value', () {
    final gte = c(QueryOp.gte, shown);
    expect(gte.where, '(r0.max_depth >= ?)');
    expectParams(gte.params, [29.95]);
    final lte = c(QueryOp.lte, shown);
    expect(lte.where, '(r0.max_depth < ?)');
    expectParams(lte.params, [30.05]);
  });

  test('equality is the half-open band shown as the value', () {
    final eq = c(QueryOp.eq, shown);
    expect(eq.where, '((r0.max_depth >= ? AND r0.max_depth < ?))');
    expectParams(eq.params, [29.95, 30.05]);
    final neq = c(QueryOp.neq, shown);
    expect(
      neq.where,
      '((r0.max_depth) IS NOT NULL AND NOT (r0.max_depth >= ? '
      'AND r0.max_depth < ?))',
    );
    expectParams(neq.params, [29.95, 30.05]);
  });

  test('between and in widen each value by half a grain', () {
    final b = c(
      QueryOp.between,
      ListValue([const NumberValue(18, null, grain: 0.1), shown]),
    );
    expect(b.where, '(r0.max_depth >= ? AND r0.max_depth < ?)');
    expectParams(b.params, [17.95, 30.05]);
    final i = c(
      QueryOp.inList,
      ListValue([const NumberValue(18, null, grain: 0.1), shown]),
    );
    expect(
      i.where,
      '(((r0.max_depth >= ? AND r0.max_depth < ?)) '
      'OR ((r0.max_depth >= ? AND r0.max_depth < ?)))',
    );
    expectParams(i.params, [17.95, 18.05, 29.95, 30.05]);
  });

  test('a number with no grain still compares exactly', () {
    final gt = c(QueryOp.gt, const NumberValue(30, null));
    expect(gt.where, '(r0.max_depth > ?)');
    expect(gt.params, [30.0]);
    final eq = c(QueryOp.eq, const NumberValue(30, null));
    expect(eq.where, '(r0.max_depth = ?)');
  });
}
