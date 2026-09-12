import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive edit gear list renders arranged, which is what makes removal by
/// display index wrong: the render index no longer addresses the same item, so
/// tapping one row's X silently dropped a different piece of gear.
void main() {
  late DiveRepository repository;

  // Head to toe rather than the default alphabetical, because the repository
  // now loads a dive's gear ordered by (type, name) and that happens to match
  // the alphabetical arrangement exactly. Under head to toe the backing list
  // (Zeagle, Apeks, Faber) and the rendered order (Faber, Apeks, Zeagle) are
  // reverses of each other, which is what makes an index-addressed removal
  // observably wrong.
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
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> buildEditor() async {
    for (final gear in [zeagle, faber, apeks]) {
      await EquipmentRepository().createEquipment(gear);
    }
    final dive = await repository.createDive(
      Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        notes: '',
        gear: looseGear(const [zeagle, faber, apeks]),
      ),
    );

    final base = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith(
          (ref) => DiveListNotifier(repository, ref),
        ),
        customTankPresetsProvider.overrideWith((ref) async => []),
        equipmentArrangementProvider.overrideWithValue(headToToe),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DiveEditPage(diveId: dive.id, embedded: true)),
      ),
    );
  }

  /// The equipment section lives inside the Gas & Gear group, which starts
  /// collapsed when editing an existing dive.
  Future<void> expandGasGear(WidgetTester tester) async {
    final summary = find.textContaining('3 items');
    await tester.ensureVisible(summary.first);
    await tester.pumpAndSettle();
    await tester.tap(summary.first);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildEditor());
    await tester.pumpAndSettle();
    await expandGasGear(tester);
  }

  testWidgets('the gear list renders grouped by type', (tester) async {
    await open(tester);

    final headers = tester
        .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
        .map((h) => h.type)
        .toList();

    expect(headers, [
      EquipmentType.tank,
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
  });

  testWidgets('the Sort action opens the gear sort sheet', (tester) async {
    await open(tester);

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Equipment'), findsOneWidget);
    expect(find.text('Order types by'), findsOneWidget);
  });

  testWidgets('removing a row removes the tapped item, not its index', (
    tester,
  ) async {
    await open(tester);

    // Faber renders FIRST under head to toe but is LAST in the backing list,
    // so removing by render index would drop Zeagle instead.
    final removeFaber = find.descendant(
      of: find.ancestor(
        of: find.text('Faber'),
        matching: find.byType(ListTile),
      ),
      matching: find.byTooltip('Remove equipment'),
    );
    await tester.ensureVisible(removeFaber);
    await tester.pumpAndSettle();
    await tester.tap(removeFaber);
    await tester.pumpAndSettle();

    expect(find.text('Faber'), findsNothing);
    expect(find.text('Zeagle'), findsOneWidget);
    expect(find.text('Apeks'), findsOneWidget);
  });
}
