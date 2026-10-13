import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

const _fast = KdfParams(m: 1024, t: 1);

void main() {
  late FakeCloudStorageProvider cloud;
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

  SharedLibraryTransport folder() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships.transportForLibrary(l),
  );

  Future<Map<String, bool>> sealedByPath() async {
    final t = folder();
    final files = await t.sealableFiles();
    return {
      for (final e in files.entries)
        e.key: LibraryCipher.isSealed(await cloud.downloadFile(e.value)),
    };
  }

  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    cloud = FakeCloudStorageProvider();
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

  test('turning it on seals every file and the owner still reads it', () async {
    final code = await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    expect(code, isNotEmpty);
    expect((await sealedByPath()).values, everyElement(isTrue));
    final manifest = (await folder().readManifest())!;
    expect(manifest['encrypted'], isTrue);
    final r = await syncer().sync(lib.id, diverId: 'd1');
    expect(r.status, SharedLibrarySyncStatus.success);
    // The passphrase and the new code both open it.
    final slots = (await folder().readKeyslots())!;
    expect(
      await LibraryCipher.unlock(slots, 'correct horse battery'),
      isNotNull,
    );
    expect(await LibraryCipher.unlock(slots, code), isNotNull);
  });

  test('a late plain upload is converted by the next owner sync', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    // A member who had not seen the switch writes a plain site file.
    final plain = folder()..encrypting = false;
    await plain.writeSite(const SiteDocument(id: 's2', fields: {'name': 'X'}));
    await syncer().sync(lib.id, diverId: 'd1');
    expect((await sealedByPath()).values, everyElement(isTrue));
  });

  test('turning it off leaves every file plain and drops the key', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    await encryption.turnOff(libraryId: lib.id, diverId: 'd1');
    expect((await sealedByPath()).values, everyElement(isFalse));
    expect(await folder().readKeyslots(), isNull);
    expect((await folder().readManifest())!['encrypted'], isFalse);
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect(me.libraryKey, isNull);
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
  });

  test('a new passphrase locks out the old key', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    final oldKey = (await SharedLibraryStore().libraryCipherFor(lib.id))!;
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a brand new passphrase',
    );
    final slots = (await folder().readKeyslots())!;
    expect(await LibraryCipher.unlock(slots, 'correct horse battery'), isNull);
    expect(slots.libraryKeyId, isNot(oldKey.keyId));
    // Every file is under the new key.
    final t = folder();
    for (final id in (await t.sealableFiles()).values) {
      expect(
        LibraryCipher.keyIdOf(await cloud.downloadFile(id)),
        slots.libraryKeyId.toLowerCase(),
      );
    }
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
  });

  test('a file sealed under the old key is re-sealed, not lost', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    final oldKey = (await SharedLibraryStore().libraryCipherFor(lib.id))!;
    // A member's device still on the old key reads a site document before
    // the change, and uploads it after.
    final stale = folder()
      ..cipher = oldKey
      ..encrypting = true;
    final file = (await stale.listSites()).single;
    final doc = await stale.readSite(file.id);
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'a brand new passphrase',
    );
    await stale.writeSite(doc);
    final newKeyId = (await folder().readKeyslots())!.libraryKeyId;
    expect(
      LibraryCipher.keyIdOf(await cloud.downloadFile(file.id)),
      oldKey.keyId.toLowerCase(),
    );

    await syncer().sync(lib.id, diverId: 'd1');

    expect(
      LibraryCipher.keyIdOf(await cloud.downloadFile(file.id)),
      newKeyId.toLowerCase(),
    );
    final fresh = folder()
      ..cipher = (await SharedLibraryStore().libraryCipherFor(lib.id))
      ..encrypting = true;
    expect((await fresh.readSite(file.id)).id, doc.id);
  });

  test('a turn-off cut short is finished by the next owner sync', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    // This device has read every document since: unchanged ones are not
    // read again.
    await syncer().sync(lib.id, diverId: 'd1');
    await expectLater(
      encryption.turnOff(
        libraryId: lib.id,
        diverId: 'd1',
        progress: (done, total) {
          if (done == 1) throw StateError('connection lost');
        },
      ),
      throwsStateError,
    );
    expect((await sealedByPath()).values, contains(true));

    await syncer().sync(lib.id, diverId: 'd1');

    expect((await sealedByPath()).values, everyElement(isFalse));
    expect((await folder().readManifest())!['rewriting'], isNull);
    expect(await SharedLibraryStore().libraryCipherFor(lib.id), isNull);
  });

  test('a turn-on cut short is finished by the next owner sync', () async {
    await expectLater(
      encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'correct horse battery',
        progress: (done, total) {
          if (done == 1) throw StateError('connection lost');
        },
      ),
      throwsA(isA<RekeyIncompleteError>()),
    );
    expect((await sealedByPath()).values, contains(false));

    await syncer().sync(lib.id, diverId: 'd1');

    expect((await sealedByPath()).values, everyElement(isTrue));
    expect((await folder().readManifest())!['rewriting'], isNull);
  });

  test(
    'a passphrase change cut short leaves the earlier keys readable',
    () async {
      await encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'first passphrase',
      );
      final first = (await SharedLibraryStore().libraryCipherFor(lib.id))!;
      await encryption.changePassphrase(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'second passphrase',
      );
      final second = (await SharedLibraryStore().libraryCipherFor(lib.id))!;
      // A change to a third key writes its list, then stops before the
      // library switches to it.
      final third = await LibraryCipher.generate();
      await folder().writePreviousKeys([first, second], under: third);

      final t = folder()
        ..cipher = second
        ..encrypting = true;
      expect(
        (await t.readPreviousKeys()).keys,
        contains(first.keyId.toLowerCase()),
      );
    },
  );

  test('a new recovery code also opens the encrypted library', () async {
    final first = await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    final fresh = await memberships.reissueRecoveryCode(
      libraryId: lib.id,
      diverId: 'd1',
    );
    final slots = (await folder().readKeyslots())!;
    expect(await LibraryCipher.unlock(slots, fresh), isNotNull);
    expect(await LibraryCipher.unlock(slots, first), isNull);
    expect(
      await LibraryCipher.unlock(slots, 'correct horse battery'),
      isNotNull,
    );
  });

  test(
    'a new recovery code that could not be recorded keeps the old one',
    () async {
      final first = await encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'correct horse battery',
      );
      cloud.failUploadsNamed = SharedLibraryLayout.rolesFile;
      await expectLater(
        memberships.reissueRecoveryCode(libraryId: lib.id, diverId: 'd1'),
        throwsA(anything),
      );
      cloud.failUploadsNamed = null;
      final slots = (await folder().readKeyslots())!;
      expect(await LibraryCipher.unlock(slots, first), isNotNull);
    },
  );

  test('a key change cut short still hands over its recovery code', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'first passphrase',
    );
    Object? error;
    try {
      await encryption.changePassphrase(
        libraryId: lib.id,
        diverId: 'd1',
        passphrase: 'second passphrase',
        progress: (done, total) {
          if (done == 1) throw StateError('connection lost');
        },
      );
    } catch (e) {
      error = e;
    }
    expect(error, isA<RekeyIncompleteError>());
    final code = (error! as RekeyIncompleteError).recoveryCode;
    final slots = (await folder().readKeyslots())!;
    expect(await LibraryCipher.unlock(slots, code), isNotNull);
  });

  test('a non-owner cannot change encryption', () async {
    await DiverRepository().createDiver(
      Diver(
        id: 'd2',
        name: 'Bo',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    await expectLater(
      encryption.turnOn(
        libraryId: lib.id,
        diverId: 'd2',
        passphrase: 'correct horse battery',
      ),
      throwsStateError,
    );
  });

  for (final change in ['passphrase', 'off']) {
    test(
      'the backup index follows a ${change == 'off' ? 'turn-off' : 'new passphrase'}',
      () async {
        await encryption.turnOn(
          libraryId: lib.id,
          diverId: 'd1',
          passphrase: 'first passphrase',
        );
        final sealed = await memberships.transportForLibrary(
          (await SharedLibraryStore().getLibrary(lib.id))!,
        );
        await sealed.writeBackupIndex({'b1': 'pinned'});
        if (change == 'off') {
          await encryption.turnOff(libraryId: lib.id, diverId: 'd1');
        } else {
          await encryption.changePassphrase(
            libraryId: lib.id,
            diverId: 'd1',
            passphrase: 'second passphrase',
          );
        }
        final t = await memberships.transportForLibrary(
          (await SharedLibraryStore().getLibrary(lib.id))!,
        );
        expect(await t.readBackupIndex(), {'b1': 'pinned'});
      },
    );
  }
}
