import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  List<String> messages(QueryNode? n) => validateQuery(
    n,
    fixtureDives,
    fixtureRegistry,
  ).map((e) => e.message).toList();

  test('a clean tree and an empty query have no errors', () {
    expect(messages(null), isEmpty);
    expect(
      messages(
        AndNode([
          ConditionNode(
            const FieldPath(['depth']),
            QueryOp.gt,
            const NumberValue(30, null),
          ),
          ScopedNode(
            const FieldPath(['gear']),
            ConditionNode(
              const FieldPath(['type']),
              QueryOp.eq,
              const EnumValue('wetsuit'),
            ),
          ),
          ConditionNode(
            const FieldPath(['buddies', 'certifications', 'level']),
            QueryOp.eq,
            const StringValue('x'),
          ),
          ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
          ConditionNode(const FieldPath(['site']), QueryOp.eq, kFixtureSite),
          const TextNode(['manta']),
        ]),
      ),
      isEmpty,
    );
  });

  test('every error kind, all reported at once', () {
    final errors = validateQuery(
      AndNode([
        ConditionNode(
          const FieldPath(['depht']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
        ConditionNode(
          const FieldPath(['favorite']),
          QueryOp.contains,
          const StringValue('x'),
        ),
        ConditionNode(
          const FieldPath(['rating']),
          QueryOp.gt,
          const NumberValue(3, QueryUnit.m),
        ),
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(900, null),
        ),
        ConditionNode(
          const FieldPath(['waterType']),
          QueryOp.inList,
          const ListValue([]),
        ),
        ConditionNode(
          const FieldPath(['waterType']),
          QueryOp.eq,
          const EnumValue('lake'),
        ),
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.eq,
          const StringValue('deep'),
        ),
        ConditionNode(
          const FieldPath(['weights']),
          QueryOp.gt,
          const NumberValue(1, null),
        ),
        const ScopedNode(FieldPath(['depth']), TextNode(['x'])),
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.between,
          const ListValue([NumberValue(1, null)]),
        ),
        ConditionNode(
          const FieldPath(['site']),
          QueryOp.eq,
          const StringValue('Salt Pier'),
        ),
      ]),
      fixtureDives,
      fixtureRegistry,
    );
    final m = errors.map((e) => e.message).join('\n');
    expect(errors.length, 11, reason: m);
    expect(m, contains('unknown field "depht"'));
    expect(m, contains('contains cannot be used with favorite'));
    expect(m, contains('rating takes no unit'));
    expect(m, contains('out of range'));
    expect(m, contains('list is empty'));
    expect(m, contains('"lake" is not a waterType value'));
    expect(m, contains('depth expects a number'));
    expect(m, contains('"weights" is a relation'));
    expect(m, contains('[...] needs a relation'));
    expect(m, contains('between needs two values'));
    expect(m, contains('site expects a reference'));
    expect(errors.first.path, const FieldPath(['depht']));
  });

  test(
    'an unknown segment deep in a scoped group is resolved in that scope',
    () {
      expect(
        messages(
          ScopedNode(
            const FieldPath(['gear']),
            ConditionNode(
              const FieldPath(['depth']),
              QueryOp.gt,
              const NumberValue(1, null),
            ),
          ),
        ),
        [contains('unknown field "depth"')],
      );
    },
  );

  test('free text inside a scope without search columns is an error', () {
    expect(messages(const ScopedNode(FieldPath(['gear']), TextNode(['x']))), [
      contains('free text'),
    ]);
  });

  test('a unit from another dimension, an empty group and empty text', () {
    expect(
      messages(
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, QueryUnit.f),
        ),
      ),
      [contains('unit')],
    );
    expect(messages(const AndNode([])), [contains('empty')]);
    expect(messages(const OrNode([])), [contains('empty')]);
    expect(messages(const TextNode([])), [contains('empty')]);
  });

  test('a date range is only valid under in', () {
    final range = DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 1, 31));
    expect(
      messages(ConditionNode(const FieldPath(['date']), QueryOp.lt, range)),
      [contains('day')],
    );
    expect(
      messages(ConditionNode(const FieldPath(['date']), QueryOp.inList, range)),
      isEmpty,
    );
  });

  test('scoped nesting counts against the hop cap', () {
    QueryNode nest(int n) => n == 0
        ? ConditionNode(
            const FieldPath(['name']),
            QueryOp.eq,
            const StringValue('x'),
          )
        : ScopedNode(const FieldPath(['buddies']), nest(n - 1));
    expect(messages(nest(4)), isEmpty);
    expect(messages(nest(5)), [contains('4')]);
    expect(
      messages(
        ScopedNode(
          const FieldPath(['buddies']),
          ScopedNode(
            const FieldPath(['buddies']),
            ScopedNode(
              const FieldPath(['buddies']),
              ConditionNode(
                const FieldPath(['buddies', 'certifications', 'level']),
                QueryOp.eq,
                const StringValue('x'),
              ),
            ),
          ),
        ),
      ),
      [contains('4')],
    );
  });
}
