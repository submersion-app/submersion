import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LegacyBuddyConversionService service;

  Future<void> insertDive(String id, String buddy, {int at = 1000}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value('me'),
          diveDateTime: at,
          createdAt: 1,
          updatedAt: 1,
          buddy: Value(buddy),
        ),
      );

  Future<void> insertBuddy(String id, String name) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          diverId: const Value('me'),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    service = LegacyBuddyConversionService(BuddyRepository());
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test(
    'planCandidates plans each dive and drops placeholder-only text',
    () async {
      await insertBuddy('jim', 'Jim Dunfield');
      await insertDive('d1', 'Jim Dunfield, Ann', at: 2000);
      await insertDive('d2', 'None', at: 1000);

      final data = await service.planCandidates('me');

      expect(data.diverId, 'me');
      expect(data.dives.map((d) => d.diveId), ['d1']);
      expect(data.dives.single.plan.links.map((l) => l.target), const [
        ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield'),
        NewBuddyTarget('Ann'),
      ]);
      expect(data.matcher.candidates.map((c) => c.id), ['jim']);
    },
  );

  test('planFor plans one dive against the diver buddies', () async {
    await insertBuddy('jim', 'Jim Dunfield');
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026),
      buddy: 'jim dunfield',
      diveMaster: 'Ana',
    );

    final (plan, matcher) = await service.planFor(dive, 'me');

    expect(plan.diveId, 'd1');
    expect(
      plan.links.first.target,
      const ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield'),
    );
    expect(plan.links.last.roleId, DiveRole.diveMasterId);
    expect(matcher.candidates.single.id, 'jim');
  });

  test('apply and undo round-trip through the buddy repository', () async {
    await insertDive('d1', 'Ann');
    final data = await service.planCandidates('me');

    final receipt = await service.apply(
      [for (final d in data.dives) d.plan],
      diverId: 'me',
      newBuddyNote: 'note',
    );
    expect(receipt.linkIds, hasLength(1));

    await service.undo(receipt);
    expect(await db.select(db.diveBuddies).get(), isEmpty);
    expect(await db.select(db.buddies).get(), isEmpty);
  });
}
