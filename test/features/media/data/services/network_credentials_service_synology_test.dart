import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/data/synology/synology_share_sessions.dart';

import '../../../../support/fake_keychain_storage.dart';

class _FakeRepo extends Fake implements NetworkCredentialsRepository {
  final Map<String, String> authTypes = {};

  @override
  Future<String> upsert({
    required String hostname,
    required String authType,
    String? displayName,
  }) async {
    authTypes[hostname] = authType;
    return 'id-$hostname';
  }

  @override
  Future<NetworkCredentialHost?> findByHostname(String hostname) async => null;
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  const host = 'nas.example.com';
  late InMemoryKeychain keychain;
  late _FakeRepo repo;
  late int logins;
  late List<String> loginPasswords;
  late NetworkCredentialsService service;

  // Each share accepts only its own password.
  const passwords = {'code1': 'secret', 'code2': 'other', 'open1': ''};

  setUp(() {
    keychain = InMemoryKeychain();
    repo = _FakeRepo();
    logins = 0;
    loginPasswords = [];
    final client = MockClient((request) async {
      final form = request.bodyFields;
      if (form['api'] == 'SYNO.Core.Sharing.Login') {
        logins++;
        loginPasswords.add(form['password'] ?? '');
        if (form['password'] != passwords[form['sharing_id']]) {
          return _json({
            'success': false,
            'error': {'code': 101},
          });
        }
        return _json({
          'success': true,
          'data': {'sharing_sid': 'sid-$logins'},
        });
      }
      return _json({'success': true, 'data': <String, Object?>{}});
    });
    service = NetworkCredentialsService(
      repository: repo,
      storage: keychain,
      synologySessions: SynologyShareSessions(client: client),
    );
  });

  final share1 = SynologyShareLink.tryParseShareLink(
    Uri.parse('https://$host:5001/mo/sharing/code1'),
  )!;
  final share2 = SynologyShareLink.tryParseShareLink(
    Uri.parse('https://$host:5001/mo/sharing/code2'),
  )!;

  Future<void> saveShare(SynologyShareLink link, String password) =>
      service.save(
        hostname: NetworkCredentialsService.synologyShareKey(link),
        authType: 'synologyShare',
        password: password,
      );

  test('saving a share password needs a password', () async {
    expect(
      () => service.save(hostname: host, authType: 'synologyShare'),
      throwsArgumentError,
    );
  });

  test('the key names the NAS and the share', () {
    expect(
      NetworkCredentialsService.synologyShareKey(share1),
      '$host:5001/mo/sharing/code1',
    );
    // The /photo spelling of a link reaches the same share and key.
    final prefixed = SynologyShareLink.tryParseShareLink(
      Uri.parse('https://$host:5001/photo/mo/sharing/code1/'),
    )!;
    expect(
      NetworkCredentialsService.synologyShareKey(prefixed),
      NetworkCredentialsService.synologyShareKey(share1),
    );
  });

  test('a saved share password belongs to its share only', () async {
    await saveShare(share1, 'secret');
    expect(repo.authTypes['$host:5001/mo/sharing/code1'], 'synologyShare');
    expect(await service.synologySharePassword(share1), 'secret');
    expect(await service.synologySharePassword(share2), isNull);
  });

  test('two shares on one NAS keep their own passwords', () async {
    await saveShare(share1, 'secret');
    await saveShare(share2, 'other');
    expect(await service.synologySharePassword(share1), 'secret');
    expect(await service.synologySharePassword(share2), 'other');

    final h1 = await service.headersFor(
      share1.originalUri(id: 1, cacheKey: '1_1'),
    );
    final h2 = await service.headersFor(
      share2.originalUri(id: 2, cacheKey: '2_2'),
    );
    expect(h1?['X-SYNO-SHARING'], 'code1');
    expect(h2?['X-SYNO-SHARING'], 'code2');
    expect(loginPasswords, ['secret', 'other']);
  });

  test('a password saved for the whole host still opens a share', () async {
    // How the first prototype stored it.
    await service.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'secret',
    );
    expect(await service.synologySharePassword(share1), 'secret');
    final headers = await service.headersFor(
      share1.originalUri(id: 1, cacheKey: '1_1'),
    );
    expect(headers?['X-SYNO-SHARING'], 'code1');
  });

  test("a share's own password wins over a host-wide one", () async {
    await service.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'secret',
    );
    await saveShare(share2, 'other');
    expect(await service.synologySharePassword(share2), 'other');
    expect(await service.synologySharePassword(share1), 'secret');
  });

  test('share API URLs get session headers', () async {
    await saveShare(share1, 'secret');
    final headers = await service.headersFor(
      share1.thumbnailUri(
        id: 1,
        cacheKey: '1_1',
        size: SynologyThumbnailSize.m,
      ),
    );
    expect(headers, {'Cookie': 'sharing_sid=sid-1', 'X-SYNO-SHARING': 'code1'});

    // The secret is cached, the session reused.
    await service.headersFor(share1.originalUri(id: 2, cacheKey: '2_2'));
    expect(logins, 1);
  });

  test('other URLs on the same host get no headers', () async {
    await saveShare(share1, 'secret');
    await service.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'secret',
    );
    expect(
      await service.headersFor(Uri.parse('https://$host/photo.jpg')),
      isNull,
    );
    expect(logins, 0);
  });

  test('a rejected password yields no headers instead of throwing', () async {
    await saveShare(share1, 'wrong');
    expect(
      await service.headersFor(share1.originalUri(id: 1, cacheKey: '1_1')),
      isNull,
    );
  });

  test('basic credentials are no share password', () async {
    await service.save(
      hostname: host,
      authType: 'basic',
      username: 'u',
      password: 'p',
    );
    expect(await service.synologySharePassword(share1), isNull);
    final headers = await service.headersFor(Uri.parse('https://$host/a.jpg'));
    expect(headers?['Authorization'], startsWith('Basic '));
  });

  test('a share without a password falls back to host credentials', () async {
    await service.save(
      hostname: host,
      authType: 'basic',
      username: 'u',
      password: 'p',
    );
    final headers = await service.headersFor(
      share1.originalUri(id: 1, cacheKey: '1_1'),
    );
    expect(headers?['Authorization'], startsWith('Basic '));
    // One try without a password, then remembered as refused.
    await service.headersFor(share1.originalUri(id: 2, cacheKey: '2_2'));
    expect(loginPasswords, ['']);
  });

  test('a share without a password gets headers without one', () async {
    final open = SynologyShareLink.tryParseShareLink(
      Uri.parse('https://$host:5001/mo/sharing/open1'),
    )!;
    final headers = await service.headersFor(
      open.originalUri(id: 1, cacheKey: '1_1'),
    );
    expect(headers?['X-SYNO-SHARING'], 'open1');
    expect(loginPasswords, ['']);
  });

  test('without sessions a share secret yields no headers', () async {
    final plain = NetworkCredentialsService(
      repository: repo,
      storage: keychain,
    );
    await plain.save(
      hostname: NetworkCredentialsService.synologyShareKey(share1),
      authType: 'synologyShare',
      password: 'secret',
    );
    expect(
      await plain.headersFor(share1.originalUri(id: 1, cacheKey: '1_1')),
      isNull,
    );
    // The stored secret stays: it is valid, this instance just cannot use it.
    expect(keychain.values, isNotEmpty);
  });
}
