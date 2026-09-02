import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_crypto.dart';

/// A single scuba/freediving workout summary from the `workouts` listing
/// endpoint -- not yet the full dive profile (see [SuuntoCloudClient.fetchSmlJson]
/// for that).
class SuuntoWorkoutSummary {
  const SuuntoWorkoutSummary({
    required this.key,
    required this.startTime,
    required this.activityId,
    this.maxDepth,
    this.diveTimeSeconds,
    this.totalTimeSeconds,
  });

  /// Opaque workout identifier used to fetch the full SML export.
  final String key;

  /// Workout-level start time. Approximate -- the authoritative dive start
  /// comes from the per-dive header's `DateTime` field once fetched.
  final DateTime startTime;

  /// Sports-Tracker activity id (78 = scuba diving, 79 = freediving).
  final int activityId;

  /// Maximum depth in meters, when present in the listing's
  /// `DiveHeaderExtension`. Best-effort only, for progress display.
  final double? maxDepth;

  /// Computer-reported bottom time in seconds, when present.
  final int? diveTimeSeconds;

  /// Overall workout elapsed time in seconds.
  final int? totalTimeSeconds;

  /// [diveTimeSeconds] when available, else [totalTimeSeconds].
  int? get durationSeconds => diveTimeSeconds ?? totalTimeSeconds;
}

/// One page of the dive-workout listing, plus the cursor needed to ask for
/// the page after it.
class SuuntoDivePage {
  const SuuntoDivePage({
    required this.dives,
    required this.nextOffset,
    required this.hasMore,
  });

  /// The page's dive workouts, newest first. Empty only when the account's
  /// history is exhausted -- [SuuntoCloudClient.fetchDivePage] walks past
  /// listing pages that hold no dives rather than returning them.
  final List<SuuntoWorkoutSummary> dives;

  /// The `offset` to hand [SuuntoCloudClient.fetchDivePage] for the next
  /// page. Meaningless once [hasMore] is false.
  final int nextOffset;

  /// Whether the server reported a full listing page, meaning there is more
  /// history past this one.
  final bool hasMore;
}

/// Talks to an UNDOCUMENTED, UNOFFICIAL Suunto/Sports-Tracker cloud API
/// (api.sports-tracker.com). Using this against your own Suunto account may
/// violate Suunto's Terms of Service -- read them before using this. Use
/// only with your own account and your own data.
///
/// A Dart port of suunto2subsurface's `SuuntoClient`
/// (https://github.com/dotanalon/suunto2subsurface), itself a C++ port of
/// suunto-export/export_suunto_dives.py's `SuuntoClient`.
class SuuntoCloudClient {
  SuuntoCloudClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const String _baseUrl = 'https://api.sports-tracker.com/apiserver/v1/';
  static const String _appVersionCode = '6008013';
  static const String _packageName = 'com.stt.android.suunto';

  static const int _activityScubaDiving = 78;
  static const int _activityFreeDiving = 79;

  final http.Client _http;

  String? sessionKey;

  bool get hasSession => sessionKey?.isNotEmpty ?? false;

  /// Throws [SuuntoApiException] on failure. On success, [sessionKey] is set
  /// and returned.
  Future<String> login(String email, String password) async {
    final totp = await SuuntoCrypto.generateTotp(email);
    final signedParams = [
      MapEntry('l', email),
      MapEntry('p', password),
      MapEntry('totp', totp),
    ];
    final signature = SuuntoCrypto.signParams('login2', signedParams);

    final saltBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final salt = base64Url.encode(saltBytes).replaceAll('=', '');

    final formParams = [
      ...signedParams,
      MapEntry('timestamp', DateTime.now().millisecondsSinceEpoch.toString()),
      MapEntry('salt', salt),
      MapEntry('signature', signature),
    ];

    final body = Uint8List.fromList(utf8.encode(_urlEncodeForm(formParams)));
    final responseBytes = await _request(
      'POST',
      'login2',
      body: body,
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'x-login-email-verification-enabled': 'true',
      },
    );

