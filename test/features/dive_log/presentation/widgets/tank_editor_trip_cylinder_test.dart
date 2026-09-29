import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _PresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _PresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _apeks = EquipmentItem(
  id: 'reg-a',
  name: 'Apeks XTX',
  type: EquipmentType.regulator,
);

/// Bumped to make the overridden active-equipment list reload, the way a
/// dependency change (such as the current diver) reloads the real one. The
/// reload never finishes, so the editor is caught mid-reload.
final _reload = StateProvider<int>((ref) => 0);

/// A slot on trip t1 with one fill, as the board would fold it.
TripCylinderState filledSlot(
  String id, {
  double pressure = 200,
  double o2 = 32,
  String bottle = '14',
  double volume = 11.1,
  double workingPressure = 207,
}) {
  final t0 = DateTime.utc(2026, 3, 9, 7);
  return foldCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 't1',
      label: 'Truck $id',
      volume: volume,
      workingPressure: workingPressure,
      createdAt: t0,
      updatedAt: t0,
    ),
    events: [
      TripCylinderEvent(
        id: 'f-$id',
        tripCylinderId: id,
        kind: TripCylinderEventKind.fill,
        occurredAt: t0,
        bottleLabel: bottle,
        pressure: pressure,
        o2Percent: o2,
        createdAt: t0,
        updatedAt: t0,
      ),
    ],
    uses: const [],
  );
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required List<EquipmentItem> equipment,
  required Widget editor,
  MockSettingsNotifier? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final builtInPresets = TankPresets.all
      .map((p) => TankPresetEntity.fromBuiltIn(p))
      .toList();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => settings ?? MockSettingsNotifier(),
        ),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tankPresetListNotifierProvider.overrideWith(
          (ref) => _PresetListNotifier(builtInPresets),
        ),
        tankPresetsProvider.overrideWith((ref) => Future.value(builtInPresets)),
        activeEquipmentProvider.overrideWith((ref) async {
          if (ref.watch(_reload) > 0) await Completer<void>().future;
          return equipment;
        }),
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: editor)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> equipment,
  DiveTank tank = const DiveTank(id: 'tank-1'),
  void Function(DiveTank)? onChanged,
  String? tripId,
  bool suggested = false,
  List<TripCylinderState> slots = const [],
  Set<String> taken = const {},
}) => _pumpEditor(
  tester,
  equipment: equipment,
  editor: TankEditor(
    tank: tank,
    tankNumber: 1,
    // A dive on a trip gets the trip's slots from the page; none without.
    tripCylinderStates: tripId == null ? null : slots,
    takenTripCylinderIds: taken,
    suggested: suggested,
    onChanged: onChanged ?? (_) {},
    onRemove: () {},
  ),
);

/// The editor under a parent that can replace its tank, as the dive edit
/// page does when it links a tank itself.
Future<void> _pumpHost(
  WidgetTester tester, {
  required ValueNotifier<DiveTank> tank,
  required List<TripCylinderState> slots,
  required void Function(DiveTank) onChanged,
  MockSettingsNotifier? settings,
}) => _pumpEditor(
  tester,
  equipment: const [],
  settings: settings,
  editor: ValueListenableBuilder<DiveTank>(
    valueListenable: tank,
    builder: (_, t, _) => TankEditor(
      tank: t,
      tankNumber: 1,
      tripCylinderStates: slots,
      onChanged: onChanged,
      onRemove: () {},
    ),
  ),
);

Future<void> _openTripCylinderPicker(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('tank-trip-cylinder-picker')),
  );
  await tester.tap(find.byKey(const Key('tank-trip-cylinder-picker')));
  await tester.pumpAndSettle();
}

