# Lightroom Cloud Auto-Linking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect a diver's Adobe Lightroom cloud catalog, auto-link photos/videos to dives by capture time, and push rendition bytes through the Media Store pipeline so linked media displays on every synced device.

**Architecture:** Lightroom is an acquisition source, not a live dependency. A new `ConnectorMediaResolver` fills the empty `MediaSourceType.serviceConnector` slot in `MediaSourceResolverRegistry`; the existing `MediaUploadPipeline` (PR #550) then materializes bytes through that resolver, hashes, uploads, and stamps. A scan service matches Lightroom capture times to dive windows via a new confidence-bearing `DivePhotoMatcher` API; confident matches auto-attach, ambiguous ones become pending suggestions.

**Tech Stack:** Flutter/Dart, Drift, Riverpod, `package:http` (+ `MockClient` for tests), `flutter_secure_storage` via `FallbackSecureStorage`, SharedPreferences, Adobe IMS OAuth 2.0 + PKCE, Lightroom Partner API (`https://lr.adobe.io`).

## Global Constraints

- **Branch AFTER PR #550 merges.** Create the worktree from a main containing `lib/features/media_store/` and schema v103. After creating the worktree run `git submodule update --init --recursive`, `flutter pub get`, and `dart run build_runner build --delete-conflicting-outputs`.
- If any #550 name cited here drifted in the final merge (`MediaUploadPipeline`, `mediaStoreRuntimeProvider`, `MediaCacheStore`, `getBackfillCandidateIds`), adapt to the merged name — the architecture does not depend on the names.
- Schema migration: read the current `schemaVersion` in `lib/core/database/database.dart` on your branch and bump it by exactly 1 (referred to below as `vNEXT`). Other worktrees have claimed v104/v105; the idempotent-DDL + `beforeOpen` re-assert pattern (established by #550 and the parallel-branch collision fix) is mandatory.
- All new user-facing strings go into `lib/l10n/arb/app_en.arb` AND the 10 other locales (ar, de, es, fr, he, hu, it, nl, pt, zh); regenerate with `flutter gen-l10n`.
- Wall-clock-as-UTC convention: every external timestamp is parsed with `parseExternalDateAsWallClockUtc` from `lib/core/util/wall_clock_utc.dart`. Never call `.toLocal()` on dive/media times.
- SnackBars triggered from actions must pass `persist: false` if using the app's snackbar helper with an action button (repo trap #406).
- No emojis anywhere. `dart format .` (whole repo) must be clean before every commit. `flutter analyze` (whole project, never piped through `tail`) must pass before the final commit of each task.
- Run tests per-file (`flutter test test/<path>`), never the whole suite mid-task.
- Commit messages: conventional style, no Co-Authored-By line, no session URL.
- Adobe endpoints used throughout: authorize `https://ims-na1.adobelogin.com/ims/authorize/v2`, token `https://ims-na1.adobelogin.com/ims/token/v3`, API base `https://lr.adobe.io`. Redirect URI constant: `https://submersion.app/lightroom/callback`. Scopes: `openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access`. Every `lr.adobe.io` JSON response body starts with the abuse-guard prefix `while (1) {}` which must be stripped before `jsonDecode`.

## File Structure

```
lib/core/services/oauth/oauth_pkce.dart                     (Task 1: moved from dropbox/)
lib/core/services/lightroom/lightroom_auth_store.dart        (Task 2)
lib/core/services/lightroom/adobe_ims_auth_manager.dart      (Task 3)
lib/core/services/lightroom/lightroom_models.dart            (Task 4)
lib/core/services/lightroom/lightroom_api_client.dart        (Task 4)
lib/features/media/domain/entities/connector_account.dart    (Task 5)
lib/features/media/data/repositories/connector_accounts_repository.dart (Task 5)
lib/core/database/database.dart                              (Task 6: vNEXT migration)
lib/features/media/domain/entities/media_item.dart           (Task 6: suggestion entity fields)
lib/features/media/data/repositories/media_repository.dart   (Task 6: suggestion CRUD + dedup queries)
lib/features/media/domain/services/dive_photo_matcher.dart   (Task 7: matchTimestamp)
lib/features/media/data/services/lightroom_connector_state.dart (Task 8)
lib/features/media/data/services/lightroom_scan_service.dart (Task 9)
lib/features/media/data/resolvers/connector_media_resolver.dart (Task 10)
lib/features/media/presentation/providers/lightroom_providers.dart (Task 11)
lib/features/media/presentation/providers/media_resolver_providers.dart (Task 11: registry entry)
lib/features/media_store/data/media_upload_pipeline.dart     (Task 12: eligibility + thumb-only)
lib/features/settings/presentation/widgets/lightroom_connect_dialog.dart (Task 13)
lib/features/settings/presentation/pages/lightroom_settings_page.dart   (Task 13)
lib/features/media/presentation/helpers/lightroom_scan_helper.dart      (Task 14)
lib/features/media/presentation/widgets/lightroom_suggestions_row.dart  (Task 15)
```

---

### Task 1: Promote PKCE helpers to a shared location

**Files:**
- Create: `lib/core/services/oauth/oauth_pkce.dart`
- Delete: `lib/core/services/cloud_storage/dropbox/dropbox_pkce.dart`
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart` (import only)
- Move test: `test/core/services/cloud_storage/dropbox/dropbox_pkce_test.dart` -> `test/core/services/oauth/oauth_pkce_test.dart`

**Interfaces:**
- Produces: top-level functions `String generateCodeVerifier({Random? random})` and `String codeChallengeS256(String verifier)` importable from `package:submersion/core/services/oauth/oauth_pkce.dart`. Consumed by Task 3 and (unchanged behavior) the Dropbox auth manager.

- [ ] **Step 1: Move the file**

Create `lib/core/services/oauth/oauth_pkce.dart` with the exact current contents of `dropbox_pkce.dart` (imports `dart:convert`, `dart:math`, `package:crypto/crypto.dart`; functions `generateCodeVerifier` and `codeChallengeS256` unchanged). Delete `lib/core/services/cloud_storage/dropbox/dropbox_pkce.dart`.

- [ ] **Step 2: Update imports**

In `dropbox_auth_manager.dart`, replace the `dropbox_pkce.dart` import with `package:submersion/core/services/oauth/oauth_pkce.dart`. Run `grep -rn "dropbox_pkce" lib/ test/` and update every remaining reference (the auth manager test imports it for `codeChallengeS256`).

- [ ] **Step 3: Move the test**

Move `dropbox_pkce_test.dart` to `test/core/services/oauth/oauth_pkce_test.dart`, updating its import. Contents unchanged (RFC 7636 vector tests).

- [ ] **Step 4: Verify**

Run: `flutter test test/core/services/oauth/oauth_pkce_test.dart test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`
Expected: PASS. Run `flutter analyze` — no issues.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor(oauth): promote PKCE helpers from dropbox to shared core/services/oauth"
```

---

### Task 2: Lightroom auth store

**Files:**
- Create: `lib/core/services/lightroom/lightroom_auth_store.dart`
- Test: `test/core/services/lightroom/lightroom_auth_store_test.dart`

**Interfaces:**
- Consumes: `FallbackSecureStorage` (`lib/core/services/secure_storage/fallback_secure_storage.dart`).
- Produces: `LightroomAuthData` (`clientId`, `clientSecret?`, `refreshToken`, `email?`, `displayName?`, `catalogId?`, `toJson`/`fromJson`) and `LightroomAuthStore` (`static const storageKey = 'lightroom_auth'`, `Future<LightroomAuthData?> load()`, `Future<void> save(LightroomAuthData)`, `Future<void> clear()`). Consumed by Tasks 3, 5, 13.

- [ ] **Step 1: Write the failing test**

Mirror `test/core/services/cloud_storage/dropbox/dropbox_auth_store_test.dart`, using the existing `InMemoryKeychain` from the dropbox test support file (`test/core/services/cloud_storage/dropbox/support/fake_keychain_storage.dart` — import it across suites, or copy it to `test/core/services/lightroom/support/` if the import is awkward):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';

import '../cloud_storage/dropbox/support/fake_keychain_storage.dart';

void main() {
  test('round-trips full auth data', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(
        clientId: 'cid',
        clientSecret: 'sec',
        refreshToken: 'rt',
        email: 'a@b.c',
        displayName: 'Eric',
        catalogId: 'cat123',
      ),
    );
    final loaded = await store.load();
    expect(loaded!.clientId, 'cid');
    expect(loaded.clientSecret, 'sec');
    expect(loaded.refreshToken, 'rt');
    expect(loaded.catalogId, 'cat123');
  });

  test('returns null when unset and on corrupt blob', () async {
    final keychain = InMemoryKeychain();
    final store = LightroomAuthStore(storage: keychain);
    expect(await store.load(), isNull);
    await keychain.write(key: LightroomAuthStore.storageKey, value: '{nope');
    expect(await store.load(), isNull); // corrupt blob left in place
  });

  test('clear removes the blob', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'c', refreshToken: 'r'),
    );
    await store.clear();
    expect(await store.load(), isNull);
  });
}
```

Note: `InMemoryKeychain` implements `FlutterSecureStorage`; check its actual class name/constructor in the support file and adjust the test if it differs.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/lightroom/lightroom_auth_store_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement**

`lib/core/services/lightroom/lightroom_auth_store.dart` — mirror `dropbox_auth_store.dart` exactly (single JSON blob, corrupt-blob-returns-null-without-deleting):

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../secure_storage/fallback_secure_storage.dart';

/// Persisted Lightroom connection credentials. BYO client id: the user's
/// own Adobe Developer Console credentials live alongside the refresh
/// token so the whole connection is one atomic blob.
class LightroomAuthData {
  const LightroomAuthData({
    required this.clientId,
    required this.refreshToken,
    this.clientSecret,
    this.email,
    this.displayName,
    this.catalogId,
  });

  final String clientId;
  final String refreshToken;
  final String? clientSecret;
  final String? email;
  final String? displayName;
  final String? catalogId;

  LightroomAuthData copyWith({
    String? refreshToken,
    String? email,
    String? displayName,
    String? catalogId,
  }) {
    return LightroomAuthData(
      clientId: clientId,
      clientSecret: clientSecret,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      catalogId: catalogId ?? this.catalogId,
    );
  }

  Map<String, Object?> toJson() => {
    'clientId': clientId,
    'clientSecret': clientSecret,
    'refreshToken': refreshToken,
    'email': email,
    'displayName': displayName,
    'catalogId': catalogId,
  };

  factory LightroomAuthData.fromJson(Map<String, Object?> json) {
    return LightroomAuthData(
      clientId: json['clientId'] as String,
      clientSecret: json['clientSecret'] as String?,
      refreshToken: json['refreshToken'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      catalogId: json['catalogId'] as String?,
    );
  }
}

/// Secure-storage persistence for the Lightroom connection. One JSON blob
/// under a single key so load/save stay atomic (S3/Dropbox precedent).
class LightroomAuthStore {
  LightroomAuthStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  static const String storageKey = 'lightroom_auth';

  final FallbackSecureStorage _storage;

  Future<LightroomAuthData?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LightroomAuthData.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(LightroomAuthData data) =>
      _storage.write(key: storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/lightroom/lightroom_auth_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): secure auth store for BYO Adobe credentials"
```

