import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/test_database.dart';

/// Issue #2943. A delete and the row it removes are ordered by their sync
/// clocks (HLC) whenever both carry one, for every entity, in both
/// directions. The wall-clock guards (`updatedAt` against this device's
/// `lastSync`, or against the tombstone's `deletedAt`) mix two devices'
/// clocks, so a row this device never touched read as edited here whenever
/// the peer's clock ran ahead, or an earlier sync had a failed record. They
/// stay as the fallback for a row or tombstone with no clock.
void main() {
  late FakeCloudStorageProvider cloud;
  late SyncDataSerializer serializer;

  setUp(() async {
    // The clock is process-wide and seeds once, so a far-future stamp a
    // previous file received would otherwise outrank every clock here.
    SyncClock.instance.reset();
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: serializer,
    cloudProvider: cloud,
  );

  String clock(int physicalTime, String node, {int counter = 0}) =>
      Hlc(physicalTime, counter, node).toString();

  SyncPayload peerPayload({
    SyncData data = const SyncData(),
    Map<String, List<SyncDeletion>> deletions = const {},
    int exportedAt = 9000,
  }) => SyncPayload(
    version: syncFormatVersion,
    exportedAt: exportedAt,
    deviceId: 'peer-dev',
    checksum: sha256.convert(utf8.encode(jsonEncode(data.toJson()))).toString(),
    data: data,
    deletions: deletions,
  );

  Future<void> seedPeerPayload({
    SyncData data = const SyncData(),
    Map<String, List<SyncDeletion>> deletions = const {},
    int exportedAt = 9000,
  }) => seedPeerBaseFromPayload(
    cloud,
    'peer-dev',
    peerPayload(data: data, deletions: deletions, exportedAt: exportedAt),
  );

  Future<Map<String, dynamic>?> conflictFor(String entity, String id) async {
    for (final c in await SyncRepository().getConflictRecords()) {
      if (c.entityType == entity && c.recordId == id) {
        return jsonDecode(c.conflictData!) as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// A dive this device holds as it received it: [updatedAt] and [hlc] are
  /// the writer's, and nothing is pending.
  Future<void> seedReceivedDive(
    String id, {
    required int updatedAt,
    required String hlc,
  }) async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: id, diveNumber: 1),
    );
    final row = await serializer.fetchRecord('dives', id);
    await serializer.upsertRecord('dives', {
      ...row!,
      'updatedAt': updatedAt,
      'hlc': hlc,
    });
  }

  group('A peer deletion against a local row, both with a clock', () {
    test('the reporter scenario: a received dive this device never touched '
        'is deleted with no conflict although lastSync is behind its '
        'updatedAt', () async {
      final diveRepo = DiveRepository();

      // Device A creates the dive, then deletes it. B's copy is A's row as
      // it was before the delete.
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-x', diveNumber: 1),
      );
      final aRow = await serializer.fetchRecord('dives', 'dive-x');
      await diveRepo.deleteDive('dive-x');
      await seedPeerLog(cloud, 'device-a');

      // Device B: A's row, stamped by A's clock ahead of B's lastSync.
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-x', diveNumber: 1),
      );
      await serializer.upsertRecord('dives', {...aRow!, 'updatedAt': 5000000});
      await SyncRepository().clearPendingRecords();
      await setLastSync(DateTime.fromMillisecondsSinceEpoch(4000000));

      final result = await buildService().performSync();

      expect(result.conflictsFound, 0);
      expect(result.status, isNot(SyncResultStatus.hasConflicts));
      expect(await conflictFor('dives', 'dive-x'), isNull);
      expect(
        await serializer.fetchRecord('dives', 'dive-x'),
        isNull,
        reason:
            "the delete's clock is after the row's, so it applies whatever "
            'the two wall clocks say',
      );
    });

    test('a dive stamped by a fast wall clock is deleted with no conflict '
        'when the delete is later by clock', () async {
      // B's fast clock stamped the edit at 8000; A received it (its clock
      // moved past 8000) and deleted the dive at A's wall time 6000.
      await seedReceivedDive(
        'dive-fast',
        updatedAt: 8000,
        hlc: clock(8000, 'device-b'),
      );
      await seedPeerPayload(
        deletions: {
          'dives': [
            SyncDeletion(
              id: 'dive-fast',
              deletedAt: 6000,
              hlc: clock(8000, 'device-a', counter: 1),
            ),
          ],
        },
      );
      await impersonateFreshDevice();
      await setLastSync(DateTime.fromMillisecondsSinceEpoch(9000));

      final result = await buildService().performSync();

      expect(result.conflictsFound, 0);
      expect(await conflictFor('dives', 'dive-fast'), isNull);
      expect(await serializer.fetchRecord('dives', 'dive-fast'), isNull);
    });

    test('a dive whose clock is later than the delete is kept as a deletion '
        'conflict, whatever the wall clocks say', () async {
      // Wall clocks alone read this row as older than the delete and
      // unchanged since the last sync, so they would delete it.
      await seedReceivedDive(
        'dive-newer',
        updatedAt: 3000,
        hlc: clock(9000, 'device-b'),
      );
      final deleteClock = clock(6000, 'device-a');
      await seedPeerPayload(
        deletions: {
          'dives': [
            SyncDeletion(id: 'dive-newer', deletedAt: 5000, hlc: deleteClock),
          ],
        },
      );
      await impersonateFreshDevice();
      await setLastSync(DateTime.fromMillisecondsSinceEpoch(9500));

      final result = await buildService().performSync();

      expect(result.conflictsFound, 1);
      expect(await serializer.fetchRecord('dives', 'dive-newer'), isNotNull);
      final conflict = await conflictFor('dives', 'dive-newer');
      expect(conflict, isNotNull);
      expect(conflict!['_deleted'], isTrue);
      expect(conflict['deletedAt'], 5000);
      expect(conflict['hlc'], deleteClock);
    });

    test('a row ordered by its clock alone is stamped with its clock time '
        'when it conflicts', () async {
      // Every clocked parent has a timestamp today; a row that lacks one
      // still conflicts, dated by its own clock rather than failing.
      await seedReceivedDive(
        'dive-unstamped',
        updatedAt: 3000,
        hlc: clock(9000, 'device-b'),
      );
      await seedPeerPayload(
        deletions: {
          'dives': [
            SyncDeletion(
              id: 'dive-unstamped',
              deletedAt: 5000,
              hlc: clock(6000, 'device-a'),
            ),
          ],
        },
      );
      await impersonateFreshDevice();

      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: _UnstampedDivesSerializer(),
        cloudProvider: cloud,
      ).performSync();

      expect(result.conflictsFound, 1);
      final record = (await SyncRepository().getConflictRecords()).singleWhere(
        (c) => c.recordId == 'dive-unstamped',
      );
      expect(record.localUpdatedAt, 9000);
    });

    test('a tombstone with no clock still falls back to the wall-clock '
        'age guard', () async {
      await seedReceivedDive(
        'dive-legacy',
        updatedAt: 8000,
        hlc: clock(8000, 'device-b'),
      );
      await seedPeerPayload(
        deletions: {
          'dives': [const SyncDeletion(id: 'dive-legacy', deletedAt: 5000)],
        },
      );
      await impersonateFreshDevice();
      await setLastSync(DateTime.fromMillisecondsSinceEpoch(9000));

      final result = await buildService().performSync();

      expect(result.conflictsFound, 1);
      expect(await serializer.fetchRecord('dives', 'dive-legacy'), isNotNull);
      expect(await conflictFor('dives', 'dive-legacy'), isNotNull);
    });
  });

  group('A peer live copy against a local deletion, both with a clock', () {
    /// Creates a dive, deletes it here (a tombstone carrying this device's
    /// clock), and returns the row as it was before the delete.
    Future<Map<String, dynamic>> deleteLocalDive(String id) async {
      final diveRepo = DiveRepository();
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: id, diveNumber: 1),
      );
      await buildService().performSync();
      final row = await serializer.fetchRecord('dives', id);
      await diveRepo.deleteDive(id);
      expect(await serializer.fetchRecord('dives', id), isNull);
      return row!;
    }

    test('a copy older than the delete by clock does not revive the dive, '
        'though its updatedAt is later than the delete', () async {
      final row = await deleteLocalDive('dive-stale');
      // A peer's fast clock stamped this copy before it saw the delete.
      await seedPeerPayload(
        data: SyncData(
          dives: [
            {...row, 'updatedAt': 99999999999999},
          ],
        ),
      );

      await buildService().performSync();

      expect(
        await serializer.fetchRecord('dives', 'dive-stale'),
        isNull,
        reason: "the copy's clock is the row's from before the delete",
      );
    });

    test('a copy newer than the delete by clock revives the dive, though its '
        'updatedAt is earlier than the delete', () async {
      final row = await deleteLocalDive('dive-revived');
      final later = DateTime.now().millisecondsSinceEpoch + 86400000;
      await seedPeerPayload(
        data: SyncData(
          dives: [
            {...row, 'updatedAt': 1000, 'hlc': clock(later, 'peer-dev')},
          ],
        ),
      );

      await buildService().performSync();

      expect(await serializer.fetchRecord('dives', 'dive-revived'), isNotNull);
      final remaining = await SyncRepository().getAllDeletions();
      expect(remaining.any((d) => d.recordId == 'dive-revived'), isFalse);
    });

    test('a parent revived by clock in the same payload keeps the link from '
        'its child', () async {
      final diveRepo = DiveRepository();
      Map<String, dynamic> site({required int updatedAt, String? hlc}) => {
        'id': 'site-c',
        'name': 'Reef',
        'description': '',
        'notes': '',
        'isShared': false,
        'createdAt': 1000,
        'updatedAt': updatedAt,
        'hlc': ?hlc,
      };
      await serializer.upsertRecord('diveSites', site(updatedAt: 1000));
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-c', diveNumber: 1),
      );
      final diveRow = await serializer.fetchRecord('dives', 'dive-c');
      await buildService().performSync();

      // Deleted here with a wall time no peer copy below can beat, so only
      // the clocks can revive it.
      await serializer.deleteRecord('dives', 'dive-c');
      await serializer.deleteRecord('diveSites', 'site-c');
      await SyncRepository().logDeletion(
        entityType: 'diveSites',
        recordId: 'site-c',
        deletedAt: 99999999999999,
      );

      final later = DateTime.now().millisecondsSinceEpoch + 86400000;
      await seedPeerPayload(
        data: SyncData(
          diveSites: [site(updatedAt: 9000, hlc: clock(later, 'peer-dev'))],
          dives: [
            {
              ...diveRow!,
              'siteId': 'site-c',
              'updatedAt': 9000,
              'hlc': clock(later, 'peer-dev', counter: 1),
            },
          ],
        ),
      );

      final result = await buildService().performSync();

      expect(result.status, isNot(SyncResultStatus.error));
      expect(await serializer.fetchRecord('diveSites', 'site-c'), isNotNull);
      final dive = await serializer.fetchRecord('dives', 'dive-c');
      expect(dive, isNotNull);
      expect(
        dive!['siteId'],
        'site-c',
        reason:
            'dives merge before diveSites, so the revival must already be '
            'known when the dive is applied',
      );
    });
  });

  /// A parent that resolves by its clock alone (no updatedAt merge flag:
  /// species, media, diveTanks, diveDataSources) is revived by the merge
  /// guard when its copy is newer, so the revived-parent precompute must see
  /// it too, or a child in the same payload is dropped against a tombstone
  /// that no longer stands.
  group('A clock-only parent revived in the same payload as its child', () {
    Future<void> deleteLocalSpecies() async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'dive-s', diveNumber: 1),
      );
      await serializer.upsertRecord('species', {
        'id': 'sp-1',
        'commonName': 'Manta',
        'category': 'fish',
        'isBuiltIn': false,
      });
      await buildService().performSync();
      await serializer.deleteRecord('species', 'sp-1');
      await SyncRepository().logDeletion(
        entityType: 'species',
        recordId: 'sp-1',
        deletedAt: 99999999999999,
      );
    }

    SyncData revivedWithChild() {
      final later = DateTime.now().millisecondsSinceEpoch + 86400000;
      return SyncData(
        species: [
          {
            'id': 'sp-1',
            'commonName': 'Manta',
            'category': 'fish',
            'isBuiltIn': false,
            'hlc': clock(later, 'peer-dev'),
          },
        ],
        sightings: [
          {
            'id': 'sgt-1',
            'diveId': 'dive-s',
            'speciesId': 'sp-1',
            'count': 1,
            'notes': '',
            'hlc': clock(later, 'peer-dev', counter: 1),
          },
        ],
      );
    }

    Future<void> expectRevivedWithChild() async {
      expect(await serializer.fetchRecord('species', 'sp-1'), isNotNull);
      expect(
        await serializer.fetchRecord('sightings', 'sgt-1'),
        isNotNull,
        reason: 'the sighting must not be dropped for a species coming back',
      );
    }

    test('through the streaming base apply', () async {
      await deleteLocalSpecies();
      await seedPeerPayload(data: revivedWithChild());

      final result = await buildService().performSync();

      expect(result.status, isNot(SyncResultStatus.error));
      await expectRevivedWithChild();
    });

    test('through the inline base apply', () async {
      await deleteLocalSpecies();
      await seedPeerPayload(data: revivedWithChild());

      final result =
          await (buildService()
                ..baseParseClientSpawn = (_) async =>
                    throw StateError('forced inline fallback'))
              .performSync();

      expect(result.status, isNot(SyncResultStatus.error));
      await expectRevivedWithChild();
    });

    test('through the in-memory payload apply', () async {
      await deleteLocalSpecies();

      final result = await buildService().debugApplyPayload(
        peerPayload(data: revivedWithChild()),
      );

      expect(result.recordsFailed, 0);
      await expectRevivedWithChild();
    });
  });

  /// A payload that both deletes a parent and sends it live is the
  /// publisher's current truth: the merge applies the live row over a local
  /// tombstone, so a child in the same payload keeps its link to it.
  group('A parent the same payload deletes and sends live', () {
    Map<String, dynamic> site() => {
      'id': 'site-k',
      'name': 'Reef',
      'description': '',
      'notes': '',
      'isShared': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    };

    Future<Map<String, dynamic>> deleteLocalSite() async {
      await serializer.upsertRecord('diveSites', site());
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'dive-k', diveNumber: 1),
      );
      final dive = await serializer.fetchRecord('dives', 'dive-k');
      await buildService().performSync();
      await serializer.deleteRecord('dives', 'dive-k');
      await serializer.deleteRecord('diveSites', 'site-k');
      await SyncRepository().logDeletion(
        entityType: 'diveSites',
        recordId: 'site-k',
        deletedAt: 99999999999999,
      );
      return dive!;
    }

    SyncPayload contradictedPayload(Map<String, dynamic> dive) => peerPayload(
      data: SyncData(
        diveSites: [site()],
        dives: [
          {...dive, 'siteId': 'site-k'},
        ],
      ),
      deletions: {
        'diveSites': [const SyncDeletion(id: 'site-k', deletedAt: 500)],
      },
    );

    Future<void> expectSiteKeptWithLink() async {
      expect(await serializer.fetchRecord('diveSites', 'site-k'), isNotNull);
      final dive = await serializer.fetchRecord('dives', 'dive-k');
      expect(dive, isNotNull);
      expect(
        dive!['siteId'],
        'site-k',
        reason: 'the site comes back, so the dive must keep its link',
      );
    }

    test('through the streaming base apply', () async {
      final dive = await deleteLocalSite();
      await seedPeerBaseFromPayload(
        cloud,
        'peer-dev',
        contradictedPayload(dive),
      );

      final result = await buildService().performSync();

      expect(result.status, isNot(SyncResultStatus.error));
      await expectSiteKeptWithLink();
    });

    test('through the in-memory payload apply', () async {
      final dive = await deleteLocalSite();

      final result = await buildService().debugApplyPayload(
        contradictedPayload(dive),
      );

      expect(result.recordsFailed, 0);
      await expectSiteKeptWithLink();
    });
  });
}

/// Reads dives without their timestamps, so a dive can only be ordered by
/// its clock.
class _UnstampedDivesSerializer extends SyncDataSerializer {
  @override
  Future<Map<String, dynamic>?> fetchRecord(
    String entityType,
    String recordId,
  ) async {
    final row = await super.fetchRecord(entityType, recordId);
    if (entityType != 'dives' || row == null) return row;
    return {...row}
      ..remove('updatedAt')
      ..remove('createdAt');
  }
}
