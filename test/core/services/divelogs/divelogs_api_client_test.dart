import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth.dart';

void main() {
  Map<String, dynamic> diveJson(int id) => {
    'id': id,
    'date': '2022-09-03',
    'time': '14:42:00',
    'duration': 2808,
    'maxdepth': 12,
  };

  DivelogsApiClient client(
    Future<http.Response> Function(http.Request) handler, {
    void Function()? onRejected,
    List<String>? tokens,
  }) {
    final queue = List<String>.from(tokens ?? ['t1']);
    return DivelogsApiClient(
      getBearerToken: () async =>
          queue.length > 1 ? queue.removeAt(0) : queue.first,
      onTokenRejected: onRejected ?? () {},
      httpClient: MockClient(handler),
    );
  }

  test('getAllDives sends bearer header and parses array body', () async {
    late http.Request captured;
    final api = client((req) async {
      captured = req;
      return http.Response(jsonEncode([diveJson(1), diveJson(2)]), 200);
    });
    final result = await api.getAllDives();
    expect(captured.url.toString(), 'https://divelogs.de/api/dives');
    expect(captured.headers['Authorization'], 'Bearer t1');
    expect(result.dives, hasLength(2));
    expect(result.skippedCount, 0);
  });

  test('getAllDives tolerates object body with dives key', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode({
          'dives': [diveJson(1)],
        }),
        200,
      ),
    );
    final result = await api.getAllDives();
    expect(result.dives, hasLength(1));
  });

  test('getAllDives skips malformed dives and counts them', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode([
          diveJson(1),
          {'date': '2022-01-01'},
        ]),
        200,
      ),
    );
    final result = await api.getAllDives();
    expect(result.dives, hasLength(1));
    expect(result.skippedCount, 1);
  });

  test('401 invalidates token and retries exactly once', () async {
    var rejections = 0;
    var calls = 0;
    final api = client(
      (req) async {
        calls++;
        if (req.headers['Authorization'] == 'Bearer t1') {
          return http.Response('', 401);
        }
        return http.Response(jsonEncode([diveJson(1)]), 200);
      },
      onRejected: () => rejections++,
      tokens: ['t1', 't2'],
    );
    final result = await api.getAllDives();
    expect(result.dives, hasLength(1));
    expect(rejections, 1);
    expect(calls, 2);
  });

  test('second 401 throws DivelogsApiException', () async {
    final api = client((req) async => http.Response('', 401));
    expect(
      () => api.getAllDives(),
      throwsA(
        isA<DivelogsApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });

  test('getUser returns decoded map', () async {
    final api = client(
      (req) async => http.Response(jsonEncode({'username': 'eric'}), 200),
    );
    final user = await api.getUser();
    expect(user['username'], 'eric');
  });

  test('getGear parses array and skips unusable rows', () async {
    final api = client((req) async {
      expect(req.url.path, '/api/gear');
      return http.Response(
        jsonEncode([
          {'id': 45, 'name': 'Apex XTX50', 'geartype': 1},
          {'geartype': 2},
        ]),
        200,
      );
    });
    final gear = await api.getGear();
    expect(gear, hasLength(1));
    expect(gear.single.id, '45');
  });

  test('getGeartypes accepts array-of-objects form', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode([
          {'id': 1, 'name': 'Regulator'},
          {'id': 2, 'name': 'Jacket'},
        ]),
        200,
      ),
    );
    expect(await api.getGeartypes(), {1: 'Regulator', 2: 'Jacket'});
  });

  test('getGeartypes accepts id-to-name map form', () async {
    final api = client(
      (req) async =>
          http.Response(jsonEncode({'1': 'Regulator', '2': 'Jacket'}), 200),
    );
    expect(await api.getGeartypes(), {1: 'Regulator', 2: 'Jacket'});
  });

  test('getCertifications parses documented array', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode([
          {
            'id': 123,
            'name': 'Open Water Diver',
            'date': '2022-06-15',
            'org': 'PADI',
          },
        ]),
        200,
      ),
    );
    final certs = await api.getCertifications();
    expect(certs, hasLength(1));
    expect(certs.single.org, 'PADI');
  });

  test('getPictures parses an array body', () async {
    final api = client((req) async {
      expect(req.url.path, '/api/pictures/4711');
      return http.Response(
        jsonEncode([
          {'id': 1, 'url': 'https://divelogs.de/p/1.jpg'},
          {'id': 2, 'url': '2.jpg'},
        ]),
        200,
      );
    });
    final pics = await api.getPictures('4711');
    expect(pics, hasLength(2));
    expect(pics[0].url, Uri.parse('https://divelogs.de/p/1.jpg'));
    expect(pics[1].url, isNull);
  });

  test('getPictures tolerates a {pictures: [...]} wrapper', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode({
          'pictures': [
            {'id': 1, 'url': 'https://divelogs.de/p/1.jpg'},
          ],
        }),
        200,
      ),
    );
    expect((await api.getPictures('9')).single.id, '1');
  });

  test(
    'downloadPictureBytes sends bearer to the exact url, returns bytes',
    () async {
      late Uri requested;
      final api = client((req) async {
        requested = req.url;
        expect(req.headers['Authorization'], 'Bearer t1');
        return http.Response.bytes([1, 2, 3, 4], 200);
      });
      final bytes = await api.downloadPictureBytes(
        Uri.parse('https://cdn.divelogs.de/p/5.jpg'),
      );
      expect(requested, Uri.parse('https://cdn.divelogs.de/p/5.jpg'));
      expect(bytes, [1, 2, 3, 4]);
    },
  );

  test('downloadPictureBytes retries once on 401', () async {
    var calls = 0;
    final api = client((req) async {
      calls++;
      if (req.headers['Authorization'] == 'Bearer t1') {
        return http.Response('', 401);
      }
      return http.Response.bytes([9], 200);
    }, tokens: ['t1', 't2']);
    final bytes = await api.downloadPictureBytes(
      Uri.parse('https://cdn.divelogs.de/p/5.jpg'),
    );
    expect(bytes, [9]);
    expect(calls, 2);
  });

  test('a session-expired token failure propagates untouched', () async {
    final client = DivelogsApiClient(
      getBearerToken: () async => throw const DivelogsSessionExpiredException(),
      onTokenRejected: () {},
      httpClient: MockClient((_) async => fail('no request without a token')),
    );
    await expectLater(
      client.getAllDives(),
      throwsA(isA<DivelogsSessionExpiredException>()),
    );
  });

  group('picture downloads', () {
    Future<String?> authHeaderFor(String url) async {
      String? seen = 'unset';
      final api = client((req) async {
        seen = req.headers['Authorization'];
        return http.Response.bytes([1], 200);
      });
      await api.downloadPictureBytes(Uri.parse(url));
      return seen;
    }

    test('send the token to the API host over https', () async {
      expect(
        await authHeaderFor('https://divelogs.de/pics/a.jpg'),
        'Bearer t1',
      );
      expect(await authHeaderFor('https://img.divelogs.de/a.jpg'), 'Bearer t1');
    });

    test('never send the token to another host or over http', () async {
      expect(await authHeaderFor('https://cdn.example.com/a.jpg'), isNull);
      expect(await authHeaderFor('https://evildivelogs.de/a.jpg'), isNull);
    });

    test('an http link on the API host is fetched over https', () async {
      Uri? requested;
      String? auth;
      final api = client((req) async {
        requested = req.url;
        auth = req.headers['Authorization'];
        return http.Response.bytes([1], 200);
      });
      await api.downloadPictureBytes(
        Uri.parse('http://divelogs.de/pics/a.jpg'),
      );
      expect(requested!.scheme, 'https');
      expect(auth, 'Bearer t1');
      expect(
        await authHeaderFor('http://cdn.example.com/a.jpg'),
        isNull,
        reason: 'another host over http never gets the token',
      );
    });

    test('a download that never answers times out as an API error', () async {
      final api = DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((_) => Completer<http.Response>().future),
        pictureTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        api.downloadPictureBytes(Uri.parse('https://divelogs.de/p/a.jpg')),
        throwsA(isA<DivelogsApiException>()),
      );
    });

    test('a failing download from another host is an API error', () async {
      final api = client((_) async => http.Response('', 404));
      await expectLater(
        api.downloadPictureBytes(Uri.parse('https://cdn.example.com/a.jpg')),
        throwsA(isA<DivelogsApiException>()),
      );
    });
  });

  test('getPictures keeps a dive id as a single path segment', () async {
    Uri? seen;
    final api = client((req) async {
      seen = req.url;
      return http.Response('[]', 200);
    });
    await api.getPictures('a/b?c#d');
    expect(seen!.pathSegments, ['api', 'pictures', 'a/b?c#d']);
    expect(seen!.query, isEmpty);
  });
}
