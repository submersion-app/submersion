import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart'
    hide ChecklistTemplate, ChecklistTemplateItem;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_item_dialog.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A repository whose item write fails, after the template row and its
/// sections have been written.
class _FailingItemsRepository extends ChecklistTemplateRepository {
  int saveItemsCalls = 0;

  @override
  Future<void> saveItems(
    String templateId,
    List<ChecklistTemplateItem> items,
  ) async {
    saveItemsCalls++;
    throw StateError('disk full');
  }
}

/// The checklist template editor on the shared Cancel and Save bar (issue
/// #4527, phase 4, plan 3).
void main() {
  late AppDatabase db;
  late ChecklistTemplateRepository repo;
  final now = DateTime.utc(2026, 11, 22);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ChecklistTemplateRepository();
    for (final diver in ['d1', 'd2']) {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$diver', '$diver', 1, 1)",
      );
    }
  });
  tearDown(tearDownTestDatabase);

  /// A stored template 'tpl' with section 's1' holding items a and b.
  Future<String> stored() async {
    await repo.createTemplate(
      ChecklistTemplate(
        id: 'tpl',
        diverId: 'd1',
        name: 'Packing',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.saveSections('tpl', [
      ChecklistTemplateSection(
        id: 's1',
        templateId: 'tpl',
        title: 'Gear',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await repo.saveItems('tpl', [
      for (final (id, title) in [('a', 'Fins'), ('b', 'Mask')])
        ChecklistTemplateItem(
          id: id,
          templateId: 'tpl',
          title: title,
          sectionId: 's1',
          notes: 'Check straps',
          dueOffsetDays: 3,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
    return 'tpl';
  }

  late ProviderContainer container;

  /// The editor pushed over a stand-in list, on a route with the app's
  /// leave check.
  Future<void> pump(
    WidgetTester tester, {
    String? templateId,
    ChecklistTemplateRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(
              path: 'edit',
              onExit: confirmLeaveRecordSitting,
              builder: (_, _) =>
                  ChecklistTemplateEditPage(templateId: templateId),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
          if (repository != null)
            checklistTemplateRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d1');
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();
  }

  AppBarTextAction save(WidgetTester tester) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == 'Save');

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextFormField).first, name);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
  }

  /// The labels of the editing sittings written: the setup's own writes
  /// are not sittings.
  Future<List<String?>> operationLabels() async {
    final rows = await db
        .customSelect(
          "SELECT label FROM change_log_operations "
          "WHERE label LIKE 'record_edit:%'",
        )
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  /// Change log events on [table] written under an editing sitting.
  Future<int> eventsUnderSitting(String table) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM change_log_events e '
          'JOIN change_log_operations o ON o.id = e.operation_id '
          "WHERE o.label LIKE 'record_edit:%' AND e.table_name = ?",
          variables: [Variable.withString(table)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  testWidgets('the bar is the tinted Cancel and Save bar with no back arrow', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets(
    'a stored template left alone has Save disabled and Back asks nothing',
    (tester) async {
      await pump(tester, templateId: await stored());

      expect(save(tester).onPressed, isNull);
      await back(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('LIST'), findsOneWidget);
    },
  );

  testWidgets('an item opened and confirmed unchanged is no change', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await tester.tap(find.text('Fins'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(save(tester).onPressed, isNull);
  });

  testWidgets('a new template with nothing entered closes on Cancel at once', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(save(tester).onPressed, isNull);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a section title being typed is a change, and Save writes it', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, templateId: id);
    // The title field keeps the focus: the rename has not been committed.
    await tester.enterText(find.widgetWithText(TextField, 'Gear'), 'Dive gear');
    await tester.pump();
    expect(save(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pumpAndSettle();
    expect((await repo.getSectionsForTemplate(id)).single.title, 'Dive gear');
  });

  testWidgets('the item dialog offers a section title as it is typed', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await tester.enterText(find.widgetWithText(TextField, 'Gear'), 'Dive gear');
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<ChecklistItemDialog>(
      find.byType(ChecklistItemDialog),
    );
    expect(dialog.sections.map((s) => s.title), ['Dive gear']);
  });

  testWidgets('Back with a section title being typed asks first', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await tester.enterText(find.widgetWithText(TextField, 'Gear'), 'Dive gear');
    await tester.pump();

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a section title typed blank is no change', (tester) async {
    await pump(tester, templateId: await stored());
    await tester.enterText(find.widgetWithText(TextField, 'Gear'), '  ');
    await tester.pump();

    expect(save(tester).onPressed, isNull);
  });

  testWidgets('Back after renaming asks; Keep editing keeps the name', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await rename(tester, 'Renamed');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsNothing);
    expect(find.text('Renamed'), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('moving an item and moving it back is no change', (tester) async {
    await pump(tester, templateId: await stored());
    // The section header's arrows come first, then each item's.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(1));
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up).at(2));
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('removing an item is a change; Discard writes nothing', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, templateId: id);
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNotNull);

    await back(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
    expect(await repo.getItemsForTemplate(id), hasLength(2));
  });

  testWidgets('Save writes the template, sections and items in one change log '
      'operation', (tester) async {
    final id = await stored();
    await pump(tester, templateId: id);
    await rename(tester, 'Renamed');
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect((await repo.getTemplateById(id))!.name, 'Renamed');
    expect((await repo.getItemsForTemplate(id)).map((i) => i.id), ['b']);
    final labels = await operationLabels();
    expect(labels, hasLength(1));
    final label = RecordEditLabel.decode(labels.single!);
    expect(label?.table, 'checklist_templates');
    expect(label?.id, id);
    expect(await eventsUnderSitting('checklist_templates'), 1);
    expect(
      await eventsUnderSitting('checklist_template_items'),
      greaterThan(0),
    );
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('an item write that throws leaves no new template', (
    tester,
  ) async {
    final failing = _FailingItemsRepository();
    await pump(tester, repository: failing);
    await rename(tester, 'Doomed');
    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(failing.saveItemsCalls, 1);
    expect(await repo.getAllTemplates(), isEmpty);
    final sections = await db
        .customSelect('SELECT id FROM checklist_template_sections')
        .get();
    expect(sections, isEmpty);
    expect(find.text('LIST'), findsNothing);
    expect(find.text('Doomed'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('an item write that throws keeps the stored name and sections', (
    tester,
  ) async {
    final id = await stored();
    final failing = _FailingItemsRepository();
    await pump(tester, templateId: id, repository: failing);
    await rename(tester, 'Renamed');
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(failing.saveItemsCalls, 1);
    expect((await repo.getTemplateById(id))!.name, 'Packing');
    expect(await repo.getSectionsForTemplate(id), hasLength(1));
    expect(await repo.getItemsForTemplate(id), hasLength(2));
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets('a new template is created under the page id', (tester) async {
    await pump(tester);
    await rename(tester, 'Fresh');
    await tapSave(tester);

    final templates = await repo.getAllTemplates();
    expect(templates.map((t) => t.name), ['Fresh']);
    expect(templates.single.diverId, 'd1');
    final label = RecordEditLabel.decode((await operationLabels()).single!);
    expect(label?.id, templates.single.id);
  });

  testWidgets('a template deleted while open is refused at Save', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, templateId: id);
    await repo.deleteTemplate(id);
    await rename(tester, 'Renamed');
    await tapSave(tester);

    expect(find.text('This template no longer exists.'), findsOneWidget);
    expect(await repo.getTemplateById(id), isNull);
    expect(await repo.getAllTemplates(), isEmpty);
  });

  testWidgets('a template that is missing says so and goes back to the list', (
    tester,
  ) async {
    await pump(tester, templateId: 'gone');

    expect(find.text('This template no longer exists.'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(await repo.getAllTemplates(), isEmpty);
  });

  testWidgets('a new template closes on a diver switch, writing nothing', (
    tester,
  ) async {
    await pump(tester);
    await rename(tester, 'Not yours');
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2');
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await repo.getAllTemplates(), isEmpty);
  });
}
