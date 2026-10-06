# Lightroom Native App Auth Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign `AdobeImsAuthManager` and `LightroomAuthData` to an OAuth **Native App** (public, no-secret, refresh-tokenless) credential so a connect can complete without a refresh token and against a per-connection redirect URI.

**Architecture:** Pure-Dart core only. Make the refresh token optional (Native App issues none), let each connection carry its own redirect URI (the embedded credential's Adobe-generated custom scheme, or a BYO credential's), and expose a distinct "re-auth required" signal when an access token has expired with no refresh token to renew it. Non-breaking to existing UI callers — `beginAuthorization`/`completeAuthorization` keep their current parameters and add optional ones, so the capture/UI rework (Plan 2) can land separately.

**Tech Stack:** Dart, `package:http` (+ `MockClient`), `flutter_secure_storage` via `FallbackSecureStorage`, `oauth_pkce.dart`.

## Global Constraints

- All Dart code must pass `dart format .` and `flutter analyze` with no changes/issues.
- TDD: write the failing test first, watch it fail, then implement.
- The refresh token is **opportunistic**: request it, persist and use one if returned, never require it.
- The redirect URI is **per-connection**: a new optional parameter that defaults to the existing `AdobeImsAuthManager.redirectUri` constant for backward compatibility.
- This plan is **non-breaking**: do not remove `clientSecret` handling or change any existing public parameter (Plan 2 removes the now-unused secret once the UI stops passing it).
- Scopes constant stays `openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access`.

---

### Task 1: `LightroomAuthData` — optional refresh token + per-connection redirect URI

**Files:**
- Modify: `lib/core/services/lightroom/lightroom_auth_store.dart:10-62`
- Test: `test/core/services/lightroom/lightroom_auth_store_test.dart`

**Interfaces:**
- Produces: `LightroomAuthData({required String clientId, String? redirectUri, String? refreshToken, String? clientSecret, String? email, String? displayName, String? catalogId})` — `refreshToken` is now `String?`; `redirectUri` is new. `toJson`/`fromJson` round-trip both. `copyWith` gains `redirectUri`.

- [ ] **Step 1: Write the failing test** — append to `lightroom_auth_store_test.dart`:

```dart
test('round-trips a Native App blob with no refresh token and a redirect uri', () async {
  final store = LightroomAuthStore(storage: InMemoryKeychain());
  const data = LightroomAuthData(
    clientId: 'cid',
    redirectUri: 'adobe+hash://adobeid/cid',
    catalogId: 'cat1',
  );
  await store.save(data);
  final loaded = (await store.load())!;
  expect(loaded.clientId, 'cid');
  expect(loaded.refreshToken, isNull);
  expect(loaded.redirectUri, 'adobe+hash://adobeid/cid');
  expect(loaded.catalogId, 'cat1');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/lightroom/lightroom_auth_store_test.dart -p vm`
Expected: FAIL — the constructor still requires `refreshToken`; `redirectUri` is undefined.

- [ ] **Step 3: Implement** — replace the `LightroomAuthData` class body (`lightroom_auth_store.dart:10-62`) with:

```dart
class LightroomAuthData {
  const LightroomAuthData({
    required this.clientId,
    this.redirectUri,
    this.refreshToken,
    this.clientSecret,
    this.email,
    this.displayName,
    this.catalogId,
  });

  final String clientId;

  /// The redirect URI this connection authorized against. For a Native App
  /// credential this is Adobe's generated custom scheme; null on legacy
  /// blobs saved before per-connection redirects existed.
  final String? redirectUri;

  /// Null for a Native App credential (public clients get no refresh token)
  /// or on a legacy blob; present only when Adobe returned one.
  final String? refreshToken;

  final String? clientSecret;
  final String? email;
  final String? displayName;
  final String? catalogId;

  LightroomAuthData copyWith({
    String? redirectUri,
    String? refreshToken,
    String? email,
    String? displayName,
    String? catalogId,
  }) {
    return LightroomAuthData(
      clientId: clientId,
      redirectUri: redirectUri ?? this.redirectUri,
      refreshToken: refreshToken ?? this.refreshToken,
      clientSecret: clientSecret,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      catalogId: catalogId ?? this.catalogId,
    );
  }

  Map<String, Object?> toJson() => {
    'clientId': clientId,
    'redirectUri': redirectUri,
    'clientSecret': clientSecret,
    'refreshToken': refreshToken,
    'email': email,
    'displayName': displayName,
    'catalogId': catalogId,
  };

  factory LightroomAuthData.fromJson(Map<String, Object?> json) {
    return LightroomAuthData(
      clientId: json['clientId'] as String,
      redirectUri: json['redirectUri'] as String?,
      clientSecret: json['clientSecret'] as String?,
      refreshToken: json['refreshToken'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      catalogId: json['catalogId'] as String?,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass** (new test plus the existing suite)

Run: `flutter test test/core/services/lightroom/lightroom_auth_store_test.dart -p vm`
Expected: PASS. (Existing tests that construct `LightroomAuthData` with a `refreshToken:` still compile — the field is still accepted, just now nullable.)

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/lightroom/lightroom_auth_store.dart test/core/services/lightroom/lightroom_auth_store_test.dart
git commit -m "feat(lightroom): optional refresh token + per-connection redirect uri in auth data"
```

