import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_models.dart';
import 'package:submersion/core/services/google_photos/google_photos_picker_client.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  Future<GooglePhotosPickerClient> client(
    Future<http.Response> Function(http.Request) handler, {
    int Function()? accessTokenCalls,
  }) async {
    final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
    await store.save(const GooglePhotosAuthData(refreshToken: 'rt'));
    final auth = GooglePhotosAuthManager(
      store: store,
      clientId: 'cid',
      clientSecret: 'secret',
      httpClient: MockClient((req) async {
        if (req.url.host == 'oauth2.googleapis.com') {
          return http.Response(
            jsonEncode({'access_token': 'at', 'expires_in': 3600}),
            200,
          );
        }
        return handler(req);
      }),
    );
    return GooglePhotosPickerClient(
      auth: auth,
      httpClient: MockClient(handler),
    );
  }

  test('createSession posts and parses the session', () async {
    late http.Request captured;
    final c = await client((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'id': 'sess1',
          'pickerUri': 'https://photos.google.com/share/pick/sess1',
          'mediaItemsSet': false,
          'pollingConfig': {'pollInterval': '3s', 'timeoutIn': '1800s'},
          'expireTime': '2026-09-09T13:00:00Z',
        }),
        200,
      );
    });
    final session = await c.createSession();
    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://photospicker.googleapis.com/v1/sessions',
    );
    expect(captured.headers['Authorization'], 'Bearer at');
    expect(session.id, 'sess1');
    expect(session.pickerUri, endsWith('/pick/sess1'));
    expect(session.mediaItemsSet, isFalse);
    expect(session.pollInterval, const Duration(seconds: 3));
    expect(session.expireTime, DateTime.utc(2026, 9, 9, 13));
  });

  test('getSession reflects the picked state', () async {
    final c = await client(
      (req) async => http.Response(
        jsonEncode({'id': 'sess1', 'mediaItemsSet': true}),
        200,
      ),
    );
    final session = await c.getSession('sess1');
    expect(session.mediaItemsSet, isTrue);
  });

  test('listMediaItems follows pagination and parses metadata', () async {
    final c = await client((req) async {
      expect(req.url.queryParameters['sessionId'], 'sess1');
      final page = req.url.queryParameters['pageToken'];
      if (page == null) {
        return http.Response(
          jsonEncode({
            'mediaItems': [
              {
                'id': 'm1',
                'createTime': '2026-08-01T09:15:00Z',
                'type': 'PHOTO',
                'mediaFile': {
                  'baseUrl': 'https://lh3.googleusercontent.com/m1',
                  'mimeType': 'image/jpeg',
                  'filename': 'DSC_0001.JPG',
                  'mediaFileMetadata': {
                    'width': 6000,
                    'height': 4000,
                    'cameraMake': 'NIKON',
                    'cameraModel': 'Z6',
                  },
                },
              },
            ],
            'nextPageToken': 'p2',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'mediaItems': [
            {
              'id': 'm2',
              'type': 'VIDEO',
              'mediaFile': {
                'baseUrl': 'https://lh3.googleusercontent.com/m2',
                'mimeType': 'video/mp4',
              },
            },
          ],
        }),
        200,
      );
    });

    final items = await c.listMediaItems('sess1');
    expect(items.map((i) => i.id), ['m1', 'm2']);
    final photo = items.first;
    expect(photo.type, PickedMediaType.photo);
    expect(photo.createTime, DateTime.utc(2026, 8, 1, 9, 15));
    expect(photo.width, 6000);
    expect(photo.cameraModel, 'Z6');
    expect(items[1].isVideo, isTrue);
  });

  test('downloadBytes asks for the original with =d for a photo and '
      '=dv for a video', () async {
    final urls = <String>[];
    final c = await client((req) async {
      urls.add(req.url.toString());
      return http.Response.bytes([1, 2, 3], 200);
    });
    const photo = PickedMediaItem(
      id: 'm1',
      type: PickedMediaType.photo,
      baseUrl: 'https://lh3.googleusercontent.com/m1',
      mimeType: 'image/jpeg',
    );
    const video = PickedMediaItem(
      id: 'm2',
      type: PickedMediaType.video,
      baseUrl: 'https://lh3.googleusercontent.com/m2',
      mimeType: 'video/mp4',
    );
    expect(await c.downloadBytes(photo), [1, 2, 3]);
    await c.downloadBytes(video);
    await c.downloadBytes(photo, width: 256, height: 256);
    expect(urls, [
      'https://lh3.googleusercontent.com/m1=d',
      'https://lh3.googleusercontent.com/m2=dv',
      'https://lh3.googleusercontent.com/m1=w256-h256',
    ]);
  });

  test('a 401 triggers exactly one token refresh and retry', () async {
    var calls = 0;
    final c = await client((req) async {
      calls++;
      if (calls == 1) {
        return http.Response('{"error":{"message":"stale"}}', 401);
      }
      return http.Response(jsonEncode({'id': 'sess1'}), 200);
    });
    final session = await c.getSession('sess1');
    expect(session.id, 'sess1');
    expect(calls, 2);
  });

  test('a persistent non-2xx surfaces as GooglePhotosApiException with the '
      "server's message", () async {
    final c = await client(
      (_) async => http.Response(
        jsonEncode({
          'error': {'code': 403, 'message': 'Permission denied on session.'},
        }),
        403,
      ),
    );
    await expectLater(
      c.listMediaItems('sess1'),
      throwsA(
        isA<GooglePhotosApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having(
              (e) => e.message,
              'message',
              'Permission denied on session.',
            ),
      ),
    );
  });

  test('a transport error (not just http.ClientException) surfaces as a '
      'statusCode-0 GooglePhotosApiException', () async {
    final c = await client((_) async => throw const SocketException('down'));
    await expectLater(
      c.getSession('sess1'),
      throwsA(
        isA<GooglePhotosApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          0,
        ),
      ),
    );
  });

  test('deleteSession swallows failures', () async {
    final c = await client((_) async => http.Response('nope', 500));
    await c.deleteSession('sess1'); // must not throw
  });
}