---

### Task 3: Adobe IMS auth manager (OAuth 2.0 + PKCE)

**Files:**
- Create: `lib/core/services/lightroom/adobe_ims_auth_manager.dart`
- Test: `test/core/services/lightroom/adobe_ims_auth_manager_test.dart`

**Interfaces:**
- Consumes: `oauth_pkce.dart` (Task 1), `LightroomAuthStore`/`LightroomAuthData` (Task 2), `CloudStorageException` from `lib/core/services/cloud_storage/cloud_storage_provider.dart` (reused as the surfaced error type; its `displayMessage` is what dialogs show).
- Produces:
  - `Uri beginAuthorization({required String clientId, String? clientSecret})`
  - `Future<LightroomAuthData> completeAuthorization(String codeOrRedirectUrl)`
  - `Future<String> getAccessToken()` (cached, single-flight refresh)
  - `Future<LightroomAuthData?> loadAuth()`
  - `Future<void> updateAuth(LightroomAuthData data)` (used post-connect to persist catalogId/account labels)
  - `void invalidateAccessToken()`
  - `Future<void> disconnect()`
  - `static String? extractAuthorizationCode(String input)`
  - constants `redirectUri`, `scopes`.

- [ ] **Step 1: Write the failing test**

Model on `dropbox_auth_manager_test.dart` (MockClient from `package:http/testing.dart`, `InMemoryKeychain`, fixed `now`, fixed verifier). Cover:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';

import '../cloud_storage/dropbox/support/fake_keychain_storage.dart';

