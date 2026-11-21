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
  late NetworkCredentialsService service;

  setUp(() {
    keychain = InMemoryKeychain();
    repo = _FakeRepo();
    logins = 0;
    final client = MockClient((request) async {
      final form = request.bodyFields;
      if (form['api'] == 'SYNO.Core.Sharing.Login') {
        logins++;
        if (form['password'] != 'secret') {
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

  final shareLink = Uri.parse('https://$host:5001/mo/sharing/code1');

  test('saving a share password needs a password', () async {
    expect(
      () => service.save(hostname: host, authType: 'synologyShare'),
      throwsArgumentError,
    );
  });

  test('a saved share password is stored for the host', () async {
    await service.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'secret',
    );
    expect(repo.authTypes[host], 'synologyShare');
    expect(await service.synologySharePassword(host), 'secret');
  });

  test('share API URLs get session headers', () async {
    await service.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'secret',
    );
    final link = SynologyShareLink.tryParseShareLink(shareLink)!;
    final headers = await service.headersFor(
      link.thumbnailUri(id: 1, cacheKey: '1_1', size: SynologyThumbnailSize.m),
    );
    expect(headers, {'Cookie': 'sharing_sid=sid-1', 'X-SYNO-SHARING': 'code1'});

    // The secret is cached, the session reused.
    await service.headersFor(link.originalUri(id: 2, cacheKey: '2_2'));
    expect(logins, 1);
  });

  test('other URLs on the same host get no headers', () async {
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
    await service.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'wrong',
    );
    final link = SynologyShareLink.tryParseShareLink(shareLink)!;
    expect(
      await service.headersFor(link.originalUri(id: 1, cacheKey: '1_1')),
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
    expect(await service.synologySharePassword(host), isNull);
    final headers = await service.headersFor(Uri.parse('https://$host/a.jpg'));
    expect(headers?['Authorization'], startsWith('Basic '));
  });

  test('without sessions a share secret yields no headers', () async {
    final plain = NetworkCredentialsService(
      repository: repo,
      storage: keychain,
    );
    await plain.save(
      hostname: host,
      authType: 'synologyShare',
      password: 'secret',
    );
    final link = SynologyShareLink.tryParseShareLink(shareLink)!;
    expect(
      await plain.headersFor(link.originalUri(id: 1, cacheKey: '1_1')),
      isNull,
    );
    // The stored secret stays: it is valid, this instance just cannot use it.
    expect(keychain.values, isNotEmpty);
  });
}
