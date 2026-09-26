import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  test('nodes and values are value-equal', () {
    QueryNode build() => AndNode([
      ConditionNode(
        FieldPath(['site', 'country']),
        QueryOp.eq,
        const StringValue('Mexico'),
      ),
      NotNode(ConditionNode(FieldPath(['weights']), QueryOp.isSet, null)),
      ScopedNode(
        FieldPath(['gear']),
        ConditionNode(
          FieldPath(['type']),
          QueryOp.inList,
          ListValue([const EnumValue('wetsuit'), const EnumValue('drysuit')]),
        ),
      ),
      TextNode(['night', 'dive']),
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
    final path = FieldPath(['buddies', 'certifications', 'level']);
    expect(path.length, 3);
    expect(path.toString(), 'buddies.certifications.level');
  });

  test('a condition with isEmpty or isSet carries no value', () {
    expect(
      () => ConditionNode(
        FieldPath(['notes']),
        QueryOp.isEmpty,
        const StringValue('x'),
      ),
      throwsArgumentError,
    );
    expect(
      () => ConditionNode(FieldPath(['notes']), QueryOp.eq, null),
      throwsArgumentError,
    );
  });

  test('nodes copy their lists, so a caller cannot mutate a built tree', () {
    final segments = ['depth'];
    final children = <QueryNode>[
      ConditionNode(
        FieldPath(segments),
        QueryOp.gt,
        const NumberValue(1, null),
      ),
    ];
    final items = <QueryValue>[const EnumValue('salt')];
    final words = ['manta'];
    final and = AndNode(children);
    final or = OrNode(children);
    final text = TextNode(words);
    final list = ListValue(items);
    final path = FieldPath(segments);
    final hashes = [
      and.hashCode,
      or.hashCode,
      text.hashCode,
      list.hashCode,
      path.hashCode,
    ];

    children.add(TextNode(['x']));
    items.add(const EnumValue('fresh'));
    words.add('ray');
    segments.add('extra');

    expect(and.children, hasLength(1));
    expect(or.children, hasLength(1));
    expect(text.words, ['manta']);
    expect(list.items, hasLength(1));
    expect(path.segments, ['depth']);
    expect([
      and.hashCode,
      or.hashCode,
      text.hashCode,
      list.hashCode,
      path.hashCode,
    ], hashes);
    expect(() => and.children.add(TextNode(['y'])), throwsUnsupportedError);
    expect(() => path.segments.add('y'), throwsUnsupportedError);
  });
}
