import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveComputersCompanion, DivesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/app_router.dart' show newDivePage;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/trip_section.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  late Trip trip;
  late TripCylinder a;
  late TripCylinder b;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    final now = DateTime.now();
    trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(now.year, now.month, now.day - 1),
        endDate: DateTime(now.year, now.month, now.day + 5),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final slots = TripCylinderRepository();
    TripCylinder slot(String label, int order) => TripCylinder(
      id: '',
      tripId: trip.id,
      label: label,
      volume: 11.1,
      workingPressure: 207,
      sortOrder: order,
      createdAt: now,
      updatedAt: now,
    );
    a = await slots.createCylinder(slot('Truck 1', 0));
    b = await slots.createCylinder(slot('Truck 2', 1));
    // a's fill is the older one, so the oldest-fill-first suggestion
    // picks a.
    final morning = DateTime.utc(2026, 3, 9, 7);
    for (final (c, minutes) in [(a, 0), (b, 60)]) {
      final at = morning.add(Duration(minutes: minutes));
      await slots.createEvent(
        TripCylinderEvent(
          id: '',
          tripCylinderId: c.id,
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          pressure: 200,
          o2Percent: 32,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> pumpEditPage(
    WidgetTester tester, {
    String? diveId,
    String? tripId,
    String? tripCylinderId,
    DivePrefill? prefill,
    TripRepository? trips,
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith((ref) {
            return DiveListNotifier(repository, ref);
          }),
          customTankPresetsProvider.overrideWith((ref) async => []),
          if (trips != null) tripRepositoryProvider.overrideWithValue(trips),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              tripId: tripId,
              tripCylinderId: tripCylinderId,
              prefill: prefill,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    // No pumpAndSettle: the new-dive path starts a 10s GPS capture whose
    // pending timer never settles in tests.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The trip load, the states provider and the suggestion each take a few
  /// turns; pumpAndSettle never returns on this page.
  Future<void> settleTrip(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  List<TankRow> rows(WidgetTester tester) =>
      tester.widgetList<TankRow>(find.byType(TankRow)).toList();

  testWidgets('the log-dive shortcut links the first tank to its slot', (
    tester,
  ) async {
    await pumpEditPage(tester, tripId: trip.id, tripCylinderId: b.id);
    await settleTrip(tester);
    final row = rows(tester).first;
    expect(row.tank.tripCylinderId, b.id);
    expect(row.tank.startPressure, 200);
    expect(row.tank.gasMix.o2, 32);
    // Chosen on the board, not suggested.
    expect(row.suggested, isFalse);
  });

  testWidgets('a trip with no slot named suggests one for the new tank', (
    tester,
  ) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    final row = rows(tester).first;
    expect(row.tank.tripCylinderId, a.id);
    expect(row.suggested, isTrue);
  });

  testWidgets('a tank filled from a scan is never suggested', (tester) async {
    // The scanned start pressure is a reading; a suggestion would replace
    // it with the board's, and None would not bring it back.
    await pumpEditPage(
      tester,
      tripId: trip.id,
      prefill: const DivePrefill(startPressureBar: 180, o2Percent: 32),
    );
    await settleTrip(tester);
    final row = rows(tester).first;
    expect(row.tank.tripCylinderId, isNull);
    expect(row.tank.startPressure, 180);
    expect(row.suggested, isFalse);
  });

  testWidgets('an added tank takes the next full slot', (tester) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final r = rows(tester);
    expect(r[0].tank.tripCylinderId, a.id);
    expect(r[1].tank.tripCylinderId, b.id);
    // Each picker hides the slot the other tank holds.
    expect(r[0].takenTripCylinderIds, {b.id});
    expect(r[1].takenTripCylinderIds, {a.id});
  });

  testWidgets('None turns the suggestion down for good', (tester) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    final first = rows(tester).first;
    first.onChanged(first.tank.copyWith(clearTripCylinderId: true));
    await tester.pump();
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final r = rows(tester);
    expect(r[0].tank.tripCylinderId, isNull);
    expect(r[0].suggested, isFalse);
    expect(r[1].tank.tripCylinderId, isNotNull);
  });

  testWidgets('clearing the trip drops every tank link', (tester) async {
    await pumpEditPage(tester, tripId: trip.id, tripCylinderId: b.id);
    await settleTrip(tester);
    final clear = find.descendant(
      of: find.byType(TripSection),
      matching: find.byIcon(Icons.clear),
    );
    // The Trip section starts folded, its rows built but hidden; open it by
    // its header icon (the row's own "Trip" label opens the trip picker).
    await tester.tap(
      find.descendant(
        of: find.byType(TripSection),
        matching: find.byIcon(Icons.flight_takeoff),
      ),
    );
    await settleTrip(tester);
    // The page's bottom bar covers the lower rows until they scroll up.
    await tester.ensureVisible(clear);
    await tester.pump();
    await tester.tap(clear);
    await tester.pump();
    expect(rows(tester).first.tank.tripCylinderId, isNull);
  });

  testWidgets('a loaded tank is never suggested', (tester) async {
    final dive = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime.now(),
        trip: trip,
        tanks: const [DiveTank(id: 'k1', startPressure: 200, endPressure: 60)],
      ),
    );
    await pumpEditPage(tester, diveId: dive.id);
    await settleTrip(tester);
    // Editing opens with Gas & Gear folded; its tank rows appear on expand.
    await tester.tap(find.text('Gas & Gear').first);
    await settleTrip(tester);
    // Adding a tank runs the suggestion over every tank: only the new one
    // may take a slot.
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final r = rows(tester);
    expect(r[0].tank.tripCylinderId, isNull);
    expect(r[0].suggested, isFalse);
    expect(r[1].tank.tripCylinderId, a.id);
  });

  testWidgets('a second computer\'s tank can share the slot', (tester) async {
    // Issue #2661: two computers logged one cylinder and the rows were not
    // consolidated. The first computer's row holds Truck 1; the second's
    // is that computer's copy of the same cylinder, so Truck 1 stays open
    // to it. The first computer's other tank still cannot take it.
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'perdix',
            name: 'Perdix',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final dive = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime.now(),
        trip: trip,
        tanks: [
          DiveTank(id: 'k1', tripCylinderId: a.id),
          const DiveTank(id: 'k2', order: 1),
          const DiveTank(id: 'k3', order: 2, computerId: 'perdix'),
        ],
      ),
    );
    await pumpEditPage(tester, diveId: dive.id);
    await settleTrip(tester);
    await tester.tap(find.text('Gas & Gear').first);
    await settleTrip(tester);
    final r = rows(tester);
    expect(r.map((row) => row.tank.id), ['k1', 'k2', 'k3']);
    expect(r[1].takenTripCylinderIds, {a.id});
    expect(r[2].takenTripCylinderIds, isEmpty);
  });

  testWidgets('a hand-added tank on a downloaded dive cannot share', (
    tester,
  ) async {
    // A download stamps the computer on every tank it writes; a tank the
    // diver adds carries none, and is the dive's own computer's, so the
    // slot the downloaded tank holds stays taken for it.
    for (final id in ['teric', 'perdix']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final dive = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime.now(),
        trip: trip,
        tanks: [
          DiveTank(id: 'k1', computerId: 'teric', tripCylinderId: a.id),
          const DiveTank(id: 'k2', order: 1),
          const DiveTank(id: 'k3', order: 2, computerId: 'perdix'),
        ],
      ),
    );
    // Saving never writes the dive's computer: the download does.
    await (db.update(db.dives)..where((d) => d.id.equals(dive.id))).write(
      const DivesCompanion(computerId: Value('teric')),
    );
    await pumpEditPage(tester, diveId: dive.id);
    await settleTrip(tester);
    await tester.tap(find.text('Gas & Gear').first);
    await settleTrip(tester);
    final r = rows(tester);
    expect(r.map((row) => row.tank.id), ['k1', 'k2', 'k3']);
    expect(r[1].takenTripCylinderIds, {a.id});
    expect(r[2].takenTripCylinderIds, isEmpty);
  });

  testWidgets('a past dive suggests and fills from the slots as they were', (
    tester,
  ) async {
    // At noon a (filled 07:00) is the oldest full slot, with EAN32. By
    // today's state a was refilled at 14:00 with EAN36, which would make b
    // (08:00) the oldest instead.
    final refill = DateTime.utc(2026, 3, 9, 14);
    await TripCylinderRepository().createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: a.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: refill,
        pressure: 200,
        o2Percent: 36,
        createdAt: refill,
        updatedAt: refill,
      ),
    );
    final dive = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime.utc(2026, 3, 9, 12),
        trip: trip,
        tanks: const [DiveTank(id: 'k1', startPressure: 200, endPressure: 60)],
      ),
    );
    await pumpEditPage(tester, diveId: dive.id);
    await settleTrip(tester);
    await tester.tap(find.text('Gas & Gear').first);
    await settleTrip(tester);
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final added = rows(tester)[1].tank;
    expect(added.tripCylinderId, a.id);
    expect(added.gasMix.o2, 32);
  });

  testWidgets('a tank with no full slot left stays unlinked', (tester) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final r = rows(tester);
    expect(r.map((row) => row.tank.tripCylinderId), [a.id, b.id, null]);
    expect(r[2].suggested, isFalse);
  });

  testWidgets('a trip picked while the shortcut loads is kept', (tester) async {
    final now = DateTime.now();
    await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Curacao',
        startDate: DateTime(now.year, now.month, now.day + 10),
        endDate: DateTime(now.year, now.month, now.day + 15),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final gate = Completer<void>();
    await pumpEditPage(
      tester,
      tripId: trip.id,
      tripCylinderId: b.id,
      trips: _GatedTripRepository(gate.future),
    );
    // The shortcut's trip load is still waiting; the diver picks Curacao.
    await tester.tap(
      find.descendant(
        of: find.byType(TripSection),
        matching: find.byIcon(Icons.flight_takeoff),
      ),
    );
    await settleTrip(tester);
    final notSet = find.descendant(
      of: find.byType(TripSection),
      matching: find.text('Not set'),
    );
    await tester.ensureVisible(notSet.first);
    await tester.pump();
    await tester.tap(notSet.first);
    await settleTrip(tester);
    await tester.tap(find.text('Curacao').last);
    await settleTrip(tester);

    final curacao = find.descendant(
      of: find.byType(TripSection),
      matching: find.text('Curacao'),
    );
    expect(curacao, findsOneWidget);

    gate.complete();
    await settleTrip(tester);

    expect(curacao, findsOneWidget);
    expect(rows(tester).first.tank.tripCylinderId, isNot(b.id));
  });

  testWidgets('switching trips drops the old link and suggests anew', (
    tester,
  ) async {
    final now = DateTime.now();
    final other = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Curacao',
        startDate: DateTime(now.year, now.month, now.day + 10),
        endDate: DateTime(now.year, now.month, now.day + 15),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final slots = TripCylinderRepository();
    final reef = await slots.createCylinder(
      TripCylinder(
        id: '',
        tripId: other.id,
        label: 'Reef 1',
        volume: 11.1,
        workingPressure: 207,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final morning = DateTime.utc(2026, 3, 9, 7);
    await slots.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: reef.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: morning,
        pressure: 200,
        o2Percent: 32,
        createdAt: morning,
        updatedAt: morning,
      ),
    );
    await pumpEditPage(tester, tripId: trip.id, tripCylinderId: b.id);
    await settleTrip(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(TripSection),
        matching: find.byIcon(Icons.flight_takeoff),
      ),
    );
    await settleTrip(tester);
    final tripRow = find.descendant(
      of: find.byType(TripSection),
      matching: find.text('Bonaire'),
    );
    await tester.ensureVisible(tripRow.first);
    await tester.pump();
    await tester.tap(tripRow.first);
    await settleTrip(tester);
    await tester.tap(find.text('Curacao').last);
    await settleTrip(tester);

    final row = rows(tester).first;
    expect(row.tank.tripCylinderId, reef.id);
    expect(row.suggested, isTrue);
  });

  testWidgets('the link is saved with the dive', (tester) async {
    String? savedId;
    await pumpEditPage(
      tester,
      tripId: trip.id,
      tripCylinderId: b.id,
      onSaved: (id) => savedId = id,
    );
    await settleTrip(tester);
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 100 && savedId == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final saved = await repository.getDiveById(savedId!);
    expect(saved!.tanks.first.tripCylinderId, b.id);
  });

  testWidgets('the new-dive route passes the trip and slot through', (
    tester,
  ) async {
    DiveEditPage? built;
    final router = GoRouter(
      initialLocation: '/dives/new?tripId=t9&tripCylinderId=c9',
      routes: [
        GoRoute(
          path: '/dives/new',
          builder: (context, state) {
            built = newDivePage(state);
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(built!.tripId, 't9');
    expect(built!.tripCylinderId, 'c9');
  });
}

/// Holds every trip lookup until [gate] completes, as a slow database would.
class _GatedTripRepository extends TripRepository {
  _GatedTripRepository(this.gate);

  final Future<void> gate;

  @override
  Future<Trip?> getTripById(String id) async {
    await gate;
    return super.getTripById(id);
  }
}
