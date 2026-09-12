import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive detail Equipment card renders through the diver's arrangement
/// (#1486, #1576) rather than the raw join order.
void main() {
  late DiveRepository repository;

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
  const aqualung = EquipmentItem(
    id: 'reg-2',
    name: 'Aqualung',
    type: EquipmentType.regulator,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> buildDetail(EquipmentArrangement arrangement) async {
    for (final gear in [zeagle, faber, apeks, aqualung]) {
      await EquipmentRepository().createEquipment(gear);
    }
    final dive = await repository.createDive(
      Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        notes: '',
        gear: looseGear(const [zeagle, faber, apeks, aqualung]),
      ),
    );

    final base = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveProvider(dive.id).overrideWith((ref) async => dive),
        equipmentArrangementProvider.overrideWithValue(arrangement),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id, embedded: true),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    required EquipmentArrangement arrangement,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildDetail(arrangement));
    await tester.pumpAndSettle();
  }

  testWidgets('renders a header per type, in the chosen type order', (
    tester,
  ) async {
    await open(
      tester,
      arrangement: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );

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

  testWidgets('renders no headers when grouping is off', (tester) async {
    await open(
      tester,
      arrangement: EquipmentArrangement.defaults.copyWith(groupByType: false),
    );

    expect(find.byType(EquipmentGroupHeader), findsNothing);
    expect(find.text('Zeagle'), findsOneWidget);
  });

  testWidgets('orders items within a group by the chosen field', (
    tester,
  ) async {
    await open(
      tester,
      arrangement: EquipmentArrangement.defaults.copyWith(
        itemSortDirection: SortDirection.descending,
      ),
    );

    // Descending name inside the Regulator group puts Aqualung above Apeks.
    expect(
      tester.getTopLeft(find.text('Aqualung')).dy,
      lessThan(tester.getTopLeft(find.text('Apeks')).dy),
    );
  });

  testWidgets('the header Sort action opens the gear sort sheet', (
    tester,
  ) async {
    await open(tester, arrangement: EquipmentArrangement.defaults);

    // The same Sort control the Equipment page offers.
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Equipment'), findsOneWidget);
    expect(find.text('Order types by'), findsOneWidget);
  });
}
