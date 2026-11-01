import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// `checklist_id` has no SQL `ON DELETE` action, and a peer's tombstone for a
/// checklist need not name the children this device holds: an item added here
/// that the peer never saw has no tombstone of its own. The apply runs with
/// foreign keys deferred, so the parent's delete goes through, and the repair
/// at the end of it removes what the delete orphaned.
void main() {
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  test('a checklist tombstone alone also removes its children here', () async {
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final repository = TripChecklistRepository();
    final checklist = await TripChecklistsRepository().createChecklist(
      tripId: trip.id,
      name: 'Dive equipment',
    );
    final section = await repository.createSection(
      checklistId: checklist.id,
      title: 'Gear',
    );
    final item = await repository.createItem(
      TripChecklistItem(
        id: '',
        checklistId: checklist.id,
        title: 'Mask',
        sectionId: section.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await SyncRepository().resetSyncState();

    const data = SyncData();
    final payload = SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: 'peer',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: {
        'tripChecklists': [
          SyncDeletion(
            id: checklist.id,
            deletedAt: DateTime.now().millisecondsSinceEpoch + 60000,
          ),
        ],
      },
    );
    await seedPeerBaseFromPayload(cloud, 'peer', payload);

    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();

    expect(result.status, isNot(SyncResultStatus.error));
    expect(
      await TripChecklistsRepository().getChecklistsForTrip(trip.id),
      isEmpty,
    );
    final serializer = SyncDataSerializer();
    expect(await serializer.fetchRecord('tripChecklistItems', item.id), isNull);
    expect(
      await serializer.fetchRecord('tripChecklistSections', section.id),
      isNull,
    );
  });
}
