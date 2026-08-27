import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_templates_page.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Renders [ChecklistTemplatesPage] behind a real [GoRouter] so the FAB and
/// per-tile edit/tap affordances (which call `context.push`) can actually
/// navigate, landing on the real edit page.
///
/// Overrides [sharedPreferencesProvider] because `checklistTemplatesProvider`
/// resolves `validatedCurrentDiverIdProvider`, which watches
/// `currentDiverIdProvider` -> `sharedPreferencesProvider` (throws unless
/// overridden).
Future<Widget> _routedApp() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/checklist-templates',
    routes: [
      GoRoute(
        path: '/checklist-templates',
        builder: (context, state) => const ChecklistTemplatesPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ChecklistTemplateEditPage(),
          ),
          GoRoute(
            path: ':templateId/edit',
            builder: (context, state) => ChecklistTemplateEditPage(
              templateId: state.pathParameters['templateId'],
            ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('lists templates with item counts', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith(
            (ref) async => [
              ChecklistTemplate(
                id: 'tpl1',
                name: 'Liveaboard packing',
                description: 'Everything for a week aboard',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
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
        child: const ChecklistTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checklist Templates'), findsOneWidget);
    expect(find.text('Liveaboard packing'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [checklistTemplatesProvider.overrideWith((ref) async => [])],
        child: const ChecklistTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No templates yet'), findsOneWidget);
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
        child: const ChecklistTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('renders a divider between multiple template rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith(
            (ref) async => [
              ChecklistTemplate(
                id: 'tpl1',
                name: 'Liveaboard packing',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              ChecklistTemplate(
                id: 'tpl2',
                name: 'Resort packing',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
        ],
        child: const ChecklistTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Liveaboard packing'), findsOneWidget);
    expect(find.text('Resort packing'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('tapping the FAB navigates to the new-template page', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.pumpWidget(await _routedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistTemplateEditPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a template row navigates to its edit page', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final repo = ChecklistTemplateRepository();
    final created = await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Liveaboard packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(await _routedApp());
    await tester.pumpAndSettle();

    expect(find.text('Liveaboard packing'), findsOneWidget);
    await tester.tap(find.text('Liveaboard packing'));
    await tester.pumpAndSettle();

    final editPage = tester.widget<ChecklistTemplateEditPage>(
      find.byType(ChecklistTemplateEditPage),
    );
    expect(editPage.templateId, created.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the edit icon navigates to the edit page', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final repo = ChecklistTemplateRepository();
    final created = await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Liveaboard packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(await _routedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    final editPage = tester.widget<ChecklistTemplateEditPage>(
      find.byType(ChecklistTemplateEditPage),
    );
    expect(editPage.templateId, created.id);
  });

  testWidgets('deleting a template via the confirmation dialog removes it', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final repo = ChecklistTemplateRepository();
    await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Liveaboard packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(await _routedApp());
    await tester.pumpAndSettle();
    expect(find.text('Liveaboard packing'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Template'), findsOneWidget);
    expect(
      find.text(
        'Delete "Liveaboard packing"? Trips that already applied it keep '
        'their items.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Liveaboard packing'), findsNothing);
    expect(await repo.getAllTemplates(), isEmpty);
  });

  testWidgets('cancelling the delete confirmation keeps the template', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final repo = ChecklistTemplateRepository();
    await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Liveaboard packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(await _routedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Liveaboard packing'), findsOneWidget);
    expect(await repo.getAllTemplates(), hasLength(1));
  });

  testWidgets('shows the item-count subtitle for a template with items', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final repo = ChecklistTemplateRepository();
    final created = await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Liveaboard packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.saveItems(created.id, [
      ChecklistTemplateItem(
        id: '',
        templateId: created.id,
        title: 'Wetsuit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ChecklistTemplateItem(
        id: '',
        templateId: created.id,
        title: 'Fins',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(await _routedApp());
    await tester.pumpAndSettle();

    expect(find.text('2 items'), findsOneWidget);
  });
}
