import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/data_quality/domain/detectors/missing_gas_switches.dart';
import 'package:submersion/features/dive_log/presentation/providers/detected_gas_switches_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Cylinders card of the dive page, edited in place (issue #4527,
/// plan 5).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9, 9);
  const back = DiveTank(
    id: 'a',
    volume: 12,
    workingPressure: 232,
    startPressure: 200,
    endPressure: 60,
    gasMix: GasMix(o2: 32),
  );
  const deco = DiveTank(
    id: 'b',
    volume: 7,
    startPressure: 200,
    endPressure: 140,
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
    order: 1,
  );
  final oc = Dive(id: 'dive', dateTime: t0, entryTime: t0, tanks: const [back]);
  final twoGas = oc.copyWith(
    tanks: const [back, deco],
    runtime: const Duration(minutes: 50),
  );
  final ccr = oc.copyWith(
    diveMode: DiveMode.ccr,
    setpointLow: 0.7,
    setpointHigh: 1.3,
    setpointDeco: 1.4,
    diluentGas: const GasMix(o2: 21),
    scrubber: const ScrubberInfo(type: 'Sofnolime', ratedMinutes: 180),
    loopVolume: 6.5,
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pumpEditor(
    WidgetTester tester,
    Dive dive, {
    AppSettings settings = const AppSettings(),
    List<GasSwitch> switches = const [],
    Map<String, List<TankPressurePoint>> pressures = const {},
    List<CylinderConfig> configs = const [],
    MissedSwitches? detected,
  }) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller =
        RecordEditController<Dive>(
            onSave: (_) async {},
            invalidCards: (s) => [if (!gasSwitchesValid(s)) 'tanks'],
          )
          ..unlock(dive)
          ..openCard('tanks');
    addTearDown(controller.dispose);
    // The switches the editor loads, as if read from the database.
    loadGasSwitches(
      controller.session!,
      read: () async => switches,
      writer: _NoWriter.new,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(settings),
          ),
          tankPressuresProvider(dive.id).overrideWith((ref) async => pressures),
          cylinderConfigsProvider.overrideWith((ref) async => configs),
          if (detected != null)
            detectedGasSwitchesProvider(
              dive.id,
            ).overrideWith((ref) async => detected),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: Column(
                  children: [
                    DiveTanksCardEditor(session: controller.session!),
                    const TextField(key: ValueKey('elsewhere')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Into every text field the editor shows, and out again.
  Future<void> touchEveryField(WidgetTester tester) async {
    final fields = find.descendant(
      of: find.byType(DiveTanksCardEditor),
      matching: find.byType(EditableText),
    );
    for (var i = 0; i < fields.evaluate().length; i++) {
      await tester.ensureVisible(fields.at(i));
      await tester.tap(fields.at(i), warnIfMissed: false);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('elsewhere')));
    await tester.pumpAndSettle();
  }

  for (final (name, settings) in [
    ('metric', const AppSettings()),
    (
      'imperial',
      const AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
      ),
    ),
  ]) {
    testWidgets('opening a CCR dive\'s card and tapping every field leaves '
        'the sitting clean, $name', (tester) async {
      final c = await pumpEditor(tester, ccr, settings: settings);
      expect(find.byType(CcrSettingsPanel), findsOneWidget);

      await touchEveryField(tester);

      expect(c.session!.isDirty, isFalse);
    });

    testWidgets('every cylinder row expanded and tapped leaves the sitting '
        'clean, $name', (tester) async {
      final c = await pumpEditor(tester, twoGas, settings: settings);
      for (final id in ['a', 'b']) {
        final row = find.byWidgetPredicate(
          (w) => w is TankRow && w.tank.id == id,
        );
        await tester.ensureVisible(row);
        await tester.tap(
          find.descendant(of: row, matching: find.byType(InkWell)).first,
        );
        await tester.pumpAndSettle();
      }

      await touchEveryField(tester);

      expect(c.session!.isDirty, isFalse);
    });
  }

  testWidgets('a gauge dive shows the mode selector alone', (tester) async {
    await pumpEditor(tester, oc.copyWith(diveMode: DiveMode.gauge));

    expect(find.byType(DiveModeSelector), findsOneWidget);
    expect(find.byType(TankRow), findsNothing);
    expect(find.text(l.diveLog_edit_addTank), findsNothing);
  });

  testWidgets('picking CCR shows the panel with the seeded setpoints', (
    tester,
  ) async {
    final c = await pumpEditor(tester, oc);

    await tester.tap(find.text('CCR'));
    await tester.pumpAndSettle();

    expect(find.byType(CcrSettingsPanel), findsOneWidget);
    final s = c.session!;
    expect(s.valueOf(diveModeField), DiveMode.ccr);
    expect(s.valueOf(diveSetpointLowField), isNotNull);
    expect(s.valueOf(diveSetpointHighField), isNotNull);
  });

  testWidgets('add a cylinder, then remove it', (tester) async {
    final c = await pumpEditor(tester, oc);

    await tester.tap(find.text(l.diveLog_edit_addTank));
    await tester.pumpAndSettle();
    expect(c.session!.working.tanks, hasLength(2));
    expect(find.byType(TankRow), findsNWidgets(2));
    expect(c.session!.changedCardIds, {'tanks'});

    final added = c.session!.working.tanks.last;
    final row = tester.widget<TankRow>(
      find.byWidgetPredicate((w) => w is TankRow && w.tank.id == added.id),
    );
    row.onRemove!();
    await tester.pumpAndSettle();
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('remove is not offered for the only cylinder', (tester) async {
    await pumpEditor(tester, oc);

    final row = tester.widget<TankRow>(find.byType(TankRow));
    expect(row.onRemove, isNull);
    expect(row.canRemove, isFalse);
  });

  testWidgets('a change on a row goes to the sitting', (tester) async {
    final c = await pumpEditor(tester, oc);

    tester
        .widget<TankRow>(find.byType(TankRow))
        .onChanged(back.copyWith(endPressure: 70));
    await tester.pumpAndSettle();

    expect(c.session!.working.tanks.single.endPressure, 70);
  });

  group('a saved configuration', () {
    // Its back gas is a 15 L steel twin: applied to the dive's 12 L back gas,
    // it changes the size, which is asked first (issue #2563).
    CylinderConfig twin() => CylinderConfig(
      id: 'cfg',
      name: 'Twin 15s',
      items: [
        CylinderConfigItem(
          id: 'i',
          configId: 'cfg',
          tankRole: TankRole.backGas,
          volumeL: 15,
          workingPressureBar: 232,
          createdAt: t0,
          updatedAt: t0,
        ),
      ],
      createdAt: t0,
      updatedAt: t0,
    );

    Future<void> apply(WidgetTester tester) async {
      await tester.tap(find.byTooltip(l.cylinderConfigs_applyAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Twin 15s').last);
      await tester.pumpAndSettle();
    }

    testWidgets('that overwrites asks first; declining changes nothing', (
      tester,
    ) async {
      final c = await pumpEditor(tester, oc, configs: [twin()]);

      await apply(tester);
      expect(find.text(l.cylinderConfigs_overwriteTitle), findsOneWidget);
      await tester.tap(find.text(l.common_action_cancel));
      await tester.pumpAndSettle();

      expect(c.session!.isDirty, isFalse);
    });

    testWidgets('replaced, the cylinder takes its size', (tester) async {
      final c = await pumpEditor(tester, oc, configs: [twin()]);

      await apply(tester);
      await tester.tap(find.text(l.cylinderConfigs_overwriteConfirm));
      await tester.pumpAndSettle();

      expect(c.session!.working.tanks.single.volume, 15);
      expect(c.session!.changedCardIds, {'tanks'});
    });

    testWidgets('replaced, a cylinder that came while it asked is kept', (
      tester,
    ) async {
      final c = await pumpEditor(tester, oc, configs: [twin()]);
      final s = c.session!;

      await apply(tester);
      setTanks(s, [
        ...s.working.tanks,
        const DiveTank(id: 'arrived', volume: 7, role: TankRole.stage),
      ]);
      await tester.tap(find.text(l.cylinderConfigs_overwriteConfirm));
      await tester.pumpAndSettle();

      expect([for (final t in s.working.tanks) t.id], contains('arrived'));
      expect(s.working.tanks.first.volume, 15);
    });
  });

  testWidgets('O2 that cannot be read refuses Done', (tester) async {
    final c = await pumpEditor(tester, oc);
    await tester.tap(
      find
          .descendant(of: find.byType(TankRow), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    final o2 = find.widgetWithText(TextFormField, l.diveLog_tank_label_o2);
    await tester.enterText(o2, '3.2.1');
    await tester.pump();
    await tester.pump();

    expect(c.invalidCardIds, {'tanks'});
    c.closeCard('tanks');
    expect(c.openCardIds, contains('tanks'));
  });

  testWidgets('a switch added shows and is held', (tester) async {
    final c = await pumpEditor(
      tester,
      twoGas,
      switches: [
        GasSwitch(
          id: 's1',
          diveId: 'dive',
          timestamp: 0,
          tankId: 'a',
          createdAt: t0,
        ),
      ],
    );
    expect(find.byType(GasSwitchesEditor), findsOneWidget);

    await tester.tap(find.text(l.diveLog_edit_gasSwitches_add));
    await tester.pumpAndSettle();

    expect(sittingGasSwitches(c.session!)!.current, hasLength(2));
    expect(c.session!.changedCardIds, {'tanks'});
  });

  testWidgets('switches hidden for a planned dive and for one breathing '
      'cylinder', (tester) async {
    await pumpEditor(tester, oc);
    expect(find.byType(GasSwitchesEditor), findsNothing);

    await pumpEditor(tester, twoGas.copyWith(isPlanned: true));
    expect(find.byType(GasSwitchesEditor), findsNothing);
  });

  testWidgets('Reassign exchanges in the sitting and says the readings move '
      'at Save', (tester) async {
    final c = await pumpEditor(
      tester,
      twoGas,
      pressures: {
        'a': const [
          TankPressurePoint(tankId: 'a', timestamp: 0, pressure: 200),
          TankPressurePoint(tankId: 'a', timestamp: 600, pressure: 60),
        ],
        'b': const [
          TankPressurePoint(tankId: 'b', timestamp: 0, pressure: 200),
        ],
      },
    );

    await tester.tap(find.text(l.diveLog_tank_reassignSeries));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.diveLog_reassignSheet_swap));
    await tester.pumpAndSettle();
    if (find.byType(BottomSheet).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    expect(heldTankSeriesExchanges(c.session!), [('a', 'b')]);
    expect(c.session!.working.tanks.first.endPressure, 140);
    expect(find.text(l.diveLog_tank_reassignPending), findsOneWidget);
  });

  testWidgets('an own cylinder scanned on a row joins the gear: Equipment '
      'gets its dot', (tester) async {
    final c = await pumpEditor(tester, oc);
    const cylinder = EquipmentItem(
      id: 'own',
      name: 'My AL80',
      type: EquipmentType.tank,
    );

    final row = tester.widget<TankRow>(find.byType(TankRow));
    expect(row.onOwnCylinderUsed, isNotNull);
    await tester.runAsync(() async {
      await row.onOwnCylinderUsed!(cylinder);
      await c.session!.settled();
    });
    await tester.pump();

    expect([for (final g in c.session!.working.gear) g.item.id], ['own']);
    expect(c.session!.changedCardIds, {'equipment'});
  });

  testWidgets('cylinders replaced from another card rebuild their rows; a '
      'row\'s own change keeps it', (tester) async {
    final c = await pumpEditor(tester, oc);
    final before = tester.state(find.byType(TankRow));

    setTanks(c.session!, [back.copyWith(endPressure: 70)]);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TankRow)), same(before));

    setTanks(c.session!, [back.copyWith(volume: 15)], replaced: true);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TankRow)), isNot(same(before)));
  });

  testWidgets('a change that arrives underneath rebuilds the rows, so the '
      'next keystroke keeps it', (tester) async {
    final c = await pumpEditor(tester, oc);
    final row = find.descendant(
      of: find.byType(TankRow),
      matching: find.byType(InkWell),
    );
    await tester.tap(row.first);
    await tester.pumpAndSettle();

    // A sync: the start pressure changes on a cylinder the diver has not
    // touched, so the sitting follows it.
    c.storedChanged(oc.copyWith(tanks: [back.copyWith(startPressure: 180)]));
    await tester.pumpAndSettle();
    if (find
        .widgetWithText(TextFormField, l.diveLog_tank_label_o2)
        .evaluate()
        .isEmpty) {
      await tester.tap(row.first);
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.widgetWithText(TextFormField, l.diveLog_tank_label_o2),
      '30',
    );
    await tester.pump();

    final tank = c.session!.working.tanks.single;
    expect(tank.gasMix.o2, 30);
    expect(tank.startPressure, 180);
  });

  testWidgets('a change underneath leaves the rows alone once the diver '
      'has changed the cylinders', (tester) async {
    final c = await pumpEditor(tester, oc);
    setTanks(c.session!, [back.copyWith(endPressure: 70)]);
    await tester.pumpAndSettle();
    final before = tester.state(find.byType(TankRow));

    c.storedChanged(oc.copyWith(tanks: [back.copyWith(startPressure: 180)]));
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(TankRow)), same(before));
    expect(c.session!.working.tanks.single.endPressure, 70);
  });

  group('the rebreather panels write to the sitting', () {
    testWidgets('a CCR deco setpoint and loop volume typed', (tester) async {
      final c = await pumpEditor(tester, ccr);

      await tester.enterText(
        find.widgetWithText(TextField, l.diveLog_ccr_label_deco),
        '1.6',
      );
      await tester.enterText(
        find.widgetWithText(TextField, l.diveLog_ccr_label_loopVolume),
        '7',
      );
      await tester.pumpAndSettle();

      final s = c.session!;
      expect(s.valueOf(diveSetpointDecoField), 1.6);
      expect(s.valueOf(diveLoopVolumeField), 7);
      expect(s.changedCardIds, {'tanks'});
    });

    testWidgets('an SCR loop O2 typed', (tester) async {
      final scr = oc.copyWith(
        diveMode: DiveMode.scr,
        scrType: ScrType.cmf,
        diluentGas: const GasMix(o2: 40),
      );
      final c = await pumpEditor(tester, scr);

      await tester.enterText(
        find.widgetWithText(TextField, l.diveLog_scr_label_max),
        '55',
      );
      await tester.pumpAndSettle();

      expect(c.session!.valueOf(diveLoopO2MaxField), 55);
      expect(c.session!.valueOf(diveDiluentGasField), const GasMix(o2: 40));
    });
  });

  group('the gas switch rows', () {
    final switches = [
      GasSwitch(
        id: 's1',
        diveId: 'dive',
        timestamp: 0,
        tankId: 'a',
        createdAt: t0,
      ),
      GasSwitch(
        id: 's2',
        diveId: 'dive',
        timestamp: 1200,
        tankId: 'b',
        createdAt: t0,
      ),
    ];

    GasSwitchesEditor editor(WidgetTester tester) =>
        tester.widget<GasSwitchesEditor>(find.byType(GasSwitchesEditor));

    testWidgets('are bounded by the sitting and start on the first gas', (
      tester,
    ) async {
      await pumpEditor(tester, twoGas, switches: switches);

      expect(editor(tester).maxTimestamp, 3000);
      expect(editor(tester).startingTank?.id, 'a');
      expect(editor(tester).switches.map((g) => g.id), ['s1', 's2']);
    });

    // Each cylinder breathed at its own time: a from the start, b at 20 min.
    final readings = {
      'a': const [
        TankPressurePoint(tankId: 'a', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 'a', timestamp: 60, pressure: 190),
        TankPressurePoint(tankId: 'a', timestamp: 600, pressure: 150),
        TankPressurePoint(tankId: 'a', timestamp: 1200, pressure: 150),
      ],
      'b': const [
        TankPressurePoint(tankId: 'b', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 'b', timestamp: 1200, pressure: 200),
        TankPressurePoint(tankId: 'b', timestamp: 1260, pressure: 190),
        TankPressurePoint(tankId: 'b', timestamp: 1800, pressure: 150),
      ],
    };

    testWidgets('breath starts follow a held reassign onto the cylinder that '
        'now holds the readings', (tester) async {
      final c = await pumpEditor(
        tester,
        twoGas,
        switches: switches,
        pressures: readings,
      );
      final before = editor(tester).breathStarts;
      expect(before, isNotEmpty);

      exchangeTankSeries(c.session!, 'a', 'b', exchange: (_, _) async {});
      await tester.pumpAndSettle();

      expect(editor(tester).breathStarts, {
        'a': ?before['b'],
        'b': ?before['a'],
      });
    });

    testWidgets('the detected switches are not offered while a reassign is '
        'held', (tester) async {
      final c = await pumpEditor(
        tester,
        twoGas,
        switches: switches,
        pressures: readings,
        detected: (
          addable: const <MissedSwitch>[],
          deep: const <DeepStart>[],
          unplaced: null,
          startingTankId: 'a',
        ),
      );
      expect(editor(tester).onFillDetected, isNotNull);

      exchangeTankSeries(c.session!, 'a', 'b', exchange: (_, _) async {});
      await tester.pumpAndSettle();

      expect(editor(tester).onFillDetected, isNull);
    });

    testWidgets('the time sheet draws each cylinder with the readings it '
        'holds in the sitting', (tester) async {
      final c = await pumpEditor(
        tester,
        twoGas.copyWith(
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 0),
            DiveProfilePoint(timestamp: 1200, depth: 21),
            DiveProfilePoint(timestamp: 3000, depth: 0),
          ],
        ),
        switches: switches,
        pressures: readings,
      );
      exchangeTankSeries(c.session!, 'a', 'b', exchange: (_, _) async {});
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('gas-switch-pick-s2')),
      );
      await tester.tap(find.byKey(const ValueKey('gas-switch-pick-s2')));
      await tester.pumpAndSettle();

      final sheet = tester.widget(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_GasSwitchTimeSheet',
        ),
      );
      final drawn =
          (sheet as dynamic).tankPressures
              as Map<String, List<TankPressurePoint>>;
      expect(drawn['a'], readings['b']);
      expect(drawn['b'], readings['a']);
    });

    testWidgets('a row removed, then a time changed and left', (tester) async {
      final c = await pumpEditor(tester, twoGas, switches: switches);

      editor(tester).onRemove('s1');
      await tester.pumpAndSettle();
      expect(sittingGasSwitches(c.session!)!.current.map((g) => g.id), ['s2']);

      editor(
        tester,
      ).onChanged(switches[1].copyWith(timestamp: 1500), GasSwitchField.time);
      editor(tester).onTimeSettled!('s2');
      await tester.pumpAndSettle();
      expect(sittingGasSwitches(c.session!)!.current.single.timestamp, 1500);
      expect(c.session!.changedCardIds, {'tanks'});
    });
  });

  testWidgets('a scan in flight delays Save until it lands', (tester) async {
    final c = await pumpEditor(tester, oc);
    final scan = Completer<void>();

    tester.widget<TankRow>(find.byType(TankRow)).onScanPending!(scan.future);

    expect(c.session!.isSettled, isFalse);
    scan.complete();
    await tester.pump();
    expect(c.session!.isSettled, isTrue);
  });
}

class _NoWriter implements DiverGasSwitchWriter {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
