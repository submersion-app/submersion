import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  final tree = OrNode([
    AndNode([
      ConditionNode(
        const FieldPath(['depth']),
        QueryOp.gt,
        const NumberValue(30.48, QueryUnit.ft),
      ),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.between,
        ListValue([
          DateValue(DateTime(2025, 1, 1)),
          DateValue(DateTime(2025, 12, 31)),
        ]),
      ),
      ConditionNode(
        const FieldPath(['site']),
        QueryOp.eq,
        const RefValue('site-1', 'Salt Pier'),
      ),
      ConditionNode(
        const FieldPath(['favorite']),
        QueryOp.eq,
        const BoolValue(true),
      ),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.inList,
        DateRangeValue(DateTime(2024, 3, 1), DateTime(2024, 3, 31)),
      ),
    ]),
    NotNode(ConditionNode(const FieldPath(['weights']), QueryOp.isSet, null)),
    ScopedNode(
      const FieldPath(['gear']),
      ConditionNode(
        const FieldPath(['type']),
        QueryOp.inList,
        const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]),
      ),
    ),
    const TextNode(['night']),
  ]);

  test('round trips through JSON text', () {
    final text = jsonEncode(queryNodeToJson(tree));
    final back = queryNodeFromJson(jsonDecode(text) as Map<String, Object?>);
    expect(back, equals(tree));
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
}
