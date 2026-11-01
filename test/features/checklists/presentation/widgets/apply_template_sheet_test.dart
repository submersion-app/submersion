import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';

import '../../../../helpers/test_app.dart';

/// `showTemplatePickerSheet` is now a pure picker (issue #3356): it only
/// lists templates and pops with the chosen one's id. What "applying" a
/// template means -- creating a new checklist, or replacing an existing
/// one's content after a confirmation -- lives in the callers instead
/// (trip_checklists_panel_test.dart and trip_checklist_block_test.dart).
void main() {
  testWidgets('lists templates with item counts', (tester) async {
    final template = ChecklistTemplate(
      id: 'tpl1',
      name: 'Liveaboard packing',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    String? picked;
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith((ref) async => [template]),
          checklistTemplateItemsProvider('tpl1').overrideWith(
            (ref) async => [
              ChecklistTemplateItem(
                id: 'x1',
                templateId: 'tpl1',
                title: 'Wetsuit',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showTemplatePickerSheet(context: context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Apply template'), findsOneWidget);
    expect(find.text('Liveaboard packing'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);

    await tester.tap(find.text('Liveaboard packing'));
    await tester.pumpAndSettle();

    expect(picked, 'tpl1');
  });

  testWidgets('shows empty state when no templates exist', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [checklistTemplatesProvider.overrideWith((ref) async => [])],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTemplatePickerSheet(context: context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text('No templates yet. Create them in Settings.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the error message when the templates provider fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTemplatePickerSheet(context: context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('dismissing the sheet without a choice resolves to null', (
    tester,
  ) async {
    String? picked = 'unset';
    await tester.pumpWidget(
      testApp(
        overrides: [checklistTemplatesProvider.overrideWith((ref) async => [])],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showTemplatePickerSheet(context: context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the barrier above the sheet to dismiss it without picking.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
}
