import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Merging two profiles moves the trip and site shares naming the
/// duplicate to the keeper, as it does for equipment shares (issue #2151).
void main() {
  late AppDatabase db;

  Future<void> tripShare(String id, String trip, String diver) => db
      .into(db.tripShares)
      .insert(
        TripSharesCompanion.insert(
          id: id,
          tripId: trip,
          diverId: diver,
          createdAt: 1,
        ),
      );

  Future<void> siteShare(String id, String site, String diver) => db
      .into(db.siteShares)
      .insert(
        SiteSharesCompanion.insert(
          id: id,
          siteId: site,
          diverId: diver,
          createdAt: 1,
        ),
      );

  Future<Map<String, String>> tripShares() async => {
    for (final s in await db.select(db.tripShares).get()) s.tripId: s.diverId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['keep', 'dup', 'parent']);
    await seedTrip(db, 'parents', owner: 'parent'); // shared with dup only
    await seedTrip(db, 'both', owner: 'parent'); // with keep and dup
    await seedTrip(db, 'keeps', owner: 'keep'); // shared with dup: self-share
    await seedTrip(db, 'dups', owner: 'dup'); // shared with keep: moves to keep
    await seedSite(db, 'reef', owner: 'parent');
    await tripShare('s-parents', 'parents', 'dup');
    await tripShare('s-both-keep', 'both', 'keep');
    await tripShare('s-both-dup', 'both', 'dup');
    await tripShare('s-keeps', 'keeps', 'dup');
    await tripShare('s-dups', 'dups', 'keep');
    await siteShare('s-reef', 'reef', 'dup');
  });

  tearDown(tearDownTestDatabase);

  test(
    'the duplicate\'s shares become the keeper\'s and collisions go',
    () async {
      final repo = DiverMergeRepository();
      await repo.mergeDivers(keeperId: 'keep', duplicateId: 'dup');

      expect(await tripShares(), {'parents': 'keep', 'both': 'keep'});
      final reef = (await db.select(db.siteShares).get()).single;
      expect((reef.siteId, reef.diverId), ('reef', 'keep'));
      // Re-created under a new id, never changed in place (#2670).
      expect(reef.id, isNot('s-reef'));
      expect(await tombstoneCount(db, ItemSharesRepository.tripEntity), 4);
      expect(await tombstoneCount(db, ItemSharesRepository.siteEntity), 1);
    },
  );

  test('undo puts every share back', () async {
    final repo = DiverMergeRepository();
    final snapshot = await repo.mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    await repo.undoMerge(snapshot);

    final rows = {
      for (final s in await db.select(db.tripShares).get()) s.id: s.diverId,
    };
    expect(rows, {
      's-parents': 'dup',
      's-both-keep': 'keep',
      's-both-dup': 'dup',
      's-keeps': 'dup',
      's-dups': 'keep',
    });
    final reef = (await db.select(db.siteShares).get()).single;
    expect((reef.id, reef.diverId), ('s-reef', 'dup'));
  });
}
