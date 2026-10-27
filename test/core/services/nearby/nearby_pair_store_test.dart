import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_pair_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  test(
    'store then secretFor returns the same bytes; remove clears it',
    () async {
      final keychain = InMemoryKeychain();
      final store = SecureNearbyPairStore(storage: keychain);
      final secret = Uint8List.fromList(List.generate(32, (i) => i));

      expect(await store.secretFor('peer-a'), isNull);
      await store.store('peer-a', secret);
      expect(await store.secretFor('peer-a'), secret);
      expect(await store.secretFor('peer-b'), isNull);

      // A second store instance over the same keychain sees it: the secret
      // outlives the object, as it must outlive an app restart.
      expect(
        await SecureNearbyPairStore(storage: keychain).secretFor('peer-a'),
        secret,
      );

      await store.remove('peer-a');
      expect(await store.secretFor('peer-a'), isNull);
    },
  );

  test('a corrupt stored value reads as no secret', () async {
    final keychain = InMemoryKeychain();
    await keychain.write(key: 'nearby_pair_peer-a', value: '%%%not base64');
    final store = SecureNearbyPairStore(storage: keychain);
    expect(await store.secretFor('peer-a'), isNull);
  });

  test('all lists every stored secret and forgets removed ones', () async {
    final store = SecureNearbyPairStore(storage: InMemoryKeychain());
    final a = Uint8List.fromList([1]);
    final b = Uint8List.fromList([2]);
    await store.store('a', a);
    await store.store('b', b);
    await store.store('a', a);
    expect(await store.all(), {'a': a, 'b': b});
    await store.remove('a');
    expect(await store.all(), {'b': b});
  });

  test('revoke keeps the secret aside; pairing again clears it', () async {
    final store = SecureNearbyPairStore(storage: InMemoryKeychain());
    final a = Uint8List.fromList([1]);
    final b = Uint8List.fromList([2]);
    await store.store('peer', a);
    await store.revoke('peer');
    expect(await store.secretFor('peer'), isNull);
    expect(await store.all(), isEmpty);
    expect(await store.revoked(), {'peer': a});

    await store.store('peer', b);
    expect(await store.revoked(), isEmpty);
    expect(await store.secretFor('peer'), b);
  });
}
