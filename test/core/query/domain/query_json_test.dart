import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  final tree = OrNode([
    AndNode([
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.gt,
        const NumberValue(30.48, QueryUnit.ft),
      ),
      ConditionNode(
        FieldPath(['date']),
        QueryOp.between,
        ListValue([
          DateValue(DateTime(2025, 1, 1)),
          DateValue(DateTime(2025, 12, 31)),
        ]),
      ),
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('site-1', 'Salt Pier'),
      ),
      ConditionNode(FieldPath(['favorite']), QueryOp.eq, const BoolValue(true)),
      ConditionNode(
        FieldPath(['date']),
        QueryOp.inList,
        DateRangeValue(DateTime(2024, 3, 1), DateTime(2024, 3, 31)),
      ),
    ]),
    NotNode(ConditionNode(FieldPath(['weights']), QueryOp.isSet, null)),
    ScopedNode(
      FieldPath(['gear']),
      ConditionNode(
        FieldPath(['type']),
        QueryOp.inList,
        ListValue([const EnumValue('wetsuit'), const EnumValue('drysuit')]),
      ),
    ),
    TextNode(['night']),
  ]);

  test('round trips through JSON text', () {
    final text = jsonEncode(queryNodeToJson(tree));
    final back = queryNodeFromJson(jsonDecode(text) as Map<String, Object?>);
    expect(back, equals(tree));
  });

  test('keeps a number display grain, and reads its absence as none', () {
    // Issue #4398: a saved `depth < 27.1` still compares as shown.
    final grained = ConditionNode(
      FieldPath(['depth']),
      QueryOp.lt,
      const NumberValue(8.26, null, grain: 0.03, shown: 27.1),
    );
    final json = queryNodeToJson(grained);
    final back = queryNodeFromJson(
      jsonDecode(jsonEncode(json)) as Map<String, Object?>,
    );
    expect(back, equals(grained));
    final plain = ConditionNode(
      FieldPath(['depth']),
      QueryOp.lt,
      const NumberValue(8.26, null),
    );
    expect(
      jsonEncode(queryNodeToJson(plain)),
      isNot(contains('"g"')),
      reason: 'an exact number writes what it always did',
    );
  });

  test('carries the version', () {
    expect(queryNodeToJson(tree)['version'], kQueryJsonVersion);
  });

  test('rejects a newer version, a missing node and a bad op', () {
    expect(
      () => queryNodeFromJson({'version': 99, 'node': <String, Object?>{}}),
      throwsA(isA<QueryJsonException>()),
    );
    expect(
      () => queryNodeFromJson({'version': 1}),
      throwsA(isA<QueryJsonException>()),
    );
    expect(
      () => queryNodeFromJson({
        'version': 1,
        'node': {
          't': 'cond',
          'path': ['depth'],
          'op': 'nope',
          'value': null,
        },
      }),
      throwsA(isA<QueryJsonException>()),
    );
  });

  test('rejects an impossible calendar day instead of normalizing it', () {
    // DateTime(2025, 2, 30) would silently become March 2; a hand-edited or
    // corrupted saved query must fail, never change meaning.
    for (final kind in ['date', 'range']) {
      expect(
        () => queryNodeFromJson({
          'version': 1,
          'node': {
            't': 'cond',
            'path': ['date'],
            'op': kind == 'date' ? 'eq' : 'inList',
            'value': kind == 'date'
                ? {'k': 'date', 'v': '2025-02-30'}
                : {'k': 'range', 's': '2025-02-30', 'e': '2025-03-01'},
          },
        }),
        throwsA(isA<QueryJsonException>()),
        reason: kind,
      );
    }
    expect(
      () => queryNodeFromJson({
        'version': 1,
        'node': {
          't': 'cond',
          'path': ['date'],
          'op': 'eq',
          'value': {'k': 'date', 'v': '2025-13-01'},
        },
      }),
      throwsA(isA<QueryJsonException>()),
    );
  });

  test('every malformed shape is a QueryJsonException, never another type', () {
    final shapes = <Map<String, Object?>>[
      // isEmpty carrying a value: ConditionNode's own ArgumentError
      {
        't': 'cond',
        'path': ['notes'],
        'op': 'isEmpty',
        'value': {'k': 'str', 'v': 'x'},
      },
      // a path that is not a list: a cast failure
      {
        't': 'cond',
        'path': 'depth',
        'op': 'gt',
        'value': {'k': 'num', 'v': 1},
      },
      // a grain that is not a positive width (#4398)
      for (final g in <Object>['wide', 0, -0.1])
        {
          't': 'cond',
          'path': ['depth'],
          'op': 'gt',
          'value': {'k': 'num', 'v': 1, 'g': g},
        },
      // a shown number that is not one
      {
        't': 'cond',
        'path': ['depth'],
        'op': 'gt',
        'value': {'k': 'num', 'v': 1, 'g': 0.1, 's': 'x'},
      },
      // children that are not maps
      {
        't': 'and',
        'c': [1, 2],
      },
      // a non-numeric day component
      {
        't': 'cond',
        'path': ['date'],
        'op': 'eq',
        'value': {'k': 'date', 'v': '2025-xx-01'},
      },
    ];
    for (final node in shapes) {
      expect(
        () => queryNodeFromJson({'version': 1, 'node': node}),
        throwsA(isA<QueryJsonException>()),
        reason: '$node',
      );
    }
  });
}
