import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2599: Gas & Gear says what each list is for, and a cylinder picked
/// into a tank from the diver's own gear also joins the dive's equipment.
void main() {
  late DiveRepository repository;
  late EquipmentItem cylinder;
  const regulator = EquipmentItem(
    id: 'eq-reg',
    name: 'Apeks XTX50',
    type: EquipmentType.regulator,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    // Seed without FK enforcement so we don't need a full divers row graph.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
    final equipment = EquipmentRepository();
    await equipment.createEquipment(regulator);
    cylinder = await equipment.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Faber 12',
        type: EquipmentType.tank,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.volumeL,
            valueNum: 12,
          ),
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.workingPressureBar,
            valueNum: 232,
          ),
        ],
      ),
    );
    await repository.createDive(
      Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        notes: '',
        tanks: const [DiveTank(id: 't1', volume: 11.1, workingPressure: 207)],
        gear: looseGear(const [regulator]),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pumpExpanded(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
          activeEquipmentProvider.overrideWith(
            (ref) async => [regulator, cylinder],
          ),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: 'd1', embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(DiveEditPage)));

    // Gas & Gear starts collapsed when editing an existing dive: open it
    // from its group header.
    final header = find.descendant(
      of: find.byType(GasGearSection),
      matching: find.text(l10n.diveLog_edit_group_gasGear),
    );
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('says what the tanks and the equipment are each for', (
    tester,
  ) async {
    final l10n = await pumpExpanded(tester);

    expect(find.text(l10n.diveLog_edit_tanksCaption), findsOneWidget);
    expect(find.text(l10n.diveLog_edit_equipmentCaption), findsOneWidget);
  });

  testWidgets('a gauge dive, which has no tanks, explains neither list', (
    tester,
  ) async {
    final dive = await repository.getDiveById('d1');
    await repository.updateDive(dive!.copyWith(diveMode: DiveMode.gauge));
    final l10n = await pumpExpanded(tester);

    // The equipment caption sends the diver to Tanks, which a gauge dive
    // does not show.
    expect(find.text(l10n.diveLog_edit_tanksCaption), findsNothing);
    expect(find.text(l10n.diveLog_edit_equipmentCaption), findsNothing);
  });

  testWidgets('a cylinder picked into a tank fills it and joins the '
      'equipment list', (tester) async {
    final l10n = await pumpExpanded(tester);
    expect(find.text('Faber 12'), findsNothing);

    await tester.ensureVisible(find.byType(TankRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TankRow));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('tank-from-own-cylinder'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faber 12'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    // Listed once, in the equipment list: the tank does not link to it.
    expect(find.text('Faber 12'), findsOneWidget);

    // The tank took the cylinder's size: its collapsed row reads 12 L, not
    // the 11.1 L it was saved with.
    final done = find.text(l10n.diveLog_edit_tankCard_done);
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.textContaining('12 L'), findsOneWidget);
    expect(find.textContaining('11.1 L'), findsNothing);
  });
}