void main() {
  AdobeImsAuthManager manager(
    MockClient mock, {
    LightroomAuthStore? store,
  }) => AdobeImsAuthManager(
    store: store ?? LightroomAuthStore(storage: InMemoryKeychain()),
    httpClient: mock,
    now: () => DateTime.utc(2026, 7, 11, 12),
    verifierGenerator: () => 'a' * 43,
  );

  final tokenOk = http.Response(
    jsonEncode({
      'access_token': 'at1',
      'refresh_token': 'rt1',
      'expires_in': 3600,
    }),
    200,
  );

  test('beginAuthorization builds IMS PKCE URL without secret', () {
    final m = manager(MockClient((_) async => http.Response('', 500)));
    final uri = m.beginAuthorization(clientId: 'cid');
    expect(uri.host, 'ims-na1.adobelogin.com');
    expect(uri.path, '/ims/authorize/v2');
    expect(uri.queryParameters['client_id'], 'cid');
    expect(uri.queryParameters['response_type'], 'code');
    expect(uri.queryParameters['redirect_uri'], AdobeImsAuthManager.redirectUri);
    expect(uri.queryParameters['scope'], AdobeImsAuthManager.scopes);
    expect(uri.queryParameters['code_challenge'], codeChallengeS256('a' * 43));
    expect(uri.queryParameters['code_challenge_method'], 'S256');
  });

  test('extractAuthorizationCode handles raw code and redirect URL', () {
    expect(AdobeImsAuthManager.extractAuthorizationCode('abc123'), 'abc123');
    expect(
      AdobeImsAuthManager.extractAuthorizationCode(
        'https://submersion.app/lightroom/callback?code=xyz&state=1',
      ),
      'xyz',
    );
    expect(AdobeImsAuthManager.extractAuthorizationCode('   '), isNull);
    expect(
      AdobeImsAuthManager.extractAuthorizationCode(
        'https://submersion.app/lightroom/callback?error=access_denied',
      ),
      isNull,
    );
  });

  test('completeAuthorization exchanges code with verifier and persists', () async {
    final requests = <http.Request>[];
    final mock = MockClient((req) async {
      requests.add(req);
      return tokenOk;
    });
    final keychain = InMemoryKeychain();
    final m = manager(mock, store: LightroomAuthStore(storage: keychain));
    m.beginAuthorization(clientId: 'cid', clientSecret: 'sec');
    final data = await m.completeAuthorization('thecode');
    expect(data.refreshToken, 'rt1');
    expect(data.clientId, 'cid');
    final body = Uri.splitQueryString(requests.single.body);
    expect(body['grant_type'], 'authorization_code');
    expect(body['code'], 'thecode');
    expect(body['code_verifier'], 'a' * 43);
    expect(body['client_id'], 'cid');
    expect(body['client_secret'], 'sec');
    expect(body['redirect_uri'], AdobeImsAuthManager.redirectUri);
    expect(await m.loadAuth(), isNotNull);
  });

  test('completeAuthorization throws without beginAuthorization', () {
    final m = manager(MockClient((_) async => tokenOk));
    expect(m.completeAuthorization('c'), throwsA(isA<CloudStorageException>()));
  });

  test('getAccessToken refreshes with stored token, caches, single-flights',
      () async {
    var calls = 0;
    final mock = MockClient((req) async {
      calls++;
      final body = Uri.splitQueryString(req.body);
      expect(body['grant_type'], 'refresh_token');
      expect(body['refresh_token'], 'rt0');
      expect(body['client_id'], 'cid');
      return tokenOk;
    });
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(mock, store: store);
    final results = await Future.wait([m.getAccessToken(), m.getAccessToken()]);
    expect(results, ['at1', 'at1']);
    expect(calls, 1);
    expect(await m.getAccessToken(), 'at1'); // cached
    expect(calls, 1);
  });

  test('rotated refresh token from IMS is persisted', () async {
    final mock = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'access_token': 'at2',
          'refresh_token': 'rt-rotated',
          'expires_in': 3600,
        }),
        200,
      ),
    );
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(mock, store: store);
    await m.getAccessToken();
    expect((await store.load())!.refreshToken, 'rt-rotated');
  });

  test('4xx refresh throws but preserves stored blob', () async {
    final mock = MockClient((_) async => http.Response('denied', 400));
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(mock, store: store);
    await expectLater(
      m.getAccessToken(),
      throwsA(isA<CloudStorageException>()),
    );
    expect(await store.load(), isNotNull);
  });

  test('disconnect clears store', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(MockClient((_) async => http.Response('', 200)),
        store: store);
    await m.disconnect();
    expect(await store.load(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/lightroom/adobe_ims_auth_manager_test.dart`
Expected: FAIL (class not defined).

- [ ] **Step 3: Implement**

`lib/core/services/lightroom/adobe_ims_auth_manager.dart` — same skeleton as `DropboxAuthManager` (single-flight refresh, memory-only access token, `_expiryMargin` 60s, `_requestToken` wrapping network errors in `CloudStorageException('Could not reach Adobe', ...)`, 4xx -> reconnect message, 5xx -> `'Adobe authorization failed (<status>)'`). Differences from Dropbox:

```dart
class AdobeImsAuthManager {
  AdobeImsAuthManager({
    LightroomAuthStore? store,
    http.Client? httpClient,
    DateTime Function()? now,
    String Function()? verifierGenerator,
  }) : _store = store ?? LightroomAuthStore(),
       _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now,
       _generateVerifier = verifierGenerator ?? generateCodeVerifier;

  static final Uri _authorizeUri =
      Uri.parse('https://ims-na1.adobelogin.com/ims/authorize/v2');
  static final Uri _tokenUri =
      Uri.parse('https://ims-na1.adobelogin.com/ims/token/v3');
  static const String redirectUri =
      'https://submersion.app/lightroom/callback';
  static const String scopes =
      'openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access';
  static const Duration _expiryMargin = Duration(seconds: 60);
  ...
```

- `beginAuthorization({required String clientId, String? clientSecret})`: throws `CloudStorageException` on empty clientId; stashes `_pendingVerifier`, `_pendingClientId`, `_pendingClientSecret`; returns `_authorizeUri.replace(queryParameters: {'client_id': clientId, 'scope': scopes, 'response_type': 'code', 'redirect_uri': redirectUri, 'code_challenge': codeChallengeS256(verifier), 'code_challenge_method': 'S256'})`.
- `static String? extractAuthorizationCode(String input)`: trim; empty -> null; if it parses as a URI with a `code` query parameter, return that; if the URI parses but has no `code`, return null; otherwise return the trimmed input as a raw code (a raw code contains no `://`).
- `completeAuthorization(String codeOrRedirectUrl)`: requires pending state (else `CloudStorageException('No authorization in progress...')`); extract code (null -> `CloudStorageException` telling the user to paste the full redirected URL); POST form to `_tokenUri` with `grant_type=authorization_code`, `client_id`, `code`, `code_verifier`, `redirect_uri`, plus `client_secret` when non-empty; parse `access_token`/`refresh_token`/`expires_in`; save `LightroomAuthData(clientId: _pendingClientId!, clientSecret: _pendingClientSecret, refreshToken: ...)`; cache access token; clear pending state; return the data.
- `_refreshAccessToken()`: load store (null -> `CloudStorageException('Lightroom is not connected.')`); POST `grant_type=refresh_token`, `refresh_token`, `client_id`, plus `client_secret` when set. If the response carries a non-empty `refresh_token` different from the stored one, persist `data.copyWith(refreshToken: newToken)` (IMS rotates refresh tokens).
- `getAccessToken()`: cached-until-expiry, single-flight via `_refreshInFlight ??= ...whenComplete(() => _refreshInFlight = null)`.
- `updateAuth(LightroomAuthData data)` -> `_store.save(data)`; `loadAuth()` -> `_store.load()`.
- `disconnect()`: `invalidateAccessToken(); await _store.clear();` (IMS has no token-revoke endpoint usable here; clearing local credentials is the whole story).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/lightroom/adobe_ims_auth_manager_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): Adobe IMS OAuth2+PKCE auth manager"
```

---

### Task 4: Lightroom API client and models

**Files:**
- Create: `lib/core/services/lightroom/lightroom_models.dart`
- Create: `lib/core/services/lightroom/lightroom_api_client.dart`
- Test: `test/core/services/lightroom/lightroom_api_client_test.dart`

**Interfaces:**
- Consumes: `AdobeImsAuthManager.getAccessToken()` and `loadAuth()` (Task 3), `parseExternalDateAsWallClockUtc` (`lib/core/util/wall_clock_utc.dart`).
- Produces (consumed by Tasks 9, 10, 13, 15):

```dart
class LightroomAccount { final String id; final String? fullName; final String? email; }
class LightroomAlbum { final String id; final String name; }
class LightroomAsset {
  final String id;
  final String subtype;          // 'image' | 'video'
  final DateTime? captureDate;   // wall-clock UTC; null when Lightroom reports the unknown sentinel
  final String? fileName;
  final double? latitude;
  final double? longitude;
  final int? videoDurationSeconds;
  bool get isVideo => subtype == 'video';
}
class LightroomAssetPage { final List<LightroomAsset> assets; final String? nextUrl; }
class LightroomApiException implements Exception { final int statusCode; final String message; }

class LightroomApiClient {
  LightroomApiClient({required AdobeImsAuthManager auth, http.Client? httpClient});
  Future<LightroomAccount> getAccount();
  Future<String> getCatalogId();
  Future<List<LightroomAlbum>> listAlbums(String catalogId);
  Future<LightroomAssetPage> listAssets(String catalogId, {DateTime? capturedAfter, DateTime? capturedBefore, String? nextUrl});
  Future<LightroomAssetPage> listAlbumAssets(String catalogId, String albumId, {String? nextUrl});
  Future<Uint8List> getRendition({required String catalogId, required String assetId, required String size}); // size: '2048' | 'thumbnail2x'
  static String assetWebUrl(String catalogId, String assetId);
  static String stripAbuseGuard(String body);
}
```

- [ ] **Step 1: Write the failing test**

Use `MockClient`; every JSON fixture body MUST be prefixed with `'while (1) {}'`. Cover:

- `stripAbuseGuard` removes the exact prefix (and any following newline) and leaves other bodies untouched.
- `getAccount` GETs `https://lr.adobe.io/v2/account` with headers `Authorization: Bearer <token>` and `X-API-Key: <clientId>` (clientId comes from `auth.loadAuth()`), parses `{'id': ..., 'full_name': ..., 'email': ...}`.
- `getCatalogId` GETs `/v2/catalog`, returns `json['id']`.
- `listAssets` builds `/v2/catalogs/cat1/assets?subtype=image%3Bvideo&captured_after=<iso>&captured_before=<iso>`, parses this fixture:

```dart
final assetsFixture = 'while (1) {}' + jsonEncode({
  'resources': [
    {
      'id': 'asset1',
      'subtype': 'image',
      'payload': {
        'captureDate': '2026-07-01T10:15:00',
        'importSource': {'fileName': 'IMG_1.jpg'},
        'location': {'latitude': 4.5, 'longitude': 55.5},
      },
    },
    {
      'id': 'asset2',
      'subtype': 'video',
      'payload': {
        'captureDate': '2026-07-01T10:20:00',
        'importSource': {'fileName': 'MOV_1.mp4'},
        'video': {'duration': 12.5},
      },
    },
    {
      'id': 'asset3',
      'subtype': 'image',
      'payload': {'captureDate': '0000-00-00T00:00:00'},
    },
  ],
  'links': {'next': {'href': '/v2/catalogs/cat1/assets?name_after=asset2'}},
});
```

  Assert: 3 assets; `captureDate` of asset1 equals `DateTime.utc(2026, 7, 1, 10, 15)`; asset3 `captureDate` is null; asset2 `isVideo` true with `videoDurationSeconds` 12 (rounded down is fine — assert 12 or 13 per your rounding, pick `.round()`); `nextUrl` resolves to `https://lr.adobe.io/v2/catalogs/cat1/assets?name_after=asset2`.
- `listAssets(nextUrl: ...)` GETs the given URL verbatim (no params re-added).
- `listAlbumAssets` GETs `/v2/catalogs/cat1/albums/al1/assets?embed=asset` and unwraps `resources[i]['asset']` (fixture: album_asset resources each containing an embedded `asset` object of the same shape as above).
- `getRendition` GETs `/v2/catalogs/cat1/assets/a1/renditions/2048`, returns raw `bodyBytes` (fixture returns non-JSON bytes); a 404 throws `LightroomApiException` with `statusCode == 404`.
- Any non-2xx on a JSON endpoint throws `LightroomApiException` carrying the status code; a 401 message mentions reconnecting.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/lightroom/lightroom_api_client_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`lightroom_models.dart`: plain classes above plus a tolerant parser:

```dart
factory LightroomAsset.fromResource(Map<String, Object?> resource) {
  final payload = resource['payload'] as Map<String, Object?>? ?? const {};
  final rawCapture = payload['captureDate'] as String?;
  DateTime? captureDate;
  if (rawCapture != null && !rawCapture.startsWith('0000')) {
    captureDate = parseExternalDateAsWallClockUtc(rawCapture);
  }
  final importSource = payload['importSource'] as Map<String, Object?>? ?? const {};
  final location = payload['location'] as Map<String, Object?>? ?? const {};
  final video = payload['video'] as Map<String, Object?>? ?? const {};
  return LightroomAsset(
    id: resource['id'] as String,
    subtype: resource['subtype'] as String? ?? 'image',
    captureDate: captureDate,
    fileName: importSource['fileName'] as String?,
    latitude: (location['latitude'] as num?)?.toDouble(),
    longitude: (location['longitude'] as num?)?.toDouble(),
    videoDurationSeconds: (video['duration'] as num?)?.round(),
  );
}
```

`lightroom_api_client.dart`:

- `static const String baseUrl = 'https://lr.adobe.io';`
- `static String stripAbuseGuard(String body)`: `const guard = 'while (1) {}'; var s = body; if (s.startsWith(guard)) s = s.substring(guard.length); return s.trimLeft();`
- Private `Future<Map<String, Object?>> _getJson(Uri uri)`: builds headers `{'Authorization': 'Bearer ${await _auth.getAccessToken()}', 'X-API-Key': (await _auth.loadAuth())!.clientId}`; 401 -> `LightroomApiException(401, 'Adobe rejected the credentials. Reconnect Lightroom in Settings.')`; other non-2xx -> `LightroomApiException(status, 'Lightroom API error <status>')`; else `jsonDecode(stripAbuseGuard(response.body))`.
- `listAssets`: when `nextUrl` is null build `Uri.parse('$baseUrl/v2/catalogs/$catalogId/assets').replace(queryParameters: {...})` with `subtype: 'image;video'` plus `captured_after`/`captured_before` formatted `toIso8601String()` without the trailing `Z` handling needed — use the wall-clock value's `toIso8601String().replaceFirst('Z', '')`; when `nextUrl` is provided, resolve it against `baseUrl` if relative. Parse `resources` list via `LightroomAsset.fromResource`, and `links.next.href` into an absolute `nextUrl` (null when absent).
- `listAlbumAssets`: same but resource is `resource['asset'] as Map<String, Object?>` unwrapped before `fromResource` (album-asset rows wrap the asset; skip rows without an embedded asset).
- `listAlbums`: GET `/v2/catalogs/$catalogId/albums?subtype=collection`, map `resources` to `LightroomAlbum(id, payload['name'] ?? 'Untitled')`, follow `links.next` pages until exhausted (albums are few).
- `getRendition`: GET with the same headers; 2xx -> `response.bodyBytes`; else `LightroomApiException(status, ...)`.
- `static String assetWebUrl(String catalogId, String assetId) => 'https://lightroom.adobe.com/libraries/$catalogId/assets/$assetId';`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/lightroom/lightroom_api_client_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): partner API client with abuse-guard stripping and pagination"
```

---

### Task 5: ConnectorAccounts repository

**Files:**
- Create: `lib/features/media/domain/entities/connector_account.dart`
- Create: `lib/features/media/data/repositories/connector_accounts_repository.dart`
- Test: `test/features/media/data/connector_accounts_repository_test.dart`

**Interfaces:**
- Consumes: existing Drift table `ConnectorAccounts` (`database.dart:960` — id, connectorType, displayName, baseUrl?, accountIdentifier?, credentialsRef, addedAt, lastUsedAt?). The table is currently unused by any code; this is its first repository. Drift's generated row class is also named `ConnectorAccount`, so the repository imports the domain entity with `as domain` (repo convention).
- Produces (consumed by Tasks 9, 11, 13):

```dart
// domain entity
class ConnectorAccount extends Equatable {
  final String id; final String connectorType; final String displayName;
  final String? baseUrl; final String? accountIdentifier; // Lightroom: catalog id
  final String credentialsRef; final DateTime addedAt; final DateTime? lastUsedAt;
}

class ConnectorAccountsRepository {
  ConnectorAccountsRepository(AppDatabase db);
  Future<domain.ConnectorAccount?> getByType(String connectorType); // newest by addedAt when several
  Future<domain.ConnectorAccount> create({
    required String connectorType,
    required String displayName,
    required String credentialsRef,
    String? accountIdentifier,
  }); // uuid v4 id, addedAt = now
  Future<void> updateDisplay(String id, {String? displayName, String? accountIdentifier});
  Future<void> touchLastUsed(String id);
  Future<void> delete(String id);
}
```

- [ ] **Step 1: Write the failing test**

In-memory `AppDatabase` (follow any existing repository test for construction, e.g. the media repository tests use `AppDatabase(DatabaseConnection(NativeDatabase.memory()))` or a shared helper — mirror it). Cover: create-then-getByType round-trip (all fields), getByType returns null when absent, touchLastUsed sets lastUsedAt, delete removes, getByType picks the newest of two accounts of the same type.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/connector_accounts_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Entity mirrors `MediaItem`'s Equatable style. Repository uses plain Drift queries; `create` uses `const Uuid().v4()` (package already in pubspec — `MediaRepository.createMedia` uses it) and `DateTime.now().millisecondsSinceEpoch` for `addedAt`. Row-to-entity mapping converts epoch ints via `DateTime.fromMillisecondsSinceEpoch(x, isUtc: true)`. The table is not synced — no `markRecordPending`, no HLC.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/connector_accounts_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(media): connector accounts repository (first consumer of the v72 table)"
```

---

### Task 6: Schema vNEXT + suggestion entity/CRUD + dedup queries

**Files:**
- Modify: `lib/core/database/database.dart` (table def, schemaVersion, onUpgrade, beforeOpen backstop)
- Modify: `lib/features/media/domain/entities/media_item.dart` (`PendingPhotoSuggestion` fields)
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_repository_suggestions_test.dart`, plus a migration test following `test/core/database/migration_v103_media_store_test.dart`

**Interfaces:**
- Produces (consumed by Tasks 9, 15):
  - `PendingPhotoSuggestions` table gains `TextColumn get connectorAccountId => text().nullable()();` and `TextColumn get remoteAssetId => text().nullable()();`
  - `PendingPhotoSuggestion` entity gains `final String? connectorAccountId; final String? remoteAssetId;`
  - `MediaRepository` additions:

```dart
Future<Set<String>> getConnectorRemoteAssetIds();          // media WHERE source_type='serviceConnector' AND remote_asset_id NOT NULL
Future<Set<String>> getPendingSuggestionRemoteAssetIds();  // suggestions WHERE dismissed=0 AND remote_asset_id NOT NULL
Future<PendingPhotoSuggestion> createPendingSuggestion(PendingPhotoSuggestion s); // uuid when id empty
Future<List<PendingPhotoSuggestion>> getPendingSuggestionsForDive(String diveId); // dismissed=0, ordered takenAt
Future<void> dismissPendingSuggestion(String id);
Future<void> deleteSuggestionsForRemoteAsset(String remoteAssetId); // all candidate rows for a confirmed asset
```

- [ ] **Step 1: Write the failing tests**

Suggestions test (in-memory DB): create a suggestion with `connectorAccountId`/`remoteAssetId` set (note: `platformAssetId` is NOT NULL in the table — connector suggestions store the Lightroom asset id in BOTH `platformAssetId` and `remoteAssetId`); read back via `getPendingSuggestionsForDive`; `dismissPendingSuggestion` hides it from the list and from `getPendingSuggestionRemoteAssetIds`; `deleteSuggestionsForRemoteAsset` removes two candidate rows sharing one remoteAssetId; `getConnectorRemoteAssetIds` returns ids only for `sourceType == serviceConnector` media rows (insert one gallery row and one connector row via `createMedia` and assert only the connector one appears). Suggestions reference a dive (FK) — insert a minimal dive row first, mirroring existing media tests.

Migration test: follow `migration_v103_media_store_test.dart`'s pattern — open a database at the prior schema, migrate, assert `PRAGMA table_info(pending_photo_suggestions)` contains `connector_account_id` and `remote_asset_id`; run the idempotent DDL twice to prove re-entry safety.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/data/media_repository_suggestions_test.dart`
Expected: FAIL (columns/methods missing).

- [ ] **Step 3: Implement**

1. Add the two nullable columns to the `PendingPhotoSuggestions` table class.
2. Bump `schemaVersion` to vNEXT (current+1 — read the actual current value on your branch).
3. In `onUpgrade`, add (reusing the file's existing idempotent-DDL helper if #550 introduced one; otherwise add this private helper):

```dart
Future<void> _addPendingSuggestionConnectorColumns() async {
  final info = await customSelect(
    'PRAGMA table_info(pending_photo_suggestions)',
  ).get();
  final existing = info.map((r) => r.data['name'] as String).toSet();
  if (!existing.contains('connector_account_id')) {
    await customStatement(
      'ALTER TABLE pending_photo_suggestions ADD COLUMN connector_account_id TEXT',
    );
  }
  if (!existing.contains('remote_asset_id')) {
    await customStatement(
      'ALTER TABLE pending_photo_suggestions ADD COLUMN remote_asset_id TEXT',
    );
  }
}
```

Call it from `onUpgrade` under `if (from < vNEXT)` AND from the `beforeOpen` backstop block (parallel-branch collision pattern — follow how v103 re-asserts).
4. Extend the `PendingPhotoSuggestion` entity (constructor, props list) and the repository's row<->entity mapping.
5. Implement the six repository methods with plain Drift queries; `createPendingSuggestion` fills `id` with `const Uuid().v4()` when empty and `createdAt` now. No sync/HLC (table is per-device).
6. Run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/media_repository_suggestions_test.dart test/core/database/` (the whole database directory to catch migration regressions).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(media): connector columns on pending suggestions + suggestion CRUD and remote-asset dedup queries (schema vNEXT)"
```

---

### Task 7: DivePhotoMatcher confidence API

**Files:**
- Modify: `lib/features/media/domain/services/dive_photo_matcher.dart`
- Test: `test/features/media/domain/dive_photo_matcher_timestamp_test.dart`

**Interfaces:**
- Consumes: existing `DiveBounds` (`diveId`, `entryTime`, `exitTime`) and window constants `preBuffer` (30 min) / `postBuffer` (60 min). The existing `match()` method is untouched.
- Produces (consumed by Task 9):

```dart
enum TimestampMatchKind { confident, ambiguous, none }

class TimestampMatch {
  const TimestampMatch({
    required this.kind,
    this.diveId,
    this.candidateDiveIds = const [],
  });
  final TimestampMatchKind kind;
  final String? diveId;                 // set when confident
  final List<String> candidateDiveIds;  // set when ambiguous, closest-entry first
}

// instance method on DivePhotoMatcher:
TimestampMatch matchTimestamp({
  required DateTime takenAt,
  required List<DiveBounds> dives,
});
```

Rules (spec section 6): extended window = `[entry - preBuffer, exit + postBuffer]`, core window = `[entry, exit]`, boundaries inclusive. Zero extended hits -> `none`. Exactly one extended hit -> `confident`. Multiple extended hits: exactly one core hit -> `confident` for that dive; otherwise `ambiguous` with all extended-hit dives sorted by `|takenAt - entry|` ascending.

- [ ] **Step 1: Write the failing test**

Cases (build `DiveBounds` with `DateTime.utc`):
1. Inside core window of a lone dive -> confident.
2. In post-margin of a lone dive (exit + 45 min) -> confident (single extended hit).
3. Surface interval between dive A (exit 10:00) and dive B (entry 10:45), photo 10:20 -> ambiguous, candidates ordered [closer dive first] — compute which entry is nearer and assert the order.
4. Photo during dive B's core while also in dive A's post-margin -> confident dive B.
5. Photo outside every window -> none.
6. Boundary: exactly `entry - 30min` -> hit (inclusive); `entry - 30min - 1s` -> miss.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/domain/dive_photo_matcher_timestamp_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
TimestampMatch matchTimestamp({
  required DateTime takenAt,
  required List<DiveBounds> dives,
}) {
  bool inExtended(DiveBounds d) =>
      !takenAt.isBefore(d.entryTime.subtract(preBuffer)) &&
      !takenAt.isAfter(d.exitTime.add(postBuffer));
  bool inCore(DiveBounds d) =>
      !takenAt.isBefore(d.entryTime) && !takenAt.isAfter(d.exitTime);

  final extended = dives.where(inExtended).toList();
  if (extended.isEmpty) {
    return const TimestampMatch(kind: TimestampMatchKind.none);
  }
  if (extended.length == 1) {
    return TimestampMatch(
      kind: TimestampMatchKind.confident,
      diveId: extended.single.diveId,
    );
  }
  final core = extended.where(inCore).toList();
  if (core.length == 1) {
    return TimestampMatch(
      kind: TimestampMatchKind.confident,
      diveId: core.single.diveId,
    );
  }
  extended.sort(
    (a, b) => takenAt
        .difference(a.entryTime)
        .abs()
        .compareTo(takenAt.difference(b.entryTime).abs()),
  );
  return TimestampMatch(
    kind: TimestampMatchKind.ambiguous,
    candidateDiveIds: extended.map((d) => d.diveId).toList(),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/domain/dive_photo_matcher_timestamp_test.dart` plus the existing matcher test file (locate with `ls test/features/media/domain/`) to confirm no regression.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(media): confidence-bearing timestamp matching on DivePhotoMatcher"
```

---

### Task 8: Per-device connector state (SharedPreferences)

**Files:**
- Create: `lib/features/media/data/services/lightroom_connector_state.dart`
- Test: `test/features/media/data/lightroom_connector_state_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences` (test with `SharedPreferences.setMockInitialValues({})`).
- Produces (consumed by Tasks 9, 13, 16), keys namespaced per account (`lightroom_<accountId>_...`) following `MediaStoreAttachState`'s style:

```dart
class LightroomConnectorState {
  LightroomConnectorState({required SharedPreferences prefs, required String accountId});
  Future<DateTime?> lastPollAt();
  Future<void> setLastPollAt(DateTime t);
  Future<List<String>> albumIds();              // empty = whole catalog
  Future<void> setAlbumIds(List<String> ids);
  Future<bool> autoPollEnabled();               // default true
  Future<void> setAutoPollEnabled(bool enabled);
  Future<String?> lastError();                  // needs-reauth surfacing (spec section 7)
  Future<void> setLastError(String? message);   // null clears
  Future<void> clear();                         // on disconnect
}
```

- [ ] **Step 1: Write the failing test** — round-trip each field, defaults (null / empty / true / null), `setLastError(null)` clears, `clear()` resets all four, and two different accountIds do not collide.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/lightroom_connector_state_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** — trivial `prefs.getInt/setInt` (epoch ms) for lastPollAt, `getStringList` for albumIds, `getBool` for autoPoll, `getString/setString/remove` for lastError. Keys: `'lightroom_${accountId}_last_poll_at'`, `..._album_ids`, `..._auto_poll`, `..._last_error`.

- [ ] **Step 4: Run test to verify it passes** — same command, PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): per-device connector scan state in SharedPreferences"
```

---

### Task 9: LightroomScanService

**Files:**
- Create: `lib/features/media/data/services/lightroom_scan_service.dart`
- Test: `test/features/media/data/lightroom_scan_service_test.dart`

**Interfaces:**
- Consumes: `LightroomApiClient` (Task 4), `MediaRepository` incl. Task 6 additions, `DiveRepository` (`lib/features/dive_log/data/repositories/dive_repository_impl.dart` — `getDivesInRange(start, end)`, `getDiveById(id)`), `DivePhotoMatcher.matchTimestamp` (Task 7), `EnrichmentService.calculateEnrichment({profile, diveStartTime, photoTime})`, `ConnectorAccount` (Task 5), `LightroomConnectorState` (Task 8), injected `void Function(String mediaId) enqueueUpload`.
- Produces (consumed by Tasks 13, 14, 15, 16):

```dart
class LightroomScanSummary {
  int examined = 0, attached = 0, suggested = 0,
      skippedExisting = 0, skippedNoCaptureTime = 0;
}

class LightroomScanService {
  LightroomScanService({
    required LightroomApiClient api,
    required MediaRepository mediaRepository,
    required DiveRepository diveRepository,
    required EnrichmentService enrichmentService,
    required void Function(String mediaId) enqueueUpload,
    DivePhotoMatcher matcher = const DivePhotoMatcher(),   // adjust if ctor is non-const
    DateTime Function()? now,
  });

  static const Duration pollLookback = Duration(days: 90);

  Future<LightroomScanSummary> scanDives({
    required ConnectorAccount account,
    required List<Dive> dives,
    required LightroomConnectorState state,
  });

  Future<LightroomScanSummary> poll({
    required ConnectorAccount account,
    required LightroomConnectorState state,
  }); // dives from last pollLookback days, then scanDives, then state.setLastPollAt

  Future<void> confirmSuggestion({
    required ConnectorAccount account,
    required PendingPhotoSuggestion suggestion,
  }); // re-fetch nothing: create media row from suggestion fields, enrich, enqueue, deleteSuggestionsForRemoteAsset

  static List<({DateTime start, DateTime end})> mergeWindows(
    List<DiveBounds> bounds,
  );
}
```

- [ ] **Step 1: Write the failing tests**

Fake `LightroomApiClient` via a subclass or an abstract seam — simplest: make the scan service take the client and in tests pass a `_FakeLightroomApi` extending `LightroomApiClient` with overridden `listAssets`/`listAlbumAssets` returning canned pages (constructor: pass a throwing `AdobeImsAuthManager` and a `MockClient` that fails — the overrides never call super). In-memory `AppDatabase` with real `MediaRepository`, `DiveRepositoryImpl`, and seeded dives (two dives on one day: A 10:00-11:00, B 12:00-13:00, entry/exit set; profile points on dive A so enrichment has data). Collected `enqueued` list via the injected closure. Cases:

1. **mergeWindows**: two overlapping windows merge into one span; disjoint dives yield two spans; spans carry the pre/post buffers.
2. **Confident attach**: asset captured 10:30 -> media row created with `sourceType == MediaSourceType.serviceConnector`, `remoteAssetId == asset.id`, `connectorAccountId == account.id`, `diveId == diveA.id`, `takenAt == DateTime.utc(...)`; enrichment row saved; `enqueued` contains the media id; summary.attached == 1.
3. **Video attach**: video asset in-window creates a row with `mediaType == MediaType.video` and `durationSeconds` set; enqueued too.
4. **Ambiguous**: asset captured 11:30 (post-margin of A + pre-margin of B) -> no media row; two suggestion rows (one per candidate dive) sharing `remoteAssetId`; summary.suggested == 1.
5. **Dedup**: pre-insert a connector media row with `remoteAssetId 'asset1'`; scanning a page containing asset1 skips it (summary.skippedExisting == 1, no duplicate row). Same for an id already in a live suggestion.
6. **No capture date**: asset with null captureDate -> skippedNoCaptureTime, nothing created.
7. **Album filter**: `state.setAlbumIds(['al1'])` -> service calls `listAlbumAssets` (fake records invocations) instead of `listAssets`, and still window-filters.
8. **confirmSuggestion**: creates the media row for the suggestion's dive, deletes both candidate rows, enqueues.
9. **poll**: seeds `lastPollAt` unset; poll scans dives within lookback and stamps `setLastPollAt`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/data/lightroom_scan_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Core flow of `scanDives`:

```dart
final summary = LightroomScanSummary();
final catalogId = account.accountIdentifier;
if (catalogId == null || dives.isEmpty) return summary;

final bounds = dives.map(_boundsFor).whereType<DiveBounds>().toList();
if (bounds.isEmpty) return summary;
final spans = mergeWindows(bounds);

final existing = await _mediaRepository.getConnectorRemoteAssetIds();
final suggested = await _mediaRepository.getPendingSuggestionRemoteAssetIds();
final albumIds = await state.albumIds();

final assets = <LightroomAsset>[];
if (albumIds.isEmpty) {
  for (final span in spans) {
    String? next;
    do {
      final page = await _api.listAssets(
        catalogId,
        capturedAfter: span.start,
        capturedBefore: span.end,
        nextUrl: next,
      );
      assets.addAll(page.assets);
      next = page.nextUrl;
    } while (next != null);
  }
} else {
  for (final albumId in albumIds) {
    String? next;
    do {
      final page = await _api.listAlbumAssets(catalogId, albumId, nextUrl: next);
      assets.addAll(page.assets);
      next = page.nextUrl;
    } while (next != null);
  }
}

final seenThisScan = <String>{};
for (final asset in assets) {
  if (!seenThisScan.add(asset.id)) continue; // overlapping spans/albums
  summary.examined++;
  if (asset.captureDate == null) { summary.skippedNoCaptureTime++; continue; }
  if (existing.contains(asset.id) || suggested.contains(asset.id)) {
    summary.skippedExisting++; continue;
  }
  final match = _matcher.matchTimestamp(takenAt: asset.captureDate!, dives: bounds);
  switch (match.kind) {
    case TimestampMatchKind.none: break;
    case TimestampMatchKind.confident:
      await _attach(asset, diveId: match.diveId!, account: account);
      summary.attached++;
    case TimestampMatchKind.ambiguous:
      for (final diveId in match.candidateDiveIds) {
        await _mediaRepository.createPendingSuggestion(PendingPhotoSuggestion(
          id: '', diveId: diveId, platformAssetId: asset.id,
          takenAt: asset.captureDate!, createdAt: _now(),
          connectorAccountId: account.id, remoteAssetId: asset.id,
        ));
      }
      summary.suggested++;
  }
}
return summary;
```

`_boundsFor(Dive dive)` replicates `TripMediaScanner`'s fallbacks: entry = `dive.entryTime ?? dive.dateTime`; exit = `dive.exitTime ?? entry.add(dive.effectiveRuntime ?? const Duration(minutes: 60))`; returns `DiveBounds(diveId: dive.id, entryTime: entry, exitTime: exit)`.

`_attach` creates the row and enriches:

```dart
Future<void> _attach(LightroomAsset asset,
    {required String diveId, required ConnectorAccount account}) async {
  final now = _now();
  final saved = await _mediaRepository.createMedia(domain.MediaItem(
    id: '',
    diveId: diveId,
    mediaType: asset.isVideo ? MediaType.video : MediaType.photo,
    takenAt: asset.captureDate!,
    originalFilename: asset.fileName,
    latitude: asset.latitude,
    longitude: asset.longitude,
    durationSeconds: asset.videoDurationSeconds,
    sourceType: MediaSourceType.serviceConnector,
    connectorAccountId: account.id,
    remoteAssetId: asset.id,
    createdAt: now,
    updatedAt: now,
  ));
  final dive = await _diveRepository.getDiveById(diveId);
  final profile = dive?.profile ?? const [];
  if (dive != null && profile.isNotEmpty) {
    final result = _enrichmentService.calculateEnrichment(
      profile: profile,
      diveStartTime: dive.effectiveEntryTime,
      photoTime: asset.captureDate!,
    );
    if (result.depthMeters != null ||
        result.matchConfidence != MatchConfidence.noProfile) {
      await _mediaRepository.saveEnrichment(domain.MediaEnrichment(
        id: '',
        mediaId: saved.id,
        diveId: dive.id,
        depthMeters: result.depthMeters,
        temperatureCelsius: result.temperatureCelsius,
        elapsedSeconds: result.elapsedSeconds,
        matchConfidence: result.matchConfidence,
      ));
    }
  }
  _enqueueUpload(saved.id);
}
```

(Check `MediaEnrichment`'s exact constructor in `media_item.dart` and mirror `MediaImportService._calculateEnrichment` — including `timestampOffsetSeconds` if the constructor requires it.)

`mergeWindows`: map bounds to `(entry - preBuffer, exit + postBuffer)`, sort by start, fold overlapping/touching spans.

`poll`: `final until = _now(); final dives = await _diveRepository.getDivesInRange(until.subtract(pollLookback), until);` then `scanDives`, then `state.setLastPollAt(until)`. (`getDivesInRange` filters on dive start time; the extra window margins are inside `scanDives` already.)

`confirmSuggestion`: build a `LightroomAsset`-free attach — reuse `_attach`-like code from the suggestion's stored fields (`remoteAssetId`, `takenAt`; no filename/GPS/duration available on the suggestion — pass nulls, `mediaType: MediaType.photo` unless you also stored subtype; storing nulls is acceptable v1), then `deleteSuggestionsForRemoteAsset(suggestion.remoteAssetId!)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/lightroom_scan_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): scan service - window merge, dedup, confident attach, suggestions, poll"
```

---

### Task 10: ConnectorMediaResolver

**Files:**
- Create: `lib/features/media/data/resolvers/connector_media_resolver.dart`
- Test: `test/features/media/data/connector_media_resolver_test.dart`

**Interfaces:**
- Consumes: `MediaSourceResolver` interface (`lib/features/media/domain/services/media_source_resolver.dart`), `MediaSourceData` variants (`FileData`/`BytesData`/`UnavailableData` + `UnavailableKind`), `VerifyResult` enum (`available, notFound, unauthenticated, transientError, fromOtherDevice`), `LightroomApiClient.getRendition` (Task 4), `MediaCacheStore` + `MediaCacheKind` + `sha256OfFile` (#550: `lib/features/media_store/data/media_cache_store.dart`, `lib/core/services/media_store/store_keys.dart`).
- Produces (registered in Task 11, exercised by the pipeline in Task 12):

```dart
class ConnectorMediaResolver implements MediaSourceResolver {
  ConnectorMediaResolver({
    required bool hasLightroomAccount,
    required Future<LightroomApiClient?> Function() apiClient,
    required Future<String?> Function() catalogId,
    required Future<MediaCacheStore?> Function() cache,
  });
  // sourceType => MediaSourceType.serviceConnector
  // canResolveOnThisDevice => hasLightroomAccount && item.remoteAssetId != null
}
```

Behavior:
- `resolve(item)`: no account/api/catalog -> `UnavailableData(kind: UnavailableKind.signInRequired)`. If `item.contentHash != null` and cache has `(hash, original)` -> `FileData`. Else download rendition `'2048'`; on success: if `item.contentHash != null`, hash the bytes (write to `cache.stagingFile()`, `sha256OfFile`), and when it matches, `cache.put(hash, MediaCacheKind.original, staging)` -> `FileData`; otherwise return `BytesData(bytes)`. `LightroomApiException` with 401 -> `UnavailableData(kind: unauthenticated)`; other exceptions -> `UnavailableData(kind: networkError)`. Never throw.
- `resolveThumbnail(item, {required Size target})`: cache `(hash, thumb)` hit -> `FileData`; else download `'thumbnail2x'`; cache-put under `(hash, thumb)` when `contentHash` is known (thumbs are unverified by design); else `BytesData`.
- `extractMetadata` -> `null` (scan sets metadata at row creation).
- `verify(item)`: no account -> `VerifyResult.unauthenticated`; `remoteAssetId == null` -> `VerifyResult.notFound`; else `VerifyResult.available` (cheap optimistic answer; a real remote probe is not worth a rendition download).

- [ ] **Step 1: Write the failing test**

Fake api client (same subclass approach as Task 9) whose `getRendition` returns fixed bytes or throws `LightroomApiException(401/500, ...)`; real `MediaCacheStore` over a temp dir + in-memory `LocalCacheDatabase` (mirror #550's `media_cache_store` tests for construction). Cases: signInRequired when `hasLightroomAccount` false; BytesData on fresh download without contentHash; cache round-trip when contentHash matches downloaded bytes (second `resolve` returns FileData without calling the api — count fake invocations); hash mismatch falls back to BytesData and does NOT poison the cache; 401 -> unauthenticated; 500 -> networkError; thumbnail path caches under thumb kind.

- [ ] **Step 2: Run test to verify it fails** — FAIL.

- [ ] **Step 3: Implement** per the behavior spec above. Compute the byte hash by writing to `cache.stagingFile()` then `sha256OfFile(staging)`; on cache-put the staging file is consumed, on mismatch delete it (mirror `MediaStoreResolver._discardStaging`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/connector_media_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(media): connector resolver fills the serviceConnector registry slot"
```

---

### Task 11: Riverpod wiring

**Files:**
- Create: `lib/features/media/presentation/providers/lightroom_providers.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart` (registry entry)
- Test: `test/features/media/presentation/lightroom_providers_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 3-10, `mediaStoreRuntimeProvider` + `mediaStoreEnqueueProvider` (#550, `lib/features/media_store/presentation/providers/`), `sharedPreferencesProvider` (`lib/main.dart` override — find its declaring file via `grep -rn "sharedPreferencesProvider" lib/`), the database provider used by `mediaRepositoryProvider` (see `lib/features/media/presentation/providers/media_providers.dart` and mirror its construction), `diveRepositoryProvider` (grep for its declaring file).
- Produces (consumed by Tasks 13-16):

```dart
final lightroomAuthManagerProvider = Provider<AdobeImsAuthManager>(...);        // singleton
final connectorAccountsRepositoryProvider = Provider<ConnectorAccountsRepository>(...);
final lightroomAccountProvider = FutureProvider<domain.ConnectorAccount?>(
  (ref) => ref.watch(connectorAccountsRepositoryProvider).getByType('lightroom'),
);
final lightroomApiClientProvider = Provider<LightroomApiClient>(
  (ref) => LightroomApiClient(auth: ref.watch(lightroomAuthManagerProvider)),
);
final lightroomConnectorStateProvider =
    Provider.family<LightroomConnectorState, String>(...); // accountId -> state
final lightroomScanServiceProvider = Provider<LightroomScanService>(
  (ref) => LightroomScanService(
    api: ref.watch(lightroomApiClientProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    diveRepository: ref.watch(diveRepositoryProvider),
    enrichmentService: ref.watch(enrichmentServiceProvider),
    enqueueUpload: ref.watch(mediaStoreEnqueueProvider),
  ),
);
final connectorMediaResolverProvider = Provider<ConnectorMediaResolver>((ref) {
  final account = ref.watch(lightroomAccountProvider).value;
  return ConnectorMediaResolver(
    hasLightroomAccount: account != null,
    apiClient: () async =>
        account == null ? null : ref.read(lightroomApiClientProvider),
    catalogId: () async => account?.accountIdentifier,
    cache: () => ref
        .read(mediaStoreRuntimeProvider.future)
        .then((runtime) => runtime?.cache),
  );
});
final pendingSuggestionsForDiveProvider =
    FutureProvider.family<List<PendingPhotoSuggestion>, String>(
  (ref, diveId) =>
      ref.watch(mediaRepositoryProvider).getPendingSuggestionsForDive(diveId),
);
```

And in `media_resolver_providers.dart`, add to the registry map:

```dart
MediaSourceType.serviceConnector: ref.watch(connectorMediaResolverProvider),
```

- [ ] **Step 1: Write the failing test**

ProviderContainer test: registry now resolves `MediaSourceType.serviceConnector` without `UnsupportedError`; with no account row the resolver's `canResolveOnThisDevice` is false for a connector item; `lightroomAccountProvider` reflects a created account after `ref.invalidate`. Override the database/prefs providers the way existing provider tests do (grep `test/features/media/presentation/` for `ProviderContainer(overrides:` examples and mirror).

- [ ] **Step 2: Run test to verify it fails** — FAIL (providers missing; registry throws).

- [ ] **Step 3: Implement** the providers exactly as above (fix the two grep-located provider names). `lightroomAccountProvider` uses `FutureProvider` so the registry provider rebuilds when the account loads — note in a comment that `connectorMediaResolverProvider` intentionally watches `.value` (null until loaded; the registry rebuild on load flips `hasLightroomAccount`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/presentation/lightroom_providers_test.dart`
Expected: PASS. Also run the existing resolver-registry/media view tests under `test/features/media/` that construct the registry, in case any asserts on the exact registry key set need the new entry.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): riverpod wiring and serviceConnector registry registration"
```

---

### Task 12: Media Store pipeline integration (#550 files)

**Files:**
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`getBackfillCandidateIds`)
- Test: extend `test/features/media_store/media_upload_pipeline_test.dart` and the media repository test covering backfill candidates

**Interfaces:**
- Consumes: `ConnectorMediaResolver` semantics (Task 10) via a fake registered under `serviceConnector` in tests.
- Produces: connector rows flow through the existing queue/pipeline; videos are thumb-only.

- [ ] **Step 1: Write the failing tests**

Pipeline test additions (mirror the file's existing setup — in-memory store, temp cache, stub registry):
1. **Connector photo**: fake `serviceConnector` resolver returns `BytesData(jpegFixtureBytes)`; enqueue a `serviceConnector` photo row -> outcome `uploaded`, row stamped `contentHash` + `remoteUploadedAt` + `remoteThumbUploadedAt`, object present in store.
2. **Connector video is thumb-only**: video row -> outcome `uploaded`, `remoteThumbUploadedAt` set, `remoteUploadedAt` NULL, no original object key in the store (only the thumb key).
3. **Backfill candidates**: connector photo without `remoteUploadedAt` IS a candidate; connector video with thumb stamped is NOT; connector video without thumb IS.

- [ ] **Step 2: Run tests to verify they fail** — FAIL.

- [ ] **Step 3: Implement**

In `MediaUploadPipeline`:

```dart
static const Set<MediaSourceType> _eligibleSources = {
  MediaSourceType.platformGallery,
  MediaSourceType.localFile,
  MediaSourceType.serviceConnector,
};

/// Connector videos never download their original in v1 (spec: match +
/// thumbnail only); the store carries just the thumb, and remoteUploadedAt
/// stays null so a future playback phase can tell the difference.
bool _isThumbOnly(MediaItem item) =>
    item.sourceType == MediaSourceType.serviceConnector &&
    item.mediaType == MediaType.video;
```

In `process(...)`, immediately after the thumb-upload block and before the original-object upload block:

```dart
if (_isThumbOnly(item)) {
  await _queue.markDone(entry.id);
  return UploadOutcome.uploaded;
}
```

Also adjust the early `remoteUploadedAt != null` short-circuit so thumb-only items short-circuit on `remoteThumbUploadedAt != null` instead:

```dart
if (_isThumbOnly(item)
    ? item.remoteThumbUploadedAt != null
    : item.remoteUploadedAt != null) {
  await _queue.markDone(entry.id);
  return UploadOutcome.deduplicated;
}
```

In `MediaRepository.getBackfillCandidateIds()` replace the `where` with:

```dart
..where(
  (_db.media.remoteUploadedAt.isNull() &
          _db.media.fileType.equals('photo') &
          _db.media.sourceType.isIn([
            'platformGallery',
            'localFile',
            'serviceConnector',
          ])) |
      (_db.media.remoteThumbUploadedAt.isNull() &
          _db.media.fileType.equals('video') &
          _db.media.sourceType.equals('serviceConnector')),
)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media_store/` and the media repository test file.
Expected: PASS (including all pre-existing pipeline tests — the eligibility set widened, nothing else changed for gallery/localFile rows).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(media-store): serviceConnector upload eligibility with thumb-only videos"
```

---

### Task 13: Connect dialog, Lightroom settings page, route, tile, l10n

**Files:**
- Create: `lib/features/settings/presentation/widgets/lightroom_connect_dialog.dart`
- Create: `lib/features/settings/presentation/pages/lightroom_settings_page.dart`
- Modify: `lib/core/router/app_router.dart` (route), `lib/features/settings/presentation/pages/settings_page.dart` (tile)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/settings/presentation/lightroom_connect_dialog_test.dart`

**Interfaces:**
- Consumes: `AdobeImsAuthManager` (Task 3), `LightroomApiClient` (Task 4), `ConnectorAccountsRepository` (Task 5), `LightroomConnectorState` (Task 8), providers (Task 11).
- Produces: route `/settings/lightroom` (GoRoute name `lightroom`), settings tile, connected/disconnected page states.

- [ ] **Step 1: Add l10n strings**

To `app_en.arb` (then translate into ar/de/es/fr/he/hu/it/nl/pt/zh — every key in every file; follow the `settings_cloudSync_dropbox_*` block for tone):

```json
"settings_lightroom_title": "Adobe Lightroom",
"settings_lightroom_subtitle": "Auto-link photos and videos to dives",
"settings_lightroom_clientId_label": "Adobe client ID",
"settings_lightroom_clientSecret_label": "Client secret (optional)",
"settings_lightroom_clientId_help": "Create an integration in the Adobe Developer Console with the Lightroom Services API and a credential type that supports PKCE. Set the redirect URI to {redirectUri}.",
"@settings_lightroom_clientId_help": {"placeholders": {"redirectUri": {"type": "String"}}},
"settings_lightroom_connect": "Connect Lightroom",
"settings_lightroom_connect_instructions": "Sign in to Adobe in the browser window, then paste the full address of the page you land on (it contains the authorization code).",
"settings_lightroom_connect_codeLabel": "Redirected URL or code",
"settings_lightroom_connect_emptyCode": "Paste the redirected URL or authorization code",
"settings_lightroom_connect_reopenBrowser": "Reopen browser",
"settings_lightroom_connect_submit": "Connect",
"settings_lightroom_connected": "Connected as {name}",
"@settings_lightroom_connected": {"placeholders": {"name": {"type": "String"}}},
"settings_lightroom_disconnect": "Disconnect",
"settings_lightroom_disconnect_confirmTitle": "Disconnect Lightroom?",
"settings_lightroom_disconnect_confirmBody": "Linked photos stay on your dives and keep displaying from the media store. New photos will no longer be matched.",
"settings_lightroom_albumFilter_title": "Albums to scan",
"settings_lightroom_albumFilter_all": "Entire catalog",
"settings_lightroom_autoPoll_title": "Check for new photos automatically",
"settings_lightroom_scanNow": "Scan now",
"settings_lightroom_scan_running": "Scanning Lightroom...",
"settings_lightroom_scan_summary": "{attached} linked, {suggested} suggested, {skipped} already linked",
"@settings_lightroom_scan_summary": {"placeholders": {"attached": {"type": "int"}, "suggested": {"type": "int"}, "skipped": {"type": "int"}}},
"settings_lightroom_needsReauth": "Reconnect needed",
"media_lightroom_openInLightroom": "Open in Lightroom",
"media_lightroom_suggestions_title": "Suggested from Lightroom",
"media_lightroom_suggestion_accept": "Add to this dive",
"media_lightroom_suggestion_dismiss": "Dismiss"
```

Run `flutter gen-l10n` after editing all 11 files.

- [ ] **Step 2: Write the failing dialog test**

Mirror `dropbox_connect_dialog_test.dart` (locate it for the pump/override pattern). `LightroomConnectDialog({required this.authManager, required this.clientId, this.clientSecret, this.openUri})` — inject a fake `openUri` recording the launched URL, a real `AdobeImsAuthManager` over `MockClient`. Cases: opens browser with an IMS authorize URL on first frame; empty submit shows the emptyCode error; pasting a redirect URL calls `completeAuthorization` and pops `true`; a `CloudStorageException` from token exchange surfaces `displayMessage` in the field's `errorText`.

- [ ] **Step 3: Implement dialog + page + route + tile**

Dialog: copy `dropbox_connect_dialog.dart`'s structure verbatim, swapping provider calls for `authManager.beginAuthorization(clientId: clientId, clientSecret: clientSecret)` / `authManager.completeAuthorization(code)`. Pop `true` on success.

Page (`LightroomSettingsPage`, ConsumerStatefulWidget) — two states via `ref.watch(lightroomAccountProvider)`:
- **Disconnected**: client ID + optional secret `TextField`s, help text (`settings_lightroom_clientId_help` with `AdobeImsAuthManager.redirectUri`), Connect button -> `showDialog(LightroomConnectDialog(...))`; on `true`: `final api = ref.read(lightroomApiClientProvider); final account = await api.getAccount(); final catalogId = await api.getCatalogId();` -> persist catalogId + labels via `authManager.updateAuth(auth.copyWith(catalogId: catalogId, displayName: account.fullName, email: account.email))` -> `connectorAccountsRepository.create(connectorType: 'lightroom', displayName: account.fullName ?? account.email ?? 'Adobe account', accountIdentifier: catalogId, credentialsRef: LightroomAuthStore.storageKey)` -> `ref.invalidate(lightroomAccountProvider)`.
- **Connected**: account name header with a needs-reauth `Chip` (`settings_lightroom_needsReauth`, error color) shown when `LightroomConnectorState.lastError()` is non-null (FutureBuilder; the helper in Task 14 writes/clears it); a status line showing last poll time when set; album filter tile (loads `api.listAlbums`, multi-select checkbox dialog persisted via `LightroomConnectorState.setAlbumIds`; empty selection = entire catalog); auto-poll `SwitchListTile`; "Scan now" button -> `runLightroomScan` helper (Task 14) over all dives (`diveRepository.getAllDives()` via a provider read); Disconnect (confirm dialog -> `authManager.disconnect()`, `state.clear()`, `connectorAccountsRepository.delete(account.id)`, `ref.invalidate(lightroomAccountProvider)`).

Router: inside the `/settings` route's `routes:` list add

```dart
GoRoute(
  path: 'lightroom',
  name: 'lightroom',
  builder: (context, state) => const LightroomSettingsPage(),
),
```

Settings tile (in the same section as the media/cloud tiles in `settings_page.dart`):

```dart
ListTile(
  leading: const Icon(Icons.photo_library_outlined),
  title: Text(context.l10n.settings_lightroom_title),
  subtitle: Text(context.l10n.settings_lightroom_subtitle),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/lightroom'),
),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/settings/presentation/lightroom_connect_dialog_test.dart` and the existing settings-page tests directory.
Expected: PASS. Widget-test traps: `themeAnimationDuration: Duration.zero` in pumps, `tester.runAsync` for post-pump drift awaits, labels may render uppercased.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): connect flow, settings page, route, and localized strings"
```

---

### Task 14: Scan actions on dive and trip surfaces

**Files:**
- Create: `lib/features/media/presentation/helpers/lightroom_scan_helper.dart`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (header action)
- Modify: `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (action near the existing gallery-scan affordance)
- Test: `test/features/media/presentation/lightroom_scan_helper_test.dart`

**Interfaces:**
- Consumes: `lightroomAccountProvider`, `lightroomScanServiceProvider`, `lightroomConnectorStateProvider` (Task 11), `divesForTripProvider` (`lib/features/trips/presentation/providers/trip_providers.dart`), dive detail's current `Dive`.
- Produces:

```dart
Future<void> runLightroomScan(
  BuildContext context,
  WidgetRef ref,
  List<Dive> dives,
) async {
  final account = await ref.read(lightroomAccountProvider.future);
  if (account == null || !context.mounted) return;
  final state = ref.read(lightroomConnectorStateProvider(account.id));
  final service = ref.read(lightroomScanServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settings_lightroom_scan_running)),
  );
  try {
    final summary = await service.scanDives(
      account: account,
      dives: dives,
      state: state,
    );
    await state.setLastError(null);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.settings_lightroom_scan_summary(
            summary.attached,
            summary.suggested,
            summary.skippedExisting,
          ),
        ),
      ),
    );
    for (final dive in dives) {
      ref.invalidate(pendingSuggestionsForDiveProvider(dive.id));
      // Also invalidate the per-dive media provider DiveMediaSection
      // watches (grep dive_media_section.dart for its name, e.g.
      // mediaForDiveProvider(dive.id)) so new photos appear immediately.
    }
  } on Exception catch (e) {
    final message = e is CloudStorageException ? e.displayMessage : e.toString();
    await state.setLastError(message);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
```

If the repo's shared snackbar helper (with its `persist` parameter, trap #406) is the established pattern on these pages, use it with `persist: false` instead of raw `ScaffoldMessenger` — match whichever the surrounding file already uses.

- [ ] **Step 1: Write the failing test** — pump a ProviderScope with fakes (fake scan service via provider override returning a canned summary); a test button invoking `runLightroomScan` shows the summary SnackBar text; with no account, nothing happens and no SnackBar appears.

- [ ] **Step 2: Run test to verify it fails** — FAIL.

- [ ] **Step 3: Implement** the helper, then wire the surfaces:

- `DiveMediaSection`: in the header row (near the existing add/scan actions — the widget already has `onScanPressed` for gallery scanning), add an `IconButton` with `Icons.cloud_sync_outlined`, tooltip `media_lightroom_openInLightroom`-adjacent — use `settings_lightroom_scanNow` — shown only when `ref.watch(lightroomAccountProvider).value != null`, calling `runLightroomScan(context, ref, [dive])`. The section receives `diveId` only; fetch the dive via the same provider the page uses (grep `dive_detail_page.dart` for the dive provider and read it) or thread the `Dive` in from the parent if simpler.
- `trip_overview_tab.dart`: next to the existing "scan gallery" affordance, add an equivalent Lightroom button gated on the same account check, calling `runLightroomScan(context, ref, dives)` with the trip's dives from `divesForTripProvider(trip.id)`.

- [ ] **Step 3b: "Open in Lightroom" action (spec sections 5/8)**

In the photo viewer page (`lib/features/media/presentation/pages/photo_viewer_page.dart` — confirm the path with `grep -rn "class PhotoViewerPage" lib/`), add an app-bar menu item labeled `media_lightroom_openInLightroom`, visible only when the current item has `sourceType == MediaSourceType.serviceConnector`, `remoteAssetId != null`, AND `ref.watch(lightroomAccountProvider).value?.accountIdentifier != null` (the catalog id lives only on the connected device; other devices simply do not show the action). On tap:

```dart
final catalogId = ref.read(lightroomAccountProvider).value!.accountIdentifier!;
launchUrl(
  Uri.parse(LightroomApiClient.assetWebUrl(catalogId, item.remoteAssetId!)),
  mode: LaunchMode.externalApplication,
);
```

This is the whole video story on the connected device: the gallery shows the store thumbnail (Task 12), and this action opens the playable asset on lightroom.adobe.com.

- [ ] **Step 4: Run tests** — helper test PASS; run the existing dive-media-section, photo-viewer, and trip-overview widget tests to confirm no regressions.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): scan actions on dive detail and trip overview"
```

---

### Task 15: Suggestions row with confirm/dismiss

**Files:**
- Create: `lib/features/media/presentation/widgets/lightroom_suggestions_row.dart`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (render the row under the media grid)
- Test: `test/features/media/presentation/lightroom_suggestions_row_test.dart`

**Interfaces:**
- Consumes: `pendingSuggestionsForDiveProvider` (Task 11), `LightroomScanService.confirmSuggestion` (Task 9), `MediaRepository.dismissPendingSuggestion` (Task 6), `LightroomApiClient.getRendition` (thumbnails).
- Produces: `LightroomSuggestionsRow({required String diveId})` — renders nothing when there are no live suggestions.

- [ ] **Step 1: Write the failing test**

Override `pendingSuggestionsForDiveProvider` with two suggestions and the api client provider with a fake whose `getRendition` returns a 1x1 JPEG fixture. Assert: the row shows `media_lightroom_suggestions_title` and two cards; tapping accept on one calls `confirmSuggestion` (fake scan service records it) and the row refreshes; tapping dismiss calls `dismissPendingSuggestion`. With an empty suggestion list the widget renders `SizedBox.shrink`.

- [ ] **Step 2: Run test to verify it fails** — FAIL.

- [ ] **Step 3: Implement**

ConsumerWidget: `ref.watch(pendingSuggestionsForDiveProvider(diveId))`; `AsyncValue.value` handling (avoid the `.when(loading:)` reload-flicker trap — use `valueOrNull`). Horizontal `ListView` of cards: thumbnail via `FutureBuilder<Uint8List>` on `getRendition(catalogId, suggestion.remoteAssetId!, 'thumbnail2x')` with a grey `ColoredBox` placeholder on error/loading; taken-at caption; accept (check icon) -> `confirmSuggestion` then `ref.invalidate(pendingSuggestionsForDiveProvider(diveId))` + invalidate the dive media provider; dismiss (close icon) -> `dismissPendingSuggestion(suggestion.id)` + invalidate. Only render suggestions where `remoteAssetId != null` (gallery suggestions, if ever populated, are not this widget's concern). Mount it in `DiveMediaSection` below the grid.

- [ ] **Step 4: Run tests** — PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): suggestion row with confirm and dismiss on dive detail"
```

---

### Task 16: Auto-poll on startup

**Files:**
- Modify: `lib/features/media/presentation/providers/lightroom_providers.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (`_DiveListPageState.initState`)
- Test: `test/features/media/presentation/lightroom_auto_poll_test.dart`

**Interfaces:**
- Produces:

```dart
/// Fire-and-forget startup poll. Runs at most once per 6 hours per device,
/// only when an account exists and auto-poll is enabled.
final lightroomAutoPollProvider = FutureProvider<void>((ref) async {
  final account = await ref.watch(lightroomAccountProvider.future);
  if (account == null) return;
  final state = ref.read(lightroomConnectorStateProvider(account.id));
  if (!await state.autoPollEnabled()) return;
  final last = await state.lastPollAt();
  if (last != null &&
      DateTime.now().difference(last) < const Duration(hours: 6)) {
    return;
  }
  try {
    await ref
        .read(lightroomScanServiceProvider)
        .poll(account: account, state: state);
    await state.setLastError(null);
  } on Exception catch (e, st) {
    await state.setLastError(
      e is CloudStorageException ? e.displayMessage : e.toString(),
    );
    LoggerService.forClass(LightroomScanService)
        .warning('Auto-poll failed', error: e, stackTrace: st);
  }
});
```

(Match `LoggerService`'s actual method signature — grep an existing `.warning(` call site.)

- [ ] **Step 1: Write the failing test** — ProviderContainer with a fake scan service recording `poll` calls: polls when enabled and stale; skips when disabled; skips when `lastPollAt` is 1 hour ago; skips with no account.

- [ ] **Step 2: Run test to verify it fails** — FAIL.

- [ ] **Step 3: Implement** the provider, then in `_DiveListPageState.initState` add:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) ref.read(lightroomAutoPollProvider);
});
```

(One line of coupling on the home page; errors inside the provider must be caught and logged, never surfaced — wrap the `poll` call in try/catch with `LoggerService`.)

- [ ] **Step 4: Run tests** — auto-poll test PASS; run the dive list page test file to confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lightroom): startup auto-poll gated on interval and toggle"
```

