import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late GoogleDriveTokenStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = GoogleDriveTokenStore(storage: storage);
  });

  gauth.AccessCredentials creds() => gauth.AccessCredentials(
    gauth.AccessToken('Bearer', 'at-1', DateTime.utc(2026, 7, 2, 12)),
    'rt-1',
    ['https://www.googleapis.com/auth/drive.appdata'],
    idToken: 'id-1',
  );

  test('load returns null when nothing is stored', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the credentials', () async {
    await store.save(creds());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.accessToken.data, 'at-1');
    expect(loaded.refreshToken, 'rt-1');
    expect(loaded.idToken, 'id-1');
    expect(loaded.scopes, ['https://www.googleapis.com/auth/drive.appdata']);
    expect(storage.values.keys, [GoogleDriveTokenStore.storageKey]);
  });

  test('clear removes the blob', () async {
    await store.save(creds());
    await store.clear();
    expect(await store.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('corrupted JSON loads as null instead of throwing', () async {
    storage.values[GoogleDriveTokenStore.storageKey] = 'not-json{';
    expect(await store.load(), isNull);
    // The corrupt blob is preserved, not deleted (save() overwrites it).
    expect(storage.values, isNotEmpty);
  });

  test('valid JSON that is not an object loads as null', () async {
    storage.values[GoogleDriveTokenStore.storageKey] = '[]';
    expect(await store.load(), isNull);
  });

  test('an object with wrong-typed fields loads as null', () async {
    storage.values[GoogleDriveTokenStore.storageKey] = jsonEncode({
      'accessToken': 42,
    });
    expect(await store.load(), isNull);
  });
}
