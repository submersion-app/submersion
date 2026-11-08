import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The bulk editor's gear list follows the diver's gear arrangement, with
/// the same Sort action as the single-dive gear list (#2274). It used to be
/// alphabetical only, with newly added gear at the bottom.

/// Stands in for the diver's saved arrangement, so a test can change it
/// while the editor is open, as picking a sort in the sheet does.
final _arrangement = StateProvider<EquipmentArrangement>(
  (ref) => EquipmentArrangement.defaults,
);

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  // Head to toe rather than the default alphabetical, so the arranged order
  // (Faber, Apeks, Zeagle) differs from the alphabetical one the list used
  // to show (Apeks, Faber, Zeagle).
  const headToToe = EquipmentArrangement(
    typeOrder: EquipmentTypeOrder.headToToe,
    groupByType: true,
    itemSortField: EquipmentItemSortField.name,
    itemSortDirection: SortDirection.ascending,
  );
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const apeks = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed({required List<EquipmentItem> onFirstDive}) async {
    for (final gear in [zeagle, faber, apeks]) {
      await EquipmentRepository().createEquipment(gear);
    }
    for (final id in ['d1', 'd2']) {
      await repository.createDive(
        Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
      );
    }
    await repository.bulkAddEquipment(
      ['d1'],
      [for (final gear in onFirstDive) gear.id],
    );
  }

  Future<void> pump(
    WidgetTester tester,
    EquipmentArrangement arrangement,
  ) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          _arrangement.overrideWith((ref) => arrangement),
          equipmentArrangementProvider.overrideWith(
            (ref) => ref.watch(_arrangement),
          ),
        ],
        child: const DiveEditPage(bulkDiveIds: ['d1', 'd2'], embedded: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder gearEditor() => find.ancestor(
    of: find.text('Equipment'),
    matching: find.byType(BulkMembershipEditor),
  );

  Finder inGearEditor(Finder finder) =>
      find.descendant(of: gearEditor(), matching: finder);

  /// The gear names in the order they appear down the list.
  List<String> rowOrder(WidgetTester tester, List<String> names) {
    final sorted = [...names]
      ..sort(
        (a, b) => tester
            .getTopLeft(inGearEditor(find.text(a)))
            .dy
            .compareTo(tester.getTopLeft(inGearEditor(find.text(b))).dy),
      );
    return sorted;
  }

  testWidgets('the gear rows follow the arrangement under type headings', (
    tester,
  ) async {
    await seed(onFirstDive: const [zeagle, faber, apeks]);
    await pump(tester, headToToe);

    expect(rowOrder(tester, ['Apeks', 'Faber', 'Zeagle']), [
      'Faber',
      'Apeks',
      'Zeagle',
    ]);
    final headings = tester
        .widgetList<EquipmentGroupHeader>(
          inGearEditor(find.byType(EquipmentGroupHeader)),
        )
        .map((h) => h.type)
        .toList();
    expect(headings, [
      EquipmentType.tank,
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
  });

  testWidgets('without grouping the rows are sorted and carry no headings', (
    tester,
  ) async {
    await seed(onFirstDive: const [zeagle, faber, apeks]);
    await pump(
      tester,
      headToToe.copyWith(
        typeOrder: EquipmentTypeOrder.none,
        groupByType: false,
        itemSortDirection: SortDirection.descending,
      ),
    );

    expect(rowOrder(tester, ['Apeks', 'Faber', 'Zeagle']), [
      'Zeagle',
      'Faber',
      'Apeks',
    ]);
    expect(inGearEditor(find.byType(EquipmentGroupHeader)), findsNothing);
  });

  testWidgets('the Sort action opens the gear sort sheet', (tester) async {
    await seed(onFirstDive: const [faber]);
    await pump(tester, headToToe);

    // Icon only: a third labelled button beside Use Set and Add would squeeze
    // the section title on a phone.
    final sort = inGearEditor(find.byTooltip('Sort'));
    await tester.ensureVisible(sort);
    await tester.tap(sort);
    await tester.pumpAndSettle();

    expect(find.text('Sort Equipment'), findsOneWidget);
    expect(find.text('Order types by'), findsOneWidget);
  });

  testWidgets('added gear takes its sorted place, not the bottom', (
    tester,
  ) async {
    await seed(onFirstDive: const [zeagle, faber]);
    await pump(tester, headToToe);

    final add = inGearEditor(find.widgetWithText(TextButton, 'Add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apeks'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1'));
    await tester.pumpAndSettle();

    expect(rowOrder(tester, ['Apeks', 'Faber', 'Zeagle']), [
      'Faber',
      'Apeks',
      'Zeagle',
    ]);
    // The new row is still an add to every selected dive.
    final apeksRow = find.ancestor(
      of: inGearEditor(find.text('Apeks')),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: apeksRow, matching: find.textContaining('adding')),
      findsOneWidget,
    );
  });

  // Picking a new sort in the sheet changes the shared setting while the
  // editor is open. The list follows it, and each row keeps its choice.
  testWidgets('a sort changed mid-edit re-sorts and keeps every choice', (
    tester,
  ) async {
    await seed(onFirstDive: const [zeagle, faber, apeks]);
    await pump(tester, headToToe);

    final toggle = find.byKey(const ValueKey('membership-toggle-bcd-1'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    ProviderScope.containerOf(
      tester.element(gearEditor()),
    ).read(_arrangement.notifier).state = headToToe.copyWith(
      typeOrder: EquipmentTypeOrder.none,
      groupByType: false,
      itemSortDirection: SortDirection.descending,
    );
    await tester.pumpAndSettle();

    expect(rowOrder(tester, ['Apeks', 'Faber', 'Zeagle']), [
      'Zeagle',
      'Faber',
      'Apeks',
    ]);
    expect(inGearEditor(find.byType(EquipmentGroupHeader)), findsNothing);
    final zeagleRow = find.ancestor(
      of: inGearEditor(find.text('Zeagle')),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: zeagleRow, matching: find.textContaining('adding')),
      findsOneWidget,
    );
  });
}
