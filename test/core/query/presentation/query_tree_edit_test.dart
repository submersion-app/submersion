import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';

void main() {
  ConditionNode cond(String key, double v) =>
      ConditionNode(FieldPath([key]), QueryOp.gt, NumberValue(v, null));
  final a = cond('depth', 30);
  final b = cond('rating', 3);
  final c = cond('otu', 1);

  test('nodeAt walks groups, NOT and scoped nodes', () {
    final root = AndNode([
      a,
      NotNode(OrNode([b, c])),
    ]);
    expect(nodeAt(root, []), root);
    expect(nodeAt(root, [1, 0, 1]), c);
    expect(nodeAt(root, [1, 0]), OrNode([b, c]));
    expect(nodeAt(root, [5]), isNull);
    expect(nodeAt(ScopedNode(FieldPath(['gear']), a), [0]), a);
  });

  test('replaceAt returns a new tree and leaves the old one intact', () {
    final root = AndNode([a, b]);
    final out = replaceAt(root, [1], c);
    expect(out, AndNode([a, c]));
    expect(root, AndNode([a, b]));
    expect(replaceAt(root, [], c), c);
  });

  test('removeAt keeps a one-child group, drops an emptied one', () {
    // A group with one row left stays a group: the builder shows a card
    // the diver can keep adding to. Only an emptied group, NOT or scope
    // disappears, and that collapses upward.
    expect(removeAt(AndNode([a, b]), [0]), AndNode([b]));
    expect(
      removeAt(
        AndNode([
          a,
          OrNode([b, c]),
        ]),
        [1, 0],
      ),
      AndNode([
        a,
        OrNode([c]),
      ]),
    );
    expect(
      removeAt(
        AndNode([
          a,
          OrNode([b]),
        ]),
        [1, 0],
      ),
      AndNode([a]),
    );
    expect(removeAt(a, []), isNull);
    expect(removeAt(NotNode(a), [0]), isNull);
    expect(removeAt(AndNode([a, NotNode(b)]), [1, 0]), AndNode([a]));
    expect(removeAt(AndNode([a]), [0]), isNull);
  });

  test('appendChild adds to the group at the path', () {
    expect(appendChild(AndNode([a]), [], b), AndNode([a, b]));
    expect(
      appendChild(
        AndNode([
          a,
          OrNode([b]),
        ]),
        [1],
        c,
      ),
      AndNode([
        a,
        OrNode([b, c]),
      ]),
    );
    expect(() => appendChild(a, [], b), throwsArgumentError);
  });

  test('toggleNegation wraps and unwraps', () {
    expect(toggleNegation(AndNode([a, b]), [0]), AndNode([NotNode(a), b]));
    expect(toggleNegation(AndNode([NotNode(a), b]), [0]), AndNode([a, b]));
  });

  test('setGroupOp swaps AND and OR keeping the children', () {
    expect(setGroupOp(AndNode([a, b]), [], and: false), OrNode([a, b]));
    expect(setGroupOp(AndNode([a, b]), [], and: true), AndNode([a, b]));
    expect(
      setGroupOp(NotNode(OrNode([a, b])), [0], and: true),
      NotNode(AndNode([a, b])),
    );
  });

  test('normalizeQuery drops empty groups and double NOT, keeps nesting', () {
    expect(normalizeQuery(AndNode([a])), AndNode([a]));
    expect(
      normalizeQuery(
        OrNode([
          AndNode([a]),
        ]),
      ),
      OrNode([
        AndNode([a]),
      ]),
    );
    expect(normalizeQuery(NotNode(NotNode(a))), a);
    expect(normalizeQuery(AndNode([])), isNull);
    expect(normalizeQuery(AndNode([a, OrNode([])])), AndNode([a]));
    expect(
      normalizeQuery(
        AndNode([
          a,
          OrNode([b]),
        ]),
      ),
      AndNode([
        a,
        OrNode([b]),
      ]),
    );
    expect(normalizeQuery(null), isNull);
    expect(normalizeQuery(NotNode(AndNode([]))), isNull);
  });

  test('top-level conjuncts are the AND children or the node itself', () {
    expect(topLevelConjuncts(null), isEmpty);
    expect(topLevelConjuncts(a), [a]);
    expect(topLevelConjuncts(AndNode([a, b])), [a, b]);
    expect(topLevelConjuncts(OrNode([a, b])), [
      OrNode([a, b]),
    ]);
    expect(removeTopLevelConjunct(AndNode([a, b, c]), 1), AndNode([a, c]));
    expect(removeTopLevelConjunct(AndNode([a, b]), 0), b);
    expect(removeTopLevelConjunct(a, 0), isNull);
    expect(removeTopLevelConjunct(OrNode([a, b]), 0), isNull);
  });
}
