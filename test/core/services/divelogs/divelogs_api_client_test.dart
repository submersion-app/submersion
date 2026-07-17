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
}
