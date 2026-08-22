import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';

void main() {
  group('login', () {
    test(
      'sends a form-encoded POST and stores the returned session key',
      () async {
        http.Request? captured;
        final client = SuuntoCloudClient(
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(jsonEncode({'sessionkey': 'sk-abc'}), 200);
          }),
        );

        final key = await client.login('diver@example.com', 'hunter2');

        expect(key, 'sk-abc');
        expect(client.sessionKey, 'sk-abc');
        expect(client.hasSession, isTrue);

        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/apiserver/v1/login2');
        final body = captured!.body;
        expect(body, contains('l=diver%40example.com'));
        expect(body, contains('p=hunter2'));
        expect(body, contains('totp='));
        expect(body, contains('signature='));
        expect(body, contains('salt='));
        expect(
          captured!.headers['Content-Type'],
          contains('application/x-www-form-urlencoded'),
        );
      },
    );

    test('throws when the response has no sessionkey', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({}), 200);
        }),
      );

      expect(
        () => client.login('diver@example.com', 'hunter2'),
        throwsA(isA<SuuntoApiException>()),
      );
    });

    test('throws on a rejected login (401)', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          return http.Response('unauthorized', 401);
        }),
      );

      expect(
        () => client.login('diver@example.com', 'wrong-password'),
        throwsA(
          isA<SuuntoApiException>().having(
            (e) => e.isSessionRejected,
            'isSessionRejected',
            isTrue,
          ),
        ),
      );
    });
  });

  group('verifySession', () {
    test('returns true when the session is still accepted', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          expect(request.headers['STTAuthorization'], 'sk-abc');
          return http.Response(jsonEncode({'payload': []}), 200);
        }),
      )..sessionKey = 'sk-abc';

      expect(await client.verifySession(), isTrue);
    });

    test('returns false when the server rejects the session', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          return http.Response('unauthorized', 401);
        }),
      )..sessionKey = 'stale-key';

      expect(await client.verifySession(), isFalse);
    });
  });

  group('listDives', () {
    test(
      'filters to scuba/freediving activities and sorts by start time',
      () async {
        final client = SuuntoCloudClient(
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'payload': [
                  {'key': 'later', 'activityId': 78, 'startTime': 2000},
                  {'key': 'running', 'activityId': 1, 'startTime': 1500},
                  {'key': 'earlier', 'activityId': 79, 'startTime': 1000},
                ],
              }),
              200,
            );
          }),
        )..sessionKey = 'sk-abc';

        final dives = await client.listDives();

        expect(dives.map((d) => d.key).toList(), ['earlier', 'later']);
        expect(dives[0].activityId, 79);
        expect(dives[1].activityId, 78);
      },
    );

    test('paginates until a short page is returned', () async {
      final offsetsSeen = <int>[];
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
          offsetsSeen.add(offset);
          final items = offset == 0
              ? List.generate(
                  100,
                  (i) => {'key': 'dive-$i', 'activityId': 78, 'startTime': i},
                )
              : [
                  {'key': 'dive-100', 'activityId': 78, 'startTime': 100},
                ];
          return http.Response(jsonEncode({'payload': items}), 200);
        }),
      );

      final dives = await client.listDives();

      expect(offsetsSeen, [0, 100]);
      expect(dives, hasLength(101));
    });

    test('reads maxDepth/diveTime from the DiveHeaderExtension', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'payload': [
                {
                  'key': 'dive-1',
                  'activityId': 78,
                  'startTime': 1000,
                  'totalTime': 1900.0,
                  'extensions': [
                    {
                      'type': 'DiveHeaderExtension',
                      'maxDepth': 18.5,
                      'diveTime': 1800.0,
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );

      final dives = await client.listDives();
      expect(dives.single.maxDepth, 18.5);
      expect(dives.single.diveTimeSeconds, 1800);
      expect(dives.single.durationSeconds, 1800);
    });

    test('throws on an API error envelope', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {'code': 5, 'description': 'boom'},
            }),
            200,
          );
        }),
      );

      expect(
        () => client.listDives(),
        throwsA(
          isA<SuuntoApiException>().having(
            (e) => e.message,
            'message',
            contains('boom'),
          ),
        ),
      );
    });
  });

  group('fetchSmlJson', () {
    test('GETs the per-dive sml endpoint with the session header', () async {
      http.Request? captured;
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{"ok":true}', 200);
        }),
      )..sessionKey = 'sk-abc';

      final bytes = await client.fetchSmlJson('dive-key-1');

      expect(utf8.decode(bytes), '{"ok":true}');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/apiserver/v1/workouts/dive-key-1/sml');
      expect(captured!.headers['STTAuthorization'], 'sk-abc');
    });

    test('throws with a snippet of the body on a server error', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          return http.Response('server exploded', 500);
        }),
      );

      expect(
        () => client.fetchSmlJson('dive-key-1'),
        throwsA(
          isA<SuuntoApiException>().having(
            (e) => e.message,
            'message',
            contains('server exploded'),
          ),
        ),
      );
    });
  });
}
