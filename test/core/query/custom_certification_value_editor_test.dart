import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import 'presentation/query_value_editor_test.dart' show kTestBuilderStrings;

/// Issue #690: the query builder offers custom agencies beside the built-ins.
void main() {
  const clubId = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';
  final context = QueryEditorContext(
    registry: appQueryRegistry,
    root: certificationQueryEntity,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.certificationAgencies: {'Club X': clubId},
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 10, 5),
  );
  final agency = resolvePath(
    appQueryRegistry,
    certificationQueryEntity,
    FieldPath(['agency']),
  );

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('the dropdown offers a custom agency and stores its id', (
    tester,
  ) async {
    // The menu is a lazy list; make room for every agency.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: context,
          target: agency,
          op: QueryOp.eq,
          value: const EnumValue('padi'),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Club X').last);
    await tester.pumpAndSettle();
    expect(out, const EnumValue(clubId));
    expect((out! as EnumValue).label, 'Club X');
  });

  testWidgets('a selected custom agency shows its name', (tester) async {
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: context,
          target: agency,
          op: QueryOp.eq,
          value: const EnumValue(clubId, label: 'Club X'),
          onChanged: (_) {},
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.text('Club X'), findsOneWidget);
  });

  testWidgets('chips include custom agencies', (tester) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: context,
          target: agency,
          op: QueryOp.inList,
          value: ListValue(const [EnumValue('padi')]),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Club X'));
    await tester.pump();
    final items = (out! as ListValue).items.cast<EnumValue>();
    expect(items.map((e) => e.name), containsAll(['padi', clubId]));
    expect(items.firstWhere((e) => e.name == clubId).label, 'Club X');
  });
}
