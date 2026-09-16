import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BuddyConversionRepository repo;

  /// The legacy text each seeded dive held when it was planned, keyed by dive
  /// id, so [plan] carries it the way the service does.
  final plannedText = <String, (String?, String?)>{};

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> insertDive(
    String id, {
    String diverId = 'me',
    String? buddy,
    String? diveMaster,
    int? number,
    int at = 1000,
    String? siteId,
  }) {
    plannedText[id] = (buddy, diveMaster);
    return db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            diveDateTime: at,
            createdAt: 1,
            updatedAt: 1,
            buddy: Value(buddy),
            diveMaster: Value(diveMaster),
            diveNumber: Value(number),
            siteId: Value(siteId),
          ),
        );
  }

  Future<void> insertBuddy(
    String id,
    String name, {
    String? diverId = 'me',
    int createdAt = 1,
  }) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          diverId: Value(diverId),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  Future<void> link(String diveId, String buddyId) => db
      .into(db.diveBuddies)
      .insert(
        DiveBuddiesCompanion.insert(
          id: '$diveId|$buddyId',
          diveId: diveId,
          buddyId: buddyId,
          createdAt: 1,
        ),
      );

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType && r.syncStatus == 'pending') r.recordId,
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType == entityType) t.recordId,
  };

  setUp(() async {
    plannedText.clear();
    db = await setUpTestDatabase();
    repo = BuddyConversionRepository();
    await insertDiver('me');
    await insertDiver('other');
  });

  tearDown(tearDownTestDatabase);

  group('candidateBuddies', () {
    test(
      'returns the diver own and unowned buddies with dive counts',
      () async {
        await insertBuddy('own', 'Ann');
        await insertBuddy('free', 'Bob', diverId: null);
        await insertBuddy('theirs', 'Cy', diverId: 'other');
        await insertDive('d1');
        await link('d1', 'own');

        final byId = {
          for (final c in await repo.candidateBuddies('me')) c.id: c,
        };

        expect(byId.keys, unorderedEquals(['own', 'free']));
        expect(byId['own']!.diveCount, 1);
        expect(byId['own']!.name, 'Ann');
        expect(byId['free']!.diverId, isNull);
        expect(byId['free']!.diveCount, 0);
      },
    );
  });

  group('unlinkedTextDives', () {
    test('lists the diver dives with unlinked text, newest first', () async {
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Blue Hole', 1, 1)",
      );
      await insertDive('old', buddy: 'Ann', at: 1000, number: 1, siteId: 's1');
      await insertDive('new', diveMaster: 'Bob', at: 2000);
      await insertDive('blank', buddy: '   ', at: 3000);
      await insertBuddy('cy', 'Cy');
      await insertDive('linked', buddy: 'Cy', at: 4000);
      await link('linked', 'cy');
      await insertDive('theirs', diverId: 'other', buddy: 'Dee', at: 5000);

      final rows = await repo.unlinkedTextDives('me');

      expect(rows.map((r) => r.diveId), ['new', 'old']);
      expect(rows.first.diveMasterText, 'Bob');
      final old = rows.last;
      expect(old.buddyText, 'Ann');
      expect(old.diveNumber, 1);
      expect(old.siteName, 'Blue Hole');
      expect(
        old.dateTime,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
    });
  });

  ConversionPlan plan(String diveId, List<PlannedLink> links) => ConversionPlan(
    diveId: diveId,
    buddyText: plannedText[diveId]?.$1,
    diveMasterText: plannedText[diveId]?.$2,
    links: links,
  );

  PlannedLink newLink(String name, [String roleId = DiveRole.buddyId]) =>
      PlannedLink(target: NewBuddyTarget(name), roleId: roleId);

  PlannedLink existing(
    String id,
    String name, [
    String roleId = DiveRole.buddyId,
  ]) => PlannedLink(
    target: ExistingBuddyTarget(buddyId: id, name: name),
    roleId: roleId,
  );

  Future<ConversionReceipt> run(List<ConversionPlan> plans) =>
      repo.apply(plans, diverId: 'me', newBuddyNote: 'converted');

  group('apply', () {
    test('creates new buddies and links them with their roles', () async {
      await insertDive('d1', buddy: 'Ann', diveMaster: 'Bob');

      final receipt = await run([
        plan('d1', [newLink('Ann'), newLink('Bob', DiveRole.diveMasterId)]),
      ]);

      final buddies = await db.select(db.buddies).get();
      expect(buddies.map((b) => b.name), unorderedEquals(['Ann', 'Bob']));
      expect(buddies.every((b) => b.diverId == 'me'), isTrue);
      expect(buddies.every((b) => b.notes == 'converted'), isTrue);
      final links = await db.select(db.diveBuddies).get();
      final nameById = {for (final b in buddies) b.id: b.name};
      expect(
        {for (final l in links) nameById[l.buddyId]: l.role},
        {'Ann': DiveRole.buddyId, 'Bob': DiveRole.diveMasterId},
      );
      expect(receipt.diveIds, ['d1']);
      expect(receipt.linkIds, unorderedEquals(links.map((l) => l.id)));
      expect(receipt.createdBuddyIds, unorderedEquals(nameById.keys));
      expect(receipt.claimedBuddyIds, isEmpty);
    });

    test('leaves the dive text columns untouched', () async {
      await insertDive('d1', buddy: 'Ann', diveMaster: 'Bob');
      await run([
        plan('d1', [newLink('Ann'), newLink('Bob', DiveRole.diveMasterId)]),
      ]);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('d1'))).getSingle();
      expect(dive.buddy, 'Ann');
      expect(dive.diveMaster, 'Bob');
      expect(dive.updatedAt, 1);
    });

    test('links an existing buddy without creating one', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('ann', 'Ann');

      final receipt = await run([
        plan('d1', [existing('ann', 'Ann')]),
      ]);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect((await db.select(db.diveBuddies).getSingle()).buddyId, 'ann');
      expect(receipt.createdBuddyIds, isEmpty);
    });

    test('creates one buddy for a new name shared by several dives', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2', buddy: 'ann');

      final receipt = await run([
        plan('d1', [newLink('Ann')]),
        plan('d2', [newLink('ann')]),
      ]);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect(await db.select(db.diveBuddies).get(), hasLength(2));
      expect(receipt.createdBuddyIds, hasLength(1));
      expect(receipt.diveIds, ['d1', 'd2']);
    });

    test('reuses a buddy created since planning', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('ann', 'Ann');

      await run([
        plan('d1', [newLink('ann')]),
      ]);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect((await db.select(db.diveBuddies).getSingle()).buddyId, 'ann');
    });

    test('falls back to the name when a planned buddy was deleted', () async {
      await insertDive('d1', buddy: 'Ann');

      final receipt = await run([
        plan('d1', [existing('gone', 'Ann')]),
      ]);

      expect(receipt.createdBuddyIds, hasLength(1));
      expect((await db.select(db.buddies).getSingle()).name, 'Ann');
    });

    test(
      'does not link a planned buddy another diver has claimed since',
      () async {
        await insertDive('d1', buddy: 'Ann');
        await insertBuddy('theirs', 'Ann', diverId: 'other');

        final receipt = await run([
          plan('d1', [existing('theirs', 'Ann')]),
        ]);

        final link = await db.select(db.diveBuddies).getSingle();
        expect(link.buddyId, isNot('theirs'));
        expect(receipt.createdBuddyIds, [link.buddyId]);
        final theirs = await (db.select(
          db.buddies,
        )..where((t) => t.id.equals('theirs'))).getSingle();
        expect(theirs.diverId, 'other');
        expect(receipt.claimedBuddyIds, isEmpty);
      },
    );

    test('writes one link when two rows resolve to one buddy', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('ann', 'Ann');

      await run([
        plan('d1', [existing('ann', 'Ann'), newLink('ANN')]),
      ]);

      expect(await db.select(db.diveBuddies).get(), hasLength(1));
    });

    test('skips a dive that gained links since planning', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('cy', 'Cy');
      await link('d1', 'cy');

      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);

      expect(receipt.isEmpty, isTrue);
      expect(await db.select(db.diveBuddies).get(), hasLength(1));
      expect(await db.select(db.buddies).get(), hasLength(1));
    });

    test('skips a dive whose buddy text changed since planning', () async {
      await insertDive('d1', buddy: 'Ann');
      final stale = plan('d1', [newLink('Ann')]);
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        const DivesCompanion(buddy: Value('Bob')),
      );

      final receipt = await run([stale]);

      expect(receipt.isEmpty, isTrue);
      expect(await db.select(db.buddies).get(), isEmpty);
      expect(await db.select(db.diveBuddies).get(), isEmpty);
    });

    test(
      'skips a dive whose dive-master text changed since planning',
      () async {
        await insertDive('d1', buddy: 'Ann', diveMaster: 'Bob');
        await insertDive('d2', buddy: 'Cy');
        final stale = plan('d1', [
          newLink('Ann'),
          newLink('Bob', DiveRole.diveMasterId),
        ]);
        await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
          const DivesCompanion(diveMaster: Value(null)),
        );

        final receipt = await run([
          stale,
          plan('d2', [newLink('Cy')]),
        ]);

        expect(receipt.diveIds, ['d2']);
        expect((await db.select(db.buddies).getSingle()).name, 'Cy');
      },
    );

    test('skips a dive deleted since planning', () async {
      final receipt = await run([
        plan('ghost', [newLink('Ann')]),
      ]);

      expect(receipt.isEmpty, isTrue);
      expect(await db.select(db.buddies).get(), isEmpty);
    });

    test('claims an unowned buddy for the diver', () async {
      await insertDive('d1', buddy: 'Leo');
      await insertBuddy('leo', 'Leo Cox', diverId: null);

      final receipt = await run([
        plan('d1', [existing('leo', 'Leo Cox')]),
      ]);

      final leo = await (db.select(
        db.buddies,
      )..where((t) => t.id.equals('leo'))).getSingle();
      expect(leo.diverId, 'me');
      expect(receipt.claimedBuddyIds, ['leo']);
      expect(await pending('buddies'), {'leo'});
    });

    test('stages the buddies and links for sync, never the dive', () async {
      await insertDive('d1', buddy: 'Ann, Bob');
      await insertBuddy('bob', 'Bob');

      final receipt = await run([
        plan('d1', [newLink('Ann'), existing('bob', 'Bob')]),
      ]);

      expect(await pending('diveBuddies'), receipt.linkIds.toSet());
      expect(await pending('buddies'), receipt.createdBuddyIds.toSet());
      expect(await pending('dives'), isEmpty);
    });

    test('announces the change once', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2', buddy: 'Bob');
      var notifications = 0;
      final sub = SyncEventBus.changes.listen((_) => notifications++);
      addTearDown(sub.cancel);

      await run([
        plan('d1', [newLink('Ann')]),
        plan('d2', [newLink('Bob')]),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });

    test('rolls everything back when a write fails', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2', buddy: 'Bob');
      await db.customStatement(
        "CREATE TRIGGER fail_d2 BEFORE INSERT ON dive_buddies "
        "WHEN NEW.dive_id = 'd2' BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );

      await expectLater(
        run([
          plan('d1', [newLink('Ann')]),
          plan('d2', [newLink('Bob')]),
        ]),
        throwsA(anything),
      );

      expect(await db.select(db.buddies).get(), isEmpty);
      expect(await db.select(db.diveBuddies).get(), isEmpty);
      expect(await db.select(db.syncRecords).get(), isEmpty);
    });
  });

  group('undo', () {
    test('removes the links and the buddies the conversion created', () async {
      await insertDive('d1', buddy: 'Ann');
      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);

      await repo.undo(receipt);

      expect(await db.select(db.diveBuddies).get(), isEmpty);
      expect(await db.select(db.buddies).get(), isEmpty);
      expect(await tombstones('diveBuddies'), receipt.linkIds.toSet());
      expect(await tombstones('buddies'), receipt.createdBuddyIds.toSet());
    });

    test('keeps a created buddy that another dive linked since', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2');
      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);
      await link('d2', receipt.createdBuddyIds.single);

      await repo.undo(receipt);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect((await db.select(db.diveBuddies).getSingle()).diveId, 'd2');
    });

    test('keeps an existing buddy it only linked', () async {
      await insertDive('d1', buddy: 'Bob');
      await insertBuddy('bob', 'Bob');
      final receipt = await run([
        plan('d1', [existing('bob', 'Bob')]),
      ]);

      await repo.undo(receipt);

      expect((await db.select(db.buddies).getSingle()).id, 'bob');
      expect(await db.select(db.diveBuddies).get(), isEmpty);
    });

    test('returns a claimed buddy to unowned', () async {
      await insertDive('d1', buddy: 'Leo');
      await insertBuddy('leo', 'Leo Cox', diverId: null);
      final receipt = await run([
        plan('d1', [existing('leo', 'Leo Cox')]),
      ]);
      await db.delete(db.syncRecords).go();

      await repo.undo(receipt);

      final leo = await (db.select(
        db.buddies,
      )..where((t) => t.id.equals('leo'))).getSingle();
      expect(leo.diverId, isNull);
      expect(await pending('buddies'), {'leo'});
    });

    test('keeps a claim that a later dive of the diver still needs', () async {
      await insertDive('d1', buddy: 'Leo');
      await insertDive('d2');
      await insertBuddy('leo', 'Leo Cox', diverId: null);
      final receipt = await run([
        plan('d1', [existing('leo', 'Leo Cox')]),
      ]);
      await link('d2', 'leo');
      await db.delete(db.syncRecords).go();

      await repo.undo(receipt);

      final leo = await (db.select(
        db.buddies,
      )..where((t) => t.id.equals('leo'))).getSingle();
      expect(leo.diverId, 'me');
      expect((await db.select(db.diveBuddies).getSingle()).diveId, 'd2');
      expect(await pending('buddies'), isEmpty);
    });

    test('returns a claim when only another diver dive links it', () async {
      await insertDive('d1', buddy: 'Leo');
      await insertDive('t1', diverId: 'other');
      await insertBuddy('leo', 'Leo Cox', diverId: null);
      await link('t1', 'leo');
      final receipt = await run([
        plan('d1', [existing('leo', 'Leo Cox')]),
      ]);

      await repo.undo(receipt);

      final leo = await (db.select(
        db.buddies,
      )..where((t) => t.id.equals('leo'))).getSingle();
      expect(leo.diverId, isNull);
    });

    test(
      'announces the change once and an empty receipt does nothing',
      () async {
        await insertDive('d1', buddy: 'Ann');
        final receipt = await run([
          plan('d1', [newLink('Ann')]),
        ]);
        var notifications = 0;
        final sub = SyncEventBus.changes.listen((_) => notifications++);
        addTearDown(sub.cancel);

        await repo.undo(receipt);
        await repo.undo(const ConversionReceipt(diverId: 'me'));
        await Future<void>.delayed(Duration.zero);

        expect(notifications, 1);
      },
    );
  });
}
