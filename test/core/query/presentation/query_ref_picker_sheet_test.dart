import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {
        'Salt Pier': 's1',
        'Sand Slope': 's2',
        'Cenote': 's3',
      },
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );

  Widget host(Future<void> Function(BuildContext ctx) onOpen) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) =>
            TextButton(onPressed: () => onOpen(ctx), child: const Text('open')),
      ),
    ),
  );

  testWidgets('lists names, filters, returns the tapped ref', (tester) async {
    RefValue? picked;
    await tester.pumpWidget(
      host((ctx) async {
        picked = await showQueryRefPicker(
          ctx,
          editor: context,
          kind: QuerySubject.sites,
          title: 'Choose site',
          searchHint: 'Search',
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Cenote'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sa');
    await tester.pumpAndSettle();
    expect(find.text('Cenote'), findsNothing);
    await tester.tap(find.text('Sand Slope'));
    await tester.pumpAndSettle();
    expect(picked, const RefValue('s2', 'Sand Slope'));
  });

  testWidgets('the multi picker toggles and returns the selection', (
    tester,
  ) async {
    List<RefValue>? picked;
    await tester.pumpWidget(
      host((ctx) async {
        picked = await showQueryRefMultiPicker(
          ctx,
          editor: context,
          kind: QuerySubject.sites,
          title: 'Choose sites',
          searchHint: 'Search',
          doneLabel: 'Done',
          selected: const [RefValue('s1', 'Salt Pier')],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cenote'));
    await tester.tap(find.text('Salt Pier'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked, const [RefValue('s3', 'Cenote')]);
  });
}
