import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/agent_access_token_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  final tokenShape = RegExp(r'^[A-Za-z0-9_-]+$');

  group('AgentAccessTokenStore', () {
    test('ensure generates a 43-char base64url token once', () async {
      final store = AgentAccessTokenStore(storage: InMemoryKeychain());
      expect(await store.read(), isNull);
      final a = await store.ensure();
      expect(a, hasLength(43));
      expect(tokenShape.hasMatch(a), isTrue);
      expect(await store.ensure(), a);
      expect(await store.read(), a);
    });

    test('regenerate replaces the token', () async {
      final store = AgentAccessTokenStore(storage: InMemoryKeychain());
      final a = await store.ensure();
      final b = await store.regenerate();
      expect(b, isNot(a));
      expect(b, hasLength(43));
      expect(await store.read(), b);
    });

    test('clear removes it', () async {
      final store = AgentAccessTokenStore(storage: InMemoryKeychain());
      await store.ensure();
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('concurrent ensure calls agree on one token', () async {
      final store = AgentAccessTokenStore(storage: InMemoryKeychain());
      final results = await Future.wait([
        store.ensure(),
        store.ensure(),
        store.ensure(),
      ]);
      expect(results.toSet(), hasLength(1));
      expect(await store.read(), results.first);
    });

    test('an empty stored token is replaced on ensure', () async {
      final keychain = InMemoryKeychain()
        ..values[AgentAccessTokenStore.key] = '';
      final store = AgentAccessTokenStore(storage: keychain);
      final token = await store.ensure();
      expect(token, hasLength(43));
      expect(keychain.values[AgentAccessTokenStore.key], token);
    });

    test('the token is stored under the agent_access_token key', () async {
      final keychain = InMemoryKeychain();
      final store = AgentAccessTokenStore(storage: keychain);
      final a = await store.ensure();
      expect(keychain.values[AgentAccessTokenStore.key], a);
    });
  });
}
