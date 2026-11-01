import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
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
  final d1 = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 1, 1),
    visibilityMeters: 15,
  );
  final d2 = Dive(
    id: 'd2',
    diveNumber: 2,
    dateTime: DateTime(2026, 1, 2),
    visibilityMeters: 20,
  );
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

  Future<void> pumpSheet(WidgetTester tester) async {
    final diveRepo = DiveRepository();
    final entity = DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: BulkDiveEditService(
        diveRepo,
        BuddyRepository(),
        SpeciesRepository(),
      ),
      weightsByDive: const {'d1': twoWeights},
      sites: const [],
      centers: const [],
      trips: const [],
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tableEditorDiveConfigProvider.overrideWith(
            (ref) => _TestConfigNotifier(config),
          ),
        ],
        child: SizedBox(
          width: 800,
          height: 400,
          child: TableEditorSheet<Dive, DiveField>(
            tab: TableEditorTab.dives,
            entity: entity,
            rows: [d1, d2],
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
    // d1 has two weight rows: its weight cell shows the placeholder and
    // stays closed.
    final weightCells = find.text('--');
    await tapCell(tester, weightCells.first);

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('double tap calls onOpenRecord', (tester) async {
    await pumpSheet(tester);
    await tester.tap(cell(vis(20)));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(cell(vis(20)));
    await tester.pump();
    // Let the double-tap recognizer's timer run out before the test ends.
    await tester.pump(const Duration(milliseconds: 400));

    expect(opened, ['d2']);
  });
}
