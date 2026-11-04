import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// The diver's own roles on a dive are a relation, normalized as every role
/// write stores them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Map<String, Object?> roles(Map<String, Object?> change) => {
    'op': 'update',
    'entity': 'dives',
    'id': 'd1',
    'relations': {'roles': change},
  };

  Future<List<String>> stored() async =>
      (await DiveRoleLinkRepository().diverRoleIdsForDives(['d1']))['d1']!;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('roles are added and removed', () async {
    await h.run([
      roles({
        'add': [DiveRole.instructorId, DiveRole.diveGuideId],
      }),
    ]);
    expect(
      await stored(),
      unorderedEquals([DiveRole.instructorId, DiveRole.diveGuideId]),
    );

    await h.run([
      roles({
        'remove': [DiveRole.instructorId],
      }),
    ]);
    expect(await stored(), [DiveRole.diveGuideId]);
    expect(h.refreshed.last, {'d1'});
  });

  test('a role beside Solo drops it, and the plan says so', () async {
    await h.run([
      roles({
        'set': [DiveRole.soloId],
      }),
    ]);

    final plan = await h.preview([
      roles({
        'add': [DiveRole.studentId],
      }),
    ]);

    expect(plan.items.single.indirectLost['roles'], {DiveRole.soloId});
    await h.apply(plan);
    expect(await stored(), [DiveRole.studentId]);
  });

  test('Solo added beside another role is blocked, not dropped', () async {
    await h.run([
      roles({
        'add': [DiveRole.instructorId],
      }),
    ]);

    final plan = await h.preview([
      roles({
        'add': [DiveRole.soloId],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    expect(plan.items.single.block!.detail, contains(DiveRole.soloId));
  });

  test('a custom role of another profile is blocked', () async {
    await db
        .into(db.diveRoles)
        .insert(
          DiveRolesCompanion.insert(
            id: 'theirs',
            name: 'Videographer',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverB),
          ),
        );

    final plan = await h.preview([
      roles({
        'add': ['theirs'],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });
}
