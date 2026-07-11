import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';

import '../../../support/fake_keychain_storage.dart';

const _guard = 'while (1) {}';

void main() {
  Future<LightroomApiClient> client(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt'),
    );
    final auth = AdobeImsAuthManager(
      store: store,
      httpClient: MockClient((req) async {
        if (req.url.host == 'ims-na1.adobelogin.com') {
          return http.Response(
            jsonEncode({'access_token': 'at', 'expires_in': 3600}),
            200,
          );
        }
        return handler(req);
      }),
    );
    return LightroomApiClient(auth: auth, httpClient: MockClient(handler));
  }

  test('stripAbuseGuard removes the prefix and leaves other bodies alone', () {
    expect(LightroomApiClient.stripAbuseGuard('$_guard{"a":1}'), '{"a":1}');
    expect(LightroomApiClient.stripAbuseGuard('$_guard\n{"a":1}'), '{"a":1}');
    expect(LightroomApiClient.stripAbuseGuard('{"a":1}'), '{"a":1}');
  });

  test('getAccount sends bearer and api key headers', () async {
    late http.Request captured;
    final c = await client((req) async {
      captured = req;
      return http.Response(
        '$_guard${jsonEncode({'id': 'acc1', 'full_name': 'Eric G', 'email': 'e@g.c'})}',
        200,
      );
    });
    final account = await c.getAccount();
    expect(account.id, 'acc1');
    expect(account.fullName, 'Eric G');
    expect(account.email, 'e@g.c');
    expect(captured.url.toString(), 'https://lr.adobe.io/v2/account');
    expect(captured.headers['Authorization'], 'Bearer at');
    expect(captured.headers['X-API-Key'], 'cid');
  });

  test('getCatalogId returns the catalog id', () async {
    final c = await client(
      (req) async => http.Response('$_guard${jsonEncode({'id': 'cat9'})}', 200),
    );
    expect(await c.getCatalogId(), 'cat9');
  });

  test(
    'listAssets parses assets, pagination link, and capture params',
    () async {
      late http.Request captured;
      final fixture =
          _guard +
          jsonEncode({
            'resources': [
              {
                'id': 'asset1',
                'subtype': 'image',
                'payload': {
                  'captureDate': '2026-07-01T10:15:00',
                  'importSource': {'fileName': 'IMG_1.jpg'},
                  'location': {'latitude': 4.5, 'longitude': 55.5},
                },
              },
              {
                'id': 'asset2',
                'subtype': 'video',
                'payload': {
                  'captureDate': '2026-07-01T10:20:00',
                  'importSource': {'fileName': 'MOV_1.mp4'},
                  'video': {'duration': 12.5},
                },
              },
              {
                'id': 'asset3',
                'subtype': 'image',
                'payload': {'captureDate': '0000-00-00T00:00:00'},
              },
            ],
            'links': {
              'next': {'href': '/v2/catalogs/cat1/assets?name_after=asset2'},
            },
          });
      final c = await client((req) async {
        captured = req;
        return http.Response(fixture, 200);
      });
      final page = await c.listAssets(
        'cat1',
        capturedAfter: DateTime.utc(2026, 7, 1, 9),
        capturedBefore: DateTime.utc(2026, 7, 1, 12),
      );
      expect(captured.url.path, '/v2/catalogs/cat1/assets');
      expect(captured.url.queryParameters['subtype'], 'image;video');
      expect(
        captured.url.queryParameters['captured_after'],
        '2026-07-01T09:00:00.000',
      );
      expect(
        captured.url.queryParameters['captured_before'],
        '2026-07-01T12:00:00.000',
      );
      expect(page.assets, hasLength(3));
      final a1 = page.assets[0];
      expect(a1.id, 'asset1');
      expect(a1.captureDate, DateTime.utc(2026, 7, 1, 10, 15));
      expect(a1.fileName, 'IMG_1.jpg');
      expect(a1.latitude, 4.5);
      expect(a1.longitude, 55.5);
      expect(a1.isVideo, isFalse);
      final a2 = page.assets[1];
      expect(a2.isVideo, isTrue);
      expect(a2.videoDurationSeconds, 13);
      expect(page.assets[2].captureDate, isNull);
      expect(
        page.nextUrl,
        'https://lr.adobe.io/v2/catalogs/cat1/assets?name_after=asset2',
      );
    },
  );

  test('listAssets with nextUrl requests it verbatim', () async {
    late http.Request captured;
    final c = await client((req) async {
      captured = req;
      return http.Response('$_guard${jsonEncode({'resources': []})}', 200);
    });
    final page = await c.listAssets(
      'cat1',
      nextUrl: 'https://lr.adobe.io/v2/catalogs/cat1/assets?name_after=x',
    );
    expect(
      captured.url.toString(),
      'https://lr.adobe.io/v2/catalogs/cat1/assets?name_after=x',
    );
    expect(page.assets, isEmpty);
    expect(page.nextUrl, isNull);
  });

  test('listAlbumAssets unwraps embedded assets', () async {
    late http.Request captured;
    final fixture =
        _guard +
        jsonEncode({
          'resources': [
            {
              'id': 'albumasset1',
              'asset': {
                'id': 'asset7',
                'subtype': 'image',
                'payload': {
                  'captureDate': '2026-07-02T08:00:00',
                  'importSource': {'fileName': 'IMG_7.jpg'},
                },
              },
            },
            {'id': 'albumasset2'},
          ],
        });
    final c = await client((req) async {
      captured = req;
      return http.Response(fixture, 200);
    });
    final page = await c.listAlbumAssets('cat1', 'al1');
    expect(captured.url.path, '/v2/catalogs/cat1/albums/al1/assets');
    expect(captured.url.queryParameters['embed'], 'asset');
    expect(page.assets, hasLength(1));
    expect(page.assets.single.id, 'asset7');
  });

  test('listAlbums follows pagination and reads names', () async {
    var call = 0;
    final c = await client((req) async {
      call++;
      if (call == 1) {
        return http.Response(
          _guard +
              jsonEncode({
                'resources': [
                  {
                    'id': 'al1',
                    'payload': {'name': 'Diving'},
                  },
                ],
                'links': {
                  'next': {'href': '/v2/catalogs/cat1/albums?after=al1'},
                },
              }),
          200,
        );
      }
      return http.Response(
        _guard +
            jsonEncode({
              'resources': [
                {'id': 'al2', 'payload': <String, Object?>{}},
              ],
            }),
        200,
      );
    });
    final albums = await c.listAlbums('cat1');
    expect(albums, hasLength(2));
    expect(albums[0].name, 'Diving');
    expect(albums[1].name, 'Untitled');
  });

  test('getRendition returns raw bytes and throws typed 404', () async {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0x01]);
    final c = await client((req) async {
      if (req.url.path.endsWith('/renditions/2048')) {
        return http.Response.bytes(bytes, 200);
      }
      return http.Response('nope', 404);
    });
    expect(
      await c.getRendition(catalogId: 'cat1', assetId: 'a1', size: '2048'),
      bytes,
    );
    await expectLater(
      c.getRendition(catalogId: 'cat1', assetId: 'a1', size: 'thumbnail2x'),
      throwsA(
        isA<LightroomApiException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
  });

  test('401 throws a reconnect-worded LightroomApiException', () async {
    final c = await client((req) async => http.Response('denied', 401));
    await expectLater(
      c.getCatalogId(),
      throwsA(
        isA<LightroomApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having(
              (e) => e.message.toLowerCase(),
              'msg',
              contains('reconnect'),
            ),
      ),
    );
  });

  test('assetWebUrl builds the lightroom.adobe.com link', () {
    expect(
      LightroomApiClient.assetWebUrl('cat1', 'a1'),
      'https://lightroom.adobe.com/libraries/cat1/assets/a1',
    );
  });
}
