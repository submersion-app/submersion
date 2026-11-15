import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_equipment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_weight_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

import 'dive_detail_page_unlock_harness.dart';

/// The Cylinders, Equipment and Weight cards on the dive page: their
/// pencils, and no control that writes while locked (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  final geared = dive.copyWith(
    tanks: const [
      DiveTank(
        id: 'a',
        volume: 12,
        startPressure: 200,
        endPressure: 60,
        transmitterSerial: '111',
        computerId: 'c',
      ),
      DiveTank(
        id: 'b',
        volume: 7,
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 50),
        order: 1,
        computerId: 'c',
      ),
    ],
    weights: const [
      DiveWeight(
        id: 'w',
        diveId: 'dive-1',
        weightType: WeightType.belt,
        amountKg: 6,
      ),
    ],
    gear: const [GearLink(item: fins)],
  );
  const shown = {
    DiveDetailSectionId.tanks,
    DiveDetailSectionId.weights,
    DiveDetailSectionId.equipment,
  };
  final pressures = {
    'a': const [
      TankPressurePoint(tankId: 'a', timestamp: 0, pressure: 200),
      TankPressurePoint(tankId: 'a', timestamp: 600, pressure: 60),
    ],
    'b': const [TankPressurePoint(tankId: 'b', timestamp: 0, pressure: 200)],
  };

  Future<FakeSave> open(
    WidgetTester tester, {
    Dive? stored,
    bool unlockEditing = true,
  }) async {
    final page = await pumpPage(
      tester,
      stored: stored ?? geared,
      visible: shown,
      unlockEditing: unlockEditing,
      size: const Size(700, 2400),
      extra: [
        tankPressuresProvider(dive.id).overrideWith((ref) async => pressures),
      ],
    );
    await settle(tester);
    return page.save;
  }

  double heightOf(WidgetTester tester, Type card) =>
      tester.getSize(find.byType(card).first).height;

  testWidgets('editing off: the cards as before, with Reassign', (
    tester,
  ) async {
    await open(tester, unlockEditing: false);

    expect(find.byType(CylindersCard), findsOneWidget);
    expect(find.byType(DiveWeightSection), findsOneWidget);
    expect(find.byType(DiveEquipmentSection), findsOneWidget);
    expect(find.text(l.diveLog_tank_reassignSeries), findsOneWidget);
  });

  testWidgets('locked: no Reassign, no Assign, check-in chips do not open', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(l.diveLog_tank_reassignSeries), findsNothing);
    expect(
      find.text(l.diveLog_tank_assignTransmitter).hitTestable(),
      findsNothing,
    );
    for (final chip in tester.widgetList<ObservationStatusChip>(
      find.byType(ObservationStatusChip),
    )) {
      expect(chip.readOnly, isTrue);
    }
  });

  testWidgets('locked: Sort still opens its sheet', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip(l.equipment_list_sortTooltip).first);
    await settle(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('unlocked: a pencil on each title row, and no card changes '
      'height', (tester) async {
    await open(tester);
    final before = [
      heightOf(tester, CylindersCard),
      heightOf(tester, DiveWeightSection),
      heightOf(tester, DiveEquipmentSection),
    ];

    await unlock(tester);

    for (final card in [
      CylindersCard,
      DiveWeightSection,
      DiveEquipmentSection,
    ]) {
      expect(
        find.descendant(
          of: find.byType(card),
          matching: find.byType(RecordPencilIcon),
        ),
        findsOneWidget,
        reason: '$card',
      );
    }
    expect([
      heightOf(tester, CylindersCard),
      heightOf(tester, DiveWeightSection),
      heightOf(tester, DiveEquipmentSection),
    ], before);
  });

  testWidgets('the Cylinders pencil opens the card where it sits', (
    tester,
  ) async {
    await open(tester);
    await unlock(tester);
    final top = tester.getTopLeft(find.byType(CylindersCard)).dy;

    await tester.tap(
      find.descendant(
        of: find.byType(CylindersCard),
        matching: find.byType(RecordPencilIcon),
      ),
    );
    await settle(tester);

    expect(find.byType(DiveTanksCardEditor), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(DiveTanksCardEditor)).dy,
      greaterThan(top),
    );
  });

  testWidgets('Assign shows in a sitting with no changes only', (tester) async {
    await open(tester);
    await unlock(tester);
    expect(
      find.text(l.diveLog_tank_assignTransmitter).hitTestable(),
      findsOneWidget,
    );

    // A change on another card: a weight added.
    await tester.tap(
      find.descendant(
        of: find.byType(DiveWeightSection),
        matching: find.byType(RecordPencilIcon),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(l.diveLog_edit_addWeightEntry));
    await settle(tester);

    expect(
      find.text(l.diveLog_tank_assignTransmitter).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('a gauge dive: Cylinders is in the strip, and opens with the '
      'mode alone', (tester) async {
    await open(tester, stored: geared.copyWith(diveMode: DiveMode.gauge));
    expect(find.byType(CylindersCard), findsNothing);

    await unlock(tester);
    await tapStripChip(tester, 'tanks');
    await settle(tester);

    expect(find.byType(DiveTanksCardEditor), findsOneWidget);
    expect(find.byType(DiveModeSelector), findsOneWidget);
  });
}
