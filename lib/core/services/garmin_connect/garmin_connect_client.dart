import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/garmin_connect/garmin_api_exception.dart';
import 'package:submersion/core/services/garmin_connect/garmin_auth_tokens.dart';
import 'package:submersion/core/services/garmin_connect/garmin_oauth1_signer.dart';

/// A dive activity summary from the Connect activity list -- not yet the dive
/// profile, which arrives as a FIT file via
/// [GarminConnectClient.downloadActivityFit].
class GarminActivitySummary {
  const GarminActivitySummary({
    required this.activityId,
    required this.startTime,
    required this.activityType,
    this.name,
    this.maxDepth,
    this.durationSeconds,
    this.latitude,
    this.longitude,
  });

  final int activityId;

  /// Activity start in UTC. Approximate -- the authoritative dive start comes
  /// from the FIT file once downloaded.
  final DateTime startTime;

  /// Garmin activity type key, e.g. `single_gas_diving`.
  final String activityType;

  final String? name;

  /// Best-effort, for the progress list only; units are metres.
  final double? maxDepth;
  final int? durationSeconds;

  /// Garmin Connect's own start-position estimate for the activity.
  ///
  /// The FIT file's own `session.start_position_lat/long` field is only set
  /// when the watch already had a GPS fix at the instant it started
  /// recording -- easy to miss underwater/on descent -- so this is kept as
  /// a fallback: Connect's backend derives it from the full recorded track
  /// (or phone-assisted positioning) and often has it even when the FIT
  /// file's own start-of-session field doesn't.
  final double? latitude;
  final double? longitude;
}

/// One page of the dive-activity listing, plus the cursor needed to ask for
/// the page after it.
class GarminDivePage {
  const GarminDivePage({
    required this.dives,
    required this.nextStart,
    required this.hasMore,
  });

  /// The page's dive activities, newest first. Empty only when the account's
  /// history is exhausted -- [GarminConnectClient.fetchDivePage] walks past
  /// listing pages that hold no dives rather than returning them.
  final List<GarminActivitySummary> dives;

  /// The `start` to hand [GarminConnectClient.fetchDivePage] for the next
  /// page. Meaningless once [hasMore] is false.
  final int nextStart;

  /// Whether Garmin reported a full listing page, meaning there is more
  /// history past this one.
  final bool hasMore;
}

/// The outcome of a sign-in attempt.
///
/// Garmin interposes a code challenge for MFA-enabled accounts, so a
/// successful password does not necessarily yield a session. The caller must
/// branch on [mfaRequired] and, when set, collect a code and call
/// [GarminConnectClient.submitMfaCode].
class GarminLoginResult {
  const GarminLoginResult._({required this.mfaRequired, this.mfaMethod});

  const GarminLoginResult.success() : this._(mfaRequired: false);
  const GarminLoginResult.needsMfa(String method)
    : this._(mfaRequired: true, mfaMethod: method);

  final bool mfaRequired;

  /// How Garmin says it delivered the code (e.g. `email`), for the prompt.
  final String? mfaMethod;
}

/// Talks to the UNDOCUMENTED, UNOFFICIAL Garmin Connect mobile API. Using
/// this against your own Garmin account may violate Garmin's Terms of
/// Service -- read them before using this. Use only with your own account
/// and your own data.
///
/// A Dart port of the sign-in and token-exchange flow implemented by the
/// MIT-licensed https://github.com/matin/garth, which is the reference for
/// this protocol. The consumer credential below is the one Garmin ships in
/// its own Android app; garth publishes it because the OAuth 1 exchange
/// cannot be performed without it.
class GarminConnectClient {
  GarminConnectClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const String _ssoBase = 'https://sso.garmin.com';
  static const String _apiBase = 'https://connectapi.garmin.com';
  static const String _clientId = 'GCM_ANDROID_DARK';
  static const String _serviceUrl =
      'https://mobile.integration.garmin.com/gcm/android';

  static const String _consumerKey = 'fc3e99d2-118c-44b8-8ae3-03370dde24c0';
  static const String _consumerSecret = 'E08WAR897WEy2knn7aFBrvegVAf0AFdWBBF';

