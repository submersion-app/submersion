import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive detail Equipment card renders gear as set bands with collapsed
/// assemblies (issue #1487), and its collapsed summary counts top-level
/// rows rather than every part.
void main() {
  late DiveRepository repository;

  const mask = EquipmentItem(
    id: 'mask',
    name: 'Cressi mask',
    type: EquipmentType.mask,
  );
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jets',
    type: EquipmentType.fins,
  );
  const provenance = [
    GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(
      equipmentId: 'hose',
      viaEquipmentId: 'reg',
      viaSetId: 'winter',
    ),
    GearProvenance(equipmentId: 'fins', viaSetId: 'winter'),
  ];
  final winter = EquipmentSet(
    id: 'winter',
    name: 'Winter kit',
    equipmentIds: const ['reg', 'fins'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> buildDetail() async {
    for (final gear in [mask, reg, hose, fins]) {
      await EquipmentRepository().createEquipment(gear);
    }
    final dive = await repository.createDive(
      Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        notes: '',
        gear: gearLinksFor(const [mask, reg, hose, fins], provenance),
      ),
    );

    final base = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveProvider(dive.id).overrideWith((ref) async => dive),
        equipmentArrangementProvider.overrideWithValue(
          EquipmentArrangement.defaults.copyWith(groupByType: false),
        ),
        equipmentSetsProvider.overrideWith((ref) async => [winter]),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id, embedded: true),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildDetail());
    await tester.pumpAndSettle();
  }

  testWidgets('the section shows the set band and a collapsed assembly', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Winter kit'), findsOneWidget);
    expect(find.textContaining('1 component'), findsOneWidget);
    expect(find.text('Long hose'), findsNothing);
    expect(find.text('Cressi mask'), findsOneWidget);
  });

  testWidgets('the collapsed summary counts top-level rows, not parts', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Equipment'));
    await tester.pumpAndSettle();
    // Four rows on the dive, three of them top-level.
    expect(find.text('3 items'), findsOneWidget);
  });
}
