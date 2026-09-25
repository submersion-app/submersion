import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  test('nodes and values are value-equal', () {
    QueryNode build() => AndNode([
      ConditionNode(
        const FieldPath(['site', 'country']),
        QueryOp.eq,
        const StringValue('Mexico'),
      ),
      NotNode(ConditionNode(const FieldPath(['weights']), QueryOp.isSet, null)),
      ScopedNode(
        const FieldPath(['gear']),
        ConditionNode(
          const FieldPath(['type']),
          QueryOp.inList,
          const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]),
        ),
      ),
      const TextNode(['night', 'dive']),
    ]);
    expect(build(), equals(build()));
    expect(build().hashCode, equals(build().hashCode));
  });

  test('a number value keeps its storage value and the typed unit', () {
    const v = NumberValue(30.48, QueryUnit.ft);
    expect(v.value, 30.48);
    expect(v.typedUnit, QueryUnit.ft);
    expect(v, isNot(equals(const NumberValue(30.48, null))));
  });

  test('FieldPath knows its length and prints dotted', () {
    const path = FieldPath(['buddies', 'certifications', 'level']);
    expect(path.length, 3);
    expect(path.toString(), 'buddies.certifications.level');
  });

  test('a condition with isEmpty or isSet carries no value', () {
    expect(
      () => ConditionNode(
        const FieldPath(['notes']),
        QueryOp.isEmpty,
        const StringValue('x'),
      ),
      throwsArgumentError,
    );
    expect(
      () => ConditionNode(const FieldPath(['notes']), QueryOp.eq, null),
      throwsArgumentError,
    );
  });
}
