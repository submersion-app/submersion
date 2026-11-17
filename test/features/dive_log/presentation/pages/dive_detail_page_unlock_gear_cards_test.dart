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
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_figure.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

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
    Object? Function()? reloadError,
  }) async {
    final page = await pumpPage(
      tester,
      stored: stored ?? geared,
      reloadError: reloadError,
      visible: shown,
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
  TextButton assign(WidgetTester tester) => tester.widget<TextButton>(
    find.widgetWithText(TextButton, l.diveLog_tank_assignTransmitter),
  );

  // Plan 7: whole-record operations are listed, disabled, while locked.
  testWidgets('locked: no Reassign; Assign shows, disabled; check-in chips '
      'say why they do not open', (tester) async {
    await open(tester);

    expect(find.text(l.diveLog_tank_reassignSeries), findsNothing);
    expect(
      find.text(l.diveLog_tank_assignTransmitter).hitTestable(),
      findsOneWidget,
    );
    expect(assign(tester).onPressed, isNull);
    expect(find.byTooltip(l.recordEdit_unlockToUseThis), findsWidgets);
    final chips = tester.widgetList<ObservationStatusChip>(
      find.byType(ObservationStatusChip),
    );
    expect(chips, isNotEmpty);
    for (final chip in chips) {
      expect(chip.operationReason, l.recordEdit_unlockToUseThis);
    }
  });

  testWidgets('the cylinder menu writes at once, so it follows Assign '
      '(issue #4494)', (tester) async {
    await open(tester);
    final menu = find.byKey(const Key('tank-gear-menu-a'));
    PopupMenuButton<Object?> button() =>
        tester.widget<PopupMenuButton<Object?>>(menu);
    expect(menu.hitTestable(), findsOneWidget);
    expect(button().enabled, isFalse);

    await unlock(tester);
    expect(button().enabled, isTrue);
  });

  // The cards drop the Future their controls' operations return, so a
  // failed read of the dive after one wrote must not escape from it: the
  // page locks, as the sitting's copy is from before the write.
  testWidgets('a card operation whose read back fails locks the page and '
      'throws nothing', (tester) async {
    Object? failure;
    await open(tester, reloadError: () => failure);
    await unlock(tester);
    failure = StateError('database closed');
    final chip = tester.widget<ObservationStatusChip>(
      find.byType(ObservationStatusChip).first,
    );
    final controller = tester
        .widget<RecordEditScope<Dive>>(
          find.byWidgetPredicate((w) => w is RecordEditScope<Dive>).first,
        )
        .notifier!;

    // As the tank menu's unlink does: it wrote, so the dive is read again.
    chip.runAsOperation(() async => true);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(controller.isUnlocked, isFalse);
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

  testWidgets('Assign works in a sitting with no changes only', (tester) async {
    await open(tester);
    await unlock(tester);
    expect(assign(tester).onPressed, isNotNull);

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
      findsOneWidget,
    );
    expect(assign(tester).onPressed, isNull);
    expect(find.byTooltip(l.recordEdit_saveOrCancelFirst), findsWidgets);
  });

  testWidgets('the Cylinders card is the same height locked and unlocked', (
    tester,
  ) async {
    await open(tester);
    final card = find.byKey(const ValueKey('diveSection_tanks'));
    final locked = tester.getSize(card).height;

    await unlock(tester);
    expect(tester.getSize(card).height, locked);
  });

  testWidgets('a reassign held in a sitting moves each series on the closed '
      'Cylinders card, with the pressures', (tester) async {
    // Cylinder a has no pressures of its own: its figure reads its series.
    await open(
      tester,
      stored: geared.copyWith(
        tanks: [
          geared.tanks.first.copyWith(
            clearStartPressure: true,
            clearEndPressure: true,
          ),
          geared.tanks.last,
        ],
      ),
    );
    await unlock(tester);
    final edit = RecordEditScope.maybeOf<Dive>(
      tester.element(find.byType(CylindersCard)),
    )!;

    exchangeTankSeries(edit.session!, 'a', 'b', exchange: (_, _) async {});
    await settle(tester);

    // b now holds a's readings, 200 down to 60, and no pressures of its own.
    final figures = tester
        .widgetList<TankFigure>(find.byType(TankFigure))
        .toList();
    expect(figures, hasLength(2));
    expect(figures.last.endLabel, contains('60'));
  });

  testWidgets('check-in is for gear the dive is stored with: one added in '
      'the sitting shows its state only', (tester) async {
    await open(tester);
    await unlock(tester);
    final edit = RecordEditScope.maybeOf<Dive>(
      tester.element(find.byType(DiveEquipmentSection)),
    )!;
    const mask = EquipmentItem(
      id: 'mask',
      name: 'Mask',
      type: EquipmentType.mask,
    );

    edit.session!.set(diveGearField, const [
      GearLink(item: fins),
      GearLink(item: mask),
    ]);
    await settle(tester);

    final chips = {
      for (final chip in tester.widgetList<ObservationStatusChip>(
        find.descendant(
          of: find.byType(DiveEquipmentSection),
          matching: find.byType(ObservationStatusChip),
        ),
      ))
        chip.equipment.id: chip.readOnly,
    };
    expect(chips, {'fins': false, 'mask': true});
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
