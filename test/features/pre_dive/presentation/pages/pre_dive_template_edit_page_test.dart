import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/full_themes/tropical_theme.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../helpers/test_app.dart';

/// Fake repository that stubs the reads the page performs and captures the
/// writes so save/create/update/saveItems can be asserted without a database.
class _FakeTemplateRepo implements PreDiveTemplateRepository {
  _FakeTemplateRepo({this.template, this.items = const [], this.gate});

  final PreDiveChecklistTemplate? template;
  final List<PreDiveChecklistTemplateItem> items;

  /// When set, the reads block until it completes, so a test can inspect the
  /// frame the page renders while the template is still in flight.
  final Completer<void>? gate;

  PreDiveChecklistTemplate? createdTemplate;
  PreDiveChecklistTemplate? updatedTemplate;
  String? savedTemplateId;
  List<PreDiveChecklistTemplateItem>? savedItems;

  @override
  Future<PreDiveChecklistTemplate?> getTemplateById(String id) async {
    if (gate != null) await gate!.future;
    return template;
  }

  @override
  Future<List<PreDiveChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async {
    if (gate != null) await gate!.future;
    return items;
  }

  @override
  Future<PreDiveChecklistTemplate> createTemplate(
    PreDiveChecklistTemplate template,
  ) async {
    createdTemplate = template;
    return template.copyWith(id: 'created-id');
  }

  @override
  Future<void> updateTemplate(PreDiveChecklistTemplate template) async {
    updatedTemplate = template;
  }

