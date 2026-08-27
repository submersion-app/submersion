import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveKey/loadKey/clearKey round-trip', () async {
    final store = EncryptionKeyStore(storage: InMemoryKeychain());
    expect(await store.loadKey(), isNull);
    final mlk = List<int>.generate(32, (i) => i);
    await store.saveKey(
      libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
      mlkBytes: mlk,
    );
    final loaded = await store.loadKey();
    expect(loaded!.libraryKeyId, '8f14e45f-ceea-467f-ab37-a10a8d5f4c11');
    expect(await loaded.mlk.extractBytes(), mlk);
    await store.clearKey();
    expect(await store.loadKey(), isNull);
  });

  test('keyslot mirror round-trip', () async {
    final store = EncryptionKeyStore(storage: InMemoryKeychain());
    expect(await store.loadKeyslotMirror(), isNull);
    final bytes = Uint8List.fromList([1, 2, 3, 250]);
    await store.saveKeyslotMirror(bytes);
    expect(await store.loadKeyslotMirror(), bytes);
    await store.clearKeyslotMirror();
    expect(await store.loadKeyslotMirror(), isNull);
  });

  test('SyncPreferences encryption flag defaults false and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SyncPreferences(await SharedPreferences.getInstance());
    expect(prefs.syncEncryptionEnabled, isFalse);
    await prefs.setSyncEncryptionEnabled(true);
    expect(prefs.syncEncryptionEnabled, isTrue);
  });
}
