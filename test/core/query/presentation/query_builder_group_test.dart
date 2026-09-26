import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_builder_group.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';
import 'query_value_editor_test.dart' show kTestBuilderStrings;

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1'},
    }),
    labels: const MapQueryLabels(
      fields: {'depth': 'Max depth', 'rating': 'Rating'},
      relations: {'site': 'Site', 'weights': 'Weights'},
    ),
    now: () => DateTime(2026, 9, 25),
  );
  ConditionNode depth(double v) =>
      ConditionNode(FieldPath(['depth']), QueryOp.gt, NumberValue(v, null));
  ConditionNode rating(double v) =>
      ConditionNode(FieldPath(['rating']), QueryOp.gte, NumberValue(v, null));
  final defaultRating = ConditionNode(
    FieldPath(['rating']),
    QueryOp.eq,
    const NumberValue(0, null),
  );

  Widget host(QueryNode? root, ValueChanged<QueryNode?> onChanged) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QueryBuilderGroup(
              context: context,
              root: root,
              onChanged: onChanged,
              strings: kTestBuilderStrings,
            ),
          ),
        ),
      );

  // The field picker's list is lazy; relations sit below the fields.
  Future<void> pick(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('renders a nested tree and toggles a group op', (tester) async {
    QueryNode? out;
    await tester.pumpWidget(
      host(
        AndNode([
          depth(30),
          OrNode([rating(3), NotNode(rating(5))]),
        ]),
        (n) => out = n,
      ),
    );
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('Rating'), findsNWidgets(2));
    // Two group cards: the root AND and the nested OR.
    expect(find.byKey(const ValueKey('group-')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-1')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('group-1')),
        matching: find.text('All of'),
      ),
    );
    await tester.pump();
    expect(
      out,
      AndNode([
        depth(30),
        AndNode([rating(3), NotNode(rating(5))]),
      ]),
    );
  });

  testWidgets('removing a row and negating a row edit the tree', (
    tester,
  ) async {
    QueryNode? out;
    await tester.pumpWidget(
      host(AndNode([depth(30), rating(3)]), (n) => out = n),
    );
    await tester.tap(find.byKey(const ValueKey('negate-1')));
    await tester.pump();
    expect(out, AndNode([depth(30), NotNode(rating(3))]));
    await tester.pumpWidget(host(out, (n) => out = n));
    await tester.tap(find.byKey(const ValueKey('remove-0')));
    await tester.pump();
    // The root card keeps its one remaining row rather than collapsing.
    expect(out, AndNode([NotNode(rating(3))]));
  });

  testWidgets('add condition opens the picker and appends a default row', (
    tester,
  ) async {
    QueryNode? out;
    await tester.pumpWidget(host(null, (n) => out = n));
    expect(find.text('Add condition'), findsOneWidget);
    await tester.tap(find.text('Add condition'));
    await tester.pumpAndSettle();
    await pick(tester, 'Max depth');
    expect(
      out,
      AndNode([
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.eq,
          const NumberValue(0, null),
        ),
      ]),
    );
  });

  testWidgets('adding a ref condition opens the ref picker first', (
    tester,
  ) async {
    QueryNode? out;
    await tester.pumpWidget(host(null, (n) => out = n));
    await tester.tap(find.text('Add condition'));
    await tester.pumpAndSettle();
    await pick(tester, 'Site');
    await tester.tap(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(
      out,
      AndNode([
        ConditionNode(
          FieldPath(['site']),
          QueryOp.eq,
          const RefValue('s1', 'Salt Pier'),
        ),
      ]),
    );
  });

  testWidgets('add group nests an OR under the root', (tester) async {
    QueryNode? out;
    await tester.pumpWidget(host(depth(30), (n) => out = n));
    await tester.tap(find.text('Add group'));
    await tester.pumpAndSettle();
    // A new group needs a first condition; the picker opens for it.
    await pick(tester, 'Rating');
    expect(
      out,
      AndNode([
        depth(30),
        OrNode([defaultRating]),
      ]),
    );
  });

  testWidgets('a scoped node is shown read-only', (tester) async {
    await tester.pumpWidget(
      host(
        ScopedNode(
          FieldPath(['weights']),
          ConditionNode(
            FieldPath(['amount']),
            QueryOp.gt,
            const NumberValue(1, null),
          ),
        ),
        (_) {},
      ),
    );
    expect(find.textContaining('edit in the Text tab'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a text row follows an outside change', (tester) async {
    await tester.pumpWidget(
      host(
        AndNode([
          TextNode(['manta']),
        ]),
        (_) {},
      ),
    );
    await tester.pumpWidget(
      host(
        AndNode([
          TextNode(['shark']),
        ]),
        (_) {},
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'shark',
    );
  });
}
