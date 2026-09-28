import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveCentersCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repo;
  late List<TripCylinder> cylinders;
  late List<TripCylinderState> states;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    );
    cylinders = [
      for (var i = 1; i <= 3; i++)
        await repo.createCylinder(
          TripCylinder(
            id: '',
            tripId: trip.id,
            label: 'Truck $i',
            workingPressure: 207,
            sortOrder: i,
            createdAt: now,
            updatedAt: now,
          ),
        ),
    ];
    states = [
      for (final c in cylinders)
        foldCylinderState(cylinder: c, events: const [], uses: const []),
    ];
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    Set<String>? preselected,
    bool several = false,
    TripCylinderEvent? editing,
    MockSettingsNotifier? settings,
    TripFillPassportCopier? copier,
    List<DiveCenter> centers = const [],
    Future<List<DiveCenter>>? centersLoad,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) =>
                settings ??
                MockSettingsNotifier(const AppSettings(defaultCurrency: 'EUR')),
          ),
          allDiveCentersProvider.overrideWith(
            (ref) => centersLoad ?? Future.value(centers),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          if (copier != null)
            tripFillPassportCopierProvider.overrideWithValue(copier),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTripCylinderFillSheet(
                  context,
                  slots: states,
                  preselected: preselected ?? {cylinders.first.id},
                  several: several,
                  editing: editing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  testWidgets('records one fill with analysis, bottle and cost', (
    tester,
  ) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await type(tester, 'fill-pressure', '200');
    await type(tester, 'fill-o2', '32');
    await type(tester, 'fill-aO2-$id', '31.6');
    await type(tester, 'fill-bottle-$id', '14');
    await type(tester, 'fill-cost', '12.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.kind, TripCylinderEventKind.fill);
    expect(e.pressure, 200);
    expect(e.o2Percent, 32);
    expect(e.analyzedO2, 31.6);
    expect(e.bottleLabel, '14');
    expect(e.cost, 12.5);
    expect(e.currency, 'EUR');
    expect(e.occurredAt.isUtc, isTrue);
  });

  testWidgets('a blank pressure and no cost store nulls', (tester) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.pressure, isNull);
    expect(e.o2Percent, 21);
    expect(e.cost, isNull);
    expect(e.currency, isNull);
  });

  testWidgets('an imperial fill pressure is stored in bar', (tester) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    final id = cylinders.first.id;
    await pumpAndOpen(tester, settings: imperial);
    expect(find.text('Fill pressure (psi)'), findsOneWidget);
    await type(tester, 'fill-pressure', '3000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    const units = UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi));
    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.pressure, closeTo(units.pressureToBar(3000), 1e-9));
  });

  testWidgets('fill several writes one event per checked slot only', (
    tester,
  ) async {
    final [a, b, c] = cylinders;
    await pumpAndOpen(tester, several: true, preselected: {a.id, b.id, c.id});
    expect(find.text('Cylinders to fill'), findsOneWidget);
    await type(tester, 'fill-bottle-${a.id}', '7');
    await type(tester, 'fill-bottle-${b.id}', '8');
    await type(tester, 'fill-bottle-${c.id}', '9');
    // Typed, then unchecked: the slot gets nothing.
    await tester.tap(find.byKey(Key('fill-slot-${b.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await repo.getEventsForCylinder(a.id)).single.bottleLabel, '7');
    expect(await repo.getEventsForCylinder(b.id), isEmpty);
    expect((await repo.getEventsForCylinder(c.id)).single.bottleLabel, '9');
  });

  testWidgets('refuses an analyzed mix over 100 percent and saves nothing', (
    tester,
  ) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await type(tester, 'fill-aO2-$id', '32');
    await type(tester, 'fill-aHe-$id', '70');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Oxygen must be 1 to 100 percent, helium 0 to 99, and together at most 100.',
      ),
      findsOneWidget,
    );
    expect(await repo.getEventsForCylinder(id), isEmpty);
  });

  testWidgets('refuses a fill with no slot picked', (tester) async {
    await pumpAndOpen(tester, several: true, preselected: {});
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one cylinder.'), findsOneWidget);
  });

  testWidgets('edits an existing fill in place', (tester) async {
    final id = cylinders.first.id;
    final now = DateTime.now().toUtc();
    final existing = await repo.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: id,
        kind: TripCylinderEventKind.fill,
        occurredAt: DateTime.utc(2026, 3, 9, 8),
        bottleLabel: '14',
        pressure: 200,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    expect(find.text('Edit fill'), findsOneWidget);
    await type(tester, 'fill-bottle-$id', '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final events = await repo.getEventsForCylinder(id);
    expect(events, hasLength(1));
    expect(events.single.bottleLabel, '15');
    expect(events.single.occurredAt, DateTime.utc(2026, 3, 9, 8));
  });

  testWidgets('a fill on an owned cylinder also lands on its passport', (
    tester,
  ) async {
    final now = DateTime.now();
    final equipmentId = (await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
    )).id;
    final owned = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: cylinders.first.tripId,
        equipmentId: equipmentId,
        label: 'My HP100',
        workingPressure: 230,
        createdAt: now,
        updatedAt: now,
      ),
    );
    states = [
      foldCylinderState(cylinder: owned, events: const [], uses: const []),
    ];
    await pumpAndOpen(tester, preselected: {owned.id});
    await type(tester, 'fill-o2', '32');
    await type(tester, 'fill-aO2-${owned.id}', '31.6');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final event = (await repo.getEventsForCylinder(owned.id)).single;
    final copy = await CylinderFillRepository().getById(
      tripFillPassportCopyId(event.id),
    );
    expect(copy, isNotNull);
    expect(copy!.o2Percent, 31.6);
    expect(copy.equipmentId, equipmentId);
  });

  testWidgets('a fill at zero pressure is refused', (tester) async {
    await pumpAndOpen(tester);
    await type(tester, 'fill-pressure', '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter 1 or more'), findsOneWidget);
    expect(await repo.getEventsForCylinder(cylinders.first.id), isEmpty);
  });

  testWidgets('the passport copy names the station even if it loads late', (
    tester,
  ) async {
    final now = DateTime.now();
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'dc1',
            name: 'Budget Marine',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final equipmentId = (await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
    )).id;
    final owned = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: cylinders.first.tripId,
        equipmentId: equipmentId,
        label: 'My HP100',
        workingPressure: 230,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final at = DateTime.utc(2026, 3, 9, 8);
    states = [
      foldCylinderState(
        cylinder: owned,
        events: [
          TripCylinderEvent(
            id: 'f0',
            tripCylinderId: owned.id,
            kind: TripCylinderEventKind.fill,
            occurredAt: at,
            diveCenterId: 'dc1',
            createdAt: at,
            updatedAt: at,
          ),
        ],
        uses: const [],
      ),
    ];
    final centersLater = Completer<List<DiveCenter>>();
    await pumpAndOpen(
      tester,
      preselected: {owned.id},
      centersLoad: centersLater.future,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    centersLater.complete([
      DiveCenter(
        id: 'dc1',
        name: 'Budget Marine',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    await tester.pumpAndSettle();

    final event = (await repo.getEventsForCylinder(owned.id)).single;
    final copy = await CylinderFillRepository().getById(
      tripFillPassportCopyId(event.id),
    );
    expect(copy!.stationName, 'Budget Marine');
  });

  testWidgets('unchecking a slot after a failed save removes its fill', (
    tester,
  ) async {
    final a = cylinders[0].id;
    final b = cylinders[1].id;
    await pumpAndOpen(
      tester,
      preselected: {a, b},
      several: true,
      copier: _FlakyCopier(failures: 1),
    );
    await type(tester, 'fill-pressure', '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(Key('fill-slot-$a')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await repo.getEventsForCylinder(a), isEmpty);
    expect(await repo.getEventsForCylinder(b), hasLength(1));
  });

  testWidgets('a station list that fails to load does not block saving', (
    tester,
  ) async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'dc1',
            name: 'Budget Marine',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final first = cylinders.first;
    final at = DateTime.utc(2026, 3, 9, 8);
    states = [
      foldCylinderState(
        cylinder: first,
        events: [
          TripCylinderEvent(
            id: 'f0',
            tripCylinderId: first.id,
            kind: TripCylinderEventKind.fill,
            occurredAt: at,
            diveCenterId: 'dc1',
            createdAt: at,
            updatedAt: at,
          ),
        ],
        uses: const [],
      ),
      ...states.skip(1),
    ];
    final failing = Completer<List<DiveCenter>>();
    await pumpAndOpen(tester, centersLoad: failing.future);
    await tester.tap(find.text('Save'));
    await tester.pump();
    failing.completeError(StateError('centers gone'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsNothing);
    final e = (await repo.getEventsForCylinder(first.id)).single;
    expect(e.diveCenterId, 'dc1');
  });

  testWidgets('a negative number asks for zero or more', (tester) async {
    await pumpAndOpen(tester);
    await type(tester, 'fill-pressure', '-200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter 0 or more'), findsOneWidget);
    expect(await repo.getEventsForCylinder(cylinders.first.id), isEmpty);
  });

  group('pure rules', () {
    test('mix validity', () {
      expect(tripCylinderMixIsValid(21, 0), isTrue);
      expect(tripCylinderMixIsValid(100, 0), isTrue);
      expect(tripCylinderMixIsValid(18, 45), isTrue);
      expect(tripCylinderMixIsValid(0.5, 0), isFalse);
      expect(tripCylinderMixIsValid(32, 70), isFalse);
      expect(tripCylinderMixIsValid(1, 100), isFalse);
    });

    test('the default station is the latest one used on the trip', () {
      TripCylinderState withFill(int hour, String? center) {
        final at = DateTime.utc(2026, 3, 9, hour);
        final fill = TripCylinderEvent(
          id: 'f$hour',
          tripCylinderId: cylinders.first.id,
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          diveCenterId: center,
          createdAt: at,
          updatedAt: at,
        );
        return foldCylinderState(
          cylinder: cylinders.first,
          events: [fill],
          uses: const [],
        );
      }

      expect(
        lastTripFillCenter([
          withFill(8, 'a'),
          withFill(10, 'b'),
          withFill(12, null),
        ]),
        'b',
      );
      expect(lastTripFillCenter(states), isNull);
    });
  });

  testWidgets('a retry after a failed save never fills a slot twice', (
    tester,
  ) async {
    final copier = _FlakyCopier(failures: 1);
    final picked = {cylinders[0].id, cylinders[1].id};
    await pumpAndOpen(
      tester,
      preselected: picked,
      several: true,
      copier: copier,
    );
    await type(tester, 'fill-pressure', '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );

    await type(tester, 'fill-pressure', '210');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    for (final id in picked) {
      final fills = await repo.getEventsForCylinder(id);
      expect(fills, hasLength(1));
      expect(fills.single.pressure, 210);
    }
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('fill several names the cost per cylinder', (tester) async {
    await pumpAndOpen(tester, several: true);
    expect(find.text('Cost per cylinder'), findsOneWidget);
    expect(find.text('Cost'), findsNothing);
  });
  final station = DiveCenter(
    id: 'dc1',
    name: 'Budget Marine',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('the station defaults to the last one, and can be cleared', (
    tester,
  ) async {
    final first = cylinders.first;
    final at = DateTime.utc(2026, 3, 9, 8);
    states = [
      foldCylinderState(
        cylinder: first,
        events: [
          TripCylinderEvent(
            id: 'f0',
            tripCylinderId: first.id,
            kind: TripCylinderEventKind.fill,
            occurredAt: at,
            diveCenterId: 'dc1',
            createdAt: at,
            updatedAt: at,
          ),
        ],
        uses: const [],
      ),
      ...states.skip(1),
    ];
    await pumpAndOpen(tester, centers: [station]);
    expect(find.text('Budget Marine'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(first.id)).single;
    expect(e.diveCenterId, isNull);
  });

  testWidgets('a named station is saved with the fill', (tester) async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'dc1',
            name: 'Budget Marine',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final first = cylinders.first;
    final at = DateTime.utc(2026, 3, 9, 8);
    states = [
      foldCylinderState(
        cylinder: first,
        events: [
          TripCylinderEvent(
            id: 'f0',
            tripCylinderId: first.id,
            kind: TripCylinderEventKind.fill,
            occurredAt: at,
            diveCenterId: 'dc1',
            createdAt: at,
            updatedAt: at,
          ),
        ],
        uses: const [],
      ),
      ...states.skip(1),
    ];
    await pumpAndOpen(tester, centers: [station]);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(first.id)).single;
    expect(e.diveCenterId, 'dc1');
  });

  testWidgets('the date and time pickers set when the fill happened', (
    tester,
  ) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);

    await tester.tap(find.byKey(const Key('fill-when')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.occurredAt.day, 15);
    expect(e.occurredAt.isUtc, isTrue);
  });

  testWidgets('cancelling the date picker keeps the time', (tester) async {
    await pumpAndOpen(tester);
    final before = tester
        .widget<ListTile>(find.byKey(const Key('fill-when')))
        .subtitle;

    await tester.tap(find.byKey(const Key('fill-when')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    final after = tester
        .widget<ListTile>(find.byKey(const Key('fill-when')))
        .subtitle;
    expect((after! as Text).data, (before! as Text).data);
  });

  testWidgets('a quick mix sets the oxygen and clears the helium', (
    tester,
  ) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await type(tester, 'fill-he', '20');
    await tester.tap(find.text('EAN36'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.o2Percent, 36);
    expect(e.hePercent, 0);
  });

  testWidgets('checking another slot, a currency and a package are saved', (
    tester,
  ) async {
    await pumpAndOpen(tester, several: true);
    await tester.tap(find.byKey(Key('fill-slot-${cylinders.last.id}')));
    await tester.pump();
    await type(tester, 'fill-cost', '10');
    await tester.tap(find.byKey(const Key('fill-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fill-package')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    for (final c in [cylinders.first, cylinders.last]) {
      final e = (await repo.getEventsForCylinder(c.id)).single;
      expect(e.currency, 'USD');
      expect(e.isPackage, isTrue);
    }
  });

  testWidgets('an unreadable number is refused', (tester) async {
    await pumpAndOpen(tester);
    await type(tester, 'fill-pressure', 'lots');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid number (decimal separator: ".")'),
      findsOneWidget,
    );
    expect(await repo.getEventsForCylinder(cylinders.first.id), isEmpty);
  });

  testWidgets('cancel closes the sheet without saving', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsNothing);
    expect(await repo.getEventsForCylinder(cylinders.first.id), isEmpty);
  });
}

/// Fails the first [failures] passport copies, then succeeds.
class _FlakyCopier extends TripFillPassportCopier {
  _FlakyCopier({required this.failures});

  int failures;

  @override
  Future<void> afterSave(
    TripCylinderEvent event,
    TripCylinder slot, {
    String? diverId,
    String? stationName,
    bool stationResolved = true,
  }) async {
    if (failures > 0) {
      failures--;
      throw StateError('copy failed');
    }
  }
}