---

### Task 2: `AdobeImsAuthManager` — no-refresh-token connect, per-connection redirect, re-auth signal

**Files:**
- Modify: `lib/core/services/lightroom/adobe_ims_auth_manager.dart`
- Test: `test/core/services/lightroom/adobe_ims_auth_manager_test.dart`

**Interfaces:**
- Consumes: `LightroomAuthData` (Task 1), `oauth_pkce.dart` helpers.
- Produces:
  - `Uri beginAuthorization({required String clientId, String? clientSecret, String? redirectUri})` — `redirectUri` defaults to `AdobeImsAuthManager.redirectUri`; the chosen value is used in the authorize URL and remembered for the token exchange.
  - `Future<LightroomAuthData> completeAuthorization(String codeOrRedirectUrl)` — succeeds whether or not a refresh token is returned; persists `redirectUri`.
  - `class LightroomReauthRequiredException implements Exception` — thrown by `getAccessToken()` when the access token is unavailable and no refresh token exists.

- [ ] **Step 1: Write the failing tests** — add to `adobe_ims_auth_manager_test.dart`. First widen the `tokenOk`-style helper with a no-refresh response and add three tests:

```dart
final tokenNoRefresh = http.Response(
  jsonEncode({'access_token': 'at1', 'expires_in': 3600}),
  200,
);

test('completeAuthorization succeeds with no refresh token and no secret', () async {
  final requests = <http.Request>[];
  final mock = MockClient((req) async {
    requests.add(req);
    return tokenNoRefresh;
  });
  final m = manager(mock, store: LightroomAuthStore(storage: InMemoryKeychain()));
  m.beginAuthorization(clientId: 'cid', redirectUri: 'adobe+hash://adobeid/cid');
  final data = await m.completeAuthorization(
    'adobe+hash://adobeid/cid?code=thecode',
  );
  expect(data.refreshToken, isNull);
  expect(data.redirectUri, 'adobe+hash://adobeid/cid');
  final body = Uri.splitQueryString(requests.single.body);
  expect(body.containsKey('client_secret'), isFalse);
  expect(body['redirect_uri'], 'adobe+hash://adobeid/cid');
  expect(await m.loadAuth(), isNotNull);
});

test('getAccessToken caches the access token from a refresh-less exchange', () async {
  final m = manager(MockClient((_) async => tokenNoRefresh));
  m.beginAuthorization(clientId: 'cid', redirectUri: 'adobe+hash://adobeid/cid');
  await m.completeAuthorization('adobe+hash://adobeid/cid?code=thecode');
  expect(await m.getAccessToken(), 'at1');
});

test('getAccessToken raises reauth-required when expired with no refresh token', () async {
  final store = LightroomAuthStore(storage: InMemoryKeychain());
  await store.save(const LightroomAuthData(clientId: 'cid'));
  final m = manager(MockClient((_) async => tokenNoRefresh), store: store);
  await expectLater(
    m.getAccessToken(),
    throwsA(isA<LightroomReauthRequiredException>()),
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/lightroom/adobe_ims_auth_manager_test.dart -p vm`
Expected: FAIL — `completeAuthorization` currently throws "did not return a refresh token"; `redirectUri` param and `LightroomReauthRequiredException` do not exist.

- [ ] **Step 3: Implement — add the exception** at the top of `adobe_ims_auth_manager.dart` (after the imports):

```dart
/// Thrown when a Native App connection's access token has expired and there
/// is no refresh token to renew it. The user must sign in again.
class LightroomReauthRequiredException implements Exception {
  const LightroomReauthRequiredException();
  @override
  String toString() => 'Lightroom sign-in has expired; sign in again.';
}
```

- [ ] **Step 4: Implement — per-connection redirect in `beginAuthorization`**. Add the field `String? _pendingRedirectUri;` alongside the other `_pending*` fields, then replace `beginAuthorization` (`adobe_ims_auth_manager.dart:79-101`):

```dart
Uri beginAuthorization({
  required String clientId,
  String? clientSecret,
  String? redirectUri,
}) {
  if (clientId.trim().isEmpty) {
    throw const CloudStorageException(
      'Enter your Adobe client ID before connecting.',
    );
  }
  final verifier = _generateVerifier();
  _pendingVerifier = verifier;
  _pendingClientId = clientId.trim();
  _pendingClientSecret = (clientSecret == null || clientSecret.trim().isEmpty)
      ? null
      : clientSecret.trim();
  _pendingRedirectUri = (redirectUri == null || redirectUri.trim().isEmpty)
      ? AdobeImsAuthManager.redirectUri
      : redirectUri.trim();
  return _authorizeUri.replace(
    queryParameters: {
      'client_id': _pendingClientId!,
      'scope': scopes,
      'response_type': 'code',
      'redirect_uri': _pendingRedirectUri!,
      'code_challenge': codeChallengeS256(verifier),
      'code_challenge_method': 'S256',
    },
  );
}
```

