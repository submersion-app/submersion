import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late DivelogsSessionStore store;
  var logins = 0;

  setUp(() {
    store = DivelogsSessionStore(storage: InMemoryKeychain());
    logins = 0;
  });

  http.Client loginClient({int status = 200}) => MockClient((req) async {
    expect(req.url.path, '/api/login');
    logins++;
    return http.Response(jsonEncode({'bearer_token': 'jwt-$logins'}), status);
  });

  DivelogsAuthFailure? reasonOf(Object error) =>
      error is DivelogsAuthException ? error.reason : null;

  test('signIn stores username and token, never the password', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    await auth.signIn('rainer', 'secret');
    final saved = await store.load();
    expect(saved!.username, 'rainer');
    expect(saved.token, 'jwt-1');
    expect(auth.username, 'rainer');
    expect(await auth.getToken(), 'jwt-1');
  });

  test('signIn maps 401 to badCredentials and stores nothing', () async {
    final auth = DivelogsAuth(
      httpClient: loginClient(status: 401),
      store: store,
    );
    Object? error;
    try {
      await auth.signIn('rainer', 'wrong');
    } catch (e) {
      error = e;
    }
    expect(reasonOf(error!), DivelogsAuthFailure.badCredentials);
    expect(await store.load(), isNull);
  });

  test('signIn maps a network error to unreachable', () async {
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => throw http.ClientException('down')),
      store: store,
    );
    Object? error;
    try {
      await auth.signIn('rainer', 'secret');
    } catch (e) {
      error = e;
    }
    expect(reasonOf(error!), DivelogsAuthFailure.unreachable);
  });

  test('signIn maps a body without a token to unexpectedResponse', () async {
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => http.Response('<html>', 200)),
      store: store,
    );
    Object? error;
    try {
      await auth.signIn('rainer', 'secret');
    } catch (e) {
      error = e;
    }
    expect(reasonOf(error!), DivelogsAuthFailure.unexpectedResponse);
  });

  test('restore reads the cached session without the network', () async {
    await store.save(
      const DivelogsSession(username: 'rainer', token: 'cached'),
    );
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => fail('no network expected')),
      store: store,
    );
    expect(await auth.restore(), isTrue);
    expect(auth.username, 'rainer');
    expect(await auth.getToken(), 'cached');
  });

  test('restore reports false when nothing is cached', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    expect(await auth.restore(), isFalse);
  });

  test('after a 401 a signed-in auth logs in again once', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    await auth.signIn('rainer', 'secret');
    auth.invalidateToken();
    final tokens = await Future.wait([auth.getToken(), auth.getToken()]);
    expect(tokens, ['jwt-2', 'jwt-2']);
    expect(logins, 2);
    expect((await store.load())!.token, 'jwt-2');
  });

  test('a restored session that is rejected expires and is cleared', () async {
    await store.save(
      const DivelogsSession(username: 'rainer', token: 'cached'),
    );
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => fail('no password to log in with')),
      store: store,
    );
    await auth.restore();
    auth.invalidateToken();
    await expectLater(
      auth.getToken(),
      throwsA(isA<DivelogsSessionExpiredException>()),
    );
    expect(await store.load(), isNull);
  });

  test('signOut clears the stored session and the password', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    await auth.signIn('rainer', 'secret');
    await auth.signOut();
    expect(await store.load(), isNull);
    await expectLater(
      auth.getToken(),
      throwsA(isA<DivelogsSessionExpiredException>()),
    );
  });

  test(
    'signing out during a renewal does not bring the session back',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final auth = DivelogsAuth(
        httpClient: MockClient((req) async {
          calls++;
          if (calls == 2) await gate.future;
          return http.Response(jsonEncode({'bearer_token': 'jwt-$calls'}), 200);
        }),
        store: store,
      );
      await auth.signIn('rainer', 'secret');
      auth.invalidateToken();
      final renewal = auth.getToken();
      await Future<void>.delayed(Duration.zero);

      await auth.signOut();
      gate.complete();

      await expectLater(
        renewal,
        throwsA(isA<DivelogsSessionExpiredException>()),
      );
      expect(await store.load(), isNull);
      await expectLater(
        auth.getToken(),
        throwsA(isA<DivelogsSessionExpiredException>()),
      );
    },
  );

  test(
    'a sign-out the keychain refuses keeps the session and says so',
    () async {
      final failing = _ClearFailsStore();
      final auth = DivelogsAuth(httpClient: loginClient(), store: failing);
      await auth.signIn('rainer', 'secret');

      await expectLater(auth.signOut(), throwsA(isA<StateError>()));

      expect(auth.username, 'rainer');
      expect(await auth.getToken(), 'jwt-1');
    },
  );
}

/// A keychain that stores sessions but refuses to delete them.
class _ClearFailsStore extends DivelogsSessionStore {
  _ClearFailsStore() : super(storage: InMemoryKeychain());

  @override
  Future<void> clear() async => throw StateError('keychain delete refused');
}
