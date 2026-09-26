import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/garmin_connect/garmin_api_exception.dart';
import 'package:submersion/core/services/garmin_connect/garmin_auth_tokens.dart';
import 'package:submersion/core/services/garmin_connect/garmin_connect_client.dart';

/// A fake covering the exact request sequence GarminConnectClient issues, so
/// tests can assert on the real auth handshake rather than stubbing methods
/// the client doesn't actually call.
class _FakeGarminServer {
  bool mfaRequired = false;
  String mfaMethod = 'email';
  bool captchaRequired = false;
  String? acceptedMfaCode;
  String? mfaInvalidMessage;

  /// When set, `/mobile/api/login` returns this responseStatus type
  /// (optionally with [loginUnknownMessage]) instead of the usual
  /// SUCCESSFUL/MFA_REQUIRED/CAPTCHA_REQUIRED outcomes -- the shape of a
  /// status Garmin might add that this client doesn't specifically handle.
  String? loginUnknownStatus;
  String? loginUnknownMessage;

  /// When set, `/mobile/api/login` returns this raw (non-JSON) body and
  /// status instead of the usual SSO envelope -- the shape of a Cloudflare
  /// interstitial or other non-Garmin response.
  String? loginRawBody;
  int loginRawStatus = 200;

  /// Wraps the activity list in `{'activityList': [...]}` instead of
  /// returning a bare JSON array -- a shape some Connect endpoints use.
  bool wrapActivityListInMap = false;

  String serviceTicket = 'ST-01-fake-ticket';
  String oauth1Token = 'ro-token';
  String oauth1TokenSecret = 'ro-secret';
  String accessToken = 'access-token-abc';
  int expiresIn = 3600;

  final List<Map<String, dynamic>> activities = [];
  final Map<int, List<int>> fitFiles = {};

  /// Bypasses the ZIP-wrapping [fitFiles] normally goes through, so tests can
  /// serve a deliberately malformed or FIT-less archive body.
  final Map<int, List<int>> rawDownloadBytes = {};

  /// HTTP statuses a download answers with, one per attempt, before it
  /// finally serves the FIT file -- the shape of Garmin rate-limiting or a
  /// flaky backend. Consumed front to back.
  final Map<int, List<int>> downloadStatusQueue = {};

  /// Extra headers sent with each [downloadStatusQueue] failure response.
  Map<String, String> downloadFailureHeaders = const {};

  /// How many times a download throws at the transport level before it
  /// succeeds, per activity id.
  final Map<int, int> downloadTransportFailures = {};

  /// Download attempts seen, per activity id.
  final Map<int, int> downloadAttempts = {};

  /// HTTP statuses the OAuth 2 token exchange answers with, one per attempt,
  /// before it hands out a token. Consumed front to back.
  final List<int> exchangeStatusQueue = [];

  /// The Authorization header of every token-exchange attempt, so a test can
  /// check each retry carries a freshly signed request.
  final List<String?> exchangeAuthHeaders = [];

  final List<http.Request> requestsSeen = [];

  MockClient get client => MockClient((request) async {
    requestsSeen.add(request);
    return _handle(request);
  });

  Future<http.Response> _handle(http.Request request) async {
    final url = request.url;

    if (url.host == 'sso.garmin.com') {
      if (url.path == '/mobile/sso/en/sign-in') {
        return http.Response(
          '',
          200,
          headers: {'set-cookie': 'CONSENTMGR=1; Path=/'},
        );
      }
      if (url.path == '/mobile/api/login') {
        if (loginRawBody != null) {
          return http.Response(loginRawBody!, loginRawStatus);
        }
        if (captchaRequired) {
          return _ssoResponse('CAPTCHA_REQUIRED');
        }
        if (loginUnknownStatus != null) {
          return _ssoResponse(
            loginUnknownStatus!,
            message: loginUnknownMessage,
          );
        }
        if (mfaRequired) {
          return _ssoResponse(
            'MFA_REQUIRED',
            extra: {
              'customerMfaInfo': {'mfaLastMethodUsed': mfaMethod},
            },
          );
        }
        return _ssoResponse('SUCCESSFUL', ticket: serviceTicket);
      }
      if (url.path == '/mobile/api/mfa/verifyCode') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final code = body['mfaVerificationCode'] as String?;
        if (acceptedMfaCode != null && code != acceptedMfaCode) {
          return _ssoResponse('INVALID_MFA_CODE', message: mfaInvalidMessage);
        }
        return _ssoResponse('SUCCESSFUL', ticket: serviceTicket);
      }
    }

