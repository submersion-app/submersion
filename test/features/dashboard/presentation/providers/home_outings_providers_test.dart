import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_outings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> dive(String id, DateTime at, {String? tripId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at.millisecondsSinceEpoch),
          tripId: Value(tripId),
          maxDepth: const Value(20),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> photo(String id, String diveId, {bool favorite = false}) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          diveId: Value(diveId),
          filePath: '/$id.jpg',
          isFavorite: Value(favorite),
          takenAt: const Value(1000),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Bonaire',
            startDate: 0,
            endDate: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await dive('b1', DateTime.utc(2026, 5, 3, 9), tripId: 't1');
    await dive('b2', DateTime.utc(2026, 5, 4, 9), tripId: 't1');
    await dive('pool', DateTime.utc(2025, 10, 26, 9));
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test(
    'pairs each outing with its cover and leaves coverless ones null',
    () async {
      await photo('p1', 'b1');
      await photo('p2', 'b2', favorite: true);

      final outings = await container.read(homeRecentOutingsProvider.future);
      expect(outings, hasLength(2));
      expect(outings.first.outing.tripId, 't1');
      expect(outings.first.cover?.id, 'p2');
      expect(outings.last.outing.diveIds, ['pool']);
      expect(outings.last.cover, isNull);
    },
  );

  test('a new photo rebuilds the outings', () async {
    final sub = container.listen(homeRecentOutingsProvider, (_, _) {});
    addTearDown(sub.close);
    final before = await container.read(homeRecentOutingsProvider.future);
    expect(before.last.cover, isNull);

    await photo('p3', 'pool');
    // The media tick is debounced; wait for the rebuild to land.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final now = container.read(homeRecentOutingsProvider).value;
      if (now != null && now.last.cover != null) break;
    }
    final after = await container.read(homeRecentOutingsProvider.future);
    expect(after.last.cover?.id, 'p3');
  });

  test('no dives give no outings', () async {
    await db.delete(db.dives).go();
    expect(await container.read(homeRecentOutingsProvider.future), isEmpty);
  });
}