- [ ] **Step 5: Implement — refresh-token-optional exchange in `completeAuthorization`**. Replace the refresh-token block and `LightroomAuthData` construction (`adobe_ims_auth_manager.dart:124-150`) so it no longer throws when a refresh token is absent and it records the redirect URI:

```dart
final tokens = await _requestToken({
  'grant_type': 'authorization_code',
  'client_id': clientId,
  'client_secret': ?_pendingClientSecret,
  'code': code,
  'code_verifier': verifier,
  'redirect_uri': _pendingRedirectUri ?? AdobeImsAuthManager.redirectUri,
});
final refreshTokenValue = tokens['refresh_token'];
final auth = LightroomAuthData(
  clientId: clientId,
  redirectUri: _pendingRedirectUri,
  clientSecret: _pendingClientSecret,
  refreshToken: refreshTokenValue is String && refreshTokenValue.isNotEmpty
      ? refreshTokenValue
      : null,
);
await _store.save(auth);
_pendingVerifier = null;
_pendingClientId = null;
_pendingClientSecret = null;
_pendingRedirectUri = null;
_cacheAccessToken(tokens);
_log.info('Lightroom connected');
return auth;
```

- [ ] **Step 6: Implement — re-auth signal in `_refreshAccessToken`**. Replace the null/`refreshToken` handling at the top of `_refreshAccessToken` (`adobe_ims_auth_manager.dart:186-198`):

```dart
Future<String> _refreshAccessToken() async {
  final auth = await _store.load();
  if (auth == null) {
    throw const CloudStorageException(
      'Lightroom is not connected. Connect Lightroom in Settings.',
    );
  }
  final refreshToken = auth.refreshToken;
  if (refreshToken == null || refreshToken.isEmpty) {
    throw const LightroomReauthRequiredException();
  }
  final tokens = await _requestToken({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': auth.clientId,
    'client_secret': ?auth.clientSecret,
  });
  final rotated = tokens['refresh_token'];
  if (rotated is String && rotated.isNotEmpty && rotated != refreshToken) {
    await _store.save(auth.copyWith(refreshToken: rotated));
  }
  return _cacheAccessToken(tokens);
}
```

- [ ] **Step 7: Run the full auth-manager suite to verify pass**

Run: `flutter test test/core/services/lightroom/adobe_ims_auth_manager_test.dart -p vm`
Expected: PASS — the three new tests pass and every existing test (secret-bearing exchange, refresh, rotation, single-flight, 4xx-preserves-blob, not-connected) still passes.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/core/services/lightroom/adobe_ims_auth_manager.dart test/core/services/lightroom/adobe_ims_auth_manager_test.dart
flutter analyze lib/core/services/lightroom/adobe_ims_auth_manager.dart
git add lib/core/services/lightroom/adobe_ims_auth_manager.dart test/core/services/lightroom/adobe_ims_auth_manager_test.dart
git commit -m "feat(lightroom): Native App auth - refresh-token-optional connect, per-connection redirect, reauth signal"
```

---

## Self-Review

**Spec coverage (auth-core slice of `2026-07-17-lightroom-native-app-connect-design.md`):**
- §2 "remove the client secret / stop requiring a refresh token / `needsReauth` on expiry" → Tasks 1–2. (Secret *removal* is deferred to Plan 2 per the non-breaking constraint; here it is made non-required, which is the behavioral half.)
- §4 "cache the access token; persist a refresh token only if returned; raise `needsReauth`" → Task 2, Steps 5–6.
- §4 "`beginAuthorization(clientId, redirectUri)`" → Task 2, Step 4 (added non-breaking as optional `redirectUri`).
- §12 migration "existing blobs → needsReauth" → satisfied structurally: legacy blobs load with `refreshToken` present (still refresh) or, once expired without one, raise `LightroomReauthRequiredException`.

**Deferred to Plan 2 (not gaps):** `flutter_web_auth_2` capture wrapper, embedded credential constants, native custom-scheme registration, the one-tap embedded Connect wiring, removing `clientSecret` from the UI + manager, the BYO wizard, and the poll-model UI. The existing `lightroomAutoPollProvider` already catches `on Exception` and records the error, so a `LightroomReauthRequiredException` during auto-poll is already a silent no-op — no change needed here.

**Placeholder scan:** none — every step carries complete code and an exact command.

**Type consistency:** `redirectUri`/`refreshToken` nullable in both `LightroomAuthData` (Task 1) and the manager's usage (Task 2); `LightroomReauthRequiredException` defined in Task 2 Step 3 and referenced in Step 6 and the Task 2 tests.
