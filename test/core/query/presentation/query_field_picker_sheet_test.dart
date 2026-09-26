import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_field_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({}),
    labels: const MapQueryLabels(
      fields: {'depth': 'Max depth', 'level': 'Level'},
      relations: {'buddies': 'Buddies', 'certifications': 'Certifications'},
      entities: {QuerySubject.dives: 'Dives', QuerySubject.buddies: 'Buddies'},
    ),
    now: () => DateTime(2026, 9, 25),
  );
  const strings = QueryFieldPickerStrings(
    title: 'Choose a field',
    searchHint: 'Search fields',
    useRelation: 'Use {name} itself',
    fieldsOf: 'Fields of {name}',
  );

  // The relations follow the fixture's thirteen fields, below the fold of
  // the sheet's lazy list.
  Future<void> scrollTo(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).last,
      );

  Widget host(void Function(FieldPick?) onPicked) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => onPicked(
            await showQueryFieldPicker(ctx, editor: context, strings: strings),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('tapping a field returns its path', (tester) async {
    FieldPick? picked;
    await tester.pumpWidget(host((p) => picked = p));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a field'), findsOneWidget);
    await tester.tap(find.text('Max depth'));
    await tester.pumpAndSettle();
    expect(picked, (path: FieldPath(['depth']), isRelation: false));
  });

  testWidgets(
    'descending a relation walks the tree and returns the full path',
    (tester) async {
      FieldPick? picked;
      await tester.pumpWidget(host((p) => picked = p));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // The chevron descends; the row itself would pick the relation.
      await scrollTo(tester, find.byKey(const ValueKey('descend-buddies')));
      await tester.tap(find.byKey(const ValueKey('descend-buddies')));
      await tester.pumpAndSettle();
      expect(find.text('Fields of Buddies'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('descend-certifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level'));
      await tester.pumpAndSettle();
      expect(picked, (
        path: FieldPath(['buddies', 'certifications', 'level']),
        isRelation: false,
      ));
    },
  );

  testWidgets('tapping a relation row uses the relation itself', (
    tester,
  ) async {
    FieldPick? picked;
    await tester.pumpWidget(host((p) => picked = p));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Buddies'));
    await tester.tap(find.text('Buddies'));
    await tester.pumpAndSettle();
    expect(picked, (path: FieldPath(['buddies']), isRelation: true));
  });

  testWidgets('search narrows by label and key', (tester) async {
    await tester.pumpWidget(host((_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dep');
    await tester.pumpAndSettle();
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('Buddies'), findsNothing);
  });
}
