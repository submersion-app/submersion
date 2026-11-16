import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_sitting_follow_up.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

class _Writer implements DiverGasSwitchWriter {
  final saved = <List<GasSwitch>>[];

  @override
  Future<bool> save({
    required String diveId,
    required List<GasSwitch> switches,
    required Set<String> loadedIds,
    bool edited = true,
    DateTime? now,
  }) async {
    saved.add(switches);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The Cylinders, Equipment and Weight cards edited in place on the dive
/// page, end to end through one Save (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2023, 1, 1, 9);
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  const back = DiveTank(
    id: 'a',
    volume: 12,
    startPressure: 200,
    endPressure: 60,
  );
  const deco = DiveTank(
    id: 'b',
    volume: 7,
    startPressure: 200,
    endPressure: 150,
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
    order: 1,
  );
  final geared = dive.copyWith(
    dateTime: t0,
    entryTime: t0,
    runtime: const Duration(minutes: 50),
    tanks: const [back, deco],
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
    DiveDetailSectionId.notes,
  };

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<FakeSave> open(
    WidgetTester tester, {
    Dive? stored,
    bool imperial = false,
    List<Override> extra = const [],
  }) async {
    final page = await pumpPage(
      tester,
      stored: stored ?? geared,
      visible: shown,
      imperial: imperial,
      size: const Size(700, 2600),
      extra: extra,
    );
    await settle(tester);
    return page.save;
  }

  /// [stored] in the test database, without its gear (no equipment rows),
  /// with one switch on the deco cylinder at 40 minutes: what the sitting
  /// reads as it starts.
  Future<Dive> seedWithSwitch(WidgetTester tester, Dive stored) async {
    final inDb = stored.copyWith(gear: const <GearLink>[]);
    await tester.runAsync(() async {
      await DiveRepository().createDive(inDb);
      await DiverGasSwitchWriter().save(
        diveId: inDb.id,
        switches: [
          GasSwitch(
            id: 'g',
            diveId: inDb.id,
            timestamp: 2400,
            tankId: 'b',
            createdAt: t0,
          ),
        ],
        loadedIds: const {},
      );
    });
    return inDb;
  }

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        // Any card on the page: every one is framed under the scope.
        tester.element(find.byType(RecordCardFrame<Dive>).first),
      )!;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  testWidgets('each card has a pencil and opens where it sits', (tester) async {
    await open(tester);
    await unlock(tester);

    await tester.tap(find.byTooltip('Edit Cylinders'));
    await tester.tap(find.byTooltip('Edit Weight'));
    await tester.tap(find.byTooltip('Edit Equipment'));
    await settle(tester);

    expect(find.byType(DiveTanksCardEditor), findsOneWidget);
    expect(find.byType(DiveWeightsCardEditor), findsOneWidget);
    expect(find.byType(DiveEquipmentCardEditor), findsOneWidget);
  });

  testWidgets('opening and closing all three in imperial units leaves the '
      'sitting clean', (tester) async {
    await open(tester, imperial: true);
    await unlock(tester);
    final c = controllerOf(tester);
    for (final id in ['tanks', 'weights', 'equipment']) {
      c.openCard(id);
    }
    await settle(tester);
    for (final id in ['tanks', 'weights', 'equipment']) {
      c.closeCard(id);
    }
    await settle(tester);

    expect(c.isDirty, isFalse);
  });

  testWidgets('a CCR mode saved, and an OC mode saved over a CCR dive drops '
      'its setpoints', (tester) async {
    final ccr = geared.copyWith(
      diveMode: DiveMode.ccr,
      setpointLow: 0.7,
      setpointHigh: 1.3,
      loopVolume: 6,
    );
    final save = await open(tester, stored: ccr);
    await unlock(tester);
    await tester.tap(find.byTooltip('Edit Cylinders'));
    await settle(tester);

    await tester.tap(find.text('OC'));
    await settle(tester);
    await tapSave(tester);

    final merged = save.calls.single.merged;
    expect(merged.diveMode, DiveMode.oc);
    expect(
      (merged.setpointLow, merged.setpointHigh, merged.loopVolume),
      (null, null, null),
    );
    expect(save.calls.single.cards, ['tanks']);
  });

  testWidgets('a stored switch is checked though Cylinders was never '
      'opened: a runtime shortened past it refuses Save', (tester) async {
    final bare = await seedWithSwitch(
      tester,
      geared.copyWith(profile: const []),
    );
    final save = await open(tester, stored: bare);
    await unlock(tester);
    final s = controllerOf(tester).session!;
    await tester.runAsync(s.settled);
    s.set(diveRuntimeField, 1800.0);
    await settle(tester);

    await tapSave(tester);

    expect(save.calls, isEmpty);
    expect(find.byType(DiveTanksCardEditor), findsOneWidget);
    expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
  });