    if (url.host == 'connectapi.garmin.com') {
      if (url.path == '/oauth-service/oauth/preauthorized') {
        expect(url.queryParameters['ticket'], serviceTicket);
        final fields = {
          'oauth_token': oauth1Token,
          'oauth_token_secret': oauth1TokenSecret,
        };
        return http.Response(
          fields.entries
              .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
              .join('&'),
          200,
        );
      }
      if (url.path == '/oauth-service/oauth/exchange/user/2.0') {
        expect(request.headers['Authorization'], contains('oauth_token="'));
        exchangeAuthHeaders.add(request.headers['Authorization']);
        if (exchangeStatusQueue.isNotEmpty) {
          return http.Response('busy', exchangeStatusQueue.removeAt(0));
        }
        return http.Response(
          jsonEncode({
            'access_token': accessToken,
            'token_type': 'Bearer',
            'expires_in': expiresIn,
          }),
          200,
        );
      }
      if (url.path == '/activitylist-service/activities/search/activities') {
        expect(request.headers['Authorization'], 'Bearer $accessToken');
        final start = int.parse(url.queryParameters['start']!);
        final limit = int.parse(url.queryParameters['limit']!);
        final page = activities.skip(start).take(limit).toList();
        final body = wrapActivityListInMap ? {'activityList': page} : page;
        return http.Response(jsonEncode(body), 200);
      }
      if (url.path.startsWith('/download-service/files/activity/')) {
        final id = int.parse(url.path.split('/').last);
        downloadAttempts[id] = (downloadAttempts[id] ?? 0) + 1;
        final transportFailures = downloadTransportFailures[id] ?? 0;
        if (transportFailures > 0) {
          downloadTransportFailures[id] = transportFailures - 1;
          throw Exception('connection reset by peer');
        }
        final queued = downloadStatusQueue[id];
        if (queued != null && queued.isNotEmpty) {
          return http.Response(
            'busy',
            queued.removeAt(0),
            headers: downloadFailureHeaders,
          );
        }
        final raw = rawDownloadBytes[id];
        if (raw != null) return http.Response.bytes(raw, 200);
        final bytes = fitFiles[id];
        if (bytes == null) return http.Response('not found', 404);
        final archive = Archive()
          ..addFile(ArchiveFile('$id.fit', bytes.length, bytes));
        return http.Response.bytes(ZipEncoder().encode(archive), 200);
      }
    }

    return http.Response('not found', 404);
  }

  http.Response _ssoResponse(
    String type, {
    String? ticket,
    String? message,
    Map<String, dynamic> extra = const {},
  }) {
    return http.Response(
      jsonEncode({
        'responseStatus': {'type': type, 'message': ?message},
        'serviceTicketId': ?ticket,
        ...extra,
      }),
      200,
    );
  }
}

Map<String, dynamic> _diveActivity({
  required int id,
  String startTimeGmt = '2026-03-15 10:00:00',
  String typeKey = 'single_gas_diving',
  double? startLatitude,
  double? startLongitude,
}) => {
  'activityId': id,
  'startTimeGMT': startTimeGmt,
  'activityType': {'typeKey': typeKey},
  'activityName': 'Dive $id',
  'startLatitude': ?startLatitude,
  'startLongitude': ?startLongitude,
};

