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
}
