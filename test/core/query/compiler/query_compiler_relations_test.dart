import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/domain/query_node.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  CompiledQuery c(QueryNode n) =>
      compileQuery(n, fixtureDives, fixtureRegistry);

  test('an fk hop', () {
    final q = c(
      ConditionNode(
        const FieldPath(['site', 'country']),
        QueryOp.eq,
        const StringValue('Mexico'),
      ),
    );
    expect(
      q.where,
      '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id '
      'AND (LOWER(r1.country) = LOWER(?))))',
    );
    expect(q.tablesTouched, {'dives', 'dive_sites'});
  });

  test('a child hop and a junction hop', () {
    expect(
      c(
        ConditionNode(
          const FieldPath(['weights', 'amount']),
          QueryOp.gt,
          const NumberValue(2, null),
        ),
      ).where,
      '(EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id '
      'AND (r1.amount_kg > ?)))',
    );
    final j = c(
      ConditionNode(
        const FieldPath(['buddies', 'name']),
        QueryOp.contains,
        const StringValue('ana'),
      ),
    );
    expect(
      j.where,
      '(EXISTS (SELECT 1 FROM buddies r1 WHERE EXISTS (SELECT 1 FROM '
      'dive_buddies j WHERE j.dive_id = r0.id AND j.buddy_id = r1.id) '
      "AND (r1.name LIKE ? ESCAPE '\\')))",
    );
    expect(j.tablesTouched, {'dives', 'buddies', 'dive_buddies'});
  });

  test('three hops number their aliases by depth', () {
    final q = c(
      ConditionNode(
        const FieldPath(['buddies', 'certifications', 'level']),
        QueryOp.eq,
        const StringValue('rescue'),
      ),
    );
    expect(q.where, contains('FROM buddies r1'));
    expect(
      q.where,
      contains('FROM certifications r2 WHERE r2.buddy_id = r1.id'),
    );
    expect(q.where, contains('LOWER(r2.level) = LOWER(?)'));
  });

  test('presence on relations: :any, :none, and the emptySql override', () {
    expect(
      c(ConditionNode(const FieldPath(['weights']), QueryOp.isSet, null)).where,
      '(EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id))',
    );
    expect(
      c(
        ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
      ).where,
      '(NOT EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id))',
    );
    expect(
      c(
        ConditionNode(const FieldPath(['buddies']), QueryOp.isEmpty, null),
      ).where,
      "(((r0.buddy IS NULL OR r0.buddy = '') AND NOT EXISTS "
      '(SELECT 1 FROM dive_buddies j WHERE j.dive_id = r0.id)))',
    );
    expect(
      c(
        ConditionNode(
          const FieldPath(['buddies', 'certifications']),
          QueryOp.isEmpty,
          null,
        ),
      ).where,
      startsWith('(NOT EXISTS (SELECT 1 FROM buddies r1'),
    );
  });

  test('NOT over a collection path means no such row', () {
    final q = c(
      NotNode(
        ScopedNode(
          const FieldPath(['gear']),
          ConditionNode(
            const FieldPath(['type']),
            QueryOp.inList,
            const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]),
          ),
        ),
      ),
    );
    expect(
      q.where,
      '(NOT COALESCE((EXISTS (SELECT 1 FROM equipment r1 WHERE r1.id IN '
      '(SELECT de.equipment_id FROM dive_equipment de WHERE de.dive_id = r0.id) '
      'AND (r1.type IN (?, ?)))), 0))',
    );
    expect(q.params, ['wetsuit', 'drysuit']);
    expect(q.tablesTouched, {'dives', 'equipment', 'dive_equipment'});
  });

  test('a scoped group evaluates its conditions on ONE row', () {
    final q = c(
      ScopedNode(
        const FieldPath(['weights']),
        AndNode([
          ConditionNode(
            const FieldPath(['amount']),
            QueryOp.gte,
            const NumberValue(1, null),
          ),
          ConditionNode(
            const FieldPath(['amount']),
            QueryOp.lte,
            const NumberValue(3, null),
          ),
        ]),
      ),
    );
    expect(
      q.where,
      '(EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id '
      'AND ((r1.amount_kg >= ?) AND (r1.amount_kg <= ?))))',
    );
  });

  test('a nested scoped group re-roots inside the hop', () {
    final q = c(
      ScopedNode(
        const FieldPath(['buddies']),
        AndNode([
          ConditionNode(
            const FieldPath(['name']),
            QueryOp.contains,
            const StringValue('a'),
          ),
          ScopedNode(
            const FieldPath(['certifications']),
            ConditionNode(
              const FieldPath(['level']),
              QueryOp.eq,
              const StringValue('rescue'),
            ),
          ),
        ]),
      ),
    );
    expect(
      q.where,
      contains(
        'FROM certifications r2 WHERE r2.buddy_id = r1.id '
        'AND (LOWER(r2.level) = LOWER(?))',
      ),
    );
  });

  test('bind counts hold across every relation shape', () {
    for (final n in <QueryNode>[
      ConditionNode(
        const FieldPath(['buddies', 'certifications', 'level']),
        QueryOp.inList,
        const ListValue([StringValue('a'), StringValue('b')]),
      ),
      NotNode(
        ScopedNode(
          const FieldPath(['gear']),
          ConditionNode(
            const FieldPath(['type']),
            QueryOp.eq,
            const EnumValue('bcd'),
          ),
        ),
      ),
      ConditionNode(const FieldPath(['buddies']), QueryOp.isEmpty, null),
    ]) {
      final q = c(n);
      expect(countPlaceholders(q.where), q.params.length, reason: q.where);
    }
  });

  test('a relation with a value op is a compile error', () {
    expect(
      () => c(
        ConditionNode(
          const FieldPath(['weights']),
          QueryOp.gt,
          const NumberValue(1, null),
        ),
      ),
      throwsA(isA<Error>()),
    );
  });
}
