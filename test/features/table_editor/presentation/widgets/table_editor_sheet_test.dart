import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart'
    show WaterType, WeightType;
import 'package:submersion/core/constants/units.dart' show DepthUnit;
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_draft_state.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/features/table_editor/presentation/widgets/table_editor_sheet.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

class _TestConfigNotifier extends EntityTableConfigNotifier<DiveField> {
  _TestConfigNotifier(EntityTableViewConfig<DiveField> config)
    : super(
        defaultConfig: config,
        fieldFromName: (n) => diveFieldFromName(n) ?? DiveField.diveNumber,
      ) {
    state = config;
  }
}

/// The sheet (#3422): a tap opens a cell, Enter commits and moves down,
/// Escape cancels, bad text is flagged and shown as typed.
void main() {
  const twoWeights = [
    DiveWeight(
      id: 'w1',
      diveId: 'd1',
      weightType: WeightType.belt,
      amountKg: 3,
    ),
    DiveWeight(
      id: 'w2',
      diveId: 'd1',
      weightType: WeightType.belt,
      amountKg: 4,
    ),
  ];
  final d1 = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 1, 1),
    visibilityMeters: 15,
    weights: twoWeights,
  );
  final d2 = Dive(
    id: 'd2',
    diveNumber: 2,
    dateTime: DateTime(2026, 1, 2),
    visibilityMeters: 20,
  );
  final config = EntityTableViewConfig<DiveField>(
    columns: [
      EntityTableColumnConfig(field: DiveField.diveNumber, isPinned: true),
      EntityTableColumnConfig(field: DiveField.visibility),
      EntityTableColumnConfig(field: DiveField.totalWeight),
    ],
  );
  final opened = <String>[];

  setUp(() async {
    await setUpTestDatabase();
    opened.clear();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpSheet(
    WidgetTester tester, {
    EntityTableViewConfig<DiveField>? sheetConfig,
    List<Dive>? sheetRows,
    AppSettings? settings,
  }) async {
    final diveRepo = DiveRepository();
    final entity = DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: BulkDiveEditService(
        diveRepo,
        BuddyRepository(),
        SpeciesRepository(),
      ),
      sites: const [],
      centers: const [],
      trips: const [],
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tableEditorDiveConfigProvider.overrideWith(
            (ref) => _TestConfigNotifier(sheetConfig ?? config),
          ),
        ],
        child: SizedBox(
          width: 800,
          height: 400,
          child: TableEditorSheet<Dive, DiveField>(
            tab: TableEditorTab.dives,
            entity: entity,
            rows: sheetRows ?? [d1, d2],
            configProvider: tableEditorDiveConfigProvider,
            isColumnFiltered: (_) => false,
            onOpenRecord: opened.add,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(TableEditorSheet<Dive, DiveField>)),
      );

  TableDraft? draftOf(WidgetTester tester, String id, DiveField f) =>
      containerOf(
        tester,
      ).read(tableEditorDraftsProvider(TableEditorTab.dives)).at(id, f.name);

  // The visibility column formats through the diver's distance unit.
  String vis(double metres) =>
      const UnitFormatter(AppSettings()).formatDistance(metres);

  Finder cell(String text) => find.text(text);

  Future<void> tapCell(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    // The row's double-tap recognizer holds a single tap until it times out.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('tapping an editable cell opens a TextField with the current '
      'value in the diver\'s unit', (tester) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, formatDecimalForInput(15));
  });

  testWidgets('Enter commits a draft, paints it and moves down', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));

    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(draftOf(tester, 'd1', DiveField.visibility)?.value, 12.0);
    final state = containerOf(
      tester,
    ).read(tableEditorDraftsProvider(TableEditorTab.dives));
    expect(state.editing, CellPosition('d2', DiveField.visibility.name));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(vis(12)), findsOneWidget);
  });

  testWidgets('Escape cancels without a draft', (tester) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));
    await tester.enterText(find.byType(TextField), '99');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(draftOf(tester, 'd1', DiveField.visibility), isNull);
    expect(find.text(vis(15)), findsOneWidget);
  });

  testWidgets('an unparsable value is flagged and shows the raw text', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final draft = draftOf(tester, 'd1', DiveField.visibility);
    expect(draft?.flag, TableDraftFlag.unparsable);
    expect(draft?.rawText, 'abc');
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('a draft equal to the original is dropped', (tester) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));
    await tester.enterText(find.byType(TextField), '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(draftOf(tester, 'd1', DiveField.visibility), isNull);
  });

  testWidgets('a read-only weight cell does not open an editor', (
    tester,
  ) async {
    await pumpSheet(tester);
    // d1 has two weight rows: its weight cell shows their total and stays
    // closed.
    await tapCell(
      tester,
      find.text(const UnitFormatter(AppSettings()).formatWeight(7)),
    );

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Enter follows the order the sheet shows, not the list order', (
    tester,
  ) async {
    // Sorted by visibility descending, d2 (20 m) sits above d1 (15 m).
    await pumpSheet(
      tester,
      sheetConfig: config.copyWith(
        sortField: DiveField.visibility,
        sortAscending: false,
      ),
    );
    await tapCell(tester, cell(vis(20)));
    await tester.enterText(find.byType(TextField), '21');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final state = containerOf(
      tester,
    ).read(tableEditorDraftsProvider(TableEditorTab.dives));
    expect(state.editing, CellPosition('d1', DiveField.visibility.name));
  });

  testWidgets('Enter from a weight cell skips the dive with two weight rows', (
    tester,
  ) async {
    // d2 above d1; d1's weight cell is read-only.
    await pumpSheet(tester, sheetRows: [d2, d1]);
    await tapCell(tester, cell('--').first);
    await tester.enterText(find.byType(TextField), '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final state = containerOf(
      tester,
    ).read(tableEditorDraftsProvider(TableEditorTab.dives));
    expect(state.at('d2', DiveField.totalWeight.name)?.value, 5.0);
    expect(state.editing, isNull);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping a toggle cell flips it without opening an editor', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      sheetConfig: EntityTableViewConfig<DiveField>(
        columns: [
          EntityTableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          EntityTableColumnConfig(field: DiveField.isFavorite),
        ],
      ),
    );
    await tapCell(tester, find.text('No').first);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    final state = containerOf(
      tester,
    ).read(tableEditorDraftsProvider(TableEditorTab.dives));
    expect(state.forEntity('d1').single.value, isTrue);
  });

  testWidgets('tapping another cell commits the open text', (tester) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));
    await tester.enterText(find.byType(TextField), '12');

    await tapCell(tester, cell(vis(20)));

    expect(draftOf(tester, 'd1', DiveField.visibility)?.value, 12.0);
    final state = containerOf(
      tester,
    ).read(tableEditorDraftsProvider(TableEditorTab.dives));
    expect(state.editing, CellPosition('d2', DiveField.visibility.name));
  });

  testWidgets('the cell menu can discard a draft', (tester) async {
    await pumpSheet(tester);
    await tapCell(tester, cell(vis(15)));
    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(draftOf(tester, 'd1', DiveField.visibility), isNotNull);

    await tester.longPress(find.text(vis(12)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard change'));
    await tester.pumpAndSettle();

    expect(draftOf(tester, 'd1', DiveField.visibility), isNull);
    expect(find.text(vis(15)), findsOneWidget);
  });

  testWidgets(
    'a toggle on an already drafted cell keeps the draft\'s original',
    (tester) async {
      await pumpSheet(
        tester,
        sheetConfig: EntityTableViewConfig<DiveField>(
          columns: [
            EntityTableColumnConfig(
              field: DiveField.diveNumber,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: DiveField.isFavorite),
          ],
        ),
      );
      containerOf(tester)
          .read(tableEditorDraftsProvider(TableEditorTab.dives).notifier)
          .put(
            TableDraft(
              entityId: 'd1',
              fieldName: DiveField.isFavorite.name,
              original: true,
              value: false,
            ),
          );
      await tester.pump();

      await tapCell(tester, find.text('No').first);

      final draft = draftOf(tester, 'd1', DiveField.isFavorite);
      expect(draft, isNull); // true again equals the remembered original
    },
  );

  group('choice and keyboard', () {
    final choiceConfig = EntityTableViewConfig<DiveField>(
      columns: [
        EntityTableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        EntityTableColumnConfig(field: DiveField.visibility),
        EntityTableColumnConfig(field: DiveField.waterType),
      ],
    );

    testWidgets('a choice cell opens a pulldown and selecting commits', (
      tester,
    ) async {
      await pumpSheet(tester, sheetConfig: choiceConfig);
      await tapCell(tester, find.text('--').first);
      expect(find.byType(DropdownMenu<String?>), findsOneWidget);

      await tester.tap(find.byType(DropdownMenu<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Salt Water').last);
      await tester.pumpAndSettle();

      expect(draftOf(tester, 'd1', DiveField.waterType)?.value, 'salt');
      expect(find.text('Salt Water'), findsOneWidget);
    });

    testWidgets('Tab commits and moves to the next editable cell', (
      tester,
    ) async {
      await pumpSheet(tester, sheetConfig: choiceConfig);
      await tapCell(tester, cell(vis(15)));
      await tester.enterText(find.byType(TextField), '12');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(draftOf(tester, 'd1', DiveField.visibility)?.value, 12.0);
      final state = containerOf(
        tester,
      ).read(tableEditorDraftsProvider(TableEditorTab.dives));
      expect(state.editing, CellPosition('d1', DiveField.waterType.name));
      expect(find.byType(DropdownMenu<String?>), findsOneWidget);
    });

    TableDraftsNotifier notifierOf(WidgetTester tester) => containerOf(
      tester,
    ).read(tableEditorDraftsProvider(TableEditorTab.dives).notifier);

    final salty = d1.copyWith(waterType: WaterType.salt);
    final waterCell = CellPosition('d1', DiveField.waterType.name);

    Future<void> openCell(WidgetTester tester, CellPosition position) async {
      notifierOf(tester).setEditing(position);
      await tester.pump();
      await tester.pump();
    }

    Future<void> closeCell(WidgetTester tester) async {
      notifierOf(tester).setEditing(null);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a cleared choice stays cleared when reopened and left', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        sheetConfig: choiceConfig,
        sheetRows: [salty, d2],
      );
      notifierOf(tester).put(
        TableDraft(
          entityId: 'd1',
          fieldName: DiveField.waterType.name,
          original: 'salt',
          value: null,
        ),
      );

      await openCell(tester, waterCell);
      await closeCell(tester);

      final draft = draftOf(tester, 'd1', DiveField.waterType);
      expect(draft, isNotNull);
      expect(draft!.value, isNull);
    });

    testWidgets('a flagged choice survives being opened and left', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        sheetConfig: choiceConfig,
        sheetRows: [salty, d2],
      );
      notifierOf(tester).put(
        TableDraft(
          entityId: 'd1',
          fieldName: DiveField.waterType.name,
          original: 'salt',
          value: 'salt',
          rawText: 'Swamp',
          flag: TableDraftFlag.unknownValue,
        ),
      );

      await openCell(tester, waterCell);
      await closeCell(tester);

      expect(
        draftOf(tester, 'd1', DiveField.waterType)?.flag,
        TableDraftFlag.unknownValue,
      );
    });

    testWidgets('Escape on a choice cell closes it without a draft', (
      tester,
    ) async {
      await pumpSheet(tester, sheetConfig: choiceConfig);
      await openCell(tester, waterCell);
      expect(find.byType(DropdownMenu<String?>), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(DropdownMenu<String?>), findsNothing);
      expect(draftOf(tester, 'd1', DiveField.waterType), isNull);
    });

    testWidgets('Space flips a toggle reached by keyboard', (tester) async {
      await pumpSheet(
        tester,
        sheetConfig: EntityTableViewConfig<DiveField>(
          columns: [
            EntityTableColumnConfig(field: DiveField.diveNumber),
            EntityTableColumnConfig(field: DiveField.isFavorite),
          ],
        ),
      );
      await openCell(tester, CellPosition('d1', DiveField.isFavorite.name));
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(draftOf(tester, 'd1', DiveField.isFavorite)?.value, isTrue);
    });

    testWidgets('editing a multi-line value keeps its line breaks', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        sheetConfig: EntityTableViewConfig<DiveField>(
          columns: [
            EntityTableColumnConfig(field: DiveField.diveNumber),
            EntityTableColumnConfig(field: DiveField.notes),
          ],
        ),
        sheetRows: [
          d1.copyWith(notes: 'one\ntwo'),
          d2,
        ],
      );
      await openCell(tester, CellPosition('d1', DiveField.notes.name));

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: 'one!\ntwo'),
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(draftOf(tester, 'd1', DiveField.notes)?.value, 'one!\ntwo');
    });

    testWidgets('a keyboard move carries the paste target with it', (
      tester,
    ) async {
      await pumpSheet(tester, sheetConfig: choiceConfig);
      await tapCell(tester, cell(vis(15)));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final state = containerOf(
        tester,
      ).read(tableEditorDraftsProvider(TableEditorTab.dives));
      expect(state.selected, CellPosition('d2', DiveField.visibility.name));
    });

    testWidgets('Tab follows the columns as shown, pinned first', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        sheetConfig: EntityTableViewConfig<DiveField>(
          columns: [
            EntityTableColumnConfig(field: DiveField.waterType),
            EntityTableColumnConfig(
              field: DiveField.visibility,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: DiveField.notes),
          ],
        ),
      );
      await tapCell(tester, cell(vis(15)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        containerOf(
          tester,
        ).read(tableEditorDraftsProvider(TableEditorTab.dives)).editing,
        waterCell,
      );
    });

    testWidgets('clicking a read-only cell commits and closes the open cell', (
      tester,
    ) async {
      await pumpSheet(tester, sheetConfig: choiceConfig);
      await tapCell(tester, cell(vis(15)));
      await tester.enterText(find.byType(TextField), '12');

      await tapCell(tester, find.text('#2'));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(draftOf(tester, 'd1', DiveField.visibility)?.value, 12.0);
    });

    testWidgets('a deferred commit does not restore an older draft', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        sheetConfig: EntityTableViewConfig<DiveField>(
          columns: [
            EntityTableColumnConfig(field: DiveField.diveNumber),
            EntityTableColumnConfig(field: DiveField.visibility),
            EntityTableColumnConfig(field: DiveField.notes),
          ],
        ),
      );
      TableDraft notes(String value) => TableDraft(
        entityId: 'd1',
        fieldName: DiveField.notes.name,
        original: null,
        value: value,
      );
      notifierOf(tester).put(notes('old'));
      await tester.pump();
      await tapCell(tester, cell(vis(15)));
      await tester.enterText(find.byType(TextField), '12');

      notifierOf(tester)
        ..put(notes('pasted'))
        ..setEditing(null);
      await tester.pump();
      await tester.pump();

      expect(draftOf(tester, 'd1', DiveField.notes)?.value, 'pasted');
      expect(draftOf(tester, 'd1', DiveField.visibility)?.value, 12.0);
    });
  });

  group('imperial diver', () {
    const imperial = AppSettings(depthUnit: DepthUnit.feet);
    String feet(double metres) =>
        const UnitFormatter(imperial).formatDistance(metres);

    testWidgets('Enter on an untouched cell makes no draft', (tester) async {
      await pumpSheet(tester, settings: imperial);
      await tapCell(tester, find.text(feet(15)));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '49.21',
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(draftOf(tester, 'd1', DiveField.visibility), isNull);
    });

    testWidgets('the column header names the unit a cell is typed in', (
      tester,
    ) async {
      await pumpSheet(tester, settings: imperial);

      expect(find.text('Visibility (ft)'), findsOneWidget);
    });
  });

  testWidgets('double tap opens a record from its key column, not from an '
      'editable cell', (tester) async {
    await pumpSheet(tester);

    // The first tap opens the cell, so the second lands on the same spot.
    final editable = tester.getCenter(cell(vis(20)));
    await tester.tapAt(editable);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(editable);
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, isEmpty);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('#2'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.text('#2'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, ['d2']);
  });
}
