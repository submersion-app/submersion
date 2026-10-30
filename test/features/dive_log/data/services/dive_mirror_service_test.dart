import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository dives;
  late BuddyRepository buddies;
  late DiverRepository divers;
  late SiteRepository sites;
  late ItemSharesRepository shares;
  late DiveMirrorService service;
  late String eric;
  late String chris;
  late Buddy chrisBuddy;

  Future<String> diver(String name) async => (await divers.createDiver(
    Diver(
      id: '',
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  )).id;

  Buddy buddy(String owner, String name, {String? linked, String? email}) =>
      Buddy(
        id: '',
        diverId: owner,
        linkedDiverId: linked,
        name: name,
        email: email,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    buddies = BuddyRepository();
    divers = DiverRepository();
    sites = SiteRepository();
    shares = ItemSharesRepository();
    service = DiveMirrorService();
    eric = await diver('Eric');
    chris = await diver('Chris');
    chrisBuddy = await buddies.createBuddy(buddy(eric, 'Chris', linked: chris));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> sourceDive({
    DiveSite? site,
    String? tripId,
    String? diverRoleId,
    List<String>? diverRoleIds,
    List<BuddyWithRole>? members,
  }) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        diverId: eric,
        dateTime: DateTime(2026, 6, 1, 9),
        entryTime: DateTime(2026, 6, 1, 9),
        exitTime: DateTime(2026, 6, 1, 9, 45),
        site: site,
        tripId: tripId,
        waterTemp: 18,
        notes: 'private',
        rating: 5,
        diverRoleIds: diverRoleIds ?? [?diverRoleId],
        diveNumber: 12,
      ),
    );
    await buddies.setBuddiesForDive(
      dive.id,
      members ??
          [
            BuddyWithRole(buddy: chrisBuddy, roles: [DiveRole.builtInBuddy()]),
          ],
    );
    return dive;
  }

  test('candidates lists linked buddies with no sibling yet', () async {
    final dive = await sourceDive();
    final cands = await service.candidates(dive.id);
    expect(cands.map((c) => c.diver.id), [chris]);
    expect(cands.single.buddy.id, chrisBuddy.id);
  });

  test('candidates ignores unlinked buddies', () async {
    final dave = await buddies.createBuddy(buddy(eric, 'Dave'));
    final dive = await sourceDive(
      members: [
        BuddyWithRole(buddy: dave, roles: [DiveRole.builtInBuddy()]),
      ],
    );
    expect(await service.candidates(dive.id), isEmpty);
  });

  test('mirror creates a planned sibling owned by the buddy profile', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect(outcome.mintedOutingId, isTrue);
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.diverId, chris);
    expect(sibling?.isPlanned, isTrue);
    expect(sibling?.diveNumber, isNull);
    expect(sibling?.outingId, outcome.outingId);
    expect((await dives.getDiveById(dive.id))?.outingId, outcome.outingId);
    expect(sibling?.waterTemp, 18);
    expect(
      sibling?.entryTime?.millisecondsSinceEpoch,
      DateTime(2026, 6, 1, 9).millisecondsSinceEpoch,
    );
    // unmirrored
    expect(sibling?.notes, '');
    expect(sibling?.rating, isNull);
  });

  test('the source diver becomes a linked buddy on the sibling', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    final siblingBuddies = await buddies.getBuddiesForDive(
      outcome.createdDiveIds.single,
    );
    expect(siblingBuddies, hasLength(1));
    expect(siblingBuddies.single.buddy.linkedDiverId, eric);
    expect(siblingBuddies.single.buddy.diverId, chris);
    expect(siblingBuddies.single.buddy.name, 'Eric');
    expect(siblingBuddies.single.primaryRole.id, DiveRole.buddyId);
  });

  test('the target takes the role its buddy held on the source', () async {
    final dive = await sourceDive(
      members: [
        BuddyWithRole(
          buddy: chrisBuddy,
          roles: [DiveRole.synthetic(DiveRole.instructorId)],
        ),
      ],
    );
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.diverRoleIds.firstOrNull, DiveRole.instructorId);
  });

  test('the sibling carries every role on both sides (#1221)', () async {
    final dive = await sourceDive(
      diverRoleIds: const [DiveRole.diveMasterId, DiveRole.diveGuideId],
      members: [
        BuddyWithRole(
          buddy: chrisBuddy,
          roles: [
            DiveRole.synthetic(DiveRole.instructorId),
            DiveRole.synthetic(DiveRole.safetyDiverId),
          ],
        ),
      ],
    );
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    final siblingId = outcome.createdDiveIds.single;
    final sibling = await dives.getDiveById(siblingId);
    expect(sibling?.diverRoleIds, [
      DiveRole.instructorId,
      DiveRole.safetyDiverId,
    ]);
    final siblingBuddies = await buddies.getBuddiesForDive(siblingId);
    expect(siblingBuddies.single.buddy.linkedDiverId, eric);
    expect(siblingBuddies.single.roleIds, [
      DiveRole.diveGuideId,
      DiveRole.diveMasterId,
    ]);
  });

  test(
    'other buddies are matched by name or created in the target list',
    () async {
      final dave = await buddies.createBuddy(
        buddy(eric, 'Dave', email: 'dave@example.com'),
      );
      final dive = await sourceDive(
        members: [
          BuddyWithRole(buddy: chrisBuddy, roles: [DiveRole.builtInBuddy()]),
          BuddyWithRole(buddy: dave, roles: [DiveRole.builtInBuddy()]),
        ],
      );
      final outcome = await service.mirror(
        sourceDiveId: dive.id,
        targetDiverIds: [chris],
      );
      final names = (await buddies.getBuddiesForDive(
        outcome.createdDiveIds.single,
      )).map((b) => b.buddy.name).toSet();
      expect(names, {'Eric', 'Dave'});
      final chrisList = await buddies.getAllBuddies(diverId: chris);
      expect(
        chrisList.firstWhere((b) => b.name == 'Dave').email,
        'dave@example.com',
      );
      expect(chrisList, hasLength(2));
    },
  );

  test('an unshared site is shared with the target profile only and is '
      'referenced (issue #2151)', () async {
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric),
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    // Not every profile: the mirror shares the site with Chris alone, so
    // no other profile's list gains it.
    expect((await sites.getSiteById(site.id))?.isShared, isFalse);
    expect(
      await shares.sharingOf(SharedItemKind.site, site.id),
      ItemSharing(profileIds: {chris}),
    );
    expect(outcome.addedSiteShareIds, hasLength(1));
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.site?.id, site.id);
  });

  test('a site already shared with the target by name is referenced and left '
      'alone', () async {
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric),
    );
    await shares.setSharing(
      SharedItemKind.site,
      site.id,
      ItemSharing(profileIds: {chris}),
      actingDiverId: eric,
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect(outcome.addedSiteShareIds, isEmpty);
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.site?.id, site.id);
  });

  test('a site shared with another profile gains the target, and undo keeps '
      'the other share', () async {
    final dana = await diver('Dana');
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric),
    );
    await shares.setSharing(
      SharedItemKind.site,
      site.id,
      ItemSharing(profileIds: {dana}),
      actingDiverId: eric,
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect(
      await shares.sharingOf(SharedItemKind.site, site.id),
      ItemSharing(profileIds: {dana, chris}),
    );

    await service.undo(outcome);

    expect(
      await shares.sharingOf(SharedItemKind.site, site.id),
      ItemSharing(profileIds: {dana}),
    );
  });

  test('a trip shared with the target by name stays on the sibling', () async {
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        diverId: eric,
        startDate: DateTime(2026, 5, 30),
        endDate: DateTime(2026, 6, 6),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await shares.setSharing(
      SharedItemKind.trip,
      trip.id,
      ItemSharing(profileIds: {chris}),
      actingDiverId: eric,
    );
    final dive = await sourceDive(tripId: trip.id);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.tripId, trip.id);
  });

  test(
    'a trip that does not reach the target is left off the sibling',
    () async {
      final dana = await diver('Dana');
      final trip = await TripRepository().createTrip(
        Trip(
          id: '',
          name: 'Bonaire',
          diverId: eric,
          startDate: DateTime(2026, 5, 30),
          endDate: DateTime(2026, 6, 6),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await shares.setSharing(
        SharedItemKind.trip,
        trip.id,
        ItemSharing(profileIds: {dana}),
        actingDiverId: eric,
      );
      final dive = await sourceDive(tripId: trip.id);
      final outcome = await service.mirror(
        sourceDiveId: dive.id,
        targetDiverIds: [chris],
      );
      final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
      expect(sibling?.tripId, isNull);
    },
  );

  test('another profile\'s private site is not shared by the mirror', () async {
    // Ann made her site private after Eric logged a dive there: only Ann
    // changes its sharing (issue #2594), so the sibling goes without it.
    final ann = await diver('Ann');
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Ann Reef', diverId: ann),
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect((await sites.getSiteById(site.id))?.isShared, isFalse);
    expect(outcome.addedSiteShareIds, isEmpty);
    expect(
      await shares.sharingOf(SharedItemKind.site, site.id),
      ItemSharing.none,
    );
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.site, isNull);
  });

  test(
    'candidates is empty once a sibling exists, and mirror is idempotent',
    () async {
      final dive = await sourceDive();
      await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
      expect(await service.candidates(dive.id), isEmpty);
      final again = await service.mirror(
        sourceDiveId: dive.id,
        targetDiverIds: [chris],
      );
      expect(again.createdDiveIds, isEmpty);
      expect(again.mintedOutingId, isFalse);
      expect((await dives.getDivesByOutingId(again.outingId)).length, 2);
    },
  );

  test('undo takes back the share the mirror added', () async {
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric),
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect(
      await shares.sharingOf(SharedItemKind.site, site.id),
      ItemSharing(profileIds: {chris}),
    );

    await service.undo(outcome);

    expect(
      await shares.sharingOf(SharedItemKind.site, site.id),
      ItemSharing.none,
    );
  });

  test('undo leaves a site that was already shared alone', () async {
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric, isShared: true),
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );

    await service.undo(outcome);

    expect((await sites.getSiteById(site.id))?.isShared, isTrue);
  });

  test('undo removes the siblings and a minted outing id', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    await service.undo(outcome);
    expect(await dives.getDiveById(outcome.createdDiveIds.single), isNull);
    expect((await dives.getDiveById(dive.id))?.outingId, isNull);
  });
}