Future<void> _openRegulatorPicker(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('tank-regulator-picker')));
  await tester.tap(find.byKey(const Key('tank-regulator-picker')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an edit keeps the trip cylinder link', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [_apeks],
      tank: const DiveTank(id: 'tank-1', tripCylinderId: 'slot-1'),
      onChanged: (t) => changed = t,
    );

    // Any edit rebuilds the tank field by field; picking a regulator is the
    // one edit this editor already has a keyed control for.
    await _openRegulatorPicker(tester);
    await tester.tap(find.text('Apeks XTX').last);
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
    expect(changed?.tripCylinderId, 'slot-1');
  });

  testWidgets('no trip, or a trip with no cylinders, shows no picker', (
    tester,
  ) async {
    await _pump(tester, equipment: const []);
    expect(find.byKey(const Key('tank-trip-cylinder-picker')), findsNothing);
    await _pump(tester, equipment: const [], tripId: 't1');
    expect(find.byKey(const Key('tank-trip-cylinder-picker')), findsNothing);
  });

  testWidgets('picking a slot links and fills the tank', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a', pressure: 205, o2: 32)],
      onChanged: (t) => changed = t,
    );
    await _openTripCylinderPicker(tester);
    await tester.tap(find.textContaining('Truck a').last);
    await tester.pumpAndSettle();

    expect(changed!.tripCylinderId, 'a');
    expect(changed!.gasMix.o2, 32);
    expect(changed!.startPressure, 205);
  });

  testWidgets('None clears the link and keeps the fields', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a')],
      tank: const DiveTank(
        id: 'tank-1',
        tripCylinderId: 'a',
        startPressure: 205,
        gasMix: GasMix(o2: 32),
      ),
      onChanged: (t) => changed = t,
    );
    await _openTripCylinderPicker(tester);
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    expect(changed!.tripCylinderId, isNull);
    expect(changed!.gasMix.o2, 32);
    expect(changed!.startPressure, 205);
  });

  testWidgets('a suggested link says so', (tester) async {
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a')],
      tank: const DiveTank(id: 'tank-1', tripCylinderId: 'a'),
      suggested: true,
    );
    expect(
      find.text("Suggested from the trip's full cylinders"),
      findsOneWidget,
    );
  });

  testWidgets('an open editor picks up a link set by the page', (tester) async {
    // The page fills a tank from a slot while its editor is open (a
    // suggestion, or the log-dive shortcut): the fields must show the fill,
    // or the next keystroke would write the old values back over it.
    final tank = ValueNotifier(
      const DiveTank(id: 'tank-1', startPressure: 180),
    );
    addTearDown(tank.dispose);
    DiveTank? changed;
    await _pumpHost(
      tester,
      tank: tank,
      slots: [filledSlot('a', pressure: 205)],
      onChanged: (t) => changed = t,
    );
    tank.value = tankFromTripCylinder(
      tank.value,
      filledSlot('a', pressure: 205),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'End Pressure'),
      '60',
    );
    await tester.pump();
    expect(changed!.startPressure, 205);
    expect(changed!.tripCylinderId, 'a');
  });

  testWidgets('picking the slot already linked changes nothing', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a', pressure: 60)],
      tank: const DiveTank(
        id: 'tank-1',
        tripCylinderId: 'a',
        startPressure: 200,
      ),
      onChanged: (_) => calls++,
    );
    await _openTripCylinderPicker(tester);
    await tester.tap(find.textContaining('Truck a').last);
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('slots other tanks hold are not offered', (tester) async {
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a'), filledSlot('b')],
      taken: {'b'},
    );
    await _openTripCylinderPicker(tester);
    expect(find.textContaining('Truck a'), findsWidgets);
    expect(find.textContaining('Truck b'), findsNothing);
  });

  for (final imperial in [false, true]) {
    testWidgets('a fill from a slot with no preset drops the old one'
        '${imperial ? ' (cuft)' : ''}', (tester) async {
      final settings = MockSettingsNotifier();
      if (imperial) await settings.setImperial();
      final hp100 = filledSlot('h', volume: 15.3, workingPressure: 232);
      final tank = ValueNotifier(
        const DiveTank(
          id: 'tank-1',
          volume: 11.1,
          workingPressure: 207,
          startPressure: 200,
          endPressure: 50,
          presetName: 'al80',
        ),
      );
      addTearDown(tank.dispose);
      DiveTank? changed;
      await _pumpHost(
        tester,
        tank: tank,
        slots: [hp100],
        settings: settings,
        onChanged: (t) => changed = t,
      );
      tank.value = tankFromTripCylinder(tank.value, hp100);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'End Pressure'),
        imperial ? '800' : '60',
      );
      await tester.pump();
      expect(changed!.presetName, isNull);
      expect(changed!.volume, closeTo(15.3, 0.05));
    });
  }
}