  testWidgets('a switch stored past the end does not stop Done on Cylinders '
      'or a Save of the notes', (tester) async {
    // The seeded switch is at 40 minutes, on a dive stored as 30.
    final short = await seedWithSwitch(
      tester,
      geared.copyWith(profile: const [], runtime: const Duration(minutes: 30)),
    );
    final save = await open(tester, stored: short);
    await unlock(tester);
    final s = controllerOf(tester).session!;
    await tester.runAsync(s.settled);

    await tester.tap(find.byTooltip('Edit Cylinders'));
    await settle(tester);
    expect(find.text('Must be within the dive'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(DiveTanksCardEditor), findsNothing);

    s.set(diveNotesField, 'Strong current at the wall');
    await settle(tester);
    await tapSave(tester);

    expect(save.calls, hasLength(1));
    expect(save.calls.single.merged.notes, 'Strong current at the wall');
  });

  testWidgets('a cylinder removed with a switch and an exchange on it saves '
      'without the switch', (tester) async {
    final writer = _Writer();
    final stored = await seedWithSwitch(tester, geared);
    final save = await open(
      tester,
      stored: stored,
      extra: [diveGasSwitchWriterProvider.overrideWithValue(() => writer)],
    );
    await unlock(tester);
    final s = controllerOf(tester).session!;
    await tester.runAsync(s.settled);
    expect(sittingGasSwitches(s)!.current, hasLength(1));
    exchangeTankSeries(s, 'a', 'b', exchange: (x, y) async {});
    removeSittingTank(s, 'b');
    await settle(tester);

    await tapSave(tester);

    expect(save.calls, hasLength(1));
    expect(save.calls.single.merged.tanks.map((t) => t.id), ['a']);
    expect(writer.saved.single, isEmpty);
  });

  testWidgets('a save whose held writes are the dive\'s own (switches, a '
      'reassign) does not read the site list again', (tester) async {
    final writer = _Writer();
    SpySites? sites;
    final stored = await seedWithSwitch(tester, geared);
    await open(
      tester,
      stored: stored,
      extra: [
        diveGasSwitchWriterProvider.overrideWithValue(() => writer),
        siteListNotifierProvider.overrideWith(
          (ref) => sites = SpySites(ref.watch(siteRepositoryProvider), ref),
        ),
      ],
    );
    await unlock(tester);
    final s = controllerOf(tester).session!;
    await tester.runAsync(s.settled);
    exchangeTankSeries(s, 'a', 'b', exchange: (x, y) async {});
    removeGasSwitch(s, 'g');
    await settle(tester);

    await tapSave(tester);

    expect(writer.saved, hasLength(1));
    expect(sites?.refreshes ?? 0, 0);
  });

  testWidgets('a weight and the gear changed: one save names both cards', (
    tester,
  ) async {
    final save = await open(tester);
    await unlock(tester);
    final s = controllerOf(tester).session!;
    s
      ..set(diveWeightsField, const <DiveWeight>[])
      ..set(diveGearField, const <GearLink>[]);
    await settle(tester);

    await tapSave(tester);

    expect(save.calls.single.cards.toSet(), {'weights', 'equipment'});
    expect(save.calls.single.merged.tanks, geared.tanks);
  });

  testWidgets('a refresh that throws after the write is not a failed save', (
    tester,
  ) async {
    final save = await open(
      tester,
      extra: [
        diveGearRefreshProvider.overrideWithValue(
          (_) => throw StateError('scheduler gone'),
        ),
      ],
    );
    await unlock(tester);
    controllerOf(tester).session!.set(diveWeightsField, const <DiveWeight>[]);
    await settle(tester);

    await tapSave(tester);

    expect(save.calls, hasLength(1));
    expect(find.text(l.recordEdit_saveFailed), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('a save that changed cylinders, gear or weights refreshes what '
      'they feed; one that changed none does not', (tester) async {
    final refreshed = <String>[];
    await open(
      tester,
      extra: [diveGearRefreshProvider.overrideWithValue(refreshed.add)],
    );
    await unlock(tester);
    controllerOf(tester).session!.set(diveWeightsField, const <DiveWeight>[]);
    await settle(tester);
    await tapSave(tester);
    expect(refreshed, ['dive-1']);

    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).last, 'Changed');
    await settle(tester);
    await tapSave(tester);
    expect(refreshed, ['dive-1']);
  });

  testWidgets('a locked page makes no write on any tap in the three cards', (
    tester,
  ) async {
    final save = await open(tester);

    for (final finder in [
      find.byType(CylindersCard),
      find.text(l.diveLog_detail_section_weight),
    ]) {
      await tester.tap(finder.first, warnIfMissed: false);
      await settle(tester);
    }

    expect(save.calls, isEmpty);
    expect(find.byType(DiveTanksCardEditor), findsNothing);
  });
}
