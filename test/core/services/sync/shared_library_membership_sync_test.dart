import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
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

  test(
    "private notes on a library site reach the profile's second device",
    () async {
      final cloud = FakeCloudStorageProvider();
      Future<void> deviceWithLibrarySite() async {
        await setUpTestDatabase();
        await DiverRepository().createDiver(
          Diver(
            id: 'd1',
            name: 'Ann',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        // The library pull put the site here; it never crosses personal sync.
        await SiteRepository().createSite(
          const DiveSite(id: 's', name: 'Blue', sharedLibraryId: 'L'),
        );
      }

      await deviceWithLibrarySite();
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'surge at the corner',
        rating: 4,
      );
      expect(
        (await _service(cloud).performSync()).status,
        SyncResultStatus.success,
      );
      await tearDownTestDatabase();

      await deviceWithLibrarySite();
      expect(
        (await _service(cloud).performSync()).status,
        SyncResultStatus.success,
      );
      final site = (await SiteRepository().getSiteById('s'))!;
      expect(site.notes, 'surge at the corner');
      expect(site.rating, 4);
      await tearDownTestDatabase();
    },
  );

  test("the library's current key wins over a newer row's old one", () async {
    final cloud = FakeCloudStorageProvider();
    Future<void> profile() => DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    SharedLibraryMembership membership(String keyId) => SharedLibraryMembership(
      id: 'ms1',
      diverId: 'd1',
      libraryId: 'L',
      memberId: 'm1',
      displayName: 'Ann',
      libraryName: 'Reef Survey',
      backendKind: 's3',
      libraryKeyId: keyId,
      libraryKey: 'key-$keyId',
    );

    // The tablet changed the passphrase: it holds the new key.
    await setUpTestDatabase();
    await profile();
    await SharedLibraryStore().upsertMembership(membership('k2'));
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    await tearDownTestDatabase();

    // The phone's row is newer but holds the key from before; its library
    // row already names the new key.
    await setUpTestDatabase();
    await profile();
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        encrypted: true,
        keyId: 'k2',
      ),
    );
    await SharedLibraryStore().upsertMembership(membership('k1'));
    expect(
      (await _service(cloud).performSync()).status,
      SyncResultStatus.success,
    );
    final row = (await SharedLibraryStore().membershipsForDiver('d1')).single;
    expect(row.libraryKeyId, 'k2');
    expect(row.libraryKey, 'key-k2');
    await tearDownTestDatabase();
  });

  test(
    "a newer key from the profile's other device waits for the library",
    () async {
      final cloud = FakeCloudStorageProvider();
      final first = await LibraryCipher.generate();
      final second = await LibraryCipher.generate();
      Future<void> profile() => DiverRepository().createDiver(
        Diver(
          id: 'd1',
          name: 'Ann',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      Future<SharedLibraryMembership> membership(LibraryCipher key) async =>
          SharedLibraryMembership(
            id: 'ms1',
            diverId: 'd1',
            libraryId: 'L',
            memberId: 'm1',
            displayName: 'Ann',
            libraryName: 'Reef Survey',
            backendKind: 's3',
            libraryKeyId: key.keyId,
            libraryKey: await key.exportKey(),
          );

      // The tablet changed the passphrase: it holds the new key.
      await setUpTestDatabase();
      await profile();
      await SharedLibraryStore().upsertMembership(await membership(second));
      await _service(cloud).performSync();
      await tearDownTestDatabase();

      // The phone has not synced the library since: it still names the old
      // key, and its personal sync runs first.
      await setUpTestDatabase();
      await profile();
      await SharedLibraryStore().upsertLibrary(
        SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
          encrypted: true,
          keyId: first.keyId,
        ),
      );
      await SharedLibraryStore().upsertMembership(await membership(first));
      await _service(cloud).performSync();
      final store = SharedLibraryStore();
      expect(
        (await store.membershipsForDiver('d1')).single.libraryKeyId,
        first.keyId,
      );
      // The library sync, seeing the manifest name the new key, takes it.
      final taken = await store.takeSpareKey(
        'L',
        keyId: second.keyId,
        diverId: 'd1',
      );
      expect(taken?.keyId, second.keyId);
      expect(
        (await store.membershipsForDiver('d1')).single.libraryKeyId,
        second.keyId,
      );
      await tearDownTestDatabase();
    },
  );
}
