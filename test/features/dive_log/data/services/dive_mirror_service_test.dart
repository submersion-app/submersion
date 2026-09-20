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

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository dives;
  late BuddyRepository buddies;
  late DiverRepository divers;
  late SiteRepository sites;
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
    String? diverRoleId,
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
        waterTemp: 18,
        notes: 'private',
        rating: 5,
        diverRoleId: diverRoleId,
        diveNumber: 12,
      ),
    );
    await buddies.setBuddiesForDive(
      dive.id,
      members ??
          [BuddyWithRole(buddy: chrisBuddy, role: DiveRole.builtInBuddy())],
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
      members: [BuddyWithRole(buddy: dave, role: DiveRole.builtInBuddy())],
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
    expect(siblingBuddies.single.role.id, DiveRole.buddyId);
  });

  test('the target takes the role its buddy held on the source', () async {
    final dive = await sourceDive(
      members: [
        BuddyWithRole(
          buddy: chrisBuddy,
          role: DiveRole.synthetic(DiveRole.instructorId),
        ),
      ],
    );
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.diverRoleId, DiveRole.instructorId);
  });

  test(
    'other buddies are matched by name or created in the target list',
    () async {
      final dave = await buddies.createBuddy(
        buddy(eric, 'Dave', email: 'dave@example.com'),
      );
      final dive = await sourceDive(
        members: [
          BuddyWithRole(buddy: chrisBuddy, role: DiveRole.builtInBuddy()),
          BuddyWithRole(buddy: dave, role: DiveRole.builtInBuddy()),
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

  test('an unshared site becomes shared and is referenced', () async {
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric),
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect((await sites.getSiteById(site.id))?.isShared, isTrue);
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.site?.id, site.id);
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

  test('undo makes a site the mirror shared private again', () async {
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Blue Hole', diverId: eric),
    );
    final dive = await sourceDive(site: site);
    final outcome = await service.mirror(
      sourceDiveId: dive.id,
      targetDiverIds: [chris],
    );
    expect((await sites.getSiteById(site.id))?.isShared, isTrue);

    await service.undo(outcome);

    expect((await sites.getSiteById(site.id))?.isShared, isFalse);
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
