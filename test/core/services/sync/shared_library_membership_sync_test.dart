import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:path/path.dart' as p;
import 'package:drift/native.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

SyncService _service(FakeCloudStorageProvider cloud) => SyncService(
  syncRepository: SyncRepository(),
  serializer: SyncDataSerializer(),
  cloudProvider: cloud,
);

void main() {
  test('a membership reaches a second device of the same profile', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
        locationHint: 'bucket/site-sync',
      ),
    );
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await tearDownTestDatabase();

    await setUpTestDatabase();
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    final rows = await SharedLibraryStore().membershipsForDiver('d1');
    expect(rows.single.locationHint, 'bucket/site-sync');
    expect(rows.single.memberId, 'm1');
    await tearDownTestDatabase();
  });

  test('a deleted membership is tombstoned to the peer', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await SharedLibraryStore().deleteMembership('ms1');
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await tearDownTestDatabase();

    await setUpTestDatabase();
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    expect(await SharedLibraryStore().membershipsForDiver('d1'), isEmpty);
    await tearDownTestDatabase();
  });

  test('the signing key reaches a second device of the profile', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final store = SharedLibraryStore();
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    final key = await store.ensureSigningKey('d1');
    await _service(cloud).performSync();
    await tearDownTestDatabase();

    await setUpTestDatabase();
    await _service(cloud).performSync();
    expect(
      (await SharedLibraryStore().signingKeyForDiver('d1'))!.privateKey,
      key.privateKey,
    );
    await tearDownTestDatabase();
  });

  test('a keyless row from another device never erases a key', () async {
    final cloud = FakeCloudStorageProvider();
    final dir = Directory.systemTemp.createTempSync('membership_keys_');
    addTearDown(() => dir.deleteSync(recursive: true));
    void open(String name) => DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase(File(p.join(dir.path, name)))),
    );
    const row = SharedLibraryMembership(
      id: 'ms1',
      diverId: 'd1',
      libraryId: 'L',
      memberId: 'm1',
      displayName: 'Ann',
      libraryName: 'Reef Survey',
      backendKind: 's3',
    );

    // Device B writes the row first, without a key, and syncs it.
    open('b.sqlite');
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertMembership(row);
    await _service(cloud).performSync();
    await tearDownTestDatabase();

    // Device A pulls it, makes the profile's key, and syncs.
    open('a.sqlite');
    await _service(cloud).performSync();
    final key = await SharedLibraryStore().ensureSigningKey('d1');
    await _service(cloud).performSync();
    await tearDownTestDatabase();

    // B, still keyless, renames itself (a newer row with no key) and syncs:
    // it adopts the key instead of erasing it.
    open('b.sqlite');
    await SharedLibraryStore().upsertMembership(
      row.copyWith(displayName: 'Ann B'),
    );
    await _service(cloud).performSync();
    expect(
      (await SharedLibraryStore().signingKeyForDiver('d1'))?.publicKey,
      key.publicKey,
    );
    await tearDownTestDatabase();

    // A pulls B's rename and keeps its key.
    open('a.sqlite');
    await _service(cloud).performSync();
    final a = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: 'L',
    ))!;
    expect(a.displayName, 'Ann B');
    expect(a.signingKey?.publicKey, key.publicKey);
    await tearDownTestDatabase();
  });
}