void main() {
  group('login', () {
    test('signs in and reaches an authenticated session on success', () async {
      final server = _FakeGarminServer();
      final client = GarminConnectClient(httpClient: server.client);

      final result = await client.login('diver@example.com', 'hunter2');

      expect(result.mfaRequired, isFalse);
      expect(client.hasSession, isTrue);
      expect(client.oauth1Token!.token, 'ro-token');
      expect(client.oauth1Token!.tokenSecret, 'ro-secret');
    });

    test('reports MFA required without completing the session', () async {
      final server = _FakeGarminServer()
        ..mfaRequired = true
        ..mfaMethod = 'email';
      final client = GarminConnectClient(httpClient: server.client);

      final result = await client.login('diver@example.com', 'hunter2');

      expect(result.mfaRequired, isTrue);
      expect(result.mfaMethod, 'email');
      expect(client.hasSession, isFalse);
    });

    test('throws a challenge exception on CAPTCHA', () async {
      final server = _FakeGarminServer()..captchaRequired = true;
      final client = GarminConnectClient(httpClient: server.client);

      expect(
        () => client.login('diver@example.com', 'hunter2'),
        throwsA(isA<GarminChallengeException>()),
      );
    });

    test('surfaces the server message for a status this client does not '
        'specifically handle', () async {
      final server = _FakeGarminServer()
        ..loginUnknownStatus = 'ACCOUNT_LOCKED'
        ..loginUnknownMessage = 'Too many attempts';
      final client = GarminConnectClient(httpClient: server.client);

      await expectLater(
        client.login('diver@example.com', 'hunter2'),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.message,
            'message',
            'Sign-in failed: Too many attempts',
          ),
        ),
      );
    });

    test('falls back to a generic message for an unhandled status with none '
        'of its own', () async {
      final server = _FakeGarminServer()..loginUnknownStatus = 'UNKNOWN';
      final client = GarminConnectClient(httpClient: server.client);

      await expectLater(
        client.login('diver@example.com', 'hunter2'),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.message,
            'message',
            'Sign-in failed',
          ),
        ),
      );
    });
  });

  group('transport failures', () {
    test('wraps a transport-level failure as a GarminApiException', () async {
      final client = GarminConnectClient(
        httpClient: MockClient((request) async {
          throw Exception('network unreachable');
        }),
      );

      await expectLater(
        client.login('diver@example.com', 'hunter2'),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.message,
            'message',
            'Could not reach Garmin Connect',
          ),
        ),
      );
    });

    test('does not double-wrap a GarminApiException the transport itself '
        'throws', () async {
      final client = GarminConnectClient(
        httpClient: MockClient((request) async {
          throw const GarminApiException(
            'raw transport failure',
            statusCode: 418,
          );
        }),
      );

      await expectLater(
        client.login('diver@example.com', 'hunter2'),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.message,
            'message',
            'raw transport failure',
          ),
        ),
      );
    });

    test(
      'reports a blocked-network hint when a 200 response is not JSON',
      () async {
        final server = _FakeGarminServer()
          ..loginRawBody = '<html>captive portal</html>'
          ..loginRawStatus = 200;
        final client = GarminConnectClient(httpClient: server.client);

        await expectLater(
          client.login('diver@example.com', 'hunter2'),
          throwsA(
            isA<GarminApiException>().having(
              (e) => e.message,
              'message',
              contains('may be blocked from this network'),
            ),
          ),
        );
      },
    );

    test(
      'reports the raw HTTP status when a non-200 response is not JSON',
      () async {
        final server = _FakeGarminServer()
          ..loginRawBody = 'Service Unavailable'
          ..loginRawStatus = 503;
        final client = GarminConnectClient(httpClient: server.client);

        await expectLater(
          client.login('diver@example.com', 'hunter2'),
          throwsA(
            isA<GarminApiException>().having(
              (e) => e.message,
              'message',
              'Garmin returned HTTP 503',
            ),
          ),
        );
      },
    );
  });

  group('submitMfaCode', () {
    test('completes the session after a correct code', () async {
      final server = _FakeGarminServer()
        ..mfaRequired = true
        ..acceptedMfaCode = '123456';
      final client = GarminConnectClient(httpClient: server.client);

      final result = await client.login('diver@example.com', 'hunter2');
      expect(result.mfaRequired, isTrue);

      await client.submitMfaCode('123456', mfaMethod: result.mfaMethod!);

      expect(client.hasSession, isTrue);
    });

    test('throws when no login is awaiting a code', () async {
      final client = GarminConnectClient(
        httpClient: _FakeGarminServer().client,
      );

      expect(
        () => client.submitMfaCode('123456'),
        throwsA(isA<GarminApiException>()),
      );
    });

    test('throws on an incorrect code', () async {
      final server = _FakeGarminServer()
        ..mfaRequired = true
        ..acceptedMfaCode = '123456';
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      expect(
        () => client.submitMfaCode('000000'),
        throwsA(isA<GarminApiException>()),
      );
    });

    test('surfaces the server message on an incorrect code', () async {
      final server = _FakeGarminServer()
        ..mfaRequired = true
        ..acceptedMfaCode = '123456'
        ..mfaInvalidMessage = 'Code expired';
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      await expectLater(
        client.submitMfaCode('000000'),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.message,
            'message',
            'Verification failed: Code expired',
          ),
        ),
      );
    });
  });

  group('token exchange retries', () {
    const stored = GarminOAuth1Token(
      token: 'stored-token',
      tokenSecret: 'stored-secret',
    );

    test('retries a transient failure with a freshly signed request', () async {
      final server = _FakeGarminServer()..exchangeStatusQueue.addAll([503]);
      final delays = <Duration>[];
      final client = GarminConnectClient(
        httpClient: server.client,
        retryDelay: (d) async => delays.add(d),
      );

      await client.restoreSession(stored);

      expect(client.hasSession, isTrue);
      expect(server.exchangeAuthHeaders, hasLength(2));
      // An OAuth 1 signature carries a nonce and timestamp, so replaying
      // the first attempt's header could be refused as a replay.
      expect(
        server.exchangeAuthHeaders[1],
        isNot(server.exchangeAuthHeaders[0]),
      );
      expect(delays, [const Duration(seconds: 1)]);
    });

    test('an expired access token survives a flaky re-exchange before a '
        'download', () async {
      final server = _FakeGarminServer()
        ..expiresIn = -10
        ..fitFiles[42] = [1, 2, 3, 4];
      final client = GarminConnectClient(
        httpClient: server.client,
        retryDelay: (_) async {},
      );
      await client.login('diver@example.com', 'hunter2');
      server.exchangeStatusQueue.addAll([429, 502]);

      final bytes = await client.downloadActivityFit(42);

      expect(bytes, [1, 2, 3, 4]);
    });

    test('does not retry Garmin rejecting the stored sign-in', () async {
      final server = _FakeGarminServer()..exchangeStatusQueue.addAll([401]);
      final delays = <Duration>[];
      final client = GarminConnectClient(
        httpClient: server.client,
        retryDelay: (d) async => delays.add(d),
      );

      await expectLater(
        client.restoreSession(stored),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.isAuthExpired,
            'isAuthExpired',
            isTrue,
          ),
        ),
      );
      expect(server.exchangeAuthHeaders, hasLength(1));
      expect(delays, isEmpty);
    });

    test('gives up after three attempts', () async {
      final server = _FakeGarminServer()
        ..exchangeStatusQueue.addAll([503, 503, 503, 503]);
      final client = GarminConnectClient(
        httpClient: server.client,
        retryDelay: (_) async {},
      );

      await expectLater(
        client.restoreSession(stored),
        throwsA(
          isA<GarminApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
      expect(server.exchangeAuthHeaders, hasLength(3));
    });
  });

  group('restoreSession', () {
    test('re-exchanges a stored token for a fresh access token', () async {
      final server = _FakeGarminServer();
      final client = GarminConnectClient(httpClient: server.client);

      await client.restoreSession(
        const GarminOAuth1Token(
          token: 'stored-token',
          tokenSecret: 'stored-secret',
        ),
      );

      expect(client.hasSession, isTrue);
    });

    test('throws when Garmin rejects the stored token', () async {
      final client = GarminConnectClient(
        httpClient: MockClient((request) async => http.Response('', 401)),
      );

      expect(
        () => client.restoreSession(
          const GarminOAuth1Token(token: 'x', tokenSecret: 'y'),
        ),
        throwsA(isA<GarminApiException>()),
      );
    });
  });

  group('listDives', () {
    test('filters to dive activity types and sorts newest first', () async {
      final server = _FakeGarminServer()
        ..activities.addAll([
          _diveActivity(id: 2, startTimeGmt: '2026-03-20 08:00:00'),
          _diveActivity(
            id: 3,
            startTimeGmt: '2026-01-01 08:00:00',
            typeKey: 'running',
          ),
          _diveActivity(id: 1, startTimeGmt: '2026-01-15 08:00:00'),
        ]);
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final dives = await client.listDives();

      expect(dives.map((d) => d.activityId).toList(), [2, 1]);
      expect(dives[0].startTime, DateTime.utc(2026, 3, 20, 8, 0, 0));
    });

    test('carries Connect\'s own start position through the summary', () async {
      final server = _FakeGarminServer()
        ..activities.add(
          _diveActivity(
            id: 7,
            startLatitude: 28.4594,
            startLongitude: -16.3228,
          ),
        );
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final dives = await client.listDives();

      expect(dives.single.latitude, 28.4594);
      expect(dives.single.longitude, -16.3228);
    });

    test(
      'leaves position null when Connect has none for the activity',
      () async {
        final server = _FakeGarminServer()
          ..activities.add(_diveActivity(id: 8));
        final client = GarminConnectClient(httpClient: server.client);
        await client.login('diver@example.com', 'hunter2');

        final dives = await client.listDives();

        expect(dives.single.latitude, isNull);
        expect(dives.single.longitude, isNull);
      },
    );

    test('recognizes apnea (freediving) activity types', () async {
      final server = _FakeGarminServer()
        ..activities.add(_diveActivity(id: 5, typeKey: 'apnea_hunting'));
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final dives = await client.listDives();
      expect(dives, hasLength(1));
      expect(dives.single.activityType, 'apnea_hunting');
    });

    test('paginates until a short page is returned', () async {
      final server = _FakeGarminServer()
        ..activities.addAll([
          for (var i = 0; i < 100; i++)
            _diveActivity(id: i, startTimeGmt: '2026-01-01 00:00:00'),
          _diveActivity(id: 100, startTimeGmt: '2026-01-02 00:00:00'),
        ]);
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final dives = await client.listDives();

      expect(dives, hasLength(101));
    });

    test(
      'tolerates the activity list wrapped in {activityList: [...]}',
      () async {
        final server = _FakeGarminServer()
          ..wrapActivityListInMap = true
          ..activities.add(_diveActivity(id: 9));
        final client = GarminConnectClient(httpClient: server.client);
        await client.login('diver@example.com', 'hunter2');

        final dives = await client.listDives();

        expect(dives, hasLength(1));
        expect(dives.single.activityId, 9);
      },
    );

    test('re-exchanges the access token once it has expired', () async {
      final server = _FakeGarminServer()
        ..expiresIn = -10
        ..activities.add(_diveActivity(id: 1));
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      // The token from login() is already "expired" (expiresIn: -10), so the
      // very next API call must silently re-exchange before it succeeds.
      final dives = await client.listDives();
      expect(dives, hasLength(1));
    });
  });

  group('listDivesPaged', () {
    test('yields one page per API round trip, newest first overall', () async {
      final server = _FakeGarminServer()
        ..activities.addAll([
          for (var i = 0; i < 100; i++)
            _diveActivity(id: i, startTimeGmt: '2026-01-01 00:00:00'),
          _diveActivity(id: 100, startTimeGmt: '2026-01-02 00:00:00'),
        ]);
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final pages = await client.listDivesPaged(pageSize: 100).toList();

      expect(pages, hasLength(2));
      expect(pages[0], hasLength(100));
      expect(pages[1], hasLength(1));
    });

    test(
      'lets a caller act on the newest page before older pages arrive',
      () async {
        final server = _FakeGarminServer()
          ..activities.addAll([
            // Garmin's activity list is itself served newest-first, so the
            // fake server places the newest activity at the front of the
            // underlying list the same way the real API would put it on
            // page 0.
            _diveActivity(id: 999, startTimeGmt: '2026-06-01 00:00:00'),
            for (var i = 0; i < 100; i++)
              _diveActivity(id: i, startTimeGmt: '2026-01-01 00:00:00'),
          ]);
        final client = GarminConnectClient(httpClient: server.client);
        await client.login('diver@example.com', 'hunter2');

        final seenAfterFirstPage = <int>[];
        await for (final page in client.listDivesPaged()) {
          if (seenAfterFirstPage.isEmpty) {
            seenAfterFirstPage.addAll(page.map((d) => d.activityId));
          }
        }

        // The newest activity (999) is server-ordered first, so it must be
        // visible after only the first page has arrived, not just once every
        // page has been fetched.
        expect(seenAfterFirstPage, contains(999));
      },
    );
  });

  group('fetchDivePage', () {
    test('walks past a listing page that holds no dives', () async {
      final server = _FakeGarminServer()
        ..activities.addAll([
          _diveActivity(id: 1, typeKey: 'running'),
          _diveActivity(id: 2, typeKey: 'running'),
          _diveActivity(id: 3),
        ]);
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final page = await client.fetchDivePage(pageSize: 2);

      // The first listing page filtered down to nothing. Returning it as-is
      // would read to a caller as "the account has no dives", so the client
      // keeps walking until it has a real page or runs out of history.
      expect(page.dives.map((d) => d.activityId).toList(), [3]);
      expect(page.hasMore, isFalse);
    });

    test(
      'hands back a cursor the caller can resume the next page from',
      () async {
        final server = _FakeGarminServer()
          ..activities.addAll([
            _diveActivity(id: 1, startTimeGmt: '2026-03-03 08:00:00'),
            _diveActivity(id: 2, startTimeGmt: '2026-03-02 08:00:00'),
            _diveActivity(id: 3, startTimeGmt: '2026-03-01 08:00:00'),
          ]);
        final client = GarminConnectClient(httpClient: server.client);
        await client.login('diver@example.com', 'hunter2');

        final first = await client.fetchDivePage(pageSize: 2);
        expect(first.dives.map((d) => d.activityId).toList(), [1, 2]);
        expect(first.hasMore, isTrue);

        // Fetching a page is a plain call rather than a step through a live
        // stream, so a caller that hit a transient failure can ask for the
        // same page again instead of losing the rest of the history.
        final second = await client.fetchDivePage(
          start: first.nextStart,
          pageSize: 2,
        );
        expect(second.dives.map((d) => d.activityId).toList(), [3]);
        expect(second.hasMore, isFalse);
      },
    );

    test('reports an exhausted history as an empty page', () async {
      final server = _FakeGarminServer();
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final page = await client.fetchDivePage();

      expect(page.dives, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('downloadActivityFit', () {
    test('unwraps the ZIP Garmin serves the FIT file inside', () async {
      final server = _FakeGarminServer()..fitFiles[42] = [1, 2, 3, 4];
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');

      final bytes = await client.downloadActivityFit(42);

      expect(bytes, [1, 2, 3, 4]);
    });

    test('throws when not signed in', () async {
      final client = GarminConnectClient(
        httpClient: _FakeGarminServer().client,
      );

      expect(
        () => client.downloadActivityFit(1),
        throwsA(isA<GarminApiException>()),
      );
    });

    test('throws when the archive body is unreadable', () async {
      final server = _FakeGarminServer();
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');
      server.rawDownloadBytes[7] = [0, 1, 2, 3];

      expect(
        () => client.downloadActivityFit(7),
        throwsA(isA<GarminApiException>()),
      );
    });

    group('transient failures', () {
      late _FakeGarminServer server;
      late List<Duration> delays;
      late GarminConnectClient client;

      setUp(() async {
        server = _FakeGarminServer()..fitFiles[42] = [1, 2, 3, 4];
        delays = [];
        client = GarminConnectClient(
          httpClient: server.client,
          retryDelay: (d) async => delays.add(d),
        );
        await client.login('diver@example.com', 'hunter2');
      });

      test('retries a rate-limited download until it succeeds', () async {
        server.downloadStatusQueue[42] = [429];

        final bytes = await client.downloadActivityFit(42);

        expect(bytes, [1, 2, 3, 4]);
        expect(server.downloadAttempts[42], 2);
        expect(delays, hasLength(1));
      });

      test('retries a server error with a growing backoff', () async {
        server.downloadStatusQueue[42] = [503, 502];

        final bytes = await client.downloadActivityFit(42);

        expect(bytes, [1, 2, 3, 4]);
        expect(server.downloadAttempts[42], 3);
        expect(delays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);
      });

      test('retries a transport-level failure', () async {
        server.downloadTransportFailures[42] = 1;

        final bytes = await client.downloadActivityFit(42);

        expect(bytes, [1, 2, 3, 4]);
        expect(server.downloadAttempts[42], 2);
      });

      test(
        'waits as long as a Retry-After header asks, within a cap',
        () async {
          server
            ..downloadStatusQueue[42] = [429, 429]
            ..downloadFailureHeaders = {'retry-after': '5'};

          await client.downloadActivityFit(42);

          expect(delays, [
            const Duration(seconds: 5),
            const Duration(seconds: 5),
          ]);

          server
            ..downloadStatusQueue[42] = [429]
            ..downloadFailureHeaders = {'retry-after': '3600'};
          delays.clear();

          await client.downloadActivityFit(42);

          expect(delays.single, lessThanOrEqualTo(const Duration(seconds: 30)));
        },
      );

      group('Retry-After as an HTTP date', () {
        final now = DateTime.utc(2026, 9, 26, 12);

        setUp(() async {
          client = GarminConnectClient(
            httpClient: server.client,
            retryDelay: (d) async => delays.add(d),
            clock: () => now,
          );
          await client.login('diver@example.com', 'hunter2');
        });

        Future<Duration> delayFor(String retryAfter) async {
          server
            ..downloadStatusQueue[42] = [503]
            ..downloadFailureHeaders = {'retry-after': retryAfter};
          delays.clear();
          await client.downloadActivityFit(42);
          return delays.single;
        }

        test('waits until the date the server names', () async {
          expect(
            await delayFor('Sat, 26 Sep 2026 12:00:07 GMT'),
            const Duration(seconds: 7),
          );
        });

        test('reads the obsolete RFC 850 and asctime forms too', () async {
          expect(
            await delayFor('Saturday, 26-Sep-26 12:00:04 GMT'),
            const Duration(seconds: 4),
          );
          expect(
            await delayFor('Sat Sep 26 12:00:09 2026'),
            const Duration(seconds: 9),
          );
        });

        test('retries at once for a date already past', () async {
          expect(
            await delayFor('Sat, 26 Sep 2026 11:59:00 GMT'),
            Duration.zero,
          );
        });

        test('caps a far-off date', () async {
          expect(
            await delayFor('Sun, 27 Sep 2026 12:00:00 GMT'),
            const Duration(seconds: 30),
          );
        });

        test('falls back to the backoff for an unreadable value', () async {
          expect(await delayFor('soon'), const Duration(seconds: 1));
        });
      });

      test(
        'gives up after three attempts and reports the last status',
        () async {
          server.downloadStatusQueue[42] = [503, 503, 503, 503];

          await expectLater(
            client.downloadActivityFit(42),
            throwsA(
              isA<GarminApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                503,
              ),
            ),
          );
          expect(server.downloadAttempts[42], 3);
        },
      );

      test('does not retry a permanent failure', () async {
        server.downloadStatusQueue[42] = [404];

        await expectLater(
          client.downloadActivityFit(42),
          throwsA(isA<GarminApiException>()),
        );
        expect(server.downloadAttempts[42], 1);
        expect(delays, isEmpty);
      });
    });

    test('throws when the archive has no .fit member', () async {
      final server = _FakeGarminServer();
      final client = GarminConnectClient(httpClient: server.client);
      await client.login('diver@example.com', 'hunter2');
      final archive = Archive()
        ..addFile(ArchiveFile('notes.txt', 3, [1, 2, 3]));
      server.rawDownloadBytes[8] = ZipEncoder().encode(archive);

      expect(
        () => client.downloadActivityFit(8),
        throwsA(isA<GarminApiException>()),
      );
    });
  });
}
