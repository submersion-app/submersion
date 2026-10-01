import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Deleting a profile hands its shared trips and sites to a survivor; the
/// survivor's own hides of them go, or it would own items it cannot see
/// (issue #2594).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['heir', 'leaving']);
    await db.customStatement(
      "UPDATE divers SET is_default = 1 WHERE id = 'heir'",
    );
    await seedTrip(db, 'shared', owner: 'leaving', shared: true);
    await seedSite(db, 'pier', owner: 'leaving', shared: true);
    final hides = ProfileHidesRepository();
    await hides.hide(SharedItemKind.trip, 'shared', 'heir');
    await hides.hide(SharedItemKind.site, 'pier', 'heir');
  });

  tearDown(tearDownTestDatabase);

  test('the new owner\'s hides of reassigned items are tombstoned', () async {
    await DiverRepository().deleteDiverWithReassignment('leaving');
    final trip = await (db.select(
      db.trips,
    )..where((t) => t.id.equals('shared'))).getSingle();
    expect(trip.diverId, 'heir');
    expect(await db.select(db.tripHides).get(), isEmpty);
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 1);
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
  });
}
