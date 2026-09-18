import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';

import '../../../../helpers/test_database.dart';

/// The "last time here" lookup (issue #2075): the newest real dive logged
/// with a center, skipping the dive being edited and planned dives.
void main() {
  late AppDatabase db;
  late DiveCenterRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveCenterRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedCenter(String id) => db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> seedDive(
    String id, {
    required String centerId,
    required int at,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at),
          diveCenterId: Value(centerId),
          isPlanned: Value(planned),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  test('returns the newest dive at the center', () async {
    await seedCenter('c1');
    await seedCenter('c2');
    await seedDive('old', centerId: 'c1', at: 1000);
    await seedDive('new', centerId: 'c1', at: 3000);
    await seedDive('other', centerId: 'c2', at: 9000);

    expect(await repository.latestDiveIdAtCenter('c1'), 'new');
  });

  test('skips the dive being edited', () async {
    await seedCenter('c1');
    await seedDive('old', centerId: 'c1', at: 1000);
    await seedDive('new', centerId: 'c1', at: 3000);

    expect(
      await repository.latestDiveIdAtCenter('c1', excludingDiveId: 'new'),
      'old',
    );
  });

  test('skips planned dives and returns null when nothing is left', () async {
    await seedCenter('c1');
    await seedDive('plan', centerId: 'c1', at: 5000, planned: true);

    expect(await repository.latestDiveIdAtCenter('c1'), isNull);
  });
}