  /// The SSO endpoints are served to a WebView and sit behind Cloudflare, so
  /// a plain HTTP-client user agent draws a bot challenge. These mimic the
  /// in-app browser closely enough to pass.
  static const Map<String, String> _ssoHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Dest': 'document',
  };

  /// The OAuth endpoints check the user agent against the consumer key's
  /// registered client, so this must stay the Android app's.
  static const Map<String, String> _oauthHeaders = {
    'User-Agent': 'com.garmin.android.apps.connectmobile',
  };

  static const Map<String, String> _apiHeaders = {
    'User-Agent': 'GCM-iOS-5.22.1.4',
  };

  /// Garmin activity type keys that denote a dive. Matched by substring so a
  /// subtype Garmin adds later (it has grown this list several times) is
  /// still recognised rather than silently dropped.
  static const List<String> _diveTypeFragments = ['diving', 'apnea'];

  final http.Client _http;

  /// Minimal cookie jar. The SSO handshake threads Cloudflare and Garmin
  /// session cookies across three requests, and `package:http` does not
  /// persist them.
  final Map<String, String> _cookies = {};

  GarminOAuth1Token? _oauth1Token;
  GarminOAuth2Token? _oauth2Token;

  /// Login parameters captured between the password step and the MFA step.
  Map<String, String>? _pendingMfaParams;

  GarminOAuth1Token? get oauth1Token => _oauth1Token;

  bool get hasSession => _oauth1Token != null;

  /// Restores a previously persisted session. Throws [GarminApiException] if
  /// Garmin no longer accepts the stored credential.
  Future<void> restoreSession(GarminOAuth1Token token) async {
    _oauth1Token = token;
    _oauth2Token = await _exchangeForOAuth2(token);
  }

  /// Step 1 of sign-in: prime cookies, then post the password.
  ///
  /// Returns [GarminLoginResult.needsMfa] when Garmin wants a code, in which
  /// case the caller must follow up with [submitMfaCode].
  Future<GarminLoginResult> login(String email, String password) async {
    _cookies.clear();
    _pendingMfaParams = null;

    // Priming request: establishes the Cloudflare and SSO session cookies
    // the login POST is validated against.
    await _send(
      'GET',
      Uri.parse('$_ssoBase/mobile/sso/en/sign-in?clientId=$_clientId'),
      headers: {..._ssoHeaders, 'Sec-Fetch-Site': 'none'},
    );

    final loginParams = {
      'clientId': _clientId,
      'locale': 'en-US',
      'service': _serviceUrl,
    };

    final response = await _send(
      'POST',
      Uri.parse(
        '$_ssoBase/mobile/api/login',
      ).replace(queryParameters: loginParams),
      headers: {..._ssoHeaders, 'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'username': email,
          'password': password,
          'rememberMe': false,
          'captchaToken': '',
        }),
      ),
    );

    final json = _decodeJson(response);
    final status = json['responseStatus'] as Map<String, dynamic>? ?? const {};
    final type = status['type'] as String?;

    switch (type) {
      case 'SUCCESSFUL':
        await _completeLogin(json['serviceTicketId'] as String);
        return const GarminLoginResult.success();

      case 'MFA_REQUIRED':
        _pendingMfaParams = loginParams;
        final mfaInfo =
            json['customerMfaInfo'] as Map<String, dynamic>? ?? const {};
        final method = mfaInfo['mfaLastMethodUsed'] as String? ?? 'email';
        return GarminLoginResult.needsMfa(method);

      // Garmin returns a CAPTCHA challenge after repeated attempts or from an
      // unfamiliar network. There is no headless way through it.
      case 'CAPTCHA_REQUIRED':
        throw const GarminChallengeException(
          'Garmin is asking for a CAPTCHA. Sign in once at connect.garmin.com '
          'in a browser, then try again.',
        );

      default:
        final message = status['message'] as String?;
        throw GarminApiException(
          'Sign-in failed${message == null ? '' : ': $message'}',
          statusCode: response.statusCode,
        );
    }
  }

  /// Step 2 of sign-in, only for MFA accounts: submits the emailed/authenticator
  /// code and completes the token exchange.
  Future<void> submitMfaCode(String code, {String mfaMethod = 'email'}) async {
    final params = _pendingMfaParams;
    if (params == null) {
      throw const GarminApiException(
        'No sign-in is awaiting a verification code',
      );
    }

    final response = await _send(
      'POST',
      Uri.parse(
        '$_ssoBase/mobile/api/mfa/verifyCode',
      ).replace(queryParameters: params),
      headers: {..._ssoHeaders, 'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'mfaMethod': mfaMethod,
          'mfaVerificationCode': code,
          'rememberMyBrowser': false,
          'reconsentList': <String>[],
          'mfaSetup': false,
        }),
      ),
    );

    final json = _decodeJson(response);
    final status = json['responseStatus'] as Map<String, dynamic>? ?? const {};
    if (status['type'] != 'SUCCESSFUL') {
      final message = status['message'] as String?;
      throw GarminApiException(
        message == null
            ? 'That verification code was not accepted'
            : 'Verification failed: $message',
      );
    }

    _pendingMfaParams = null;
    await _completeLogin(json['serviceTicketId'] as String);
  }

  /// Fetches the page of dive activities at [start], newest first.
  ///
  /// Garmin's activity list is itself paginated newest-to-oldest (`start`
  /// walks forward from the most recent activity). Fetching one page at a
  /// time -- rather than buffering the diver's entire history before
  /// returning anything -- lets a caller start acting on the newest dives
  /// while older pages are still being fetched. Each page is additionally
  /// sorted newest first on its own as a defensive measure, in case Garmin
  /// ever returns a page out of order.
  ///
  /// A listing page can hold no dives at all once the per-item check has
  /// run, so this walks past such pages internally: a returned page is
  /// either non-empty or genuinely the end of the account's history, and a
  /// caller never has to tell "nothing on this page" apart from "nothing
  /// left".
  ///
  /// Exposed as an explicit cursor rather than only as [listDivesPaged] so
  /// a caller can retry a single failed page. A `Stream` that has thrown is
  /// terminated for good, and asking a terminated one for its next page
  /// reports "no more pages" -- silently truncating the history at whatever
  /// page happened to hit a transient network error.
  Future<GarminDivePage> fetchDivePage({
    int start = 0,
    int pageSize = 15,
  }) async {
    var offset = start;

    while (true) {
      final page = await _getJsonList(
        Uri.parse(
          '$_apiBase/activitylist-service/activities/search/activities',
        ).replace(
          queryParameters: {
            'start': '$offset',
            'limit': '$pageSize',
            // Server-side narrowing to the diving parent category. The
            // per-item check below still runs, so a change in how Garmin
            // honours this filter cannot let a run or a swim through.
            'activityType': 'diving',
          },
        ),
      );
      if (page.isEmpty) {
        return GarminDivePage(
          dives: const [],
          nextStart: offset,
          hasMore: false,
        );
      }

      final summaries = <GarminActivitySummary>[];
      for (final entry in page) {
        final item = entry as Map<String, dynamic>;
        final summary = _toActivitySummary(item);
        if (summary != null) summaries.add(summary);
      }

      final hasMore = page.length >= pageSize;
      offset += pageSize;
      if (summaries.isNotEmpty || !hasMore) {
        summaries.sort((a, b) => b.startTime.compareTo(a.startTime));
        return GarminDivePage(
          dives: summaries,
          nextStart: offset,
          hasMore: hasMore,
        );
      }
    }
  }

  /// Streams pages of dive activities, newest first, walking the cursor
  /// [fetchDivePage] hands back until the history runs out.
  Stream<List<GarminActivitySummary>> listDivesPaged({
    int pageSize = 15,
  }) async* {
    var start = 0;

    while (true) {
      final page = await fetchDivePage(start: start, pageSize: pageSize);
      if (page.dives.isNotEmpty) yield page.dives;
      if (!page.hasMore) break;
      start = page.nextStart;
    }
  }

  /// Every dive activity, newest first. A convenience wrapper over
  /// [listDivesPaged] for callers that don't need progressive access to
  /// pages as they arrive from the network.
  Future<List<GarminActivitySummary>> listDives({int pageSize = 15}) async {
    final dives = <GarminActivitySummary>[];
    await for (final page in listDivesPaged(pageSize: pageSize)) {
      dives.addAll(page);
    }
    return dives;
  }

  /// Downloads an activity's original upload. Garmin serves this as a ZIP
  /// archive wrapping the FIT file, even for a single activity, so the
  /// archive is unwrapped here and only the FIT bytes are returned.
  Future<Uint8List> downloadActivityFit(int activityId) async {
    final response = await _apiRequest(
      'GET',
      Uri.parse('$_apiBase/download-service/files/activity/$activityId'),
    );
    return _extractFitBytes(response.bodyBytes, activityId);
  }

  static Uint8List _extractFitBytes(Uint8List bytes, int activityId) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw GarminApiException(
        'Garmin returned an unreadable activity archive for activity '
        '$activityId',
        cause: e,
      );
    }

    for (final entry in archive) {
      if (entry.isFile && entry.name.toLowerCase().endsWith('.fit')) {
        return Uint8List.fromList(entry.readBytes() ?? const <int>[]);
      }
    }
    throw GarminApiException(
      'Garmin activity $activityId archive contained no FIT file',
    );
  }

  GarminActivitySummary? _toActivitySummary(Map<String, dynamic> item) {
    final typeKey =
        (item['activityType'] as Map<String, dynamic>?)?['typeKey'] as String?;
    if (typeKey == null || !_isDiveType(typeKey)) return null;

    final activityId = (item['activityId'] as num?)?.toInt();
    final startTime = _parseGarminUtc(item['startTimeGMT'] as String?);
    if (activityId == null || startTime == null) return null;

    return GarminActivitySummary(
      activityId: activityId,
      startTime: startTime,
      activityType: typeKey,
      name: item['activityName'] as String?,
      maxDepth: (item['maxDepth'] as num?)?.toDouble(),
      durationSeconds: (item['duration'] as num?)?.round(),
      latitude: (item['startLatitude'] as num?)?.toDouble(),
      longitude: (item['startLongitude'] as num?)?.toDouble(),
    );
  }

  static bool _isDiveType(String typeKey) {
    final lower = typeKey.toLowerCase();
    return _diveTypeFragments.any(lower.contains);
  }

  /// Garmin serves `startTimeGMT` as `yyyy-MM-dd HH:mm:ss` with no zone
  /// designator, despite it being UTC.
  static DateTime? _parseGarminUtc(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z');
  }

  // ---------------------------------------------------------------------------
  // Auth internals
  // ---------------------------------------------------------------------------

  Future<void> _completeLogin(String serviceTicket) async {
    final oauth1 = await _fetchOAuth1Token(serviceTicket);
    _oauth1Token = oauth1;
    _oauth2Token = await _exchangeForOAuth2(oauth1);
  }

  Future<GarminOAuth1Token> _fetchOAuth1Token(String serviceTicket) async {
    final url = Uri.parse('$_apiBase/oauth-service/oauth/preauthorized')
        .replace(
          queryParameters: {
            'ticket': serviceTicket,
            'login-url': _serviceUrl,
            'accepts-mfa-tokens': 'true',
          },
        );

    const signer = GarminOAuth1Signer(
      consumerKey: _consumerKey,
      consumerSecret: _consumerSecret,
    );

    final response = await _send(
      'GET',
      url,
      headers: {
        ..._oauthHeaders,
        'Authorization': signer.authorizationHeader(method: 'GET', url: url),
      },
    );
    _throwForStatus(response, 'Could not obtain a Garmin access token');

    // The response is form-encoded, not JSON.
    final fields = Uri.splitQueryString(response.body);
    final token = fields['oauth_token'];
    final secret = fields['oauth_token_secret'];
    if (token == null || secret == null) {
      throw const GarminApiException('Garmin did not return an access token');
    }

    return GarminOAuth1Token(
      token: token,
      tokenSecret: secret,
      mfaToken: fields['mfa_token'],
    );
  }

  Future<GarminOAuth2Token> _exchangeForOAuth2(GarminOAuth1Token oauth1) async {
    final url = Uri.parse('$_apiBase/oauth-service/oauth/exchange/user/2.0');

    final bodyParams = <String, String>{
      'audience': 'GARMIN_CONNECT_MOBILE_ANDROID_DI',
      if (oauth1.mfaToken != null) 'mfa_token': oauth1.mfaToken!,
    };

    final signer = GarminOAuth1Signer(
      consumerKey: _consumerKey,
      consumerSecret: _consumerSecret,
      token: oauth1.token,
      tokenSecret: oauth1.tokenSecret,
    );

    final response = await _send(
      'POST',
      url,
      headers: {
        ..._oauthHeaders,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': signer.authorizationHeader(
          method: 'POST',
          url: url,
          bodyParams: bodyParams,
        ),
      },
      body: utf8.encode(
        bodyParams.entries
            .map(
              (e) =>
                  '${Uri.encodeQueryComponent(e.key)}='
                  '${Uri.encodeQueryComponent(e.value)}',
            )
            .join('&'),
      ),
    );
    _throwForStatus(response, 'Garmin rejected the stored sign-in');

    final json = _decodeJson(response);
    final accessToken = json['access_token'] as String?;
    if (accessToken == null) {
      throw const GarminApiException('Garmin did not return an access token');
    }

    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return GarminOAuth2Token(
      accessToken: accessToken,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Issues an authenticated Connect API request, re-exchanging the stored
  /// OAuth 1 credential first if the bearer token has lapsed.
  ///
  /// Garmin has no refresh-token grant here: the long-lived OAuth 1 token is
  /// the refresh mechanism.
  Future<http.Response> _apiRequest(String method, Uri url) async {
    final oauth1 = _oauth1Token;
    if (oauth1 == null) {
      throw const GarminApiException('Not signed in to Garmin Connect');
    }
    if (_oauth2Token == null || _oauth2Token!.isExpired()) {
      _oauth2Token = await _exchangeForOAuth2(oauth1);
    }

    final response = await _send(
      method,
      url,
      headers: {
        ..._apiHeaders,
        'Authorization': _oauth2Token!.authorizationHeader,
      },
    );
    _throwForStatus(response, 'Garmin request failed');
    return response;
  }

  Future<List<dynamic>> _getJsonList(Uri url) async {
    final response = await _apiRequest('GET', url);
    if (response.bodyBytes.isEmpty) return const [];
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List) return decoded;
    // Some Connect endpoints wrap the list; tolerate both shapes.
    if (decoded is Map<String, dynamic>) {
      final list = decoded['activityList'];
      if (list is List) return list;
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final request = http.Request(method, url)
      ..followRedirects = true
      ..headers.addAll(headers);
    if (_cookies.isNotEmpty) {
      request.headers['cookie'] = _cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    if (body != null) request.bodyBytes = body;

    http.Response response;
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } on GarminApiException {
      rethrow;
    } catch (e) {
      throw GarminApiException('Could not reach Garmin Connect', cause: e);
    }

    _storeCookies(response);
    return response;
  }

  void _storeCookies(http.Response response) {
    for (final raw in response.headersSplitValues['set-cookie'] ?? const []) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      _cookies[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Falls through to the shared error below: a non-JSON body here is
      // almost always a Cloudflare interstitial rather than a Garmin reply.
    }
    throw GarminApiException(
      response.statusCode == 200
          ? 'Unexpected response from Garmin for ${response.request?.url} '
                '(a sign-in page or other interstitial may be blocked from '
                'this network)'
          : 'Garmin returned HTTP ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  void _throwForStatus(http.Response response, String message) {
    if (response.statusCode < 400) return;
    throw GarminApiException(
      '$message (HTTP ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
