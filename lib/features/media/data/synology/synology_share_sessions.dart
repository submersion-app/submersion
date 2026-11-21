import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/synology/synology_api.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';

/// Sessions for Synology Photos shares, one per share, shared by every
/// caller in the process.
///
/// A login to a share ends the session the previous login opened, so this
/// class never logs in on a timer and never lets two logins for one share
/// run at once: a grid of thumbnails asking together would otherwise knock
/// out each other's sessions. It logs in only when it has no session, or when
/// a request (or the periodic validation in [headersFor]) shows the server
/// dropped the one it has.
class SynologyShareSessions {
  SynologyShareSessions({
    required http.Client client,
    DateTime Function()? now,
    this.validateEvery = const Duration(minutes: 2),
  }) : _client = client,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;

  /// How often [headersFor] checks that its session is still accepted.
  /// Image requests cannot see Synology's JSON error (the image widget only
  /// sees "not an image"), so this is how a session replaced by another
  /// device's login is noticed.
  final Duration validateEvery;

  final _log = LoggerService.forClass(SynologyShareSessions);
  final Map<String, _Session> _sessions = {};
  final Map<String, Future<_Session>> _logins = {};
  final Map<String, Future<void>> _probes = {};

  /// The session id for [link], logging in with [password] when there is no
  /// session yet or it was opened with a different password.
  ///
  /// Throws [SynologyShareException].
  Future<String> sessionFor(SynologyShareLink link, String password) async {
    final cached = _sessions[link.key];
    if (cached != null && cached.password == password) return cached.sid;
    return (await _login(link, password)).sid;
  }

  /// Forgets [link]'s session if it is still [staleSid]. A caller holding an
  /// old session id must not discard one that a newer login just opened.
  void invalidate(SynologyShareLink link, String staleSid) {
    final cached = _sessions[link.key];
    if (cached != null && cached.sid == staleSid) _sessions.remove(link.key);
  }

  /// Request headers that authenticate a call to [link]'s API, validating the
  /// session first when [validateEvery] has passed since the last check.
  ///
  /// Throws [SynologyShareException].
  Future<Map<String, String>> headersFor(
    SynologyShareLink link,
    String password,
  ) async {
    var sid = await sessionFor(link, password);
    final session = _sessions[link.key];
    if (session != null &&
        session.sid == sid &&
        !_now().isBefore(session.validatedAt.add(validateEvery))) {
      await _probe(link, session);
      sid = await sessionFor(link, password);
    }
    return sessionHeaders(link, sid);
  }

  /// The headers a request with session [sid] needs: the cookie, and the
  /// share code Synology wants repeated in a header for API calls.
  static Map<String, String> sessionHeaders(
    SynologyShareLink link,
    String sid,
  ) => Map.unmodifiable({
    'Cookie': 'sharing_sid=$sid',
    'X-SYNO-SHARING': link.code,
  });

  Future<_Session> _login(SynologyShareLink link, String password) {
    final running = _logins[link.key];
    if (running != null) return running;
    late final Future<_Session> login;
    login = _doLogin(link, password).whenComplete(() {
      if (identical(_logins[link.key], login)) _logins.remove(link.key);
    });
    _logins[link.key] = login;
    return login;
  }

  Future<_Session> _doLogin(SynologyShareLink link, String password) async {
    final http.Response response;
    try {
      response = await _client.post(
        link.apiUri,
        body: {
          'api': 'SYNO.Core.Sharing.Login',
          'method': 'login',
          'version': '1',
          'sharing_id': link.code,
          'password': password,
        },
      );
    } catch (e) {
      throw SynologyShareException(
        SynologyShareErrorKind.unreachable,
        'Could not reach the share: $e',
      );
    }
    final Map<String, Object?> data;
    try {
      data = decodeSynologyEnvelope(response);
    } on SynologyShareException catch (e) {
      // The share answered with an error code: for a login that means the
      // password (or the share code) was not accepted.
      if (e.code != null) {
        throw SynologyShareException(
          SynologyShareErrorKind.wrongPassword,
          'The share did not accept the password',
          code: e.code,
        );
      }
      rethrow;
    }
    final sid = data['sharing_sid'];
    if (sid is! String || sid.isEmpty) {
      throw const SynologyShareException(
        SynologyShareErrorKind.unexpected,
        'The share sent no session',
      );
    }
    final session = _Session(sid: sid, password: password, validatedAt: _now());
    _sessions[link.key] = session;
    return session;
  }

  /// Checks [session] with the cheapest authenticated call. Only a
  /// definite "no session" answer drops it; anything else (offline, a
  /// different error) keeps it, because logging in again would end a
  /// session that may well be fine.
  Future<void> _probe(SynologyShareLink link, _Session session) {
    final running = _probes[link.key];
    if (running != null) return running;
    late final Future<void> probe;
    probe = _doProbe(link, session).whenComplete(() {
      if (identical(_probes[link.key], probe)) _probes.remove(link.key);
    });
    _probes[link.key] = probe;
    return probe;
  }

  Future<void> _doProbe(SynologyShareLink link, _Session session) async {
    try {
      final response = await _client.post(
        link.apiUri,
        headers: sessionHeaders(link, session.sid),
        body: {
          'api': 'SYNO.Foto.Browse.Item',
          'method': 'list',
          'version': '1',
          'offset': '0',
          'limit': '1',
          'passphrase': link.code,
        },
      );
      decodeSynologyEnvelope(response);
    } on SynologyShareException catch (e) {
      if (e.kind == SynologyShareErrorKind.noSession) {
        invalidate(link, session.sid);
        return;
      }
    } catch (e) {
      _log.warning('Could not validate the share session: $e');
    }
    if (identical(_sessions[link.key], session)) {
      _sessions[link.key] = session.validatedNow(_now());
    }
  }
}

class _Session {
  const _Session({
    required this.sid,
    required this.password,
    required this.validatedAt,
  });

  final String sid;
  final String password;
  final DateTime validatedAt;

  _Session validatedNow(DateTime now) =>
      _Session(sid: sid, password: password, validatedAt: now);
}
