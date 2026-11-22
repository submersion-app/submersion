import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/synology/synology_api.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/data/synology/synology_share_sessions.dart';

final _link = SynologyShareLink.tryParseShareLink(
  Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
)!;

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _ok(Map<String, Object?> data) =>
    _json({'success': true, 'data': data});

http.Response _error(int code) => _json({
  'success': false,
  'error': {'code': code},
});

/// A share that hands out sid-1, sid-2, ... and accepts only the newest.
class _FakeShare {
  static const password = 'secret';
  int logins = 0;
  int probes = 0;
  String? current;
  Completer<void>? holdLogin;

  Future<http.Response> handle(http.Request request) async {
    final form = request.bodyFields;
    final api = form['api'];
    if (api == 'SYNO.Core.Sharing.Login') {
      logins++;
      await holdLogin?.future;
      if (form['sharing_id'] != 'code1' || form['password'] != password) {
        return _error(101);
      }
      current = 'sid-$logins';
      return _ok({'sharing_sid': current});
    }
    if (api == 'SYNO.Foto.Browse.Item') {
      probes++;
      final cookie = request.headers['cookie'];
      if (cookie != 'sharing_sid=$current' ||
          request.headers['x-syno-sharing'] != 'code1') {
        return _error(kSynologyNoSession);
      }
      return _ok({'list': <Object?>[]});
    }
    return _error(103);
  }
}

void main() {
  late _FakeShare share;
  late DateTime now;
  late SynologyShareSessions sessions;

  setUp(() {
    share = _FakeShare();
    now = DateTime.utc(2026, 1, 1, 12);
    sessions = SynologyShareSessions(
      client: MockClient(share.handle),
      now: () => now,
    );
  });

  test('logs in once and reuses the session', () async {
    final first = await sessions.sessionFor(_link, 'secret');
    final second = await sessions.sessionFor(_link, 'secret');
    expect(first, 'sid-1');
    expect(second, 'sid-1');
    expect(share.logins, 1);
  });

  test('concurrent callers share one login', () async {
    share.holdLogin = Completer<void>();
    final a = sessions.sessionFor(_link, 'secret');
    final b = sessions.sessionFor(_link, 'secret');
    share.holdLogin!.complete();
    expect(await a, 'sid-1');
    expect(await b, 'sid-1');
    expect(share.logins, 1);
  });

  test('a wrong password is a wrongPassword error', () async {
    await expectLater(
      sessions.sessionFor(_link, 'wrong'),
      throwsA(
        isA<SynologyShareException>().having(
          (e) => e.kind,
          'kind',
          SynologyShareErrorKind.wrongPassword,
        ),
      ),
    );
  });

  test('a failed login is not cached', () async {
    await expectLater(sessions.sessionFor(_link, 'wrong'), throwsA(anything));
    expect(await sessions.sessionFor(_link, 'secret'), 'sid-2');
  });

  test('a refused password is refused again without a login', () async {
    await expectLater(sessions.sessionFor(_link, ''), throwsA(anything));
    await expectLater(
      sessions.sessionFor(_link, ''),
      throwsA(
        isA<SynologyShareException>().having(
          (e) => e.kind,
          'kind',
          SynologyShareErrorKind.wrongPassword,
        ),
      ),
    );
    expect(share.logins, 1);
  });

  test('a refused password is tried again after a while', () async {
    await expectLater(sessions.sessionFor(_link, ''), throwsA(anything));
    now = now.add(sessions.validateEvery);
    await expectLater(sessions.sessionFor(_link, ''), throwsA(anything));
    expect(share.logins, 2);
  });

  test('a login with another password is not handed a running one', () async {
    share.holdLogin = Completer<void>();
    final empty = sessions.sessionFor(_link, '');
    final right = sessions.sessionFor(_link, 'secret');
    share.holdLogin!.complete();
    await expectLater(empty, throwsA(anything));
    expect(await right, isNotEmpty);
    expect(share.logins, 2);
  });

  test('an error that is no refused password stays unexpected', () async {
    final gone = SynologyShareSessions(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"error":{"code":2004}}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await expectLater(
      gone.sessionFor(_link, 'secret'),
      throwsA(
        isA<SynologyShareException>()
            .having((e) => e.kind, 'kind', SynologyShareErrorKind.unexpected)
            .having((e) => e.code, 'code', 2004),
      ),
    );
  });

  test('a changed password logs in again', () async {
    await sessions.sessionFor(_link, 'secret');
    await expectLater(sessions.sessionFor(_link, 'other'), throwsA(anything));
    expect(share.logins, 2);
  });

  test('invalidate drops only the session that failed', () async {
    final stale = await sessions.sessionFor(_link, 'secret');
    sessions.invalidate(_link, stale);
    final fresh = await sessions.sessionFor(_link, 'secret');
    expect(fresh, 'sid-2');
    // A caller still holding the old sid must not throw away the new one.
    sessions.invalidate(_link, stale);
    expect(await sessions.sessionFor(_link, 'secret'), 'sid-2');
    expect(share.logins, 2);
  });

  test('a transport failure is unreachable', () async {
    final failing = SynologyShareSessions(
      client: MockClient((_) async => throw http.ClientException('down')),
      now: () => now,
    );
    await expectLater(
      failing.sessionFor(_link, 'secret'),
      throwsA(
        isA<SynologyShareException>().having(
          (e) => e.kind,
          'kind',
          SynologyShareErrorKind.unreachable,
        ),
      ),
    );
  });

  group('headersFor', () {
    test('carries the cookie and the share header', () async {
      final headers = await sessions.headersFor(_link, 'secret');
      expect(headers, {
        'Cookie': 'sharing_sid=sid-1',
        'X-SYNO-SHARING': 'code1',
      });
    });

    test('does not probe a session that was just created', () async {
      await sessions.headersFor(_link, 'secret');
      await sessions.headersFor(_link, 'secret');
      expect(share.probes, 0);
    });

    test('probes once the validation interval passed', () async {
      await sessions.headersFor(_link, 'secret');
      now = now.add(const Duration(minutes: 3));
      final headers = await sessions.headersFor(_link, 'secret');
      expect(share.probes, 1);
      expect(headers['Cookie'], 'sharing_sid=sid-1');
      // Validated just now: no second probe.
      await sessions.headersFor(_link, 'secret');
      expect(share.probes, 1);
    });

    test('logs in again when the probe finds the session gone', () async {
      await sessions.headersFor(_link, 'secret');
      // Another device logged in and replaced the session.
      share.current = 'someone-else';
      now = now.add(const Duration(minutes: 3));
      final headers = await sessions.headersFor(_link, 'secret');
      expect(headers['Cookie'], 'sharing_sid=sid-2');
      expect(share.logins, 2);
    });

    test('keeps the session when the probe cannot reach the share', () async {
      var reachable = true;
      final client = MockClient((request) async {
        if (!reachable) throw http.ClientException('down');
        return share.handle(request);
      });
      final flaky = SynologyShareSessions(client: client, now: () => now);
      await flaky.headersFor(_link, 'secret');
      reachable = false;
      now = now.add(const Duration(minutes: 3));
      final headers = await flaky.headersFor(_link, 'secret');
      expect(headers['Cookie'], 'sharing_sid=sid-1');
      expect(share.logins, 1);
    });
  });
}
