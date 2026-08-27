import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth_manager.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late AccountCredentialsStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = AccountCredentialsStore(storage: keychain);
  });

  MockClient loginOk({String token = 'jwt-1', List<http.Request>? log}) =>
      MockClient((req) async {
        log?.add(req);
        expect(req.url.path, '/api/login');
        return http.Response(jsonEncode({'bearer_token': token}), 200);
      });

  Future<void> seedCreds({String? token}) => store.write(
    'acc-1',
    DivelogsCredentials(
      username: 'eric',
      password: 'secret',
      bearerToken: token,
    ).toJsonString(),
  );

  test('login returns token from bearer_token field', () async {
    final token = await DivelogsAuthManager.login(
      username: 'eric',
      password: 'secret',
      httpClient: loginOk(),
    );
    expect(token, 'jwt-1');
  });

  test('login throws DivelogsAuthException on 401', () async {
    final client = MockClient((_) async => http.Response('', 401));
    expect(
      () => DivelogsAuthManager.login(
        username: 'eric',
        password: 'bad',
        httpClient: client,
      ),
      throwsA(isA<DivelogsAuthException>()),
    );
  });

  test('getToken uses persisted token without hitting network', () async {
    await seedCreds(token: 'persisted');
    final manager = DivelogsAuthManager(
      credentials: store,
      accountId: 'acc-1',
      httpClient: MockClient((_) async => fail('no network call expected')),
    );
    expect(await manager.getToken(), 'persisted');
  });

  test(
    'getToken logs in when no token persisted and persists result',
    () async {
      await seedCreds();
      final manager = DivelogsAuthManager(
        credentials: store,
        accountId: 'acc-1',
        httpClient: loginOk(token: 'fresh'),
      );
      expect(await manager.getToken(), 'fresh');
      final blob = DivelogsCredentials.fromJsonString(
        await store.read('acc-1'),
      );
      expect(blob?.bearerToken, 'fresh');
    },
  );

  test('getToken is single-flight for concurrent callers', () async {
    await seedCreds();
    final log = <http.Request>[];
    final manager = DivelogsAuthManager(
      credentials: store,
      accountId: 'acc-1',
      httpClient: loginOk(log: log),
    );
    final results = await Future.wait([
      manager.getToken(),
      manager.getToken(),
      manager.getToken(),
    ]);
    expect(results.toSet(), {'jwt-1'});
    expect(log.length, 1);
  });

  test(
    'invalidateToken forces a fresh login ignoring persisted token',
    () async {
      await seedCreds(token: 'stale');
      final manager = DivelogsAuthManager(
        credentials: store,
        accountId: 'acc-1',
        httpClient: loginOk(token: 'renewed'),
      );
      expect(await manager.getToken(), 'stale');
      manager.invalidateToken();
      expect(await manager.getToken(), 'renewed');
    },
  );

  test('disconnect deletes the credentials blob', () async {
    await seedCreds(token: 't');
    final manager = DivelogsAuthManager(credentials: store, accountId: 'acc-1');
    await manager.disconnect();
    expect(await store.read('acc-1'), isNull);
  });

  test('getToken throws when not signed in', () async {
    final manager = DivelogsAuthManager(credentials: store, accountId: 'acc-1');
    expect(() => manager.getToken(), throwsA(isA<DivelogsAuthException>()));
  });
}