---

### Task 17: Full verification and manual smoke checklist

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze` (whole project, no pipes). Both clean.

- [ ] **Step 2: Run the feature's test files**

```bash
flutter test \
  test/core/services/oauth/ \
  test/core/services/lightroom/ \
  test/features/media/data/ \
  test/features/media/domain/ \
  test/features/media/presentation/ \
  test/features/media_store/ \
  test/features/settings/presentation/lightroom_connect_dialog_test.dart \
  test/core/database/
```

Expected: all PASS.

- [ ] **Step 3: Commit any stragglers, then manual smoke (maintainer, real Adobe account)**

The items only the live API can settle — record outcomes in the PR description:
1. Adobe Developer Console: which credential type accepts the Lightroom Services API and PKCE without a secret (SPA vs Web App). If a secret is mandatory, the optional client-secret field already covers it.
2. Connect flow end-to-end: authorize -> paste redirected URL -> account + catalog fetched.
3. `captured_after`/`captured_before` supported on `/v2/catalogs/{id}/assets` as assumed; if `captured_before` is rejected, drop it from `listAssets` and add client-side early-stop (results are capture-ordered ascending from `captured_after`; stop paging once an asset's captureDate exceeds the span end).
4. Whether `updated_since` exists as a cheaper poll cursor (future optimization; poll works without it).
5. Rendition `2048` exists for a video asset (poster frame) — required by the thumb-only pipeline path.
6. Scan a real trip: confident attach + ambiguous suggestion + enrichment values on the photo detail.
7. Two-device check: second device (no Lightroom connection) displays the linked photo via the store fallback.

## Self-Review Notes

- Spec section 4's "no main-DB migration in the expected case" is superseded by Task 6: suggestion connector columns were confirmed necessary (the table cannot carry connector identity otherwise); the spec was amended accordingly.
- Task 12 deliberately extends #550 code; its pre-existing pipeline tests are the regression gate.
- `confirmSuggestion` attaches with nulls for filename/GPS/duration (not stored on suggestions) — acceptable v1 loss recorded here intentionally.