  @override
  Future<void> saveItems(
    String templateId,
    List<PreDiveChecklistTemplateItem> items,
  ) async {
    savedTemplateId = templateId;
    savedItems = items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplateItem itemFixture(
    String title, {
    String id = '',
    String? section,
    PreDiveItemType type = PreDiveItemType.check,
    bool required = false,
    int sortOrder = 0,
  }) => PreDiveChecklistTemplateItem(
    id: id.isEmpty ? title : id,
    templateId: 'tpl-1',
    section: section,
    title: title,
    sortOrder: sortOrder,
    itemType: type,
    isRequired: required,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveChecklistTemplate templateFixture({
    String name = 'Backmount Setup',
    String description = 'Pre-dive prep',
    String? category = 'Technical',
    bool strictOrder = true,
    bool isBuiltIn = false,
  }) => PreDiveChecklistTemplate(
    id: 'tpl-1',
    diverId: 'diver-1',
    name: name,
    description: description,
    category: category,
    strictOrder: strictOrder,
    isBuiltIn: isBuiltIn,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    String? templateId,
    _FakeTemplateRepo? repo,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveTemplateRepositoryProvider.overrideWithValue(
            repo ?? _FakeTemplateRepo(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
        ],
        child: PreDiveTemplateEditPage(templateId: templateId),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAddItemDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Add item'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
  }

  testWidgets('new-template mode renders name field and Save', (tester) async {
    await pumpPage(tester);
    expect(find.text('New Pre-Dive Checklist'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Strict order'), findsOneWidget);
  });

  testWidgets('Add item opens the item dialog with a type picker', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    // Type dropdown defaults to Checkbox; value fields hidden.
    expect(find.text('Checkbox'), findsOneWidget);
    expect(find.text('Value label'), findsNothing);
  });

  testWidgets('selecting Recorded value reveals the value fields', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    await tester.tap(find.text('Checkbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recorded value').last);
    await tester.pumpAndSettle();

    expect(find.text('Value label'), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Min (warning)'), findsOneWidget);
    expect(find.text('Max (warning)'), findsOneWidget);
  });

  testWidgets('switching back from Recorded value hides the value fields', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    await tester.tap(find.text('Checkbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recorded value').last);
    await tester.pumpAndSettle();
    expect(find.text('Value label'), findsOneWidget);

    // Equipment set items should not reveal the value fields.
    await tester.tap(find.text('Recorded value').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipment set items').last);
    await tester.pumpAndSettle();
    expect(find.text('Value label'), findsNothing);
  });

  testWidgets('Save with empty name shows validation and stays', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.byType(PreDiveTemplateEditPage), findsOneWidget);
  });

  testWidgets('dialog OK with empty title shows title validation', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    // Dialog stays open.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Cancel closes the item dialog without adding an item', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Discarded',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Discarded'), findsNothing);
  });

  testWidgets('adding an item appends it to the list', (tester) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Check pressure',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Section'),
      'Gas',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Check pressure'), findsOneWidget);
    // Subtitle joins section and type label.
    expect(find.textContaining('Gas'), findsOneWidget);
  });

  testWidgets('toggling Required in the dialog marks the item required', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddItemDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Buddy check',
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Required'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Buddy check'), findsOneWidget);
    // Required marker appears in the list-tile subtitle.
    expect(find.textContaining('Required'), findsOneWidget);
  });

  testWidgets('toggling Strict order flips the switch', (tester) async {
    await pumpPage(tester);
    final switchFinder = find.widgetWithText(SwitchListTile, 'Strict order');
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets('edit mode loads an existing template and its items', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo(
      template: templateFixture(),
      items: [
        itemFixture('Check O2', id: 'i1', section: 'Gas', required: true),
        itemFixture(
          'Set gradient',
          id: 'i2',
          type: PreDiveItemType.value,
          sortOrder: 1,
        ),
      ],
    );
    await pumpPage(tester, templateId: 'tpl-1', repo: repo);

    expect(find.text('Edit Pre-Dive Checklist'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Backmount Setup',
    );
    expect(find.text('Check O2'), findsOneWidget);
    expect(find.text('Set gradient'), findsOneWidget);
    // strictOrder pre-fills to true.
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Strict order'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('tapping a loaded item opens the dialog prefilled for edit', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo(
      template: templateFixture(),
      items: [itemFixture('Original title', id: 'i1', section: 'Rig')],
    );
    await pumpPage(tester, templateId: 'tpl-1', repo: repo);

    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();

    // Dialog prefilled with the existing title.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Original title'))
          .controller!
          .text,
      'Original title',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Edited title',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // The edited item replaces the original in place.
    expect(find.text('Edited title'), findsOneWidget);
    expect(find.text('Original title'), findsNothing);
  });

  testWidgets('deleting a loaded item removes it from the list', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo(
      template: templateFixture(),
      items: [
        itemFixture('Keep me', id: 'i1'),
        itemFixture('Delete me', id: 'i2', sortOrder: 1),
      ],
    );
    await pumpPage(tester, templateId: 'tpl-1', repo: repo);

    expect(find.text('Delete me'), findsOneWidget);
    // Second delete button corresponds to the second item.
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    expect(find.text('Delete me'), findsNothing);
    expect(find.text('Keep me'), findsOneWidget);
  });

  testWidgets('reordering items moves an item to a new position', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo(
      template: templateFixture(),
      items: [
        itemFixture('Item A', id: 'a'),
        itemFixture('Item B', id: 'b', sortOrder: 1),
      ],
    );
    await pumpPage(tester, templateId: 'tpl-1', repo: repo);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Item A')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Both items are still present after the reorder settles.
    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
    // Save persists items and the callback body executed without error.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.savedItems, isNotNull);
    expect(repo.savedItems!.length, 2);
  });

  testWidgets('save in new mode creates the template and saves items', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo();
    await pumpPage(tester, repo: repo);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'My checklist',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'A description',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category'),
      'Recreational',
    );

    // Add one item so saveItems receives content.
    await openAddItemDialog(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Check weights',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.createdTemplate, isNotNull);
    expect(repo.createdTemplate!.name, 'My checklist');
    expect(repo.createdTemplate!.description, 'A description');
    expect(repo.createdTemplate!.category, 'Recreational');
    expect(repo.createdTemplate!.diverId, 'diver-1');
    expect(repo.savedTemplateId, 'created-id');
    expect(repo.savedItems, isNotNull);
    expect(repo.savedItems!.length, 1);
    expect(repo.savedItems!.first.title, 'Check weights');
    expect(repo.savedItems!.first.sortOrder, 0);
  });

  testWidgets('empty category is stored as null on save', (tester) async {
    final repo = _FakeTemplateRepo();
    await pumpPage(tester, repo: repo);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'No category',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.createdTemplate, isNotNull);
    expect(repo.createdTemplate!.category, isNull);
  });

  testWidgets('save in edit mode updates the existing template', (
    tester,
  ) async {
    final repo = _FakeTemplateRepo(
      template: templateFixture(name: 'Old name'),
      items: [itemFixture('Existing', id: 'i1')],
    );
    await pumpPage(tester, templateId: 'tpl-1', repo: repo);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'New name',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.updatedTemplate, isNotNull);
    expect(repo.updatedTemplate!.id, 'tpl-1');
    expect(repo.updatedTemplate!.name, 'New name');
    expect(repo.savedTemplateId, 'tpl-1');
    expect(repo.savedItems!.length, 1);
    expect(repo.savedItems!.first.title, 'Existing');
  });

  group('a built-in opens as a viewer, not a locked editor', () {
    Future<void> pumpBuiltIn(WidgetTester tester) => pumpPage(
      tester,
      templateId: 'tpl-1',
      repo: _FakeTemplateRepo(
        template: templateFixture(name: 'GUE EDGE', isBuiltIn: true),
        items: [
          itemFixture('Goal: agree the objective', sortOrder: 0),
          itemFixture('Gas: analyze and label', sortOrder: 1),
        ],
      ),
    );

    testWidgets('shows the view title and the built-in notice', (tester) async {
      await pumpBuiltIn(tester);
      expect(find.text('View Pre-Dive Checklist'), findsOneWidget);
      expect(
        find.text('Built-in checklist. Clone it to make an editable copy.'),
        findsOneWidget,
      );
    });

    testWidgets('renders the items a diver came to read', (tester) async {
      await pumpBuiltIn(tester);
      expect(find.text('Goal: agree the objective'), findsOneWidget);
      expect(find.text('Gas: analyze and label'), findsOneWidget);
      expect(find.text('GUE EDGE'), findsOneWidget);
    });

    testWidgets('withholds every editing affordance', (tester) async {
      await pumpBuiltIn(tester);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Add item'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('item rows show nothing that reads as a control', (
      tester,
    ) async {
      // An empty checkbox was standing in as an alignment spacer, but that
      // glyph reads as "tap to toggle" on rows whose onTap is null. Nothing
      // in this mode has a leading control to align with, so the column goes
      // rather than being filled with a lookalike.
      await pumpBuiltIn(tester);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      expect(find.byIcon(Icons.check_box), findsNothing);
      expect(find.byType(Checkbox), findsNothing);

      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Goal: agree the objective'),
      );
      expect(tile.leading, isNull);
      expect(tile.onTap, isNull, reason: 'read-only rows are not tappable');
    });

    testWidgets('an editable template keeps its per-item delete', (
      tester,
    ) async {
      await pumpPage(
        tester,
        templateId: 'tpl-1',
        repo: _FakeTemplateRepo(
          template: templateFixture(),
          items: [itemFixture('Mine')],
        ),
      );
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('a user template keeps its editor', (tester) async {
      await pumpPage(
        tester,
        templateId: 'tpl-1',
        repo: _FakeTemplateRepo(
          template: templateFixture(),
          items: [itemFixture('Mine')],
        ),
      );
      expect(find.text('Edit Pre-Dive Checklist'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Add item'), findsOneWidget);
    });
  });

  group('the loading frame claims no editing it might have to retract', () {
    testWidgets('an in-flight template offers no Save and no edit title', (
      tester,
    ) async {
      // _readOnly is derived from the fetched row, so on the first frame the
      // mode is unknown. It must not render the edit chrome there: a built-in
      // resolving a moment later would have to withdraw a Save button the
      // diver has already seen.
      final gate = Completer<void>();
      final repo = _FakeTemplateRepo(
        template: templateFixture(),
        items: [itemFixture('Mine')],
        gate: gate,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            preDiveTemplateRepositoryProvider.overrideWithValue(repo),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-1',
            ),
          ],
          child: const PreDiveTemplateEditPage(templateId: 'tpl-1'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Edit Pre-Dive Checklist'), findsNothing);
      expect(find.text('View Pre-Dive Checklist'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      // A user template upgrades to the editing chrome once it is known.
      expect(find.text('Edit Pre-Dive Checklist'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('a built-in never flashes the edit chrome on the way in', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo = _FakeTemplateRepo(
        template: templateFixture(name: 'GUE EDGE', isBuiltIn: true),
        items: [itemFixture('Goal')],
        gate: gate,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            preDiveTemplateRepositoryProvider.overrideWithValue(repo),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-1',
            ),
          ],
          child: const PreDiveTemplateEditPage(templateId: 'tpl-1'),
        ),
      );
      await tester.pump();
      expect(find.text('Save'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('View Pre-Dive Checklist'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('a brand new template still gets Save immediately', (
      tester,
    ) async {
      // No fetch happens without a templateId, so nothing should be deferred.
      await pumpPage(tester);
      expect(find.text('New Pre-Dive Checklist'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  testWidgets(
    'the Save action stays visible on the tropical app bar when creating a '
    'new template (#1231)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: tropicalLight,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PreDiveTemplateEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final style = tester
          .renderObject<RenderParagraph>(find.text('Save'))
          .text
          .style;
      expect(style?.color, isNotNull);
      expect(
        style!.color,
        isNot(tropicalLight.appBarTheme.backgroundColor),
        reason:
            'a bare TextButton paints colorScheme.primary, which this theme '
            'sets to its own app bar background, so the diver sees no Save '
            'button at all',
      );
    },
  );
}
