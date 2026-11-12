import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Tag, Buddy;
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Saving a dive writes only the dive types, tags and buddies that changed,
/// so a link that stays keeps its row, and reverting the save puts every
/// link back (#4477). A rewrite under fresh ids clashed with the unique
/// keys on dive types and tags when reverted.
void main() {
  late AppDatabase db;
  final changeLog = ChangeLogRepository();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  /// Every row of [table], less the columns a write stamps afresh.
  Future<List<Map<String, Object?>>> rows(String table) async => [
    for (final row
        in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
      {
        for (final e in row.data.entries)
          if (!const {'updated_at', 'hlc'}.contains(e.key)) e.key: e.value,
      },
  ];

  /// Runs [body] in an operation of its own, and returns it.
  Future<String> inOperation(Future<void> Function() body) async {
    late String operationId;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label: 'Edit dive',
      body: () async {
        operationId = ChangeLogScope.currentOperationId!;
        await body();
      },
    );
    await changeLog.settleAll();
    return operationId;
  }

  Future<void> revert(String operationId) async {
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await service.execute(await service.planOperation(operationId));
  }

  /// [save] made in an operation, then reverted, leaves [tables] as before.
  Future<void> expectRevertRestores(
    List<String> tables,
    Future<void> Function() save,
  ) async {
    final before = {for (final t in tables) t: await rows(t)};
    final operation = await inOperation(save);
    await revert(operation);
    expect({for (final t in tables) t: await rows(t)}, before);
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
  });
  tearDown(tearDownTestDatabase);

  group('dive types', () {
    final dives = DiveRepository();

    setUp(() async {
      final dive = (await dives.getDiveById('dive'))!;
      await dives.updateDive(dive.copyWith(diveTypeIds: const ['shore']));
      await changeLog.settleAll();
    });

    test('reverting an edit that kept the types puts the dive back', () async {
      final dive = (await dives.getDiveById('dive'))!;
      await expectRevertRestores(const [
        'dives',
        'dive_dive_types',
      ], () => dives.updateDive(dive.copyWith(notes: 'Edited')));
    });

    test('reverting an edit that changed the types puts them back', () async {
      final dive = (await dives.getDiveById('dive'))!;
      await expectRevertRestores(
        const ['dives', 'dive_dive_types'],
        () => dives.updateDive(
          dive.copyWith(diveTypeIds: const ['wreck', 'shore']),
        ),
      );
      expect((await dives.getDiveById('dive'))!.diveTypeIds, ['shore']);
    });

    test('reverting a reorder puts the types back in order', () async {
      var dive = (await dives.getDiveById('dive'))!;
      await dives.updateDive(
        dive.copyWith(diveTypeIds: const ['shore', 'wreck']),
      );
      await changeLog.settleAll();
      dive = (await dives.getDiveById('dive'))!;

      await expectRevertRestores(
        const ['dives', 'dive_dive_types'],
        () => dives.updateDive(
          dive.copyWith(diveTypeIds: const ['wreck', 'shore']),
        ),
      );
      final reverted = (await dives.getDiveById('dive'))!;
      expect(reverted.diveTypeIds, ['shore', 'wreck']);
    });
  });

  group('tags', () {
    final tags = TagRepository();
    late Tag wreck;
    late Tag night;

    setUp(() async {
      wreck = await tags.createTag(
        Tag(
          id: 'wreck',
          diverId: 'me',
          name: 'Wreck',
          createdAt: epoch,
          updatedAt: epoch,
        ),
      );
      night = await tags.createTag(
        Tag(
          id: 'night',
          diverId: 'me',
          name: 'Night',
          createdAt: epoch,
          updatedAt: epoch,
        ),
      );
      await tags.setTagsForDive('dive', [wreck]);
      await changeLog.settleAll();
    });

    test('saving the same tags leaves their rows alone', () async {
      final before = await rows('dive_tags');

      await tags.setTagsForDive('dive', [wreck]);

      expect(await rows('dive_tags'), before);
    });

    test('adding a tag keeps the row of the one that stays', () async {
      final before = await rows('dive_tags');

      await tags.setTagsForDive('dive', [wreck, night]);

      final after = await rows('dive_tags');
      expect(after.map((r) => r['tag_id']).toSet(), {'wreck', 'night'});
      expect(after.firstWhere((r) => r['tag_id'] == 'wreck'), before.single);
    });

    test('dropping a tag deletes only its row', () async {
      await tags.setTagsForDive('dive', [wreck, night]);
      final kept = (await rows(
        'dive_tags',
      )).firstWhere((r) => r['tag_id'] == 'night');

      await tags.setTagsForDive('dive', [night]);

      expect((await rows('dive_tags')).single, kept);
    });

    test('reverting a save that kept the tags puts them back', () async {
      await expectRevertRestores(const [
        'dive_tags',
      ], () => tags.setTagsForDive('dive', [wreck]));
    });

    test('reverting a save that added a tag puts the old set back', () async {
      await expectRevertRestores(const [
        'dive_tags',
      ], () => tags.setTagsForDive('dive', [wreck, night]));
    });

    test('a bulk replace keeps the row of a tag that stays', () async {
      final before = await rows('dive_tags');

      await DiveRepository().bulkReplaceTags(['dive'], ['wreck', 'night']);

      final after = await rows('dive_tags');
      expect(after.firstWhere((r) => r['tag_id'] == 'wreck'), before.single);
    });

    test('reverting a bulk replace puts the old tags back', () async {
      await expectRevertRestores(const [
        'dive_tags',
      ], () => DiveRepository().bulkReplaceTags(['dive'], ['wreck', 'night']));
    });

    test('reverting a save that swapped a tag puts the old set back', () async {
      await expectRevertRestores(const [
        'dive_tags',
      ], () => tags.setTagsForDive('dive', [night]));
    });
  });

  group('buddies', () {
    final buddies = BuddyRepository();
    late Buddy samBuddy;
    late Buddy alexBuddy;

    DiveRole role(String id) => DiveRole(
      id: id,
      name: id,
      isBuiltIn: true,
      createdAt: epoch,
      updatedAt: epoch,
    );

    BuddyWithRole as(Buddy buddy, String roleId) =>
        BuddyWithRole(buddy: buddy, roles: [role(roleId)]);

    setUp(() async {
      samBuddy = await buddies.createBuddy(
        Buddy(
          id: 'sam',
          diverId: 'me',
          name: 'Sam',
          createdAt: epoch,
          updatedAt: epoch,
        ),
      );
      alexBuddy = await buddies.createBuddy(
        Buddy(
          id: 'alex',
          diverId: 'me',
          name: 'Alex',
          createdAt: epoch,
          updatedAt: epoch,
        ),
      );
      await buddies.setBuddiesForDive('dive', [as(samBuddy, DiveRole.buddyId)]);
      await changeLog.settleAll();
    });

    test('saving the same buddies leaves their rows alone', () async {
      final before = await rows('dive_buddies');

      await buddies.setBuddiesForDive('dive', [as(samBuddy, DiveRole.buddyId)]);

      expect(await rows('dive_buddies'), before);
    });

    test('a new role is written on the buddy\'s own row', () async {
      final before = (await rows('dive_buddies')).single;

      await buddies.setBuddiesForDive('dive', [
        as(samBuddy, DiveRole.instructorId),
      ]);

      final after = (await rows('dive_buddies')).single;
      expect(after['id'], before['id']);
      expect(after['role'], DiveRole.instructorId);
      final loaded = await buddies.getBuddiesForDive('dive');
      expect(loaded.single.roleIds, [DiveRole.instructorId]);
    });

    test('adding a buddy keeps the row of the one that stays', () async {
      final before = (await rows('dive_buddies')).single;

      await buddies.setBuddiesForDive('dive', [
        as(samBuddy, DiveRole.buddyId),
        as(alexBuddy, DiveRole.buddyId),
      ]);

      final after = await rows('dive_buddies');
      expect(after, hasLength(2));
      expect(after.firstWhere((r) => r['buddy_id'] == 'sam'), before);
    });

    test('a buddy linked twice is left with one link', () async {
      await db.customStatement(
        'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
        "VALUES ('again', 'dive', 'sam', 'buddy', 1)",
      );

      await buddies.setBuddiesForDive('dive', [as(samBuddy, DiveRole.buddyId)]);

      expect(await rows('dive_buddies'), hasLength(1));
    });

    test('reverting a save that kept the buddies puts them back', () async {
      await expectRevertRestores(
        const ['dive_buddies', 'dive_buddy_roles'],
        () =>
            buddies.setBuddiesForDive('dive', [as(samBuddy, DiveRole.buddyId)]),
      );
    });

    test('reverting a role change puts the old role back', () async {
      await expectRevertRestores(
        const ['dive_buddies', 'dive_buddy_roles'],
        () => buddies.setBuddiesForDive('dive', [
          as(samBuddy, DiveRole.instructorId),
        ]),
      );
    });

    test('a bulk replace keeps the row of a buddy who stays', () async {
      final before = (await rows('dive_buddies')).single;

      await buddies.bulkReplaceBuddies(
        ['dive'],
        [as(samBuddy, DiveRole.buddyId), as(alexBuddy, DiveRole.buddyId)],
      );

      final after = await rows('dive_buddies');
      expect(after.firstWhere((r) => r['buddy_id'] == 'sam'), before);
    });

    test('reverting a bulk replace puts the old buddies back', () async {
      await expectRevertRestores(
        const ['dive_buddies', 'dive_buddy_roles'],
        () => buddies.bulkReplaceBuddies(
          ['dive'],
          [
            as(samBuddy, DiveRole.instructorId),
            as(alexBuddy, DiveRole.buddyId),
          ],
        ),
      );
    });

    test('reverting a swap of buddies puts the old one back', () async {
      await expectRevertRestores(
        const ['dive_buddies', 'dive_buddy_roles'],
        () => buddies.setBuddiesForDive('dive', [
          as(alexBuddy, DiveRole.buddyId),
        ]),
      );
    });
  });
}
