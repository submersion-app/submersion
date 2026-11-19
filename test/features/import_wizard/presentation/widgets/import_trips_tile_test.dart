import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_trips_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _Dives implements DiveRepository {
  _Dives(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getDivesByIdsWithoutSamples(
    List<String> ids, {
    bool offUiIsolate = false,
    int chunkSize = 0,
  }) async => [
    for (final d in dives)
      if (ids.contains(d.id)) d,
  ];

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unexpected: ${invocation.memberName}');
}

class _Trips implements TripRepository {
  _Trips(this.trips);
  final List<Trip> trips;

  @override
  Future<Trip?> getTripById(String id) async =>
      trips.where((t) => t.id == id).firstOrNull;

  @override
  Stream<void> watchTripsChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unexpected: ${invocation.memberName}');
}

final _at = DateTime.utc(2026, 3, 10, 9);

Dive _dive(String id, String? tripId) =>
    Dive(id: id, dateTime: _at, tripId: tripId);

Trip _trip(String id, String name) => Trip(
  id: id,
  name: name,
  startDate: DateTime(2026, 3, 7),
  endDate: DateTime(2026, 3, 14),
  createdAt: _at,
  updatedAt: _at,
);

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    required List<Dive> dives,
    required List<String> ids,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveRepositoryProvider.overrideWithValue(_Dives(dives)),
          tripRepositoryProvider.overrideWithValue(
            _Trips([_trip('t1', 'Bonaire 2026'), _trip('t2', 'Red Sea')]),
          ),
        ],
        child: ImportTripsTile(importedDiveIds: ids),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists each trip with its dives, most first', (tester) async {
    final dives = [
      _dive('a', 't2'),
      for (var i = 0; i < 12; i++) _dive('b$i', 't1'),
      _dive('c', 't2'),
      _dive('d', 't2'),
      _dive('e', null),
    ];
    await pumpTile(tester, dives: dives, ids: [for (final d in dives) d.id]);

    expect(find.byKey(const Key('import_summary_trips')), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    final bonaire = find.text('Bonaire 2026: 12 dives');
    final redSea = find.text('Red Sea: 3 dives');
    expect(bonaire, findsOneWidget);
    expect(redSea, findsOneWidget);
    expect(
      tester.getTopLeft(bonaire).dy,
      lessThan(tester.getTopLeft(redSea).dy),
    );
  });

  testWidgets('one dive reads in the singular', (tester) async {
    await pumpTile(tester, dives: [_dive('a', 't2')], ids: ['a']);
    expect(find.text('Red Sea: 1 dive'), findsOneWidget);
  });

  group('tripCountDiveIds', () {
    test('counts the new dives of every profile, once', () {
      expect(
        tripCountDiveIds(
          importedDiveIds: const ['a', 'b'],
          diverOutcomes: const [
            DiverImportOutcome(
              diverId: 'me',
              name: 'Me',
              isNew: false,
              isActive: true,
              diveIds: ['a', 'b'],
            ),
            DiverImportOutcome(
              diverId: 'sam',
              name: 'Sam',
              isNew: false,
              isActive: false,
              diveIds: ['c'],
            ),
          ],
          filledDiveIds: const [],
        ),
        ['a', 'b', 'c'],
      );
    });

    test('a download filed under another profile still counts', () {
      // Such a download reports its dives only through diverOutcomes.
      expect(
        tripCountDiveIds(
          importedDiveIds: const [],
          diverOutcomes: const [
            DiverImportOutcome(
              diverId: 'sam',
              name: 'Sam',
              isNew: false,
              isActive: false,
              diveIds: ['c'],
            ),
          ],
          filledDiveIds: const [],
        ),
        ['c'],
      );
    });

    test('a filled planned dive is not a new dive', () {
      expect(
        tripCountDiveIds(
          importedDiveIds: const ['a', 'p'],
          diverOutcomes: const [],
          filledDiveIds: const ['p'],
        ),
        ['a'],
      );
    });
  });

  testWidgets('no dive in a trip shows nothing', (tester) async {
    await pumpTile(tester, dives: [_dive('a', null)], ids: ['a']);
    expect(find.byKey(const Key('import_summary_trips')), findsNothing);
  });
}