    final session =
        jsonDecode(utf8.decode(responseBytes)) as Map<String, dynamic>;
    final key = session['sessionkey'] as String?;
    if (key == null || key.isEmpty) {
      throw const SuuntoApiException('login failed: no sessionkey in response');
    }
    sessionKey = key;
    return key;
  }

  /// Cheap probe to check the current session key is still accepted by the
  /// server, without pulling any real data.
  Future<bool> verifySession() async {
    try {
      await _listWorkouts(sinceMs: 1 << 53, limit: 1, offset: 0);
      return true;
    } on SuuntoApiException {
      return false;
    }
  }

  /// Fetches the page of dive-activity workouts (scuba diving / freediving)
  /// at [offset], newest first.
  ///
  /// The Suunto/Sports-Tracker `workouts` listing is itself paginated
  /// oldest-to-newest by offset. Fetching one page at a time -- rather than
  /// buffering the diver's entire history before returning anything -- lets
  /// a caller start acting on the newest dives while older pages are still
  /// being fetched. Each page is additionally sorted newest first on its own
  /// as a defensive measure, in case the server ever returns a page out of
  /// order.
  ///
  /// The listing carries every activity type, and the dive filter runs
  /// client-side, so a listing page can hold no dives at all. This walks
  /// past such pages internally: a returned page is either non-empty or
  /// genuinely the end of the account's history, and a caller never has to
  /// tell "nothing on this page" apart from "nothing left".
  ///
  /// Exposed as an explicit cursor rather than only as [listDivesPaged] so
  /// a caller can retry a single failed page. A `Stream` that has thrown is
  /// terminated for good, and asking a terminated one for its next page
  /// reports "no more pages" -- silently truncating the history at whatever
  /// page happened to hit a transient network error.
  Future<SuuntoDivePage> fetchDivePage({
    int sinceMs = 0,
    int offset = 0,
    int pageSize = 15,
  }) async {
    var next = offset;

    while (true) {
      final items = await _listWorkouts(
        sinceMs: sinceMs,
        limit: pageSize,
        offset: next,
      );
      if (items.isEmpty) {
        return SuuntoDivePage(
          dives: const [],
          nextOffset: next,
          hasMore: false,
        );
      }

      final summaries = <SuuntoWorkoutSummary>[];
      for (final item in items) {
        final activityId = (item['activityId'] as num?)?.toInt() ?? -1;
        if (activityId == _activityScubaDiving ||
            activityId == _activityFreeDiving) {
          summaries.add(_toWorkoutSummary(item, activityId));
        }
      }

      final hasMore = items.length >= pageSize;
      next += pageSize;
      if (summaries.isNotEmpty || !hasMore) {
        summaries.sort((a, b) => b.startTime.compareTo(a.startTime));
        return SuuntoDivePage(
          dives: summaries,
          nextOffset: next,
          hasMore: hasMore,
        );
      }
    }
  }

  /// Streams pages of dive-activity workouts, newest first, walking the
  /// cursor [fetchDivePage] hands back until the history runs out.
  Stream<List<SuuntoWorkoutSummary>> listDivesPaged({
    int sinceMs = 0,
    int pageSize = 15,
  }) async* {
    var offset = 0;

    while (true) {
      final page = await fetchDivePage(
        sinceMs: sinceMs,
        offset: offset,
        pageSize: pageSize,
      );
      if (page.dives.isNotEmpty) yield page.dives;
      if (!page.hasMore) break;
      offset = page.nextOffset;
    }
  }

  /// Every dive-activity workout, newest first. A convenience wrapper over
  /// [listDivesPaged] for callers that don't need progressive access to
  /// pages as they arrive from the network.
  Future<List<SuuntoWorkoutSummary>> listDives({
    int sinceMs = 0,
    int pageSize = 15,
  }) async {
    final dives = <SuuntoWorkoutSummary>[];
    await for (final page in listDivesPaged(
      sinceMs: sinceMs,
      pageSize: pageSize,
    )) {
      dives.addAll(page);
    }
    return dives;
  }

  Future<Uint8List> fetchSmlJson(String key) =>
      _request('GET', 'workouts/$key/sml');

  SuuntoWorkoutSummary _toWorkoutSummary(
    Map<String, dynamic> item,
    int activityId,
  ) {
    final startMs = (item['startTime'] as num).toInt();
    final ext = _diveHeaderExtension(item);
    return SuuntoWorkoutSummary(
      key: item['key'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
      activityId: activityId,
      maxDepth: (ext?['maxDepth'] as num?)?.toDouble(),
      diveTimeSeconds: (ext?['diveTime'] as num?)?.round(),
      totalTimeSeconds: (item['totalTime'] as num?)?.round(),
    );
  }

  /// The workout listing nests dive-specific summary fields (maxDepth,
  /// diveTime) inside an `extensions` entry of type `DiveHeaderExtension`,
  /// separate from the generic workout fields (startTime, totalTime).
  Map<String, dynamic>? _diveHeaderExtension(Map<String, dynamic> item) {
    final extensions = item['extensions'] as List<dynamic>? ?? const [];
    for (final entry in extensions) {
      final ext = entry as Map<String, dynamic>;
      if (ext['type'] == 'DiveHeaderExtension') return ext;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _listWorkouts({
    required int sinceMs,
    required int limit,
    required int offset,
  }) async {
    final path = 'workouts?since=$sinceMs&limit=$limit&offset=$offset';
    final bytes = await _request('GET', path);
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    final error = envelope['error'];
    if (error != null) {
      final err = error as Map<String, dynamic>;
      throw SuuntoApiException(
        'API error ${err['code']}: ${err['description']}',
      );
    }

    final payload = envelope['payload'] as List<dynamic>? ?? const [];
    return payload.cast<Map<String, dynamic>>();
  }

  Future<Uint8List> _request(
    String method,
    String path, {
    Uint8List? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final requestHeaders = <String, String>{
      'User-Agent': '$_packageName/$_appVersionCode',
      'Accept-Language': 'en',
      ...headers,
    };
    final key = sessionKey;
    if (key != null && key.isNotEmpty) {
      requestHeaders['STTAuthorization'] = key;
    }

    http.Response response;
    try {
      response = switch (method) {
        'GET' =>
          await _http
              .get(uri, headers: requestHeaders)
              .timeout(const Duration(seconds: 30)),
        'POST' =>
          await _http
              .post(uri, headers: requestHeaders, body: body)
              .timeout(const Duration(seconds: 30)),
        _ => throw SuuntoApiException('unsupported HTTP method: $method'),
      };
    } on SuuntoApiException {
      rethrow;
    } catch (e) {
      throw SuuntoApiException('request failed', e);
    }

    if (response.statusCode == 401) {
      throw const SuuntoApiException('session rejected (401) -- login again');
    }
    if (response.statusCode >= 400) {
      final bytes = response.bodyBytes;
      final snippet = bytes.length > 200 ? bytes.sublist(0, 200) : bytes;
      throw SuuntoApiException(
        'HTTP ${response.statusCode}: '
        '${utf8.decode(snippet, allowMalformed: true)}',
      );
    }

    return response.bodyBytes;
  }
}

String _urlEncodeForm(List<MapEntry<String, String>> params) {
  return params
      .map(
        (p) =>
            '${Uri.encodeQueryComponent(p.key)}='
            '${Uri.encodeQueryComponent(p.value)}',
      )
      .join('&');
}
