import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
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
      writer: _NoWriter(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(settings),
          ),
          tankPressuresProvider(dive.id).overrideWith((ref) async => pressures),
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
