import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/column_rules.dart';

/// Column filter rules over a bare query tree (#3422), shared by every
/// entity's table menus.
void main() {
  final notes = ConditionNode(
    FieldPath(const ['notes']),
    QueryOp.contains,
    const StringValue('calm'),
  );
  final rating = ConditionNode(
    FieldPath(const ['rating']),
    QueryOp.gte,
    const NumberValue(3, null),
  );
  final empty = ConditionNode(
    FieldPath(const ['notes']),
    QueryOp.isEmpty,
    null,
  );

  test('addColumnRule ANDs at top level next to an OR group', () {
    final q = OrNode([notes, rating]);

    final out = addColumnRule(q, empty);

    expect(out, isA<AndNode>());
    expect((out as AndNode).children, [q, empty]);
  });

  test('addColumnRule on null is the rule itself', () {
    expect(addColumnRule(null, notes), notes);
  });

  test('addColumnRule does not duplicate an identical rule', () {
    final q = AndNode([notes, rating]);

    expect(addColumnRule(q, notes), same(q));
  });

  test(
    'resetColumnRules drops only that field and returns null when empty',
    () {
      expect(resetColumnRules(AndNode([notes, rating]), 'notes'), rating);
      expect(resetColumnRules(notes, 'notes'), isNull);
      expect(resetColumnRules(rating, 'notes'), rating);
      expect(
        resetColumnRules(AndNode([notes, NotNode(empty)]), 'notes'),
        isNull,
      );
    },
  );

  test('isColumnFiltered sees a top-level rule, plain or negated', () {
    expect(isColumnFiltered(AndNode([notes, rating]), 'notes'), isTrue);
    expect(isColumnFiltered(NotNode(notes), 'notes'), isTrue);
    expect(isColumnFiltered(rating, 'notes'), isFalse);
    expect(isColumnFiltered(null, 'notes'), isFalse);
    // A rule inside an OR group is not the column's own filter.
    expect(isColumnFiltered(OrNode([notes, rating]), 'notes'), isFalse);
  });
}
