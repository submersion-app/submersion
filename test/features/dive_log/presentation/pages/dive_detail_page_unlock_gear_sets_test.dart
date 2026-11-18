import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/set_bundle_loader.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Stands in for the diver's sets: records each set made, and answers the
/// list with them.
class _Sets extends StateNotifier<AsyncValue<List<EquipmentSet>>>
    implements EquipmentSetListNotifier {
  _Sets(List<EquipmentSet> initial) : super(AsyncValue.data(initial));

  final added = <EquipmentSet>[];

  @override
  Future<EquipmentSet> addSet(EquipmentSet set) async {
    added.add(set);
    state = AsyncValue.data([...?state.value, set]);
    return set;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No set the dive starts with includes another.
class _Loader implements SetBundleLoader {
  @override
  Future<List<SetBundle>> load(List<String> setIds) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Equipment sets on the dive page during a sitting: a set saved from the
/// gear is a record of its own, and a set used fills three cards that one
/// Save writes and one Cancel takes back (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9);
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  const wing = EquipmentItem(
    id: 'wing',
    name: 'Wing',
    type: EquipmentType.wing,
  );
  final warm = EquipmentSet(
    id: 'warm',
    name: 'Warm water',
    equipmentIds: const ['wing'],
    items: const [wing],
    createdAt: t0,
    updatedAt: t0,
  );
  // What the set carries besides its gear: a weight and a cylinder.
  final bundle = SetBundle(
    setId: 'warm',
    gearIds: const ['wing'],
    weights: const [
      (weightType: WeightType.integrated, amountKg: 4.0, notes: '', label: ''),
    ],
    cylinders: [
      CylinderConfigItem(
        id: 'c1',
        configId: 'cfg',
        tankRole: TankRole.backGas,
        volumeL: 11.1,
        workingPressureBar: 207,
        createdAt: t0,
        updatedAt: t0,
      ),
    ],
  );
  // Gear only: the set's weights and cylinders then go on with no question.
  final geared = dive.copyWith(gear: const [GearLink(item: fins)]);
  const shown = {
    DiveDetailSectionId.tanks,
    DiveDetailSectionId.weights,
    DiveDetailSectionId.equipment,
    DiveDetailSectionId.notes,
  };

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<FakeSave> open(WidgetTester tester, _Sets sets) async {
    final page = await pumpPage(
      tester,
      stored: geared,
      visible: shown,
      size: const Size(700, 2600),
      extra: <Override>[
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        equipmentSetListNotifierProvider.overrideWith((ref) => sets),
        equipmentSetsProvider.overrideWith((ref) async => [warm]),
        setBundleProvider('warm').overrideWith((ref) async => bundle),
        setBundleLoaderProvider.overrideWithValue(_Loader()),
      ],
    );
    await settle(tester);
    return page.save;
  }

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        tester.element(find.byType(RecordCardFrame<Dive>).first),
      )!;

  Finder dotOn(String cardId) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is RecordCardFrame<Dive> && w.card.id == cardId,
    ),
    matching: find.byType(RecordChangedDot),
  );

  Future<void> openEquipment(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit Equipment'));
    await settle(tester);
    expect(find.byType(DiveEquipmentCardEditor), findsOneWidget);
  }

  testWidgets('Save as set creates the set at once, and it survives '
      'Cancel', (tester) async {
    final sets = _Sets([warm]);
    final save = await open(tester, sets);
    await unlock(tester);
    await openEquipment(tester);

    await tester.tap(find.text(l.diveLog_edit_saveAsSet));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, l.diveLog_edit_saveAsSetDialog_setName),
      'Cold water',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l.diveLog_edit_save).last,
    );
    await settle(tester);

    // Made at once, while the sitting is still open.
    expect(sets.added.single.name, 'Cold water');
    expect(sets.added.single.equipmentIds, ['fins']);
    final c = controllerOf(tester);
    expect(c.isUnlocked, isTrue);
    expect(save.calls, isEmpty);

    // A change of the sitting's own, then Cancel discards it.
    await tester.tap(find.text(l.diveLog_edit_clearAllEquipment));
    await settle(tester);
    expect(c.session!.working.gear, isEmpty);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(c.isUnlocked, isFalse);
    expect(save.calls, isEmpty);
    expect(sets.added.single.name, 'Cold water');
    expect(find.text('Fins'), findsWidgets);
  });

  /// Uses [warm] from the Equipment card's set picker, letting the reads it
  /// makes run on the real clock, then closes the card.
  Future<void> useWarm(WidgetTester tester) async {
    await unlock(tester);
    await openEquipment(tester);
    await tester.tap(find.text(l.diveLog_edit_useSet));
    await settle(tester);
    final sheet = tester.widget<EquipmentSetPickerSheet>(
      find.byType(EquipmentSetPickerSheet),
    );
    final session = controllerOf(tester).session!;
    // Started on the real clock, where its database reads answer. Waiting
    // for the sitting's tracked work inside runAsync does not end here, so
    // the test waits for the cylinders to arrive, a frame at a time, for
    // up to ten seconds of real time, room for a loaded CI runner.
    await tester.runAsync(() async {
      sheet.onSetSelected(warm, const [wing]);
    });
    for (var i = 0; i < 500 && session.working.tanks.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
  }

  testWidgets('a set used brings gear, weights and cylinders: each card '
      'gets its dot, and Cancel undoes all of it', (tester) async {
    final save = await open(tester, _Sets([warm]));
    await useWarm(tester);

    final w = controllerOf(tester).session!.working;
    expect(
      [for (final g in w.gear) (g.item.id, g.viaSetId)],
      [('fins', null), ('wing', 'warm')],
    );
    expect(w.weights.single.amountKg, 4);
    expect(w.tanks.single.volume, 11.1);
    expect(dotOn('equipment'), findsOneWidget);
    expect(dotOn('weights'), findsOneWidget);
    expect(dotOn('tanks'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(controllerOf(tester).isUnlocked, isFalse);
    expect(save.calls, isEmpty);
    expect(find.byType(RecordChangedDot), findsNothing);
    expect(find.text('Wing'), findsNothing);
    // The dive as stored has no weights and no cylinders: their cards go.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RecordCardFrame<Dive> &&
            (w.card.id == 'weights' || w.card.id == 'tanks'),
      ),
      findsNothing,
    );
  });

  testWidgets('a set used is one Save, naming Equipment, Weight and '
      'Cylinders', (tester) async {
    final save = await open(tester, _Sets([warm]));
    await useWarm(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    // One call of the save service is one History entry (#4527).
    final saved = save.calls.single;
    expect(saved.cards.toSet(), {'equipment', 'weights', 'tanks'});
    expect(saved.cards, hasLength(3));
    expect([for (final g in saved.merged.gear) g.item.id], ['fins', 'wing']);
    expect(saved.merged.weights.single.amountKg, 4);
    expect(saved.merged.tanks.single.volume, 11.1);
    expect(find.text('Save'), findsNothing);
  });
}
