import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_trip_card.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The passport's Trip card (issue #2338).
void main() {
  final now = DateTime.now();
  Trip trip(String id, {int startInDays = 10}) => Trip(
    id: id,
    name: 'Trip $id',
    startDate: DateTime(now.year, now.month, now.day + startInDays),
    endDate: DateTime(now.year, now.month, now.day + startInDays + 5),
    createdAt: now,
    updatedAt: now,
  );

  PackedTrip packed(String id, {bool slot = false, bool isPacked = true}) =>
      PackedTrip(trip: trip(id), packed: isPacked, slot: slot);

  Future<(AppLocalizations, _FakePacks)> pump(
    WidgetTester tester, {
    List<PackedTrip> trips = const [],
    List<Trip> allTrips = const [],
    bool failing = false,
  }) async {
    final fake = _FakePacks(failing: failing);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          equipmentTripsProvider('tank').overrideWith((ref) async => trips),
          allTripsProvider.overrideWith((ref) async => allTrips),
          tripEquipmentRepositoryProvider.overrideWithValue(fake),
        ],
        child: const SingleChildScrollView(
          child: PassportTripCard(equipmentId: 'tank'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportTripCard)),
    );
    return (l10n, fake);
  }

  testWidgets('with no trips it says so and offers Pack for a trip', (
    tester,
  ) async {
    final (l10n, _) = await pump(tester);
    expect(find.text(l10n.passport_trip_none), findsOneWidget);
    expect(find.text(l10n.passport_trip_assign), findsOneWidget);
  });

  testWidgets('shows the first trip and +N for the rest', (tester) async {
    final (l10n, _) = await pump(
      tester,
      trips: [packed('a'), packed('b'), packed('c')],
    );
    expect(find.text(l10n.passport_trip_packedFor('Trip a')), findsOneWidget);
    expect(find.text(l10n.passport_trip_packedFor('Trip b')), findsNothing);
    expect(find.text(l10n.passport_trip_more(2)), findsOneWidget);
    await tester.tap(find.text(l10n.passport_trip_more(2)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_trip_packedFor('Trip b')), findsOneWidget);
    expect(find.text(l10n.passport_trip_packedFor('Trip c')), findsOneWidget);
  });

  testWidgets('Unassign unpacks a packed trip', (tester) async {
    final (l10n, fake) = await pump(tester, trips: [packed('a')]);
    await tester.tap(find.byTooltip(l10n.passport_trip_unassign));
    await tester.pumpAndSettle();
    expect(fake.unpacked, [('a', 'tank')]);
  });

  testWidgets('a slot-only trip shows without Unassign', (tester) async {
    final (l10n, _) = await pump(
      tester,
      trips: [packed('a', slot: true, isPacked: false)],
    );
    expect(find.text(l10n.passport_trip_packedFor('Trip a')), findsOneWidget);
    expect(find.byTooltip(l10n.passport_trip_unassign), findsNothing);
    expect(find.byTooltip(l10n.passport_trip_onBoard), findsOneWidget);
  });

  testWidgets('Pack for a trip packs the picked trip', (tester) async {
    final (l10n, fake) = await pump(tester, allTrips: [trip('a')]);
    await tester.tap(find.text(l10n.passport_trip_assign));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip a'));
    await tester.pumpAndSettle();
    expect(fake.packed.map((p) => p.$1), ['a']);
    expect(fake.packed.single.$2, ['tank']);
  });

  testWidgets('New trip packs for the trip it creates', (tester) async {
    final fake = _FakePacks();
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: PassportTripCard(equipmentId: 'tank'),
            ),
          ),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop('new-trip'),
              child: const Text('save trip'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          ...overrides,
          equipmentTripsProvider('tank').overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => const []),
          tripEquipmentRepositoryProvider.overrideWithValue(fake),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportTripCard)),
    );
    await tester.tap(find.text(l10n.passport_trip_assign));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.trips_picker_empty_createButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save trip'));
    await tester.pumpAndSettle();
    expect(fake.packed.map((p) => p.$1), ['new-trip']);
    expect(fake.packed.single.$2, ['tank']);
  });

  testWidgets('a card gone while the picker is open packs nothing', (
    tester,
  ) async {
    final fake = _FakePacks();
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          equipmentTripsProvider('tank').overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => [trip('a')]),
          tripEquipmentRepositoryProvider.overrideWithValue(fake),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, visible, _) => visible
              ? const SingleChildScrollView(
                  child: PassportTripCard(equipmentId: 'tank'),
                )
              : const Text('gone'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportTripCard)),
    );
    await tester.tap(find.text(l10n.passport_trip_assign));
    await tester.pumpAndSettle();
    // The passport closes underneath the open picker.
    show.value = false;
    await tester.pump();
    await tester.tap(find.text('Trip a'));
    await tester.pumpAndSettle();
    expect(fake.packed, isEmpty);
    expect(find.text(l10n.passport_trip_failed), findsNothing);
  });

  testWidgets('a failed unpack says so', (tester) async {
    final (l10n, _) = await pump(tester, trips: [packed('a')], failing: true);
    await tester.tap(find.byTooltip(l10n.passport_trip_unassign));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_trip_failed), findsOneWidget);
  });
}

class _FakePacks extends TripEquipmentRepository {
  _FakePacks({this.failing = false});

  final bool failing;
  final packed = <(String, List<String>)>[];
  final unpacked = <(String, String)>[];

  @override
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    if (failing) throw StateError('database is locked');
    packed.add((tripId, equipmentIds.toList()));
    return equipmentIds.length;
  }

  @override
  Future<void> unpack(String tripId, String equipmentId) async {
    if (failing) throw StateError('database is locked');
    unpacked.add((tripId, equipmentId));
  }
}
