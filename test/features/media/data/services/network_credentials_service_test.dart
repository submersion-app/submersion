// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
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
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

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
}
