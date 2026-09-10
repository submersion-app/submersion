import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive edit gear list renders as set bands with collapsed assemblies
/// (issue #1487); removing a band, an assembly or one part edits the
/// provenance, and the saved dive carries it.
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

  Future<Widget> buildEditor() async {
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
        diveListNotifierProvider.overrideWith(
          (ref) => DiveListNotifier(repository, ref),
        ),
        customTankPresetsProvider.overrideWith((ref) async => []),
        equipmentArrangementProvider.overrideWithValue(
          EquipmentArrangement.defaults.copyWith(groupByType: false),
        ),
        equipmentSetsProvider.overrideWith((ref) async => [winter]),
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
  /// collapsed when editing an existing dive. Its summary counts top-level
  /// rows: four on the dive, three of them top-level.
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

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    final target = find.byTooltip(tooltip);
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the list shows the set band and a collapsed assembly', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Winter kit'), findsOneWidget);
    expect(find.textContaining('1 component'), findsOneWidget);
    expect(find.text('Long hose'), findsNothing);
  });

  testWidgets('removing an assembly removes its parts too', (tester) async {
    await open(tester);
    await tapTooltip(tester, 'Remove assembly and its parts');
    expect(find.text('Cold water reg'), findsNothing);
    expect(find.byTooltip('Show parts'), findsNothing);

    await save(tester);
    final saved = await repository.getDiveById('dive-1');
    expect(
      saved!.gear.map((g) => g.item.id),
      unorderedEquals(['mask', 'fins']),
    );
  });

  testWidgets('removing a set band removes every row that came from it', (
    tester,
  ) async {
    await open(tester);
    await tapTooltip(tester, 'Remove set from this dive');
    expect(find.text('Winter kit'), findsNothing);
    expect(find.text('Jets'), findsNothing);
    expect(find.text('Cressi mask'), findsOneWidget);
  });

  testWidgets('removing one part keeps the assembly and the provenance', (
    tester,
  ) async {
    await open(tester);
    await tapTooltip(tester, 'Show parts');
    await tapTooltip(tester, 'Remove part');
    expect(find.text('Long hose'), findsNothing);
    expect(find.text('Cold water reg'), findsOneWidget);

    await save(tester);
    final saved = await repository.getDiveById('dive-1');
    expect(
      saved!.gear.map((g) => g.item.id),
      unorderedEquals(['mask', 'reg', 'fins']),
    );
    expect(saved.gear.firstWhere((g) => g.item.id == 'reg').viaSetId, 'winter');
    expect(
      saved.gear.firstWhere((g) => g.item.id == 'fins').viaSetId,
      'winter',
    );
  });
}
