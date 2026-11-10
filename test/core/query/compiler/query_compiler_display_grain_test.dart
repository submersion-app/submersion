import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

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

  test('a negative value keeps its away-from-zero tie (#4398)', () {
    const cold = NumberValue(-1.3, null, grain: 0.1);
    CompiledQuery t(QueryOp op) => compileQuery(
      ConditionNode(FieldPath(['waterTemp']), op, cold),
      fixtureDives,
      fixtureRegistry,
    );
    expect(t(QueryOp.eq).where, '((r0.water_temp > ? AND r0.water_temp <= ?))');
    expect(t(QueryOp.gt).where, '(r0.water_temp > ?)');
    expect(t(QueryOp.gte).where, '(r0.water_temp > ?)');
    expect(t(QueryOp.lt).where, '(r0.water_temp <= ?)');
    expect(t(QueryOp.lte).where, '(r0.water_temp <= ?)');
    expectParams(t(QueryOp.eq).params, [-1.35, -1.25]);
  });

  test('a number with no grain still compares exactly', () {
    final gt = c(QueryOp.gt, const NumberValue(30, null));
    expect(gt.where, '(r0.max_depth > ?)');
    expect(gt.params, [30.0]);
    final eq = c(QueryOp.eq, const NumberValue(30, null));
    expect(eq.where, '(r0.max_depth = ?)');
  });

  test('a field read through a diver token binds in the order written', () {
    // Every read of the column binds the diver before the band's values,
    // and no read is made that the SQL does not use.
    const deepest = QueryEntity(
      subject: QuerySubject.sites,
      table: 'dive_sites',
      fields: [
        QueryField(
          key: 'deepest',
          type: FieldType.number,
          dimension: FieldDimension.depth,
          sql:
              '(SELECT MAX(x.max_depth) FROM dives x '
              'WHERE x.site_id = {r}.id{diver:x})',
          emptySql: 'FALSE',
          labelKey: 'x',
        ),
      ],
    );
    final registry = QueryRegistry([deepest]);
    CompiledQuery q(QueryOp op, QueryValue v) => compileQuery(
      ConditionNode(FieldPath(['deepest']), op, v),
      deepest,
      registry,
      diverId: 'me',
    );
    int marks(String sql) => '?'.allMatches(sql).length;

    final neq = q(QueryOp.neq, shown);
    expect(neq.params, hasLength(marks(neq.where)));
    expect(neq.params[0], 'me', reason: 'the presence read comes first');
    expect(neq.params.sublist(1, 3), ['me', closeTo(29.95, 1e-9)]);
    expect(neq.params.sublist(3), ['me', closeTo(30.05, 1e-9)]);

    final inList = q(
      QueryOp.inList,
      ListValue([const NumberValue(18, null, grain: 0.1), shown]),
    );
    expect(
      inList.params,
      hasLength(marks(inList.where)),
      reason: 'no unused read leaves a diver bound',
    );
    expect(inList.params.first, 'me');
  });
}
