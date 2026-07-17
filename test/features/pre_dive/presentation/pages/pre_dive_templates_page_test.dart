import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_templates_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplate template(
    String name, {
    bool builtIn = false,
    bool strict = false,
  }) => PreDiveChecklistTemplate(
    id: name,
    name: name,
    isBuiltIn: builtIn,
    builtinKey: builtIn ? name : null,
    strictOrder: strict,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpPage(
    WidgetTester tester,
    List<PreDiveChecklistTemplate> templates,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          preDiveTemplatesProvider.overrideWith((ref) async => templates),
        ],
        child: const PreDiveTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders built-in badge and user templates', (tester) async {
    await pumpPage(tester, [
      template('BWRAF Buddy Check', builtIn: true),
      template('My CCR List', strict: true),
    ]);

    expect(find.text('BWRAF Buddy Check'), findsOneWidget);
    expect(find.text('My CCR List'), findsOneWidget);
    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('Strict order'), findsOneWidget);
  });

  testWidgets('built-in menu offers Clone but not Delete', (tester) async {
    await pumpPage(tester, [template('BWRAF Buddy Check', builtIn: true)]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Clone'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('user template menu offers Delete', (tester) async {
    await pumpPage(tester, [template('My CCR List')]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Clone'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('empty state renders', (tester) async {
    await pumpPage(tester, []);
    expect(find.text('No pre-dive checklists yet'), findsOneWidget);
  });
}
