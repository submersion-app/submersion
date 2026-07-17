import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';

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

  test('getDivelist parses array body and counts unusable rows', () async {
    final api = client((req) async {
      expect(req.url.path, '/api/divelist');
      return http.Response(
        jsonEncode([
          {'id': 1, 'date': '2022-09-03', 'time': '10:00:00'},
          {'no_id': true},
        ]),
        200,
      );
    });
    final result = await api.getDivelist();
    expect(result.entries, hasLength(1));
    expect(result.entries.single.id, '1');
    expect(result.skippedCount, 1);
  });

  test('getDivelist tolerates object body with dives/divelist key', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode({
          'divelist': [
            {'id': 1, 'date': '2022-09-03', 'time': '10:00:00'},
          ],
        }),
        200,
      ),
    );
    expect((await api.getDivelist()).entries, hasLength(1));
  });

  test('postDives sends JSON array body with bearer header', () async {
    late http.Request captured;
    final api = client((req) async {
      captured = req;
      return http.Response('{"success": true}', 200);
    });
    await api.postDives([
      {'date': '2022-09-03', 'time': '10:00:00', 'duration': 60, 'maxdepth': 5},
    ]);
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://divelogs.de/api/dives');
    expect(captured.headers['Authorization'], 'Bearer t1');
    expect(captured.headers['Content-Type'], startsWith('application/json'));
    final body = jsonDecode(captured.body) as List;
    expect(body, hasLength(1));
  });

  test('postDives retries once on 401 then succeeds', () async {
    var calls = 0;
    final api = client((req) async {
      calls++;
      if (req.headers['Authorization'] == 'Bearer t1') {
        return http.Response('', 401);
      }
      return http.Response('{}', 200);
    }, tokens: ['t1', 't2']);
    await api.postDives([
      {'duration': 60},
    ]);
    expect(calls, 2);
  });

  test('postDives throws DivelogsApiException on 400', () async {
    final api = client((req) async => http.Response('bad', 400));
    expect(
      () => api.postDives([<String, dynamic>{}]),
      throwsA(
        isA<DivelogsApiException>().having((e) => e.statusCode, 'status', 400),
      ),
    );
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

  test('postGear sends JSON POST to /api/gear', () async {
    late http.Request captured;
    final api = client((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    await api.postGear({'name': 'Apex XTX50', 'geartype': 1});
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/gear');
    expect(jsonDecode(captured.body), {'name': 'Apex XTX50', 'geartype': 1});
  });

  test('postCertification sends multipart fields with bearer header', () async {
    // MockClient materializes multipart bodies into encoded form-data, so
    // capture the BaseRequest instead to assert on the typed fields.
    late http.MultipartRequest captured;
    var calls = 0;
    final api = DivelogsApiClient(
      getBearerToken: () async => 't1',
      onTokenRejected: () {},
      httpClient: _CapturingClient((req) {
        calls++;
        captured = req as http.MultipartRequest;
      }),
    );
    await api.postCertification(
      name: 'Open Water Diver',
      date: '2022-06-15',
      org: 'PADI',
    );
    expect(calls, 1);
    expect(captured.url.path, '/api/certifications');
    expect(captured.headers['Authorization'], 'Bearer t1');
    expect(captured.fields, {
      'name': 'Open Water Diver',
      'date': '2022-06-15',
      'org': 'PADI',
    });
  });

  test('postCertification retries once on 401', () async {
    var calls = 0;
    final tokens = ['t1', 't2'];
    final api = DivelogsApiClient(
      getBearerToken: () async =>
          tokens.length > 1 ? tokens.removeAt(0) : tokens.first,
      onTokenRejected: () {},
      httpClient: _CapturingClient(
        (req) => calls++,
        statusFor: (req) =>
            req.headers['Authorization'] == 'Bearer t1' ? 401 : 200,
      ),
    );
    await api.postCertification(name: 'OWD', date: '2022-06-15');
    expect(calls, 2);
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

  test('postPicture sends a multipart imagefile part with filename', () async {
    late http.MultipartRequest captured;
    final api = DivelogsApiClient(
      getBearerToken: () async => 't1',
      onTokenRejected: () {},
      httpClient: _CapturingClient(
        (req) => captured = req as http.MultipartRequest,
      ),
    );
    await api.postPicture('4711', bytes: [1, 2, 3], filename: 'photo.jpg');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/pictures/4711');
    expect(captured.headers['Authorization'], 'Bearer t1');
    expect(captured.files, hasLength(1));
    expect(captured.files.single.field, 'imagefile');
    expect(captured.files.single.filename, 'photo.jpg');
  });

  test('postPicture retries once on 401', () async {
    var calls = 0;
    final tokens = ['t1', 't2'];
    final api = DivelogsApiClient(
      getBearerToken: () async =>
          tokens.length > 1 ? tokens.removeAt(0) : tokens.first,
      onTokenRejected: () {},
      httpClient: _CapturingClient(
        (req) => calls++,
        statusFor: (req) =>
            req.headers['Authorization'] == 'Bearer t1' ? 401 : 200,
      ),
    );
    await api.postPicture('9', bytes: [1], filename: 'x.jpg');
    expect(calls, 2);
  });
}

/// Minimal client that captures BaseRequests (MockClient materializes
/// multipart bodies, losing the fields we want to assert on).
class _CapturingClient extends http.BaseClient {
  _CapturingClient(this.onRequest, {this.statusFor});

  final void Function(http.BaseRequest) onRequest;
  final int Function(http.BaseRequest)? statusFor;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest(request);
    final status = statusFor?.call(request) ?? 200;
    return http.StreamedResponse(Stream.value('{}'.codeUnits), status);
  }
}
