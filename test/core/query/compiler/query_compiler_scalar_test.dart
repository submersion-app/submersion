import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  CompiledQuery c(QueryNode? n) =>
      compileQuery(n, fixtureDives, fixtureRegistry);

  test('an empty query compiles to no WHERE and the bare id subquery', () {
    final q = c(null);
    expect(q.isEmpty, isTrue);
    expect(q.where, '');
    expect(q.params, isEmpty);
    expect(q.idSubquery(), 'SELECT r0.id FROM dives r0');
    expect(q.tablesTouched, {'dives'});
  });

  test('number, ordering ops, between and in', () {
    expect(
      c(
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
      ).where,
      '(r0.max_depth > ?)',
    );
    final b = c(
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.between,
        ListValue([const NumberValue(18, null), const NumberValue(30, null)]),
      ),
    );
    expect(b.where, '(r0.max_depth >= ? AND r0.max_depth <= ?)');
    expect(b.params, [18.0, 30.0]);
    final i = c(
      ConditionNode(
        FieldPath(['rating']),
        QueryOp.inList,
        ListValue([const NumberValue(4, null), const NumberValue(5, null)]),
      ),
    );
    expect(i.where, '(r0.rating IN (?, ?))');
  });

  test('neq on a nullable column excludes the unrecorded (Review Focus 5)', () {
    expect(
      c(
        ConditionNode(
          FieldPath(['bottomTime']),
          QueryOp.neq,
          const NumberValue(10, null),
        ),
      ).where,
      '(((r0.bottom_time / 60)) IS NOT NULL AND (r0.bottom_time / 60) != ?)',
    );
  });

  test('presence uses the field emptySql', () {
    expect(
      c(ConditionNode(FieldPath(['notes']), QueryOp.isEmpty, null)).where,
      "((r0.notes IS NULL OR TRIM(r0.notes) = ''))",
    );
    expect(
      c(ConditionNode(FieldPath(['notes']), QueryOp.isSet, null)).where,
      "(NOT ((r0.notes IS NULL OR TRIM(r0.notes) = '')))",
    );
  });

  test('text eq is case-insensitive, contains escapes LIKE wildcards', () {
    final e = c(
      ConditionNode(
        FieldPath(['notes']),
        QueryOp.eq,
        const StringValue('Manta'),
      ),
    );
    expect(e.where, '(LOWER(r0.notes) = LOWER(?))');
    expect(e.params, ['Manta']);
    final k = c(
      ConditionNode(
        FieldPath(['notes']),
        QueryOp.contains,
        const StringValue('100%_x'),
      ),
    );
    expect(k.where, "(r0.notes LIKE ? ESCAPE '\\')");
    expect(k.params, ['%100\\%\\_x%']);
  });

  test('bool columns and bool predicates', () {
    expect(
      c(
        ConditionNode(
          FieldPath(['favorite']),
          QueryOp.eq,
          const BoolValue(true),
        ),
      ).params,
      [1],
    );
    expect(
      c(
        ConditionNode(
          FieldPath(['favorite']),
          QueryOp.neq,
          const BoolValue(true),
        ),
      ).params,
      [0],
    );
    expect(
      c(
        ConditionNode(FieldPath(['deco']), QueryOp.eq, const BoolValue(true)),
      ).where,
      '((r0.deco_flag = 1))',
    );
    expect(
      c(
        ConditionNode(FieldPath(['deco']), QueryOp.neq, const BoolValue(true)),
      ).where,
      '((r0.deco_flag = 0))',
    );
  });

  test('enum values bind their SQL value', () {
    expect(
      c(
        ConditionNode(
          FieldPath(['waterType']),
          QueryOp.eq,
          const EnumValue('salt'),
        ),
      ).params,
      ['salt'],
    );
    final w = c(
      ConditionNode(
        FieldPath(['weekday']),
        QueryOp.inList,
        ListValue([const EnumValue('sunday'), const EnumValue('monday')]),
      ),
    );
    expect(w.params, [0, 1]);
  });

  test('a relation compared to a ref binds the id inside its hop', () {
    final q = c(ConditionNode(FieldPath(['site']), QueryOp.eq, kFixtureSite));
    expect(
      q.where,
      '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id '
      'AND r1.id = ?))',
    );
    expect(q.params, ['site-1']);
    final n = c(ConditionNode(FieldPath(['site']), QueryOp.neq, kFixtureSite));
    // Like scalar `!=`, a relation `!=` needs a related row: a dive with no
    // site is not "a site other than X".
    expect(
      n.where,
      '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id '
      'AND r1.id != ?))',
    );
    final l = c(
      ConditionNode(
        FieldPath(['site']),
        QueryOp.inList,
        ListValue([const RefValue('a', 'A'), const RefValue('b', 'B')]),
      ),
    );
    expect(
      l.where,
      '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id '
      'AND r1.id IN (?, ?)))',
    );
    expect(
      c(
        ConditionNode(
          FieldPath(['id']),
          QueryOp.inList,
          ListValue([const StringValue('a'), const StringValue('b')]),
        ),
      ).where,
      '(r0.id IN (?, ?))',
    );
  });

  test('dates are half-open wall-clock day bounds', () {
    int ms(DateTime d) => wallClockUtcDayStart(d).millisecondsSinceEpoch;
    final day = DateTime(2025, 3, 14);
    final next = DateTime(2025, 3, 15);
    final eq = c(
      ConditionNode(FieldPath(['date']), QueryOp.eq, DateValue(day)),
    );
    expect(eq.where, '(r0.dive_date_time >= ? AND r0.dive_date_time < ?)');
    expect(eq.params, [ms(day), ms(next)]);
    expect(
      c(ConditionNode(FieldPath(['date']), QueryOp.gte, DateValue(day))).params,
      [ms(day)],
    );
    expect(
      c(ConditionNode(FieldPath(['date']), QueryOp.gt, DateValue(day))).params,
      [ms(next)],
    );
    expect(
      c(ConditionNode(FieldPath(['date']), QueryOp.lt, DateValue(day))).params,
      [ms(day)],
    );
    expect(
      c(ConditionNode(FieldPath(['date']), QueryOp.lte, DateValue(day))).params,
      [ms(next)],
    );
    final range = c(
      ConditionNode(
        FieldPath(['date']),
        QueryOp.inList,
        DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31)),
      ),
    );
    expect(range.params, [ms(DateTime(2025, 1, 1)), ms(DateTime(2026, 1, 1))]);
  });

  test('text search ORs every template per word and ANDs words', () {
    final q = c(TextNode(['night', 'dive']));
    expect(
      q.where,
      "((r0.notes LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM dive_sites ts "
      "WHERE ts.id = r0.site_id AND ts.name LIKE ? ESCAPE '\\')) "
      "AND (r0.notes LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM dive_sites ts "
      "WHERE ts.id = r0.site_id AND ts.name LIKE ? ESCAPE '\\')))",
    );
    expect(q.params, ['%night%', '%night%', '%dive%', '%dive%']);
    expect(q.tablesTouched, {'dives', 'dive_sites'});
  });

  test('AND, OR and NOT nest with parentheses', () {
    final q = c(
      OrNode([
        AndNode([
          ConditionNode(
            FieldPath(['depth']),
            QueryOp.gt,
            const NumberValue(30, null),
          ),
          NotNode(
            ConditionNode(
              FieldPath(['favorite']),
              QueryOp.eq,
              const BoolValue(true),
            ),
          ),
        ]),
        ConditionNode(
          FieldPath(['rating']),
          QueryOp.gte,
          const NumberValue(4, null),
        ),
      ]),
    );
    expect(
      q.where,
      '(((r0.max_depth > ?) AND (NOT COALESCE((r0.is_favorite = ?), 0))) '
      'OR (r0.rating >= ?))',
    );
    expect(q.params, [30.0, 1, 4.0]);
  });

  test('the bind count always equals the placeholder count', () {
    for (final n in <QueryNode>[
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.between,
        ListValue([const NumberValue(1, null), const NumberValue(2, null)]),
      ),
      TextNode(['a', 'b', 'c']),
      ConditionNode(
        FieldPath(['waterType']),
        QueryOp.inList,
        ListValue([
          const EnumValue('salt'),
          const EnumValue('fresh'),
          const EnumValue('brackish'),
        ]),
      ),
    ]) {
      final q = c(n);
      expect(countPlaceholders(q.where), q.params.length, reason: q.where);
    }
  });

  test('the root alias is a parameter', () {
    expect(
      compileQuery(
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(1, null),
        ),
        fixtureDives,
        fixtureRegistry,
        rootAlias: 'd',
      ).where,
      '(d.max_depth > ?)',
    );
  });

  test('NOT is two-valued: a NULL operand counts as not matching', () {
    final q = c(
      NotNode(
        ConditionNode(
          FieldPath(['notes']),
          QueryOp.contains,
          const StringValue('shark'),
        ),
      ),
    );
    expect(q.where, "(NOT COALESCE((r0.notes LIKE ? ESCAPE '\\'), 0))");
  });

  test(
    'a local-instant date field binds local midnight, not the UTC frame',
    () {
      final q = compileQuery(
        ConditionNode(
          FieldPath(['localDay']),
          QueryOp.eq,
          DateValue(DateTime(2025, 3, 14)),
        ),
        fixtureDives,
        fixtureRegistry,
      );
      expect(q.params, [
        DateTime(2025, 3, 14).millisecondsSinceEpoch,
        DateTime(2025, 3, 15).millisecondsSinceEpoch,
      ]);
    },
  );

  test('an empty group or empty text is a compile error, never bad SQL', () {
    expect(() => c(AndNode([])), throwsA(isA<Error>()));
    expect(() => c(TextNode([])), throwsA(isA<Error>()));
  });

  test('scoped nesting past the hop cap is a compile error', () {
    QueryNode nest(int n) => n == 0
        ? ConditionNode(FieldPath(['name']), QueryOp.eq, const StringValue('x'))
        : ScopedNode(FieldPath(['buddies']), nest(n - 1));
    expect(() => c(nest(5)), throwsA(isA<Error>()));
  });

  test(
    'a reversed between (from JSON or the builder) still means the range',
    () {
      final n = c(
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.between,
          ListValue([const NumberValue(30, null), const NumberValue(18, null)]),
        ),
      );
      expect(n.params, [18.0, 30.0]);
      final d = c(
        ConditionNode(
          FieldPath(['date']),
          QueryOp.between,
          ListValue([
            DateValue(DateTime(2025, 3, 15)),
            DateValue(DateTime(2025, 3, 14)),
          ]),
        ),
      );
      expect(d.params.first, lessThan(d.params.last as int));
    },
  );
}
