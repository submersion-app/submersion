import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Custom certification agencies and levels, as the certification pages keep
/// them: a name is free against the built-in ones and those the diver sees,
/// and one a certification or course uses cannot be deleted.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<String> created(String entity, Map<String, Object?> fields) async =>
      (await h.run([createOp(entity, fields)])).created.single.id;

  Future<int> sortOf(String id) async => (await (db.select(
    db.customCertificationLevels,
  )..where((l) => l.id.equals(id))).getSingle()).sortOrder;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a name the diver already sees is a duplicate', () async {
    await created('custom_agencies', {'name': 'Cave Club'});

    final plan = await h.preview([
      createOp('custom_agencies', {'name': 'cave club'}),
      createOp('custom_agencies', {'name': 'PADI'}),
      createOp('custom_levels', {
        'agency_id': 'padi',
        'name': 'open water',
        'is_progression': false,
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.duplicateRecord);
    }
  });

  // The repository refuses the second name only at apply, after the diver
  // has allowed the whole set.
  test('one name claimed twice in a set blocks the second', () async {
    Map<String, Object?> level(String name) => {
      'agency_id': 'padi',
      'name': name,
      'is_progression': false,
    };
    final plan = await h.preview([
      createOp('custom_agencies', {'name': 'Cave Club'}),
      createOp('custom_agencies', {'name': ' cave club '}),
      createOp('custom_levels', level('Sidemount Explorer')),
      createOp('custom_levels', level('SIDEMOUNT EXPLORER')),
    ]);

    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block!.reason, BlockReason.duplicateRecord);
    expect(plan.items[2].block, isNull);
    expect(plan.items[3].block!.reason, BlockReason.duplicateRecord);
  });

  test(
    'a level goes under a built-in or the diver\'s own agency only',
    () async {
      final plan = await h.preview([
        createOp('custom_levels', {
          'agency_id': 'padi',
          'name': 'Sidemount Explorer',
          'is_progression': false,
        }),
        createOp('custom_levels', {
          'agency_id': 'nowhere',
          'name': 'Ghost',
          'is_progression': false,
        }),
      ]);

      expect(plan.items[0].block, isNull);
      expect(plan.items[1].block!.reason, BlockReason.unknownReference);
    },
  );

  test('an agency or level in use cannot be deleted', () async {
    final agency = await created('custom_agencies', {'name': 'Cave Club'});
    final level = await created('custom_levels', {
      'agency_id': agency,
      'name': 'Cavern',
      'is_progression': true,
    });
    await db
        .into(db.certifications)
        .insert(
          CertificationsCompanion.insert(
            id: 'c1',
            name: 'Cavern',
            agency: agency,
            level: Value(level),
            diverId: const Value(kDiverA),
            createdAt: t,
            updatedAt: t,
          ),
        );

    for (final op in [
      deleteOp('custom_agencies', agency),
      deleteOp('custom_levels', level),
    ]) {
      final plan = await h.preview([op]);
      expect(plan.items.single.block!.reason, BlockReason.notPermitted);
      expect(plan.items.single.block!.detail, contains('Certifications'));
    }
  });

  test('an unused agency goes with its levels', () async {
    final agency = await created('custom_agencies', {'name': 'Cave Club'});
    await created('custom_levels', {
      'agency_id': agency,
      'name': 'Cavern',
      'is_progression': true,
    });

    final plan = await h.preview([deleteOp('custom_agencies', agency)]);
    expect(plan.items.single.reach.parts, {'custom_certification_levels': 1});

    await h.apply(plan);
    expect(await db.select(db.customCertificationLevels).get(), isEmpty);
    expect(await h.one('custom_agencies', agency), isNull);
  });

  // The agency's delete takes its levels with it, so a delete of one of them
  // in the same set would find no row and fail the apply.
  test('a level whose agency the set deletes is left to that delete', () async {
    final agency = await created('custom_agencies', {'name': 'Cave Club'});
    final level = await created('custom_levels', {
      'agency_id': agency,
      'name': 'Cavern',
      'is_progression': true,
    });

    final plan = await h.preview([
      deleteOp('custom_agencies', agency),
      deleteOp('custom_levels', level),
    ]);

    expect(plan.items.first.block, isNull);
    expect(plan.items.last.block!.reason, BlockReason.notPermitted);
    expect(plan.items.last.block!.detail, contains(agency));
  });

  test('moving a progression level reorders the progression', () async {
    final agency = await created('custom_agencies', {'name': 'Cave Club'});
    final ids = <String>[];
    for (final name in ['Cavern', 'Intro', 'Full Cave']) {
      ids.add(
        await created('custom_levels', {
          'agency_id': agency,
          'name': name,
          'is_progression': true,
        }),
      );
    }
    final fullCaveSlot = await sortOf(ids[0]);

    await h.run([
      updateOp('custom_levels', ids[2], {'sort_order': fullCaveSlot}),
    ]);

    expect(await sortOf(ids[2]), fullCaveSlot);
    expect(await sortOf(ids[0]), greaterThan(fullCaveSlot));
    expect(await sortOf(ids[1]), greaterThan(await sortOf(ids[0])));
  });

  test(
    'a progression level moves only into a slot of its progression',
    () async {
      final agency = await created('custom_agencies', {'name': 'Cave Club'});
      final level = await created('custom_levels', {
        'agency_id': agency,
        'name': 'Cavern',
        'is_progression': true,
      });
      final specialty = await created('custom_levels', {
        'agency_id': agency,
        'name': 'Photography',
        'is_progression': false,
      });

      for (final op in [
        updateOp('custom_levels', level, {'sort_order': 40}),
        updateOp('custom_levels', specialty, {'sort_order': 5}),
      ]) {
        final plan = await h.preview([op]);
        expect(plan.items.single.block?.reason, isNot(isNull), reason: '$op');
      }
    },
  );
}
