import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/security/database_security_key_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  test('loadKey returns null when nothing stored', () async {
    final store = DatabaseSecurityKeyStore(storage: InMemoryKeychain());
    expect(await store.loadKey(), isNull);
  });

  test('saveKey then loadKey round-trips id and MLK bytes', () async {
    final store = DatabaseSecurityKeyStore(storage: InMemoryKeychain());
    await store.saveKey(
      libraryKeyId: 'kid-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );
    final key = await store.loadKey();
    expect(key, isNotNull);
    expect(key!.libraryKeyId, 'kid-1');
    expect(await key.mlk.extractBytes(), List<int>.generate(32, (i) => i));
  });

  test('clearKey removes both entries', () async {
    final store = DatabaseSecurityKeyStore(storage: InMemoryKeychain());
    await store.saveKey(
      libraryKeyId: 'kid-1',
      mlkBytes: List<int>.filled(32, 7),
    );
    await store.clearKey();
    expect(await store.loadKey(), isNull);
  });

  test('uses storage keys distinct from the sync and backup stores', () {
    // Guard against a copy-paste collision with the sibling key stores.
    expect(
      DatabaseSecurityKeyStore.mlkStorageKey,
      isNot('sync_encryption_mlk'),
    );
    expect(
      DatabaseSecurityKeyStore.mlkStorageKey,
      isNot('backup_encryption_mlk'),
    );
    expect(DatabaseSecurityKeyStore.mlkStorageKey, startsWith('db_security_'));
  });
}
