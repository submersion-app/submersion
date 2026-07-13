import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';

import '../../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);

void main() {
  late BackupEncryptionKeyStore store;
  late BackupEncryptionService service;

  setUp(() {
    store = BackupEncryptionKeyStore(storage: InMemoryKeychain());
    service = BackupEncryptionService(keyStore: store);
  });

  test('enable persists key + mirror and returns a recovery code', () async {
    final r = await service.enable(passphrase: 'hunter2hunter2', kdf: _fastKdf);
    expect(r.recoveryCode.split('-'), hasLength(8));
    expect(await store.loadKey(), isNotNull);
    expect(await store.loadKeyslotMirror(), isNotNull);
  });

  test('the recovery code unwraps the same key as the passphrase', () async {
    final r = await service.enable(passphrase: 'hunter2hunter2', kdf: _fastKdf);
    final file = KeyslotFile.fromJsonBytes((await store.loadKeyslotMirror())!);
    final viaPass = await Keyslots.tryUnwrap(
      file: file,
      secret: 'hunter2hunter2',
    );
    final viaCode = await Keyslots.tryUnwrap(
      file: file,
      secret: r.recoveryCode,
    );
    expect(await viaPass!.extractBytes(), await viaCode!.extractBytes());
  });

  test(
    'changePassphrase: old fails, new works; wrong current throws',
    () async {
      await service.enable(passphrase: 'oldpassword1', kdf: _fastKdf);
      await expectLater(
        service.changePassphrase(
          currentSecret: 'wrong',
          newPassphrase: 'x',
          kdf: _fastKdf,
        ),
        throwsA(isA<WrongPassphraseException>()),
      );
      await service.changePassphrase(
        currentSecret: 'oldpassword1',
        newPassphrase: 'newpassword1',
        kdf: _fastKdf,
      );
      final file = KeyslotFile.fromJsonBytes(
        (await store.loadKeyslotMirror())!,
      );
      expect(
        await Keyslots.tryUnwrap(file: file, secret: 'oldpassword1'),
        isNull,
      );
      expect(
        await Keyslots.tryUnwrap(file: file, secret: 'newpassword1'),
        isNotNull,
      );
    },
  );

  test('re-enable adopts the retained key (same MLK + libraryKeyId) so old '
      'backups stay unlockable, but mints a fresh recovery code', () async {
    final first = await service.enable(
      passphrase: 'firstpass12',
      kdf: _fastKdf,
    );
    final firstMlk = (await store.loadKey())!.mlk;

    // Simulate Turn-off (flag only; key/mirror retained) then re-enable with
    // a different password.
    final second = await service.enable(
      passphrase: 'secondpass12',
      kdf: _fastKdf,
    );

    // Same key identity: on-device restore of pre-existing .sbe keeps working.
    expect(second.libraryKeyId, first.libraryKeyId);
    expect(
      await (await store.loadKey())!.mlk.extractBytes(),
      await firstMlk.extractBytes(),
    );

    // Fresh slots: the new password works, the fresh recovery code differs,
    // and the OLD password no longer opens the current mirror.
    final file = KeyslotFile.fromJsonBytes((await store.loadKeyslotMirror())!);
    expect(second.recoveryCode, isNot(first.recoveryCode));
    expect(
      await Keyslots.tryUnwrap(file: file, secret: 'secondpass12'),
      isNotNull,
    );
    expect(await Keyslots.tryUnwrap(file: file, secret: 'firstpass12'), isNull);
  });

  test(
    'regenerateRecoveryCode: old code stops working, new one works',
    () async {
      final first = await service.enable(
        passphrase: 'password12',
        kdf: _fastKdf,
      );
      final second = await service.regenerateRecoveryCode(
        currentSecret: 'password12',
        kdf: _fastKdf,
      );
      expect(second, isNot(first.recoveryCode));
      final file = KeyslotFile.fromJsonBytes(
        (await store.loadKeyslotMirror())!,
      );
      expect(
        await Keyslots.tryUnwrap(file: file, secret: first.recoveryCode),
        isNull,
      );
      expect(await Keyslots.tryUnwrap(file: file, secret: second), isNotNull);
    },
  );
}
