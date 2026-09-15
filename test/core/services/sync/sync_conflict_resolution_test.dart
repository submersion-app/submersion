import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Coverage for the conflict-resolution path (keepLocal / keepRemote /
/// keepBoth, incl. the _deleted branch) and getConflicts. These mutate user
/// data on resolution and previously had no tests.
void main() {
  group('Conflict resolution', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() => DatabaseService.instance.resetForTesting());

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    /// Seed a local dive and return its exported JSON map (for building the
    /// "remote" conflicting version).
    Future<Map<String, dynamic>> seedDive(String id, double maxDepth) async {
      final diveRepo = DiveRepository();
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: id, maxDepth: maxDepth),
      );
      final exported = await SyncDataSerializer().exportData(
        deviceId: 'seed',
        deletions: const [],
      );
      await SyncRepository().resetSyncState();
      return Map<String, dynamic>.from(
        exported.data.dives.firstWhere((d) => d['id'] == id),
      );
    }

    /// Put [entityType]/[recordId] into the conflict state with [remoteData]
    /// as the stored remote version.
    Future<void> raiseConflict(
      String entityType,
      String recordId,
      Map<String, dynamic> remoteData,
    ) async {
      await SyncRepository().markRecordConflict(
        entityType: entityType,
        recordId: recordId,
        conflictDataJson: jsonEncode(remoteData),
        localUpdatedAt: 1000,
      );
    }

    test('getConflicts surfaces a raised conflict', () async {
      final base = await seedDive('d-getc', 10);
      await raiseConflict('dives', 'd-getc', {...base, 'maxDepth': 99.0});

      final conflicts = await buildService().getConflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.first.entityType, 'dives');
      expect(conflicts.first.recordId, 'd-getc');
    });

    test('getConflicts resolves foreign keys on both sides (#1031)', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('tags', {
        'id': 'tag-local',
        'name': 'Wreck',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await serializer.upsertRecord('tags', {
        'id': 'tag-remote',
        'name': 'Night',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await seedDive('d-refs', 10);
      await serializer.upsertRecord('diveTags', {
        'id': 'dt-1',
        'diveId': 'd-refs',
        'tagId': 'tag-local',
        'createdAt': 1000,
      });
      await raiseConflict('diveTags', 'dt-1', {
        'id': 'dt-1',
        'diveId': 'd-refs',
        'tagId': 'tag-remote',
        'createdAt': 2000,
      });

      final conflict = (await buildService().getConflicts()).single;

      expect(
        conflict.localReferences.firstWhere((r) => r.field == 'tagId').name,
        'Wreck',
      );
      expect(
        conflict.remoteReferences.firstWhere((r) => r.field == 'tagId').name,
        'Night',
      );
    });

    test('surfaces a conflict whose local row is already gone', () async {
      // Nothing local to fetch, so there are no local fields to resolve. The
      // conflict still has to reach the dialog or the user cannot act on it.
      await raiseConflict('dives', 'd-vanished', {
        'id': 'd-vanished',
        'maxDepth': 42.0,
      });

      final conflict = (await buildService().getConflicts()).single;

      expect(conflict.localData, isEmpty);
      expect(conflict.localReferences, isEmpty);
      expect(conflict.recordId, 'd-vanished');
    });

    test('keeps a conflict when a reference lookup fails', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('tags', {
        'id': 'tag-1',
        'name': 'Wreck',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await seedDive('d-reffail', 10);
      await serializer.upsertRecord('diveTags', {
        'id': 'dt-fail',
        'diveId': 'd-reffail',
        'tagId': 'tag-1',
        'createdAt': 1000,
      });
      await raiseConflict('diveTags', 'dt-fail', {
        'id': 'dt-fail',
        'diveId': 'd-reffail',
        'tagId': 'tag-1',
        'createdAt': 2000,
      });

      final service = SyncService(
        syncRepository: SyncRepository(),
        serializer: _TagLookupFailsSerializer(),
        cloudProvider: cloud,
      );
      final conflict = (await service.getConflicts()).single;

      // Degrading to an unresolved preview is the point: dropping the
      // conflict would leave it permanently unresolvable.
      expect(conflict.recordId, 'dt-fail');
      expect(conflict.localReferences, isEmpty);
      expect(conflict.remoteReferences, isEmpty);
    });

    test(
      'keepLocal preserves the local value and clears the conflict',
      () async {
        final base = await seedDive('d-keeplocal', 10);
        await raiseConflict('dives', 'd-keeplocal', {
          ...base,
          'maxDepth': 99.0,
        });

        await buildService().resolveConflict(
          'dives',
          'd-keeplocal',
          ConflictResolution.keepLocal,
        );

        final dive = await DiveRepository().getDiveById('d-keeplocal');
        expect(dive!.maxDepth, 10, reason: 'keepLocal must not apply remote');
        expect(await buildService().getConflicts(), isEmpty);
      },
    );

    test(
      'keepRemote applies the remote value and clears the conflict',
      () async {
        final base = await seedDive('d-keepremote', 10);
        await raiseConflict('dives', 'd-keepremote', {
          ...base,
          'maxDepth': 99.0,
        });

        await buildService().resolveConflict(
          'dives',
          'd-keepremote',
          ConflictResolution.keepRemote,
        );

        final dive = await DiveRepository().getDiveById('d-keepremote');
        expect(
          dive!.maxDepth,
          99,
          reason: 'keepRemote must apply the remote row',
        );
        expect(await buildService().getConflicts(), isEmpty);
      },
    );

    test(
      'keepRemote on a deletion conflict removes the local record',
      () async {
        await seedDive('d-del', 10);
        // A deletion conflict stores a _deleted marker as the remote data.
        await raiseConflict('dives', 'd-del', {
          '_deleted': true,
          'deletedAt': 5000,
          'recordId': 'd-del',
        });

        await buildService().resolveConflict(
          'dives',
          'd-del',
          ConflictResolution.keepRemote,
        );

        expect(
          await DiveRepository().getDiveById('d-del'),
          isNull,
          reason: 'keepRemote on a deletion conflict must delete locally',
        );
        final tombstone = await DatabaseService.instance.database
            .customSelect(
              "SELECT COUNT(*) AS c FROM deletion_log "
              "WHERE entity_type = 'dives' AND record_id = 'd-del'",
            )
            .getSingle();
        expect(
          tombstone.read<int>('c'),
          1,
          reason: 'the accepted deletion must be logged so it propagates',
        );
      },
    );

    test(
      'keepRemote on a deletion conflict detaches a plan that references it',
      () async {
        await seedDive('d-planned', 10);
        // dive_plans.source_dive_id references dives with no ON DELETE
        // action, so under foreign_keys = ON a bare delete of the dive fails.
        await DivePlanRepository().savePlan(
          DivePlan(
            id: 'plan-src',
            name: 'Repeat of d-planned',
            gfLow: 40,
            gfHigh: 80,
            mode: PlanMode.oc,
            sourceDiveId: 'd-planned',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
        await raiseConflict('dives', 'd-planned', {
          '_deleted': true,
          'deletedAt': 5000,
          'recordId': 'd-planned',
        });

        await buildService().resolveConflict(
          'dives',
          'd-planned',
          ConflictResolution.keepRemote,
        );

        expect(
          await DiveRepository().getDiveById('d-planned'),
          isNull,
          reason: 'keepRemote on a deletion conflict must delete locally',
        );
        final plan = await DivePlanRepository().getPlan('plan-src');
        expect(plan, isNotNull, reason: 'the plan itself must survive');
        expect(
          plan!.sourceDiveId,
          isNull,
          reason: 'the dangling reference to the deleted dive must be cleared',
        );
        expect(await buildService().getConflicts(), isEmpty);
      },
    );

    test(
      'keepRemote on a deletion conflict relays the deleter\'s clock and time',
      () async {
        await seedDive('d-relay', 10);
        final deleterClock = const Hlc(5000, 0, 'peer').toString();
        await raiseConflict('dives', 'd-relay', {
          '_deleted': true,
          'deletedAt': 5000,
          'hlc': deleterClock,
          'recordId': 'd-relay',
        });

        await buildService().resolveConflict(
          'dives',
          'd-relay',
          ConflictResolution.keepRemote,
        );

        // Relayed onward, the tombstone still says when the peer deleted the
        // dive, not when this device resolved the conflict.
        final logged = (await SyncRepository().getAllDeletions()).single;
        expect(logged.originHlc, deleterClock);
        expect(logged.deletedAt, 5000);
      },
    );

    test(
      'keepRemote on a deletion conflict with no deletedAt stamps it now',
      () async {
        await seedDive('d-undated', 10);
        await raiseConflict('dives', 'd-undated', {
          '_deleted': true,
          'recordId': 'd-undated',
        });

        final before = DateTime.now().millisecondsSinceEpoch;
        await buildService().resolveConflict(
          'dives',
          'd-undated',
          ConflictResolution.keepRemote,
        );
        final after = DateTime.now().millisecondsSinceEpoch;

        final logged = (await SyncRepository().getAllDeletions()).single;
        expect(logged.deletedAt, inInclusiveRange(before, after));
        expect(logged.originHlc, isNull);
      },
    );

    test('keepBoth keeps the local row and duplicates the remote under a new '
        'id', () async {
      final base = await seedDive('d-both', 10);
      await raiseConflict('dives', 'd-both', {...base, 'maxDepth': 99.0});

      await buildService().resolveConflict(
        'dives',
        'd-both',
        ConflictResolution.keepBoth,
      );

      final original = await DiveRepository().getDiveById('d-both');
      expect(original!.maxDepth, 10, reason: 'original local row is preserved');

      final all = await DiveRepository().getAllDives();
      final copies = all.where((d) => d.maxDepth == 99).toList();
      expect(
        copies,
        hasLength(1),
        reason: 'the remote version is kept as a separate (new-id) dive',
      );
      expect(copies.first.id, isNot('d-both'));
    });

    test(
      'keepRemote preserves a nullable key the remote conflict map omits',
      () async {
        final diveRepo = DiveRepository();
        // A fully-synced local dive that carries a name.
        await diveRepo.createDive(
          createTestDiveWithBottomTime(
            id: 'd-omit',
            maxDepth: 10,
          ).copyWith(name: 'Local Name'),
        );
        await SyncRepository().resetSyncState();

        // A conflicting remote version that changed maxDepth but -- like an
        // older build predating the name column -- OMITS the name key. Without
        // the keepRemote overlay, `.toCompanion(false)` would write NULL and
        // clear the local name (data loss).
        final local = await SyncDataSerializer().fetchRecord('dives', 'd-omit');
        final remote = {...local!, 'maxDepth': 99.0}..remove('name');
        await raiseConflict('dives', 'd-omit', remote);

        await buildService().resolveConflict(
          'dives',
          'd-omit',
          ConflictResolution.keepRemote,
        );

        final dive = await diveRepo.getDiveById('d-omit');
        expect(
          dive!.maxDepth,
          99,
          reason: 'keepRemote applies the remote value',
        );
        expect(
          dive.name,
          'Local Name',
          reason: 'a key the remote omits must keep its local value (overlay)',
        );
      },
    );
  });
}

/// Fails only when a reference is resolved, never when the conflicting row
/// itself is loaded, so the failure lands in the reference-resolution step
/// rather than the outer conflict parse.
class _TagLookupFailsSerializer extends SyncDataSerializer {
  @override
  Future<Map<String, dynamic>?> fetchRecord(
    String entityType,
    String recordId,
  ) {
    if (entityType == 'tags') {
      throw StateError('simulated lookup failure for $recordId');
    }
    return super.fetchRecord(entityType, recordId);
  }
}
