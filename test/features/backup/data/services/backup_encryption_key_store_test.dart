import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  test(
    'saves and loads key + mirror; clear removes key but keeps mirror',
    () async {
      final store = BackupEncryptionKeyStore(storage: InMemoryKeychain());
      await store.saveKey(
        libraryKeyId: 'lib-1',
        mlkBytes: List<int>.generate(32, (i) => i),
      );
      await store.saveKeyslotMirror(Uint8List.fromList([1, 2, 3]));

      final key = await store.loadKey();
      expect(key, isNotNull);
      expect(key!.libraryKeyId, 'lib-1');
      expect(await key.mlk.extractBytes(), List<int>.generate(32, (i) => i));
      expect(await store.loadKeyslotMirror(), [1, 2, 3]);

      await store.clearKey();
      expect(await store.loadKey(), isNull);
      // The mirror is cleared independently of the key.
      expect(await store.loadKeyslotMirror(), [1, 2, 3]);
    },
  );

  test('uses storage keys distinct from the sync store', () {
    // Guard against a copy-paste collision with EncryptionKeyStore.
    expect(
      BackupEncryptionKeyStore.mlkStorageKey,
      isNot('sync_encryption_mlk'),
    );
    expect(
      BackupEncryptionKeyStore.mlkStorageKey,
      startsWith('backup_encryption_'),
    );
  });
}
