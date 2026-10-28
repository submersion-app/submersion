import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

import '../../../../helpers/test_database.dart';

/// The side trips of a trip and the larger trip of a side trip, for the
/// active profile (issue #3658).
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> trip(String id, {String? parent}) => db.customStatement(
    'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
    'created_at, updated_at) VALUES (?, ?, 0, 0, ?, 0, 0)',
    [id, id, parent],
  );

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await trip('P');
    await trip('S', parent: 'P');
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('sideTripsProvider lists the side trips', () async {
    final sides = await container.read(sideTripsProvider('P').future);
    expect(sides.map((t) => t.id), ['S']);
  });

  test('parentTripProvider names the larger trip', () async {
    expect((await container.read(parentTripProvider('S').future))!.id, 'P');
    expect(await container.read(parentTripProvider('P').future), isNull);
  });

  test("a side trip's dive editor offers the larger trip's slots", () async {
    final at = DateTime.utc(2026, 3, 9);
    final repo = TripCylinderRepository();
    for (final (tripId, label) in [('S', 'Own'), ('P', 'Shared')]) {
      await repo.createCylinder(
        TripCylinder(
          id: '',
          tripId: tripId,
          label: label,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
    final key = (
      tripId: 'S',
      atMillis: at.millisecondsSinceEpoch,
      excludeDiveId: null,
    );
    final states = await container.read(
      tripCylinderStatesAtProvider(key).future,
    );
    expect(states.map((s) => s.cylinder.label), ['Own', 'Shared']);
    final labels = await container.read(
      tripCylinderLabelsAtProvider((
        tripId: 'S',
        atMillis: at.millisecondsSinceEpoch,
      )).future,
    );
    expect(labels, hasLength(2));
  });

  /// Waits for a provider re-read after a table tick.
  Future<T> settled<T>(Future<T> Function() read, bool Function(T) done) async {
    var value = await read();
    for (var i = 0; i < 40 && !done(value); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      value = await read();
    }
    return value;
  }

  test("linking a side trip refreshes the larger trip's dives", () async {
    await db.customStatement(
      'INSERT INTO trips (id, name, start_date, end_date, created_at, '
      "updated_at) VALUES ('T', 'T', 0, 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, trip_id, created_at, '
      "updated_at) VALUES ('t1', 0, 'T', 0, 0)",
    );
    final sub = container.listen(diveIdsForTripProvider('P'), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(diveIdsForTripProvider('P').future), isEmpty);
    final t = (await TripRepository().getTripById('T'))!;
    await TripRepository().updateTrip(t.copyWith(parentTripId: 'P'));
    final ids = await settled(
      () => container.read(diveIdsForTripProvider('P').future),
      (v) => v.isNotEmpty,
    );
    expect(ids, ['t1']);
  });

  test('detaching a side trip refreshes its dive editor slots', () async {
    final at = DateTime.utc(2026, 3, 9);
    await TripCylinderRepository().createCylinder(
      TripCylinder(
        id: '',
        tripId: 'P',
        label: 'Shared',
        createdAt: at,
        updatedAt: at,
      ),
    );
    final key = (
      tripId: 'S',
      atMillis: at.millisecondsSinceEpoch,
      excludeDiveId: null,
    );
    final sub = container.listen(tripCylinderStatesAtProvider(key), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(tripCylinderStatesAtProvider(key).future),
      hasLength(1),
    );
    final s = (await TripRepository().getTripById('S'))!;
    await TripRepository().updateTrip(s.copyWith(parentTripId: null));
    final states = await settled(
      () => container.read(tripCylinderStatesAtProvider(key).future),
      (v) => v.isEmpty,
    );
    expect(states, isEmpty);
  });
}
