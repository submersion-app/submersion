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
      'filters to scuba/freediving activities and sorts newest first',
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

        expect(dives.map((d) => d.key).toList(), ['later', 'earlier']);
        expect(dives[0].activityId, 78);
        expect(dives[1].activityId, 79);
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

      final dives = await client.listDives(pageSize: 100);

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

  group('listDivesPaged', () {
    test('yields one page per API round trip', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
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

      final pages = await client.listDivesPaged().toList();

      expect(pages, hasLength(2));
      expect(pages[0], hasLength(100));
      expect(pages[1], hasLength(1));
    });

    test(
      'lets a caller act on the newest page before older pages arrive',
      () async {
        final client = SuuntoCloudClient(
          httpClient: MockClient((request) async {
            final offset = int.parse(request.url.queryParameters['offset']!);
            // Suunto's workout listing is served oldest-to-newest by offset,
            // so the fake server places the newest workout on the first
            // page (offset 0) the same way the real API would sort within a
            // page.
            final items = offset == 0
                ? [
                    {'key': 'newest', 'activityId': 78, 'startTime': 999999},
                    for (var i = 0; i < 99; i++)
                      {'key': 'dive-$i', 'activityId': 78, 'startTime': i},
                  ]
                : [
                    {'key': 'dive-99', 'activityId': 78, 'startTime': 99},
                  ];
            return http.Response(jsonEncode({'payload': items}), 200);
          }),
        );

        final seenAfterFirstPage = <String>[];
        await for (final page in client.listDivesPaged()) {
          if (seenAfterFirstPage.isEmpty) {
            seenAfterFirstPage.addAll(page.map((d) => d.key));
          }
        }

        // The newest workout is server-ordered first, so it must be visible
        // after only the first page has arrived, not just once every page
        // has been fetched.
        expect(seenAfterFirstPage, contains('newest'));
      },
    );
  });

  group('fetchDivePage', () {
    test('walks past a listing page that holds no dives', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
          // The listing carries every activity type; 78 is scuba diving and
          // 1 is a run, which the client filters out on its own side.
          final items = offset == 0
              ? [
                  {'key': 'run-1', 'activityId': 1, 'startTime': 1},
                  {'key': 'run-2', 'activityId': 1, 'startTime': 2},
                ]
              : [
                  {'key': 'dive-1', 'activityId': 78, 'startTime': 3},
                ];
          return http.Response(jsonEncode({'payload': items}), 200);
        }),
      );

      final page = await client.fetchDivePage(pageSize: 2);

      // The first listing page filtered down to nothing. Returning it as-is
      // would read to a caller as "the account has no dives", so the client
      // keeps walking until it has a real page or runs out of history.
      expect(page.dives.map((d) => d.key).toList(), ['dive-1']);
      expect(page.hasMore, isFalse);
    });

    test(
      'hands back a cursor the caller can resume the next page from',
      () async {
        final client = SuuntoCloudClient(
          httpClient: MockClient((request) async {
            final offset = int.parse(request.url.queryParameters['offset']!);
            final items = offset == 0
                ? [
                    {'key': 'dive-1', 'activityId': 78, 'startTime': 2},
                    {'key': 'dive-2', 'activityId': 78, 'startTime': 1},
                  ]
                : [
                    {'key': 'dive-3', 'activityId': 78, 'startTime': 0},
                  ];
            return http.Response(jsonEncode({'payload': items}), 200);
          }),
        );

        final first = await client.fetchDivePage(pageSize: 2);
        expect(first.dives.map((d) => d.key).toList(), ['dive-1', 'dive-2']);
        expect(first.hasMore, isTrue);

        // Fetching a page is a plain call rather than a step through a live
        // stream, so a caller that hit a transient failure can ask for the
        // same page again instead of losing the rest of the history.
        final second = await client.fetchDivePage(
          offset: first.nextOffset,
          pageSize: 2,
        );
        expect(second.dives.map((d) => d.key).toList(), ['dive-3']);
        expect(second.hasMore, isFalse);
      },
    );

    test('reports an exhausted history as an empty page', () async {
      final client = SuuntoCloudClient(
        httpClient: MockClient(
          (request) async => http.Response(jsonEncode({'payload': []}), 200),
        ),
      );

      final page = await client.fetchDivePage();

      expect(page.dives, isEmpty);
      expect(page.hasMore, isFalse);
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
