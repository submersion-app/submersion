import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

const _fast = KdfParams(m: 1024, t: 1);

/// Owner actions and syncs go by the library's encryption as its folder
/// declares it, never by a device's older view of it (issue #2567).
void main() {
  late _LandsThenFails cloud;
  late SharedLibraryMembershipService memberships;
  late LibraryEncryptionService encryption;
  late SharedLibrary lib;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  SharedLibraryTransport folder() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships.transportForLibrary(l),
  );

  setUp(() async {
    await setUpTestDatabase();
    await diver('d1');
    cloud = _LandsThenFails();
    memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: _fast,
    );
    encryption = LibraryEncryptionService(
      store: SharedLibraryStore(),
      memberships: memberships,
      kdf: _fast,
    );
    lib = await memberships.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 's1', name: 'Blue', sharedLibraryId: lib.id),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
    );
    await syncer().sync(lib.id, diverId: 'd1');
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  /// This device as it was before [change]: holding the key, the library
  /// state and the trusted roles it had then.
  Future<void> staleAfter(Future<void> Function() change) async {
    final store = SharedLibraryStore();
    final me = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    final before = (await store.getLibrary(lib.id))!;
    await change();
    await store.setLibraryStatus(
      lib.id,
      encrypted: before.encrypted,
      keyId: before.keyId,
      clearKeyId: before.keyId == null,
      roles: before.roles,
    );
    await store.setLibraryKey(
      diverId: 'd1',
      libraryId: lib.id,
      keyId: me.libraryKeyId,
      key: me.libraryKey,
    );
  }

  test(
    'a device that missed encryption being turned off writes plain',
    () async {
      await encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'a passphrase',
      );
      await staleAfter(
        () => encryption.turnOff(libraryId: lib.id, diverId: 'd1'),
      );
      await LibraryBackupService(
        store: SharedLibraryStore(),
        memberships: memberships,
        backupsDirectory: () async {
          final dir = Directory.systemTemp.createTempSync('stale_backup_');
          addTearDown(() => dir.deleteSync(recursive: true));
          return dir.path;
        },
      ).backUp(libraryId: lib.id, diverId: 'd1');
      final index = await cloud.downloadFile('index.json');
      expect(LibraryCipher.isSealed(index), isFalse);
    },
  );

  test('a device holding only an earlier key changes nothing', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'first passphrase',
    );
    await staleAfter(
      () => encryption.changePassphrase(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'second passphrase',
      ),
    );
    final manifest = (await folder().readManifest())!;
    final slots = await cloud.downloadFile(SharedLibraryLayout.keyslotsFile);
    await expectLater(
      encryption.changePassphrase(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'third passphrase',
      ),
      throwsA(isA<LibraryLockedException>()),
    );
    await expectLater(
      memberships.reissueRecoveryCode(libraryId: lib.id, diverId: 'd1'),
      throwsA(isA<LibraryLockedException>()),
    );
    expect(await folder().readManifest(), manifest);
    expect(await cloud.downloadFile(SharedLibraryLayout.keyslotsFile), slots);
  });

  test(
    'a change of key that fails before the manifest leaves it as it was',
    () async {
      await encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'first passphrase',
      );
      final manifest = (await folder().readManifest())!;
      final slots = await cloud.downloadFile(SharedLibraryLayout.keyslotsFile);
      cloud.failUploadsNamed = SharedLibraryLayout.manifestFile;
      final failed = encryption.changePassphrase(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'second passphrase',
      );
      await expectLater(failed, throwsA(isNot(isA<RekeyIncompleteError>())));
      cloud.failUploadsNamed = null;
      expect(await folder().readManifest(), manifest);
      expect(await cloud.downloadFile(SharedLibraryLayout.keyslotsFile), slots);
      expect(
        (await syncer().sync(lib.id, diverId: 'd1')).status,
        SharedLibrarySyncStatus.success,
      );
    },
  );

  test("another profile's newer key opens the library at once", () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'first passphrase',
    );
    // A second profile here, holding the first key.
    await diver('d2');
    final store = SharedLibraryStore();
    final first = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'other',
        diverId: 'd2',
        libraryId: lib.id,
        memberId: 'm2',
        displayName: 'Bo',
        libraryName: 'Reef Survey',
        backendKind: 's3',
        libraryKeyId: first.libraryKeyId,
        libraryKey: first.libraryKey,
      ),
    );
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'second passphrase',
    );
    // This device's view of the library still names the first key.
    await store.setLibraryStatus(lib.id, keyId: first.libraryKeyId);
    final result = await SharedLibraryService(
      store: store,
      transportFor: (l) async => SharedLibraryTransport(cloud, prefix: l.prefix)
        ..cipher = await store.libraryCipherFor(l.id)
        ..encrypting = l.encrypted,
    ).sync(lib.id, diverId: 'd1');
    expect(result.status, SharedLibrarySyncStatus.success);
  });

  test('a manifest someone set to off leaves the library sealed', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a passphrase',
    );
    final manifest = (await folder().readManifest())!;
    await folder().writeManifest(
      {...manifest, 'encrypted': false, SharedLibraryLayout.rewritingFlag: true}
        ..remove('keyId'),
    );
    final result = await syncer().sync(lib.id, diverId: 'd1');
    expect(result.status, SharedLibrarySyncStatus.success);
    final files = await folder().sealableFiles();
    for (final e in files.entries) {
      expect(
        LibraryCipher.isSealed(await cloud.downloadFile(e.value)),
        isTrue,
        reason: e.key,
      );
    }
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect(me.libraryKey, isNotNull);
  });

  test('an owner turning it off is believed everywhere', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a passphrase',
    );
    await encryption.turnOff(libraryId: lib.id, diverId: 'd1');
    final result = await syncer().sync(lib.id, diverId: 'd1');
    expect(result.status, SharedLibrarySyncStatus.success);
    final files = await folder().sealableFiles();
    for (final e in files.entries) {
      expect(
        LibraryCipher.isSealed(await cloud.downloadFile(e.value)),
        isFalse,
        reason: e.key,
      );
    }
    expect(
      (await SharedLibraryStore().getLibrary(lib.id))!.roles.encryption,
      const LibraryEncryption(on: false),
    );
  });

  /// The key of [lib] held only as the spare personal sync keeps aside.
  Future<void> onlySpare() async {
    final store = SharedLibraryStore();
    final me = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    await store.setLibraryKey(diverId: 'd1', libraryId: lib.id);
    await DatabaseService.instance.database.customStatement(
      'UPDATE shared_libraries SET spare_key_id = ?, spare_key = ? '
      'WHERE id = ?',
      [me.libraryKeyId, me.libraryKey, lib.id],
    );
  }

  Future<List<Object?>> spareOf() async =>
      (await DatabaseService.instance.database
              .customSelect(
                'SELECT spare_key_id, spare_key FROM shared_libraries WHERE id = ?',
                variables: [Variable.withString(lib.id)],
              )
              .getSingle())
          .data
          .values
          .toList();

  test('a key kept aside by personal sync serves an owner at once', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a passphrase',
    );
    await onlySpare();
    final dir = Directory.systemTemp.createTempSync('spare_backup_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await LibraryBackupService(
      store: SharedLibraryStore(),
      memberships: memberships,
      backupsDirectory: () async => dir.path,
    ).backUp(libraryId: lib.id, diverId: 'd1');
    expect(
      LibraryCipher.isSealed(await cloud.downloadFile('index.json')),
      isTrue,
    );
  });

  test('turning encryption off leaves no key aside', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a passphrase',
    );
    final store = SharedLibraryStore();
    final me = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    await DatabaseService.instance.database.customStatement(
      'UPDATE shared_libraries SET spare_key_id = ?, spare_key = ? '
      'WHERE id = ?',
      [me.libraryKeyId, me.libraryKey, lib.id],
    );
    await encryption.turnOff(libraryId: lib.id, diverId: 'd1');
    expect(await spareOf(), [null, null]);
  });

  test('a change of key whose manifest landed unannounced goes on', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'first passphrase',
    );
    cloud.landThenFail = SharedLibraryLayout.manifestFile;
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'second passphrase',
    );
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
  });

  test(
    'a change of key that cannot tell whether its manifest landed keeps the key',
    () async {
      await encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'first passphrase',
      );
      cloud
        ..landThenFail = SharedLibraryLayout.manifestFile
        ..blindAfter = true;
      await expectLater(
        encryption.changePassphrase(
          libraryId: lib.id,
          diverId: 'd1',
          passphrase: 'second passphrase',
        ),
        throwsA(isA<RekeyIncompleteError>()),
      );
      cloud.blind = false;
      expect(
        (await syncer().sync(lib.id, diverId: 'd1')).status,
        SharedLibrarySyncStatus.success,
      );
    },
  );

  test('roles sealed under a key this device lacks are no forgery', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a passphrase',
    );
    final roles = await folder().readRoles();
    final other = SharedLibraryTransport(cloud, prefix: 'site-sync')
      ..cipher = await LibraryCipher.generate()
      ..encrypting = true;
    await other.writeRoles(roles);
    final result = await syncer().sync(lib.id, diverId: 'd1');
    expect(result.status, SharedLibrarySyncStatus.success);
    expect(
      (await SharedLibraryStore().getLibrary(lib.id))!.rolesRejected,
      isFalse,
    );
  });

  test(
    'a profile without the key learns an owner turned encryption off',
    () async {
      await encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'a passphrase',
      );
      final store = SharedLibraryStore();
      final before = (await store.getLibrary(lib.id))!;
      await encryption.turnOff(libraryId: lib.id, diverId: 'd1');
      // This device's view from before, with no local profile holding the
      // key (the one that did has left).
      await store.setLibraryStatus(
        lib.id,
        encrypted: true,
        keyId: before.keyId,
        roles: before.roles,
      );
      final result = await syncer().sync(lib.id, diverId: 'd1');
      expect(result.status, SharedLibrarySyncStatus.success);
      expect((await store.getLibrary(lib.id))!.encrypted, isFalse);
    },
  );

  test(
    'an owner whose key here is not the approved one seals nothing',
    () async {
      final store = SharedLibraryStore();
      final me = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
      await store.upsertMembership(
        me.copyWith(signingKey: await LibrarySigner.generate()),
      );
      await expectLater(
        encryption.turnOn(
          libraryId: lib.id,
          diverId: 'd1',
          passphrase: 'a passphrase',
        ),
        throwsStateError,
      );
      expect(await folder().readKeyslots(), isNull);
    },
  );
}

/// The fake storage, which can take an upload of [landThenFail] and then
/// report it failed, and with [blindAfter] go on failing every download
/// until [blind] is cleared, as a connection that drops does.
class _LandsThenFails extends FakeCloudStorageProvider {
  String? landThenFail;
  bool blindAfter = false;
  bool blind = false;

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final result = await super.uploadFile(data, filename, folderId: folderId);
    if (filename == landThenFail) {
      landThenFail = null;
      blind = blindAfter;
      throw const CloudStorageException('timed out (test)');
    }
    return result;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) {
    if (blind) throw const CloudStorageException('offline (test)');
    return super.downloadFile(fileId);
  }
}
