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
            FieldPath(['depth']),
            QueryOp.gt,
            const NumberValue(30, null),
          ),
          ScopedNode(
            FieldPath(['gear']),
            ConditionNode(
              FieldPath(['type']),
              QueryOp.eq,
              const EnumValue('wetsuit'),
            ),
          ),
          ConditionNode(
            FieldPath(['buddies', 'certifications', 'level']),
            QueryOp.eq,
            const StringValue('x'),
          ),
          ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null),
          ConditionNode(FieldPath(['site']), QueryOp.eq, kFixtureSite),
          TextNode(['manta']),
        ]),
      ),
      isEmpty,
    );
  });

  test('every error kind, all reported at once', () {
    final errors = validateQuery(
      AndNode([
        ConditionNode(
          FieldPath(['depht']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
        ConditionNode(
          FieldPath(['favorite']),
          QueryOp.contains,
          const StringValue('x'),
        ),
        ConditionNode(
          FieldPath(['rating']),
          QueryOp.gt,
          const NumberValue(3, QueryUnit.m),
        ),
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(900, null),
        ),
        ConditionNode(FieldPath(['waterType']), QueryOp.inList, ListValue([])),
        ConditionNode(
          FieldPath(['waterType']),
          QueryOp.eq,
          const EnumValue('lake'),
        ),
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.eq,
          const StringValue('deep'),
        ),
        ConditionNode(
          FieldPath(['weights']),
          QueryOp.gt,
          const NumberValue(1, null),
        ),
        ScopedNode(FieldPath(['depth']), TextNode(['x'])),
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.between,
          ListValue([const NumberValue(1, null)]),
        ),
        ConditionNode(
          FieldPath(['site']),
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
    expect(errors.first.path, FieldPath(['depht']));
  });

  test(
    'an unknown segment deep in a scoped group is resolved in that scope',
    () {
      expect(
        messages(
          ScopedNode(
            FieldPath(['gear']),
            ConditionNode(
              FieldPath(['depth']),
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
    expect(messages(ScopedNode(FieldPath(['gear']), TextNode(['x']))), [
      contains('free text'),
    ]);
  });

  test('a unit from another dimension, an empty group and empty text', () {
    expect(
      messages(
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, QueryUnit.f),
        ),
      ),
      [contains('unit')],
    );
    expect(messages(AndNode([])), [contains('empty')]);
    expect(messages(OrNode([])), [contains('empty')]);
    expect(messages(TextNode([])), [contains('empty')]);
  });

  test('a date range is only valid under in', () {
    final range = DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 1, 31));
    expect(messages(ConditionNode(FieldPath(['date']), QueryOp.lt, range)), [
      contains('day'),
    ]);
    expect(
      messages(ConditionNode(FieldPath(['date']), QueryOp.inList, range)),
      isEmpty,
    );
  });

  test('scoped nesting counts against the hop cap', () {
    QueryNode nest(int n) => n == 0
        ? ConditionNode(FieldPath(['name']), QueryOp.eq, const StringValue('x'))
        : ScopedNode(FieldPath(['buddies']), nest(n - 1));
    expect(messages(nest(4)), isEmpty);
    expect(messages(nest(5)), [contains('4')]);
    expect(
      messages(
        ScopedNode(
          FieldPath(['buddies']),
          ScopedNode(
            FieldPath(['buddies']),
            ScopedNode(
              FieldPath(['buddies']),
              ConditionNode(
                FieldPath(['buddies', 'certifications', 'level']),
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

  test(':none on an enum with a stored value named none is ambiguous', () {
    expect(
      messages(ConditionNode(FieldPath(['current']), QueryOp.isEmpty, null)),
      [contains('current = none')],
    );
    expect(
      messages(ConditionNode(FieldPath(['waterType']), QueryOp.isEmpty, null)),
      isEmpty,
    );
  });
}
