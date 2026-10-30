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
      ops: {
        QueryOp.eq: 'is',
        QueryOp.neq: 'is not',
        QueryOp.inList: 'is one of',
        QueryOp.isEmpty: 'is not set',
        QueryOp.isSet: 'is set',
      },
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

  Widget host(
    QueryNode? root,
    ValueChanged<QueryNode?> onChanged, {
    QueryEditorContext? editor,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: QueryBuilderGroup(
          context: editor ?? context,
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

  group('a relation with nothing picked (#3810)', () {
    final siteEmpty = ConditionNode(FieldPath(['site']), QueryOp.isEmpty, null);
    final siteSet = ConditionNode(FieldPath(['site']), QueryOp.isSet, null);
    final saltPier = ConditionNode(
      FieldPath(['site']),
      QueryOp.eq,
      const RefValue('s1', 'Salt Pier'),
    );

    Future<void> chooseSite(WidgetTester tester) async {
      await tester.tap(find.text('Add condition'));
      await tester.pumpAndSettle();
      await pick(tester, 'Site');
    }

    Future<void> changeOp(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButton<QueryOp>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the picker offers not set, which adds the row', (
      tester,
    ) async {
      QueryNode? out;
      await tester.pumpWidget(host(null, (n) => out = n));
      await chooseSite(tester);
      await tester.tap(find.text('Site is not set'));
      await tester.pumpAndSettle();
      expect(out, AndNode([siteEmpty]));
    });

    testWidgets('the picker offers set, which adds the row', (tester) async {
      QueryNode? out;
      await tester.pumpWidget(host(null, (n) => out = n));
      await chooseSite(tester);
      await tester.tap(find.text('Site is set'));
      await tester.pumpAndSettle();
      expect(out, AndNode([siteSet]));
    });

    testWidgets('a diver with no rows at all can still add it', (tester) async {
      QueryNode? out;
      await tester.pumpWidget(
        host(
          null,
          (n) => out = n,
          editor: context.copyWith(names: const MapNameResolver({})),
        ),
      );
      await chooseSite(tester);
      await tester.tap(find.text('Site is not set'));
      await tester.pumpAndSettle();
      expect(out, AndNode([siteEmpty]));
    });

    testWidgets('a search leaves both rows in place', (tester) async {
      await tester.pumpWidget(host(null, (_) {}));
      await chooseSite(tester);
      await tester.enterText(find.byType(TextField).last, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Salt Pier'), findsNothing);
      expect(find.text('Site is not set'), findsOneWidget);
      expect(find.text('Site is set'), findsOneWidget);
    });

    testWidgets('dismissing the picker adds no row', (tester) async {
      QueryNode? out;
      await tester.pumpWidget(host(null, (n) => out = n));
      await chooseSite(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(out, isNull);
    });

    testWidgets('a row on not set can go back to a named row', (tester) async {
      QueryNode? out;
      await tester.pumpWidget(host(AndNode([siteEmpty]), (n) => out = n));
      await changeOp(tester, 'is');
      await tester.tap(find.text('Salt Pier'));
      await tester.pumpAndSettle();
      expect(out, AndNode([saltPier]));
    });

    testWidgets('the same change to a list starts it with the pick', (
      tester,
    ) async {
      QueryNode? out;
      await tester.pumpWidget(host(AndNode([siteEmpty]), (n) => out = n));
      await changeOp(tester, 'is one of');
      await tester.tap(find.text('Salt Pier'));
      await tester.pumpAndSettle();
      expect(
        out,
        AndNode([
          ConditionNode(
            FieldPath(['site']),
            QueryOp.inList,
            ListValue(const [RefValue('s1', 'Salt Pier')]),
          ),
        ]),
      );
    });

    testWidgets('backing out of that pick leaves the row alone', (
      tester,
    ) async {
      QueryNode? out;
      await tester.pumpWidget(host(AndNode([siteEmpty]), (n) => out = n));
      await changeOp(tester, 'is');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(out, isNull);
    });

    testWidgets('moving between named operators asks for nothing', (
      tester,
    ) async {
      QueryNode? out;
      await tester.pumpWidget(host(AndNode([saltPier]), (n) => out = n));
      await changeOp(tester, 'is not');
      expect(find.text('Choose Site'), findsNothing);
      expect(
        out,
        AndNode([
          ConditionNode(
            FieldPath(['site']),
            QueryOp.neq,
            const RefValue('s1', 'Salt Pier'),
          ),
        ]),
      );
    });

    testWidgets('a named row can still go to not set', (tester) async {
      QueryNode? out;
      await tester.pumpWidget(host(AndNode([saltPier]), (n) => out = n));
      await changeOp(tester, 'is not set');
      expect(out, AndNode([siteEmpty]));
    });
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

  testWidgets('emptying a text row says so and keeps the words', (
    tester,
  ) async {
    final changes = <QueryNode?>[];
    await tester.pumpWidget(
      host(
        AndNode([
          TextNode(['manta']),
        ]),
        changes.add,
      ),
    );
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('Enter at least one word'), findsOneWidget);
    expect(changes, isEmpty);
  });

  testWidgets('a row whose field no longer exists is shown, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AndNode([
          ConditionNode(
            FieldPath(['warpFactor']),
            QueryOp.gt,
            const NumberValue(9, null),
          ),
        ]),
        (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('warpFactor'), findsOneWidget);
    expect(find.byTooltip('No longer exists'), findsOneWidget);
    // It can still be removed.
    expect(find.byKey(const ValueKey('remove-0')), findsOneWidget);
  });
}
