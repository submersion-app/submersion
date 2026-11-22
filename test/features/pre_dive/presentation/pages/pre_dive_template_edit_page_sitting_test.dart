import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart'
    as domain;
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_item_dialog.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A repository whose item write fails, after the template row and its
/// sections have been written.
class _FailingItemsRepository extends PreDiveTemplateRepository {
  int saveItemsCalls = 0;

  @override
  Future<void> saveItems(
    String templateId,
    List<domain.PreDiveChecklistTemplateItem> items,
  ) async {
    saveItemsCalls++;
    throw StateError('disk full');
  }
}

/// The pre-dive template editor on the shared Cancel and Save bar, and a
/// built-in template still a viewer (issue #4527, phase 4, plan 3).
void main() {
  late AppDatabase db;
  late PreDiveTemplateRepository repo;
  final now = DateTime.utc(2026, 11, 22);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = PreDiveTemplateRepository();
    for (final diver in ['d1', 'd2']) {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$diver', '$diver', 1, 1)",
      );
    }
  });
  tearDown(tearDownTestDatabase);

  /// A stored template [id]: section 's1' holding a value item with
  /// thresholds and a check item; a built-in one when [builtIn].
  Future<String> stored({
    String id = 'tpl',
    bool builtIn = false,
    bool linked = false,
  }) async {
    await repo.createTemplate(
      domain.PreDiveChecklistTemplate(
        id: id,
        diverId: builtIn ? null : 'd1',
        name: builtIn ? 'Basic' : 'Twinset',
        isBuiltIn: builtIn,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (builtIn) {
      // Built-ins are seeded as they are: the repository refuses to write
      // their lists.
      await db.customStatement(
        "INSERT INTO pre_dive_checklist_template_items (id, template_id, "
        "title, sort_order, created_at, updated_at) VALUES "
        "('$id-i1', '$id', 'Air on', 0, 1, 1)",
      );
      return id;
    }
    await repo.saveSections(id, [
      domain.PreDiveChecklistTemplateSection(
        id: 's1',
        templateId: id,
        title: 'Gas',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await repo.saveItems(id, [
      domain.PreDiveChecklistTemplateItem(
        id: 'a',
        templateId: id,
        sectionId: 's1',
        title: 'Back gas pressure',
        itemType: domain.PreDiveItemType.value,
        valueLabel: 'Pressure',
        valueUnit: 'bar',
        valueMin: 0.1 + 0.2,
        valueMax: 232,
        createdAt: now,
        updatedAt: now,
      ),
      domain.PreDiveChecklistTemplateItem(
        id: 'b',
        templateId: id,
        sectionId: 's1',
        title: 'Isolator open',
        createdAt: now,
        updatedAt: now,
      ),
      if (linked)
        domain.PreDiveChecklistTemplateItem(
          id: 'c',
          templateId: id,
          title: 'Cell 1 linearity',
          itemType: domain.PreDiveItemType.cellLinearity,
          sourceItemId: 'a',
          createdAt: now,
          updatedAt: now,
        ),
    ]);
    return id;
  }

  late ProviderContainer container;

  /// The editor pushed over a stand-in list, on a route with the app's
  /// leave check, under the app's editing shortcuts.
  Future<void> pump(
    WidgetTester tester, {
    String? templateId,
    PreDiveTemplateRepository? repository,
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
                  PreDiveTemplateEditPage(templateId: templateId),
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
            preDiveTemplateRepositoryProvider.overrideWithValue(repository),
        ],
        child: RecordEditShortcuts(
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
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

  Future<void> ctrlS(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
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

  testWidgets('a user template shows the tinted Cancel and Save bar', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.widgetWithText(AppBar, 'Edit Pre-Dive Checklist'), findsOne);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('a saved template keeps its edit title as it leaves', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await rename(tester, 'Renamed');
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    // Step through the save and the page's exit, frame by frame.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('View Pre-Dive Checklist'), findsNothing);
    }
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a built-in View has the plain bar, a back arrow and no Save', (
    tester,
  ) async {
    await pump(tester, templateId: await stored(id: 'bi', builtIn: true));

    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'View Pre-Dive Checklist'), findsOne);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Air on'), findsOneWidget);

    // The editing keys have no sitting to act on.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await ctrlS(tester);
    expect(find.text('Air on'), findsOneWidget);
    expect(find.text('LIST'), findsNothing);

    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
    expect(await operationLabels(), isEmpty);
  });

  testWidgets('Escape on an untouched user template leaves it', (tester) async {
    await pump(tester, templateId: await stored());

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
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
    await tester.tap(find.text('Back gas pressure'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(save(tester).onPressed, isNull);
  });

  testWidgets('toggling strict order is a change; toggling back is not', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNotNull);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('deleting a source item is a change that clears its dependant', (
    tester,
  ) async {
    final id = await stored(linked: true);
    await pump(tester, templateId: id);
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
    await tapSave(tester);

    final items = await repo.getItemsForTemplate(id);
    expect(items.map((i) => i.id), ['b', 'c']);
    expect(items.last.sourceItemId, isNull);
  });

  testWidgets('a section title being typed is a change, and Save writes it', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, templateId: id);
    // The title field keeps the focus: the rename has not been committed.
    await tester.enterText(find.widgetWithText(TextField, 'Gas'), 'Back gas');
    await tester.pump();
    expect(save(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pumpAndSettle();
    expect((await repo.getSectionsForTemplate(id)).single.title, 'Back gas');
  });

  testWidgets('the item dialog offers a section title as it is typed', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await tester.enterText(find.widgetWithText(TextField, 'Gas'), 'Back gas');
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<PreDiveItemDialog>(
      find.byType(PreDiveItemDialog),
    );
    expect(dialog.sections.map((s) => s.title), ['Back gas']);
  });

  testWidgets('Back with a section title being typed asks first', (
    tester,
  ) async {
    await pump(tester, templateId: await stored());
    await tester.enterText(find.widgetWithText(TextField, 'Gas'), 'Back gas');
    await tester.pump();

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a section title typed blank is no change', (tester) async {
    await pump(tester, templateId: await stored());
    await tester.enterText(find.widgetWithText(TextField, 'Gas'), '  ');
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

    expect(find.text('Renamed'), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('Save writes the template, sections and items in one change log '
      'operation', (tester) async {
    final id = await stored();
    await pump(tester, templateId: id);
    await rename(tester, 'Renamed');
    // The section header's delete comes first, then each item's.
    await tester.tap(find.byIcon(Icons.delete_outline).at(2));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect((await repo.getTemplateById(id))!.name, 'Renamed');
    final items = await repo.getItemsForTemplate(id);
    expect(items.map((i) => i.id), ['a']);
    // Confirmed alone, the threshold keeps its stored value.
    expect(items.single.valueMin, 0.1 + 0.2);
    final labels = await operationLabels();
    expect(labels, hasLength(1));
    final label = RecordEditLabel.decode(labels.single!);
    expect(label?.table, 'pre_dive_checklist_templates');
    expect(label?.id, id);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('an item write that throws leaves no new template', (
    tester,
  ) async {
    // The test database seeds templates of its own: count around the Save.
    Future<(int, int)> counts() async {
      final row = await db
          .customSelect(
            'SELECT (SELECT COUNT(*) FROM pre_dive_checklist_templates) AS t, '
            '(SELECT COUNT(*) FROM pre_dive_checklist_template_sections) AS s',
          )
          .getSingle();
      return (row.read<int>('t'), row.read<int>('s'));
    }

    final before = await counts();
    final failing = _FailingItemsRepository();
    await pump(tester, repository: failing);
    await rename(tester, 'Doomed');
    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(failing.saveItemsCalls, 1);
    expect(await counts(), before);
    expect(find.text('LIST'), findsNothing);
    expect(find.text('Doomed'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('an item write that throws keeps the stored template', (
    tester,
  ) async {
    final id = await stored();
    final failing = _FailingItemsRepository();
    await pump(tester, templateId: id, repository: failing);
    await rename(tester, 'Renamed');
    await tester.tap(find.byIcon(Icons.delete_outline).at(2));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(failing.saveItemsCalls, 1);
    expect((await repo.getTemplateById(id))!.name, 'Twinset');
    expect(await repo.getItemsForTemplate(id), hasLength(2));
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets('a template deleted while open is refused at Save', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, templateId: id);
    await repo.deleteTemplate(id);
    await rename(tester, 'Renamed');
    await tapSave(tester);

    expect(find.text('This checklist no longer exists.'), findsOneWidget);
    expect(await repo.getTemplateById(id), isNull);
  });

  testWidgets('a template that is missing says so and goes back to the list', (
    tester,
  ) async {
    await pump(tester, templateId: 'gone');

    expect(find.text('This checklist no longer exists.'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(await repo.getTemplateById('gone'), isNull);
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
    expect(await operationLabels(), isEmpty);
  });
}
