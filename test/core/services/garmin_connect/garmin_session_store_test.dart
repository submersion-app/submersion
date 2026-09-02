import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/garmin_connect/garmin_auth_tokens.dart';
import 'package:submersion/core/services/garmin_connect/garmin_session_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late GarminSessionStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = GarminSessionStore(storage: storage);
  });

  GarminSessionData session({String? mfaToken}) => GarminSessionData(
    email: 'diver@example.com',
    token: GarminOAuth1Token(
      token: 'ro-token',
      tokenSecret: 'ro-secret',
      mfaToken: mfaToken,
    ),
  );

  test('load returns null when nothing stored', () async {
    expect(await store.load(), isNull);
  });

  test('round-trips email, token, secret, and mfaToken', () async {
    await store.save(session(mfaToken: 'mfa-abc'));
    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.email, 'diver@example.com');
    expect(loaded.token.token, 'ro-token');
    expect(loaded.token.tokenSecret, 'ro-secret');
    expect(loaded.token.mfaToken, 'mfa-abc');
  });

  test('a null mfaToken round-trips as null', () async {
    await store.save(session());
    final loaded = await store.load();
    expect(loaded!.token.mfaToken, isNull);
  });

  test('a corrupt blob loads as null but is left in place', () async {
    await storage.write(key: GarminSessionStore.storageKey, value: 'not json');
    expect(await store.load(), isNull);
    expect(await storage.read(key: GarminSessionStore.storageKey), 'not json');
  });

  test('a blob of the wrong shape loads as null', () async {
    await storage.write(
      key: GarminSessionStore.storageKey,
      value: jsonEncode([1, 2, 3]),
    );
    expect(await store.load(), isNull);
  });

  test('a blob missing email loads as null', () async {
    await storage.write(
      key: GarminSessionStore.storageKey,
      value: jsonEncode({'token': 'ro-token', 'tokenSecret': 'ro-secret'}),
    );
    expect(await store.load(), isNull);
  });

  test('a blob missing tokenSecret loads as null', () async {
    await storage.write(
      key: GarminSessionStore.storageKey,
      value: jsonEncode({'email': 'diver@example.com', 'token': 'ro-token'}),
    );
    expect(await store.load(), isNull);
  });

  test('a blob with a wrongly-typed mfaToken loads as null instead of '
      'throwing', () async {
    await storage.write(
      key: GarminSessionStore.storageKey,
      value: jsonEncode({
        'email': 'diver@example.com',
        'token': 'ro-token',
        'tokenSecret': 'ro-secret',
        // mfaToken must be a String? -- an int here trips the cast inside
        // GarminOAuth1Token.fromJson with a TypeError, which load() must
        // swallow the same way it does a FormatException.
        'mfaToken': 123,
      }),
    );
    expect(await store.load(), isNull);
  });

  test('clear removes the blob', () async {
    await store.save(session());
    await store.clear();
    expect(await store.load(), isNull);
    expect(await storage.read(key: GarminSessionStore.storageKey), isNull);
  });
}
