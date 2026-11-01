// Adapted from plan `docs/design/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 5. Deviations from the plan code:
//
// - The plan's hand-written `_FakeSecureStorage` is replaced with Mockito-
//   generated mocks for `FlutterSecureStorage` AND `NetworkCredentialsRepository`,
//   matching the pattern used in `local_bookmark_storage_test.dart`. This keeps
//   the service test pure-unit (no real Drift in-memory database) and consistent
//   with the rest of the media-services test suite.
// - `service.delete` takes a `String` id (not `int`) to match the schema-driven
//   adaptation already applied in Tasks 3+4 (`network_credential_hosts.id` is
//   TEXT). The plan test passes `hosts.first.id` straight through, so the
//   id-type change is transparent to the test surface.
// - `service.list()` returns `List<NetworkCredentialHost>` (the Drift data class
//   from the schema-driven repository), unchanged from the plan.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

import '../../../../support/fake_keychain_storage.dart';
import 'network_credentials_service_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage, NetworkCredentialsRepository])
void main() {
  late MockFlutterSecureStorage storage;
  late MockNetworkCredentialsRepository repo;
  late NetworkCredentialsService service;

  NetworkCredentialHost host({
    String id = 'host-id-1',
    String hostname = 'example.com',
    String authType = 'basic',
    String? displayName,
    String? credentialsRef,
    int addedAt = 1714000000000,
    int? lastUsedAt,
  }) {
    return NetworkCredentialHost(
      id: id,
      hostname: hostname,
      authType: authType,
      displayName: displayName,
      credentialsRef: credentialsRef ?? hostname,
      addedAt: addedAt,
      lastUsedAt: lastUsedAt,
    );
  }

  setUp(() {
    storage = MockFlutterSecureStorage();
    repo = MockNetworkCredentialsRepository();
    service = NetworkCredentialsService(repository: repo, storage: storage);

    // Default stubs for write/delete on storage; tests that need to assert
    // call args use `verify(...)`.
    when(
      storage.write(key: anyNamed('key'), value: anyNamed('value')),
    ).thenAnswer((_) async {});
    when(storage.delete(key: anyNamed('key'))).thenAnswer((_) async {});
    when(repo.touchLastUsed(any)).thenAnswer((_) async {});
  });

  test('save+headersFor returns Basic auth header', () async {
    when(
      repo.upsert(
        hostname: anyNamed('hostname'),
        authType: anyNamed('authType'),
        displayName: anyNamed('displayName'),
      ),
    ).thenAnswer((_) async => 'host-id-1');
    when(
      repo.findByHostname('example.com'),
    ).thenAnswer((_) async => host(authType: 'basic'));
    final basicSecret = jsonEncode({
      'authType': 'basic',
      'username': 'eric',
      'password': 'hunter2',
      'token': null,
    });
    when(
      storage.read(key: 'media_network_cred_example.com'),
    ).thenAnswer((_) async => basicSecret);

    await service.save(
      hostname: 'example.com',
      authType: 'basic',
      username: 'eric',
      password: 'hunter2',
    );
    final headers = await service.headersFor(
      Uri.parse('https://example.com/x'),
    );
    expect(headers, isNotNull);
    expect(headers!['Authorization'], startsWith('Basic '));
    final encoded = headers['Authorization']!.substring('Basic '.length);
    expect(utf8.decode(base64Decode(encoded)), 'eric:hunter2');
  });

  test('save+headersFor returns Bearer auth header', () async {
    when(
      repo.upsert(
        hostname: anyNamed('hostname'),
        authType: anyNamed('authType'),
        displayName: anyNamed('displayName'),
      ),
    ).thenAnswer((_) async => 'host-id-1');
    when(
      repo.findByHostname('example.com'),
    ).thenAnswer((_) async => host(authType: 'bearer'));
    final bearerSecret = jsonEncode({
      'authType': 'bearer',
      'username': null,
      'password': null,
      'token': 'abc.def.ghi',
    });
    when(
      storage.read(key: 'media_network_cred_example.com'),
    ).thenAnswer((_) async => bearerSecret);

    await service.save(
      hostname: 'example.com',
      authType: 'bearer',
      token: 'abc.def.ghi',
    );
    final headers = await service.headersFor(
      Uri.parse('https://example.com/x'),
    );
    expect(headers, isNotNull);
    expect(headers!['Authorization'], 'Bearer abc.def.ghi');
  });

  test('headersFor returns null when no creds for host', () async {
    when(
      storage.read(key: 'media_network_cred_other.example'),
    ).thenAnswer((_) async => null);
    expect(
      await service.headersFor(Uri.parse('https://other.example/x')),
      isNull,
    );
  });

  test('headersFor caches across calls', () async {
    when(
      repo.upsert(
        hostname: anyNamed('hostname'),
        authType: anyNamed('authType'),
        displayName: anyNamed('displayName'),
      ),
    ).thenAnswer((_) async => 'host-id-1');
    when(
      repo.findByHostname('example.com'),
    ).thenAnswer((_) async => host(authType: 'bearer'));
    final bearerSecret = jsonEncode({
      'authType': 'bearer',
      'username': null,
      'password': null,
      'token': 't',
    });
    int reads = 0;
    when(storage.read(key: 'media_network_cred_example.com')).thenAnswer((
      _,
    ) async {
      reads += 1;
      // First call returns the secret; subsequent reads (if cache misses)
      // would return null. Cache hit should prevent the second read entirely.
      return reads == 1 ? bearerSecret : null;
    });

    await service.save(hostname: 'example.com', authType: 'bearer', token: 't');
    final first = await service.headersFor(Uri.parse('https://example.com/a'));
    expect(first!['Authorization'], 'Bearer t');
    final second = await service.headersFor(Uri.parse('https://example.com/b'));
    expect(second!['Authorization'], 'Bearer t');
    // Storage should have been hit only once thanks to the in-memory cache.
    expect(reads, 1);
  });

  test('delete removes both row and secret', () async {
    when(
      repo.upsert(
        hostname: anyNamed('hostname'),
        authType: anyNamed('authType'),
        displayName: anyNamed('displayName'),
      ),
    ).thenAnswer((_) async => 'host-id-1');
    when(
      repo.findById('host-id-1'),
    ).thenAnswer((_) async => host(id: 'host-id-1'));
    when(repo.delete('host-id-1')).thenAnswer((_) async {});
    when(repo.list()).thenAnswer((_) async => <NetworkCredentialHost>[]);

    await service.save(hostname: 'example.com', authType: 'bearer', token: 't');
    await service.delete('host-id-1');

    verify(repo.delete('host-id-1')).called(1);
    verify(storage.delete(key: 'media_network_cred_example.com')).called(1);
    expect(await service.list(), isEmpty);
  });

  test('save throws on invalid combo', () async {
    expect(
      () => service.save(hostname: 'example.com', authType: 'basic'),
      throwsArgumentError,
    );
    expect(
      () => service.save(hostname: 'example.com', authType: 'bearer'),
      throwsArgumentError,
    );
    expect(
      () => service.save(hostname: 'example.com', authType: 'mystery'),
      throwsArgumentError,
    );
  });

  test(
    'headersFor returns null on corrupted JSON blob (and deletes the key)',
    () async {
      when(
        storage.read(key: 'media_network_cred_example.com'),
      ).thenAnswer((_) async => 'not-json{');

      final headers = await service.headersFor(
        Uri.parse('https://example.com/x'),
      );
      expect(headers, isNull);
      verify(storage.delete(key: 'media_network_cred_example.com')).called(1);
    },
  );

  test(
    'headersFor returns null on missing authType field (and deletes the key)',
    () async {
      final blob = jsonEncode({'username': 'eric', 'password': 'hunter2'});
      when(
        storage.read(key: 'media_network_cred_example.com'),
      ).thenAnswer((_) async => blob);

      final headers = await service.headersFor(
        Uri.parse('https://example.com/x'),
      );
      expect(headers, isNull);
      verify(storage.delete(key: 'media_network_cred_example.com')).called(1);
    },
  );

  test(
    'headersFor returns null on basic with missing username (and deletes the key)',
    () async {
      final blob = jsonEncode({'authType': 'basic', 'password': 'hunter2'});
      when(
        storage.read(key: 'media_network_cred_example.com'),
      ).thenAnswer((_) async => blob);

      final headers = await service.headersFor(
        Uri.parse('https://example.com/x'),
      );
      expect(headers, isNull);
      verify(storage.delete(key: 'media_network_cred_example.com')).called(1);
    },
  );

  test(
    'headersFor returns null on bearer with missing token (and deletes the key)',
    () async {
      final blob = jsonEncode({'authType': 'bearer'});
      when(
        storage.read(key: 'media_network_cred_example.com'),
      ).thenAnswer((_) async => blob);

      final headers = await service.headersFor(
        Uri.parse('https://example.com/x'),
      );
      expect(headers, isNull);
      verify(storage.delete(key: 'media_network_cred_example.com')).called(1);
    },
  );

  test(
    'headersFor returns null on unknown authType (and deletes the key)',
    () async {
      final blob = jsonEncode({'authType': 'mystery', 'token': 'abc'});
      when(
        storage.read(key: 'media_network_cred_example.com'),
      ).thenAnswer((_) async => blob);

      final headers = await service.headersFor(
        Uri.parse('https://example.com/x'),
      );
      expect(headers, isNull);
      verify(storage.delete(key: 'media_network_cred_example.com')).called(1);
    },
  );

  test(
    'save+headersFor fall back to the legacy keychain on errSecMissingEntitlement',
    () async {
      final inner = NoEntitlementKeychain();
      final fallbackService = NetworkCredentialsService(
        repository: repo,
        storage: inner,
      );
      when(
        repo.upsert(
          hostname: anyNamed('hostname'),
          authType: anyNamed('authType'),
          displayName: anyNamed('displayName'),
        ),
      ).thenAnswer((_) async => 'host-id-1');
      when(
        repo.findByHostname('example.com'),
      ).thenAnswer((_) async => host(authType: 'bearer'));

      await fallbackService.save(
        hostname: 'example.com',
        authType: 'bearer',
        token: 't',
      );
      final headers = await fallbackService.headersFor(
        Uri.parse('https://example.com/x'),
      );

      expect(inner.dataProtectionAttempted, isTrue);
      expect(headers?['Authorization'], 'Bearer t');
    },
  );

  group('headersFor shares and remembers lookups (#3851)', () {
    const key = 'media_network_cred_example.com';
    final uri = Uri.parse('https://example.com/photo.jpg');

    String bearerSecret(String token) => jsonEncode({
      'authType': 'bearer',
      'username': null,
      'password': null,
      'token': token,
    });

    Future<void> saveBearer(String token) =>
        service.save(hostname: 'example.com', authType: 'bearer', token: token);

    setUp(() {
      when(
        repo.upsert(
          hostname: anyNamed('hostname'),
          authType: anyNamed('authType'),
          displayName: anyNamed('displayName'),
        ),
      ).thenAnswer((_) async => 'host-id-1');
      when(repo.findById('host-id-1')).thenAnswer((_) async => host());
      when(repo.delete('host-id-1')).thenAnswer((_) async {});
      when(
        repo.findByHostname('example.com'),
      ).thenAnswer((_) async => host(authType: 'bearer'));
    });

    test('sequential lookups on a public host read storage once', () async {
      when(storage.read(key: key)).thenAnswer((_) async => null);

      for (var i = 0; i < 10; i++) {
        final next = Uri.parse('https://example.com/$i.jpg');
        expect(await service.headersFor(next), isNull);
      }

      verify(storage.read(key: key)).called(1);
    });

    test('a cold burst on a public host shares one read', () async {
      final read = Completer<String?>();
      when(storage.read(key: key)).thenAnswer((_) => read.future);

      final lookups = [
        for (var i = 0; i < 10; i++)
          service.headersFor(Uri.parse('https://example.com/$i.jpg')),
      ];
      await pumpEventQueue();
      read.complete(null);

      expect(await Future.wait(lookups), everyElement(isNull));
      verify(storage.read(key: key)).called(1);
    });

    test('a cold burst on an authenticated host shares one read', () async {
      final read = Completer<String?>();
      when(storage.read(key: key)).thenAnswer((_) => read.future);

      final lookups = [
        for (var i = 0; i < 10; i++)
          service.headersFor(Uri.parse('https://example.com/$i.jpg')),
      ];
      await pumpEventQueue();
      read.complete(bearerSecret('t'));

      final results = await Future.wait(lookups);
      expect(results.map((h) => h?['Authorization']), everyElement('Bearer t'));
      verify(storage.read(key: key)).called(1);
      verify(repo.touchLastUsed('host-id-1')).called(1);
    });

    test('remembered absence belongs to its own host', () async {
      when(storage.read(key: key)).thenAnswer((_) async => null);
      when(
        storage.read(key: 'media_network_cred_private.example'),
      ).thenAnswer((_) async => bearerSecret('p'));
      when(
        repo.findByHostname('private.example'),
      ).thenAnswer((_) async => host(hostname: 'private.example'));

      expect(await service.headersFor(uri), isNull);
      final other = await service.headersFor(
        Uri.parse('https://private.example/a.jpg'),
      );

      expect(other?['Authorization'], 'Bearer p');
    });

    test('saving credentials replaces remembered absence', () async {
      var stored = false;
      when(
        storage.read(key: key),
      ).thenAnswer((_) async => stored ? bearerSecret('t') : null);

      expect(await service.headersFor(uri), isNull);
      stored = true;
      await saveBearer('t');

      final headers = await service.headersFor(uri);
      expect(headers?['Authorization'], 'Bearer t');
    });

    test('deleting credentials replaces cached headers', () async {
      var stored = true;
      when(
        storage.read(key: key),
      ).thenAnswer((_) async => stored ? bearerSecret('t') : null);

      expect((await service.headersFor(uri))?['Authorization'], 'Bearer t');
      stored = false;
      await service.delete('host-id-1');

      expect(await service.headersFor(uri), isNull);
      expect(await service.headersFor(uri), isNull);
      verify(storage.read(key: key)).called(2);
    });

    test(
      'a lookup straddling a save does not cache its stale absence',
      () async {
        final staleRead = Completer<String?>();
        var reads = 0;
        when(storage.read(key: key)).thenAnswer((_) {
          reads += 1;
          return reads == 1
              ? staleRead.future
              : Future.value(bearerSecret('t'));
        });

        final stale = service.headersFor(uri);
        await pumpEventQueue();
        await saveBearer('t');
        staleRead.complete(null);

        expect(await stale, isNull);
        expect((await service.headersFor(uri))?['Authorization'], 'Bearer t');
        expect(reads, 2);
      },
    );

    test('a caller after a save does not join the stale lookup', () async {
      final staleRead = Completer<String?>();
      var reads = 0;
      when(storage.read(key: key)).thenAnswer((_) {
        reads += 1;
        return reads == 1 ? staleRead.future : Future.value(bearerSecret('t'));
      });

      final stale = service.headersFor(uri);
      await pumpEventQueue();
      await saveBearer('t');

      expect((await service.headersFor(uri))?['Authorization'], 'Bearer t');

      staleRead.complete(null);
      await stale;
      expect((await service.headersFor(uri))?['Authorization'], 'Bearer t');
      expect(reads, 2);
    });

    test('a lookup straddling a delete does not restore the headers', () async {
      final staleRead = Completer<String?>();
      var reads = 0;
      when(storage.read(key: key)).thenAnswer((_) {
        reads += 1;
        return reads == 1 ? staleRead.future : Future.value();
      });

      final stale = service.headersFor(uri);
      await pumpEventQueue();
      await service.delete('host-id-1');
      staleRead.complete(bearerSecret('t'));

      await stale;
      expect(await service.headersFor(uri), isNull);
    });

    test('a lookup straddling a save leaves the new secret in place', () async {
      final staleRead = Completer<String?>();
      when(storage.read(key: key)).thenAnswer((_) => staleRead.future);

      final stale = service.headersFor(uri);
      await pumpEventQueue();
      await saveBearer('t');
      staleRead.complete('not-json');

      expect(await stale, isNull);
      verifyNever(storage.delete(key: key));
    });

    test('a save during a blob removal is not hidden by absence', () async {
      final removal = Completer<void>();
      var stored = false;
      when(
        storage.read(key: key),
      ).thenAnswer((_) async => stored ? bearerSecret('t') : 'not-json');
      when(storage.delete(key: key)).thenAnswer((_) => removal.future);

      final removing = service.headersFor(uri);
      await pumpEventQueue();
      stored = true;
      await saveBearer('t');
      removal.complete();
      await removing;

      expect((await service.headersFor(uri))?['Authorization'], 'Bearer t');
    });

    test('a stale lookup finishing keeps the newer one shared', () async {
      final staleRead = Completer<String?>();
      final freshRead = Completer<String?>();
      var reads = 0;
      when(storage.read(key: key)).thenAnswer((_) {
        reads += 1;
        return reads == 1 ? staleRead.future : freshRead.future;
      });

      final stale = service.headersFor(uri);
      await pumpEventQueue();
      await saveBearer('t');
      final fresh = service.headersFor(uri);
      await pumpEventQueue();
      staleRead.complete(null);
      await stale;
      final joined = service.headersFor(uri);
      await pumpEventQueue();
      freshRead.complete(bearerSecret('t'));

      final results = await Future.wait([fresh, joined]);
      expect(results.map((h) => h?['Authorization']), everyElement('Bearer t'));
      expect(reads, 2);
    });

    test('a failed read is not remembered as absence', () async {
      var reads = 0;
      when(storage.read(key: key)).thenAnswer((_) async {
        reads += 1;
        if (reads == 1) throw PlatformException(code: 'keychain-locked');
        return bearerSecret('t');
      });

      await expectLater(
        service.headersFor(uri),
        throwsA(isA<PlatformException>()),
      );

      expect((await service.headersFor(uri))?['Authorization'], 'Bearer t');
    });

    test('a removed malformed blob is remembered as absence', () async {
      when(storage.read(key: key)).thenAnswer((_) async => 'not-json');

      expect(await service.headersFor(uri), isNull);
      expect(await service.headersFor(uri), isNull);

      verify(storage.read(key: key)).called(1);
      verify(storage.delete(key: key)).called(1);
    });

    test('announces a change only after the new secret is readable', () async {
      final keychain = InMemoryKeychain();
      final seen = <String?>[];
      late final NetworkCredentialsService announcing;
      announcing = NetworkCredentialsService(
        repository: repo,
        storage: keychain,
        onCredentialsChanged: () => seen.add(keychain.values[key]),
      );

      await announcing.save(
        hostname: 'example.com',
        authType: 'bearer',
        token: 't',
      );
      await announcing.delete('host-id-1');

      expect(seen, [isNotNull, isNull]);
    });

    test('announces nothing for a lookup or a failed write', () async {
      var changes = 0;
      final announcing = NetworkCredentialsService(
        repository: repo,
        storage: storage,
        onCredentialsChanged: () => changes += 1,
      );
      when(storage.read(key: key)).thenAnswer((_) async => 'not-json');
      when(
        storage.write(key: key, value: anyNamed('value')),
      ).thenAnswer((_) async => throw PlatformException(code: 'denied'));

      await announcing.headersFor(uri);
      await expectLater(
        announcing.save(
          hostname: 'example.com',
          authType: 'bearer',
          token: 't',
        ),
        throwsA(isA<PlatformException>()),
      );

      expect(changes, 0);
    });

    test('a failed keychain delete keeps the row for a retry', () async {
      var keychainAvailable = false;
      when(storage.delete(key: key)).thenAnswer((_) async {
        if (!keychainAvailable) throw PlatformException(code: 'denied');
      });

      await expectLater(
        service.delete('host-id-1'),
        throwsA(isA<PlatformException>()),
      );
      verifyNever(repo.delete('host-id-1'));

      keychainAvailable = true;
      await service.delete('host-id-1');
      verify(repo.delete('host-id-1')).called(1);
    });

    test('cached headers cannot be changed by a caller', () async {
      when(storage.read(key: key)).thenAnswer((_) async => bearerSecret('t'));

      final headers = await service.headersFor(uri);

      expect(() => headers!['X-Other'] = 'x', throwsUnsupportedError);
    });

    test('a lastUsedAt failure keeps the secret and its headers', () async {
      when(storage.read(key: key)).thenAnswer((_) async => bearerSecret('t'));
      when(
        repo.findByHostname('example.com'),
      ).thenAnswer((_) async => throw StateError('database closed'));

      final headers = await service.headersFor(uri);

      expect(headers?['Authorization'], 'Bearer t');
      verifyNever(storage.delete(key: key));
    });
  });
}
