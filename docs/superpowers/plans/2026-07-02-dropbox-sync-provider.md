# Dropbox Sync Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Dropbox as a first-class cloud sync backend on all five platforms (iOS, Android, macOS, Windows, Linux), implementing the existing `CloudStorageProvider` interface.

**Architecture:** A new pure-Dart module `lib/core/services/cloud_storage/dropbox/` talks to the Dropbox HTTP API v2 over `package:http`, mirroring the S3 provider's structure (auth store in keychain, injectable HTTP client, provider class composing them). OAuth 2 PKCE with the copy-paste code flow — no redirect URIs, URL schemes, or loopback servers. The sync engine above `CloudStorageProvider` is untouched.

**Tech Stack:** Dart/Flutter, `http` (MockClient for tests), `crypto` (SHA-256 for PKCE), `flutter_secure_storage` via existing `FallbackSecureStorage`, Riverpod, existing l10n pipeline (`flutter gen-l10n`).

**Spec:** `docs/superpowers/specs/2026-07-02-dropbox-sync-design.md` — read it before starting.

## Global Constraints

- Work happens in the existing worktree at `.claude/worktrees/dropbox-sync-provider` (branch `worktree-dropbox-sync-provider`). Do not touch the main checkout.
- TDD every task: failing test first, then implementation.
- `dart format .` must produce no changes before every commit.
- `flutter analyze` must be clean before every commit (run whole-project, never pipe through `tail`).
- No emojis in code, comments, or documentation. No `Co-Authored-By` lines in commits.
- All user-facing strings go through l10n; new keys must be translated into all 10 non-English locales (ar, de, es, fr, he, hu, it, nl, pt, zh) before the feature is done (Task 8).
- Run specific test files, not broad directories (avoids Bash timeouts).
- Errors surface as the existing `CloudStorageException` from `lib/core/services/cloud_storage/cloud_storage_provider.dart`.
- The Dropbox app key is public by design (PKCE, no client secret); it is a plain constant, not a secret.

---

### Task 1: PKCE helper and app key constant

**Files:**
- Create: `lib/core/services/cloud_storage/dropbox/dropbox_app.dart`
- Create: `lib/core/services/cloud_storage/dropbox/dropbox_pkce.dart`
- Test: `test/core/services/cloud_storage/dropbox/dropbox_pkce_test.dart`

**Interfaces:**
- Consumes: nothing (leaf task).
- Produces:
  - `const String dropboxAppKey` (currently empty; filled in manually after Dropbox console registration).
  - `String generateCodeVerifier({Random? random})` — 43-char base64url verifier.
  - `String codeChallengeS256(String verifier)` — base64url(SHA-256(ascii(verifier))), no padding.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/cloud_storage/dropbox/dropbox_pkce_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_pkce.dart';

void main() {
  group('codeChallengeS256', () {
    test('matches the RFC 7636 appendix B vector', () {
      // Vector computed independently (python3 hashlib/base64), not recalled.
      expect(
        codeChallengeS256('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('matches an independently computed vector', () {
      expect(
        codeChallengeS256('a' * 43),
        'ZtNPunH49FD35FWYhT5Tv8I7vRKQJ8uxMaL0_9eHjNA',
      );
    });

    test('produces no base64 padding characters', () {
      expect(codeChallengeS256(generateCodeVerifier()), isNot(contains('=')));
    });
  });

  group('generateCodeVerifier', () {
    test('is 43 chars of the unreserved base64url alphabet', () {
      final verifier = generateCodeVerifier();
      expect(verifier.length, 43);
      expect(RegExp(r'^[A-Za-z0-9\-_]{43}$').hasMatch(verifier), isTrue);
    });

    test('is deterministic for a seeded Random and unique otherwise', () {
      expect(
        generateCodeVerifier(random: Random(7)),
        generateCodeVerifier(random: Random(7)),
      );
      expect(generateCodeVerifier(), isNot(generateCodeVerifier()));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_pkce_test.dart`
Expected: FAIL — cannot resolve import `dropbox_pkce.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/cloud_storage/dropbox/dropbox_app.dart`:

```dart
/// Dropbox app key for Submersion (Dropbox developer console, "App folder"
/// access). Public by design: the PKCE flow has no client secret, so this
/// key is not sensitive and lives in source on purpose.
///
/// Empty until the Dropbox app is registered; the connect flow reports
/// "not configured in this build" until it is filled in. Registration
/// runbook: docs/superpowers/specs/2026-07-02-dropbox-sync-design.md.
const String dropboxAppKey = '';
```

Create `lib/core/services/cloud_storage/dropbox/dropbox_pkce.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 PKCE helpers for the Dropbox OAuth flow.

/// A 43-character code verifier: 32 random bytes, base64url, no padding.
/// [random] is injectable for tests; defaults to a cryptographic source.
String generateCodeVerifier({Random? random}) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// The S256 code challenge for [verifier]:
/// base64url(SHA-256(ascii(verifier))) without padding.
String codeChallengeS256(String verifier) {
  final digest = sha256.convert(ascii.encode(verifier));
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_pkce_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/dropbox/ test/core/services/cloud_storage/dropbox/
git commit -m "feat(sync): add Dropbox PKCE helpers and app key constant"
```

---

### Task 2: DropboxAuthData and DropboxAuthStore

**Files:**
- Create: `lib/core/services/cloud_storage/dropbox/dropbox_auth_store.dart`
- Test: `test/core/services/cloud_storage/dropbox/dropbox_auth_store_test.dart`

**Interfaces:**
- Consumes: `FallbackSecureStorage` from `lib/core/services/secure_storage/fallback_secure_storage.dart`; `InMemoryKeychain` test fake from `test/support/fake_keychain_storage.dart`.
- Produces:
  - `class DropboxAuthData { final String refreshToken; final String? email; final String? displayName; DropboxAuthData({required this.refreshToken, this.email, this.displayName}); Map<String, Object?> toJson(); factory DropboxAuthData.fromJson(Map<String, Object?> json); }`
  - `class DropboxAuthStore { DropboxAuthStore({FlutterSecureStorage? storage}); static const String storageKey = 'sync_dropbox_auth'; Future<DropboxAuthData?> load(); Future<void> save(DropboxAuthData data); Future<void> clear(); }`

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/cloud_storage/dropbox/dropbox_auth_store_test.dart` (template: `test/core/services/cloud_storage/s3/s3_credentials_store_test.dart`):

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late DropboxAuthStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = DropboxAuthStore(storage: storage);
  });

  DropboxAuthData auth() => DropboxAuthData(
    refreshToken: 'rt-123',
    email: 'diver@example.com',
    displayName: 'Diver',
  );

  test('load returns null when nothing stored', () async {
    expect(await store.load(), isNull);
  });

  test('round-trips all fields through the keychain blob', () async {
    await store.save(auth());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.refreshToken, 'rt-123');
    expect(loaded.email, 'diver@example.com');
    expect(loaded.displayName, 'Diver');
  });

  test('optional fields round-trip as null', () async {
    await store.save(DropboxAuthData(refreshToken: 'rt-only'));
    final loaded = await store.load();
    expect(loaded!.refreshToken, 'rt-only');
    expect(loaded.email, isNull);
    expect(loaded.displayName, isNull);
  });

  test('a corrupt blob loads as null but is left in place', () async {
    await storage.write(key: DropboxAuthStore.storageKey, value: 'not json');
    expect(await store.load(), isNull);
    expect(
      await storage.read(key: DropboxAuthStore.storageKey),
      'not json',
    );
  });

  test('a blob of the wrong shape loads as null', () async {
    await storage.write(
      key: DropboxAuthStore.storageKey,
      value: jsonEncode([1, 2, 3]),
    );
    expect(await store.load(), isNull);
  });

  test('a blob missing refreshToken loads as null', () async {
    await storage.write(
      key: DropboxAuthStore.storageKey,
      value: jsonEncode({'email': 'x@example.com'}),
    );
    expect(await store.load(), isNull);
  });

  test('clear removes the blob', () async {
    await store.save(auth());
    await store.clear();
    expect(await store.load(), isNull);
    expect(await storage.read(key: DropboxAuthStore.storageKey), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_auth_store_test.dart`
Expected: FAIL — cannot resolve import `dropbox_auth_store.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/cloud_storage/dropbox/dropbox_auth_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// The persisted Dropbox connection: the long-lived refresh token plus the
/// account labels shown in the settings UI. Access tokens are short-lived
/// and kept in memory only (DropboxAuthManager).
class DropboxAuthData {
  DropboxAuthData({required this.refreshToken, this.email, this.displayName});

  final String refreshToken;
  final String? email;
  final String? displayName;

  Map<String, Object?> toJson() => {
    'refreshToken': refreshToken,
    'email': email,
    'displayName': displayName,
  };

  /// Null-signalling parse is done by [DropboxAuthStore.load]; this factory
  /// assumes [json] already carries a string refreshToken.
  factory DropboxAuthData.fromJson(Map<String, Object?> json) =>
      DropboxAuthData(
        refreshToken: json['refreshToken'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
      );
}

/// Persists the Dropbox connection -- refresh token included -- as a single
/// JSON blob in the platform keychain, mirroring S3CredentialsStore: one
/// blob keeps load/save atomic; nothing touches SharedPreferences or the
/// database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; save() simply overwrites it.
///
/// Keychain access goes through [FallbackSecureStorage], which retries on
/// the legacy keychain when the ad-hoc no-sandbox build has no access group.
class DropboxAuthStore {
  DropboxAuthStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'sync_dropbox_auth';

  /// The stored connection, or null when unset or the stored blob is
  /// corrupt. Keychain errors other than a missing entitlement propagate.
  Future<DropboxAuthData?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      if (decoded['refreshToken'] is! String) return null;
      return DropboxAuthData.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(DropboxAuthData data) =>
      _storage.write(key: storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_auth_store_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/dropbox/dropbox_auth_store.dart test/core/services/cloud_storage/dropbox/dropbox_auth_store_test.dart
git commit -m "feat(sync): add Dropbox auth store (keychain-backed refresh token blob)"
```

---

### Task 3: DropboxAuthManager (authorize URL, code exchange, single-flight refresh, disconnect)

**Files:**
- Create: `lib/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart`
- Test: `test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`

**Interfaces:**
- Consumes: Task 1 (`dropboxAppKey`, `generateCodeVerifier`, `codeChallengeS256`), Task 2 (`DropboxAuthStore`, `DropboxAuthData`), `CloudStorageException`.
- Produces:

```dart
class DropboxAuthManager {
  DropboxAuthManager({
    String appKey = dropboxAppKey,
    DropboxAuthStore? store,
    http.Client? httpClient,
    DateTime Function()? now,
    String Function()? verifierGenerator,
  });
  Uri beginAuthorization();                              // throws if appKey empty
  Future<DropboxAuthData> completeAuthorization(String code);
  Future<String> getAccessToken();                       // cached / single-flight refresh
  void invalidateAccessToken();                          // called by the API client on 401
  Future<DropboxAuthData?> loadAuth();
  Future<void> disconnect();                             // best-effort revoke + clear
}
```

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_pkce.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late DropboxAuthStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = DropboxAuthStore(storage: keychain);
  });

  DropboxAuthManager manager(MockClient mock, {String appKey = 'test-key'}) =>
      DropboxAuthManager(
        appKey: appKey,
        store: store,
        httpClient: mock,
        now: () => DateTime.utc(2026, 7, 2, 12),
        verifierGenerator: () => 'a' * 43,
      );

  http.Response tokenResponse({String access = 'at-1'}) => http.Response(
    jsonEncode({
      'access_token': access,
      'refresh_token': 'rt-1',
      'expires_in': 14400,
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  http.Response accountResponse() => http.Response(
    jsonEncode({
      'email': 'diver@example.com',
      'name': {'display_name': 'Diver'},
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  group('beginAuthorization', () {
    test('builds the PKCE authorize URL without a redirect_uri', () {
      final uri = manager(MockClient((_) async => http.Response('', 500)))
          .beginAuthorization();
      expect(uri.host, 'www.dropbox.com');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['client_id'], 'test-key');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['token_access_type'], 'offline');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(
        uri.queryParameters['code_challenge'],
        codeChallengeS256('a' * 43),
      );
      expect(uri.queryParameters.containsKey('redirect_uri'), isFalse);
    });

    test('throws CloudStorageException when the app key is empty', () {
      final m = manager(
        MockClient((_) async => http.Response('', 500)),
        appKey: '',
      );
      expect(m.beginAuthorization, throwsA(isA<CloudStorageException>()));
    });
  });

  group('completeAuthorization', () {
    test('exchanges code+verifier, fetches account, persists auth', () async {
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/oauth2/token') return tokenResponse();
        if (request.url.path == '/2/users/get_current_account') {
          return accountResponse();
        }
        return http.Response('unexpected', 500);
      });
      final m = manager(mock);
      m.beginAuthorization();
      final auth = await m.completeAuthorization('the-code');

      final tokenReq = requests.first;
      expect(tokenReq.url.host, 'api.dropboxapi.com');
      final body = Uri.splitQueryString(tokenReq.body);
      expect(body['code'], 'the-code');
      expect(body['grant_type'], 'authorization_code');
      expect(body['code_verifier'], 'a' * 43);
      expect(body['client_id'], 'test-key');
      expect(body.containsKey('redirect_uri'), isFalse);

      expect(auth.refreshToken, 'rt-1');
      expect(auth.email, 'diver@example.com');
      expect(auth.displayName, 'Diver');
      expect((await store.load())!.refreshToken, 'rt-1');
    });

    test('throws when called with no authorization in progress', () async {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      await expectLater(
        m.completeAuthorization('code'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('wraps a rejected code as CloudStorageException and does not '
        'persist', () async {
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'invalid_grant'}),
          400,
        ),
      );
      final m = manager(mock);
      m.beginAuthorization();
      await expectLater(
        m.completeAuthorization('bad-code'),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await store.load(), isNull);
    });
  });

  group('getAccessToken', () {
    test('refreshes with the stored refresh token', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return tokenResponse(access: 'at-fresh');
      });
      expect(await manager(mock).getAccessToken(), 'at-fresh');
      final body = Uri.splitQueryString(seen.body);
      expect(body['grant_type'], 'refresh_token');
      expect(body['refresh_token'], 'rt-stored');
      expect(body['client_id'], 'test-key');
    });

    test('caches the access token across calls', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        return tokenResponse();
      });
      final m = manager(mock);
      await m.getAccessToken();
      await m.getAccessToken();
      expect(calls, 1);
    });

    test('concurrent calls share one refresh (single-flight)', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final gate = Completer<void>();
      final mock = MockClient((_) async {
        calls++;
        await gate.future;
        return tokenResponse();
      });
      final m = manager(mock);
      final first = m.getAccessToken();
      final second = m.getAccessToken();
      gate.complete();
      expect(await first, 'at-1');
      expect(await second, 'at-1');
      expect(calls, 1);
    });

    test('invalidateAccessToken forces a new refresh', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        return tokenResponse(access: 'at-$calls');
      });
      final m = manager(mock);
      expect(await m.getAccessToken(), 'at-1');
      m.invalidateAccessToken();
      expect(await m.getAccessToken(), 'at-2');
      expect(calls, 2);
    });

    test('throws CloudStorageException when not connected', () async {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('a revoked refresh token throws but preserves the stored blob',
        () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-revoked'));
      final mock = MockClient(
        (_) async =>
            http.Response(jsonEncode({'error': 'invalid_grant'}), 400),
      );
      await expectLater(
        manager(mock).getAccessToken(),
        throwsA(isA<CloudStorageException>()),
      );
      expect((await store.load())!.refreshToken, 'rt-revoked');
    });

    test('a failed refresh clears the in-flight guard so the next call '
        'retries', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('down', 503);
        return tokenResponse(access: 'at-recovered');
      });
      final m = manager(mock);
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await m.getAccessToken(), 'at-recovered');
    });
  });

  group('disconnect', () {
    test('revokes best-effort and clears the store', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      final paths = <String>[];
      final mock = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/oauth2/token') return tokenResponse();
        return http.Response('', 200);
      });
      await manager(mock).disconnect();
      expect(paths, contains('/2/auth/token/revoke'));
      expect(await store.load(), isNull);
    });

    test('clears the store even when revoke fails', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      final mock = MockClient((_) async => http.Response('down', 503));
      await manager(mock).disconnect();
      expect(await store.load(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`
Expected: FAIL — cannot resolve import `dropbox_auth_manager.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_app.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_pkce.dart';
import 'package:submersion/core/services/logger_service.dart';

/// OAuth 2 PKCE lifecycle for Dropbox: authorize-URL construction, the
/// copy-paste code exchange, in-memory access-token caching with
/// single-flight refresh, and disconnect.
///
/// The refresh token is the only persisted credential (DropboxAuthStore);
/// access tokens (~4 h lifetime) live in memory only.
class DropboxAuthManager {
  DropboxAuthManager({
    this.appKey = dropboxAppKey,
    DropboxAuthStore? store,
    http.Client? httpClient,
    DateTime Function()? now,
    String Function()? verifierGenerator,
  }) : _store = store ?? DropboxAuthStore(),
       _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now,
       _generateVerifier = verifierGenerator ?? generateCodeVerifier;

  static final _log = LoggerService.forClass(DropboxAuthManager);

  static final Uri _authorizeUri =
      Uri.parse('https://www.dropbox.com/oauth2/authorize');
  static final Uri _tokenUri =
      Uri.parse('https://api.dropboxapi.com/oauth2/token');
  static final Uri _revokeUri =
      Uri.parse('https://api.dropboxapi.com/2/auth/token/revoke');
  static final Uri _accountUri =
      Uri.parse('https://api.dropboxapi.com/2/users/get_current_account');

  /// Refresh slightly before Dropbox's expiry so an access token is never
  /// presented within its final minute.
  static const Duration _expiryMargin = Duration(seconds: 60);

  final String appKey;
  final DropboxAuthStore _store;
  final http.Client _http;
  final DateTime Function() _now;
  final String Function() _generateVerifier;

  String? _pendingVerifier;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  Future<String>? _refreshInFlight;

  /// Generates a fresh PKCE verifier and returns the authorize URL to open
  /// in the system browser. No redirect_uri: Dropbox then displays the
  /// authorization code for the user to copy into the app.
  Uri beginAuthorization() {
    if (appKey.isEmpty) {
      throw const CloudStorageException(
        'Dropbox is not configured in this build (missing app key).',
      );
    }
    final verifier = _generateVerifier();
    _pendingVerifier = verifier;
    return _authorizeUri.replace(
      queryParameters: {
        'client_id': appKey,
        'response_type': 'code',
        'code_challenge': codeChallengeS256(verifier),
        'code_challenge_method': 'S256',
        'token_access_type': 'offline',
      },
    );
  }

  /// Exchanges the pasted [code] for tokens, fetches the account labels,
  /// and persists the connection. Requires a preceding [beginAuthorization]
  /// in this session (the PKCE verifier is memory-only by design).
  Future<DropboxAuthData> completeAuthorization(String code) async {
    final verifier = _pendingVerifier;
    if (verifier == null) {
      throw const CloudStorageException(
        'No Dropbox authorization is in progress. Reopen the connect '
        'dialog and try again.',
      );
    }
    final tokens = await _requestToken({
      'code': code,
      'grant_type': 'authorization_code',
      'code_verifier': verifier,
      'client_id': appKey,
    });
    final refreshToken = tokens['refresh_token'];
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const CloudStorageException(
        'Dropbox did not return a refresh token.',
      );
    }

    String? email;
    String? displayName;
    try {
      final account = await _fetchAccount(tokens['access_token'] as String);
      email = account.$1;
      displayName = account.$2;
    } on Exception catch (e) {
      // Account labels are cosmetic; the connection itself succeeded.
      _log.warning('Could not fetch Dropbox account info: $e');
    }

    final auth = DropboxAuthData(
      refreshToken: refreshToken,
      email: email,
      displayName: displayName,
    );
    await _store.save(auth);
    _pendingVerifier = null;
    _cacheAccessToken(tokens);
    _log.info('Dropbox connected');
    return auth;
  }

  /// A currently valid access token, refreshing through the stored refresh
  /// token when needed. Concurrent callers share one refresh request.
  Future<String> getAccessToken() {
    final token = _accessToken;
    final expiry = _accessTokenExpiry;
    if (token != null && expiry != null && _now().isBefore(expiry)) {
      return Future.value(token);
    }
    return _refreshInFlight ??= _refreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Drops the cached access token so the next [getAccessToken] refreshes.
  /// Called by the API client when Dropbox rejects a token mid-flight.
  void invalidateAccessToken() {
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  /// The stored connection, or null when Dropbox is not connected.
  Future<DropboxAuthData?> loadAuth() => _store.load();

  /// Revokes the session best-effort (a network failure must not block
  /// disconnecting) and clears the stored connection.
  Future<void> disconnect() async {
    try {
      final token = await getAccessToken();
      await _http.post(
        _revokeUri,
        headers: {'Authorization': 'Bearer $token'},
      );
    } on Exception catch (e) {
      _log.warning('Dropbox token revoke failed (ignored): $e');
    }
    invalidateAccessToken();
    await _store.clear();
    _log.info('Dropbox disconnected');
  }

  Future<String> _refreshAccessToken() async {
    final auth = await _store.load();
    if (auth == null) {
      throw const CloudStorageException(
        'Dropbox is not connected. Connect Dropbox in the Cloud Sync '
        'settings.',
      );
    }
    final tokens = await _requestToken({
      'grant_type': 'refresh_token',
      'refresh_token': auth.refreshToken,
      'client_id': appKey,
    });
    return _cacheAccessToken(tokens);
  }

  /// POSTs [form] to the token endpoint and returns the decoded JSON.
  /// 4xx means the grant was rejected (bad code, revoked refresh token);
  /// the stored blob is intentionally NOT cleared -- only an explicit
  /// disconnect destroys credentials.
  Future<Map<String, Object?>> _requestToken(Map<String, String> form) async {
    final http.Response response;
    try {
      response = await _http.post(_tokenUri, body: form);
    } on Exception catch (e, st) {
      throw CloudStorageException('Could not reach Dropbox', e, st);
    }
    if (response.statusCode != 200) {
      throw CloudStorageException(
        response.statusCode >= 400 && response.statusCode < 500
            ? 'Dropbox rejected the authorization. Reconnect Dropbox in '
                  'the Cloud Sync settings.'
            : 'Dropbox authorization failed (${response.statusCode})',
        _bodySummary(response),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?> || decoded['access_token'] is! String) {
      throw const CloudStorageException(
        'Unexpected response from Dropbox authorization.',
      );
    }
    return decoded;
  }

  String _cacheAccessToken(Map<String, Object?> tokens) {
    final token = tokens['access_token'] as String;
    final expiresIn = tokens['expires_in'];
    final seconds = expiresIn is int ? expiresIn : 14400;
    _accessToken = token;
    _accessTokenExpiry =
        _now().add(Duration(seconds: seconds)).subtract(_expiryMargin);
    return token;
  }

  /// (email, displayName) from /users/get_current_account.
  Future<(String?, String?)> _fetchAccount(String accessToken) async {
    final response = await _http.post(
      _accountUri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: 'null',
    );
    if (response.statusCode != 200) {
      throw http.ClientException('account fetch ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) return (null, null);
    final name = decoded['name'];
    return (
      decoded['email'] as String?,
      name is Map<String, Object?> ? name['display_name'] as String? : null,
    );
  }

  static String _bodySummary(http.Response response) {
    final body = response.body;
    return body.length <= 200 ? body : body.substring(0, 200);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`
Expected: PASS (14 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart
git commit -m "feat(sync): add Dropbox OAuth PKCE auth manager"
```

---

### Task 4: DropboxApiClient (files endpoints, error mapping, pagination, chunked upload)

**Files:**
- Create: `lib/core/services/cloud_storage/dropbox/dropbox_api_client.dart`
- Test: `test/core/services/cloud_storage/dropbox/dropbox_api_client_test.dart`

**Interfaces:**
- Consumes: `CloudStorageException`. Auth is injected as callbacks, NOT as `DropboxAuthManager`, so this class tests with plain closures.
- Produces:

```dart
class DropboxAccount { final String? email; final String? displayName; }
class DropboxFileMetadata {
  final String pathLower;        // used as the CloudStorageProvider fileId
  final String name;
  final DateTime serverModified;
  final int? size;
}
class DropboxApiClient {
  DropboxApiClient({
    required Future<String> Function() getAccessToken,
    required void Function() onAccessTokenRejected,
    http.Client? httpClient,
    int chunkedUploadThresholdBytes = 150 * 1024 * 1024,
    int uploadChunkBytes = 8 * 1024 * 1024,
    Future<void> Function(Duration)? wait,
  });
  Future<DropboxFileMetadata> upload(String path, Uint8List data);
  Future<Uint8List> download(String path);                    // throws on not_found
  Future<DropboxFileMetadata?> getMetadata(String path);      // null on not_found
  Future<List<DropboxFileMetadata>> listFolder({String path = ''});
  Future<void> delete(String path);                           // not_found is success
  Future<DropboxAccount> getCurrentAccount();
  void close();
}
```

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/cloud_storage/dropbox/dropbox_api_client_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';

Map<String, Object?> fileEntry(
  String name, {
  String tag = 'file',
  int size = 10,
}) => {
  '.tag': tag,
  'name': name,
  'path_lower': '/$name'.toLowerCase(),
  'path_display': '/$name',
  'server_modified': '2026-07-02T12:00:00Z',
  'size': size,
};

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

http.Response apiError(String summary, [int status = 409]) =>
    json({'error_summary': summary, 'error': {}}, status);

void main() {
  var rejectedCount = 0;
  var tokenCounter = 0;

  setUp(() {
    rejectedCount = 0;
    tokenCounter = 0;
  });

  DropboxApiClient client(
    MockClient mock, {
    int chunkedThreshold = 150 * 1024 * 1024,
    int chunkBytes = 8 * 1024 * 1024,
    List<Duration>? waits,
  }) => DropboxApiClient(
    getAccessToken: () async => 'token-${++tokenCounter}',
    onAccessTokenRejected: () => rejectedCount++,
    httpClient: mock,
    chunkedUploadThresholdBytes: chunkedThreshold,
    uploadChunkBytes: chunkBytes,
    wait: (d) async => waits?.add(d),
  );

  group('upload', () {
    test('single-call upload: content endpoint, overwrite mode, bearer '
        'token, api-arg header', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return json(fileEntry('submersion_sync.json'));
      });
      final meta = await client(mock)
          .upload('/submersion_sync.json', Uint8List.fromList([1, 2, 3]));

      expect(seen.url.toString(),
          'https://content.dropboxapi.com/2/files/upload');
      expect(seen.headers['Authorization'], 'Bearer token-1');
      expect(seen.headers['Content-Type'], 'application/octet-stream');
      final arg =
          jsonDecode(seen.headers['Dropbox-API-Arg']!) as Map<String, Object?>;
      expect(arg['path'], '/submersion_sync.json');
      expect(arg['mode'], 'overwrite');
      expect(arg['mute'], true);
      expect(seen.bodyBytes, [1, 2, 3]);
      expect(meta.pathLower, '/submersion_sync.json');
      expect(meta.serverModified, DateTime.utc(2026, 7, 2, 12));
    });

    test('payload above the threshold uses an upload session '
        '(start/append/finish with correct offsets)', () async {
      final calls = <(String, Map<String, Object?>, int)>[];
      final mock = MockClient((request) async {
        final arg = jsonDecode(request.headers['Dropbox-API-Arg']!)
            as Map<String, Object?>;
        calls.add((request.url.path, arg, request.bodyBytes.length));
        if (request.url.path == '/2/files/upload_session/start') {
          return json({'session_id': 'sess-1'});
        }
        if (request.url.path == '/2/files/upload_session/append_v2') {
          return json({});
        }
        return json(fileEntry('big.bin', size: 10));
      });
      final data = Uint8List.fromList(List.filled(10, 7));
      await client(mock, chunkedThreshold: 6, chunkBytes: 4)
          .upload('/big.bin', data);

      expect(calls[0].$1, '/2/files/upload_session/start');
      expect(calls[0].$3, 4);
      expect(calls[1].$1, '/2/files/upload_session/append_v2');
      expect(
        (calls[1].$2['cursor'] as Map<String, Object?>)['offset'],
        4,
      );
      expect(calls[1].$3, 4);
      expect(calls[2].$1, '/2/files/upload_session/finish');
      expect(
        (calls[2].$2['cursor'] as Map<String, Object?>)['offset'],
        8,
      );
      expect(calls[2].$3, 2);
      expect(
        (calls[2].$2['commit'] as Map<String, Object?>)['path'],
        '/big.bin',
      );
    });

    test('insufficient_space maps to a distinct message', () async {
      final mock = MockClient(
        (_) async => apiError('path/insufficient_space/..'),
      );
      await expectLater(
        client(mock).upload('/f', Uint8List(1)),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('out of storage space'),
          ),
        ),
      );
    });
  });

  group('download', () {
    test('returns the body bytes', () async {
      final mock = MockClient(
        (request) async => http.Response.bytes([9, 8, 7], 200),
      );
      expect(await client(mock).download('/f.json'), [9, 8, 7]);
    });

    test('not_found throws CloudStorageException', () async {
      final mock = MockClient((_) async => apiError('path/not_found/..'));
      await expectLater(
        client(mock).download('/gone.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('getMetadata', () {
    test('maps the metadata JSON', () async {
      final mock = MockClient((_) async => json(fileEntry('f.json', size: 5)));
      final meta = await client(mock).getMetadata('/f.json');
      expect(meta!.name, 'f.json');
      expect(meta.size, 5);
    });

    test('not_found returns null', () async {
      final mock = MockClient((_) async => apiError('path/not_found/..'));
      expect(await client(mock).getMetadata('/gone'), isNull);
    });
  });

  group('listFolder', () {
    test('follows has_more cursors to exhaustion and keeps only files',
        () async {
      var page = 0;
      final mock = MockClient((request) async {
        page++;
        if (page == 1) {
          expect(request.url.path, '/2/files/list_folder');
          final body =
              jsonDecode(request.body) as Map<String, Object?>;
          expect(body['path'], '');
          return json({
            'entries': [fileEntry('a.json'), fileEntry('sub', tag: 'folder')],
            'cursor': 'cur-1',
            'has_more': true,
          });
        }
        expect(request.url.path, '/2/files/list_folder/continue');
        expect(
          (jsonDecode(request.body) as Map<String, Object?>)['cursor'],
          'cur-1',
        );
        return json({
          'entries': [fileEntry('b.json')],
          'cursor': 'cur-2',
          'has_more': false,
        });
      });
      final entries = await client(mock).listFolder();
      expect(entries.map((e) => e.name), ['a.json', 'b.json']);
    });
  });

  group('delete', () {
    test('posts to delete_v2', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return json({'metadata': fileEntry('f.json')});
      });
      await client(mock).delete('/f.json');
      expect(seen.url.path, '/2/files/delete_v2');
      expect(
        (jsonDecode(seen.body) as Map<String, Object?>)['path'],
        '/f.json',
      );
    });

    test('not_found is treated as success (idempotent delete)', () async {
      final mock = MockClient(
        (_) async => apiError('path_lookup/not_found/..'),
      );
      await client(mock).delete('/already-gone');
    });
  });

  group('auth retry', () {
    test('a 401 invalidates the token and retries once with a fresh one',
        () async {
      final tokens = <String?>[];
      final mock = MockClient((request) async {
        tokens.add(request.headers['Authorization']);
        if (tokens.length == 1) return http.Response('expired', 401);
        return json(fileEntry('f.json'));
      });
      final meta = await client(mock).getMetadata('/f.json');
      expect(meta, isNotNull);
      expect(rejectedCount, 1);
      expect(tokens, ['Bearer token-1', 'Bearer token-2']);
    });

    test('a second 401 surfaces as an auth CloudStorageException', () async {
      final mock = MockClient((_) async => http.Response('expired', 401));
      await expectLater(
        client(mock).getMetadata('/f.json'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('Reconnect Dropbox'),
          ),
        ),
      );
      expect(rejectedCount, 2);
    });
  });

  group('rate limiting', () {
    test('a 429 waits Retry-After seconds and retries once', () async {
      final waits = <Duration>[];
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('slow down', 429,
              headers: {'retry-after': '3'});
        }
        return json(fileEntry('f.json'));
      });
      final meta = await client(mock, waits: waits).getMetadata('/f.json');
      expect(meta, isNotNull);
      expect(waits, [const Duration(seconds: 3)]);
    });

    test('a second 429 surfaces as CloudStorageException', () async {
      final mock = MockClient(
        (_) async => http.Response('slow down', 429),
      );
      await expectLater(
        client(mock, waits: []).getMetadata('/f.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('getCurrentAccount', () {
    test('parses email and display name', () async {
      final mock = MockClient((_) async => json({
            'email': 'diver@example.com',
            'name': {'display_name': 'Diver'},
          }));
      final account = await client(mock).getCurrentAccount();
      expect(account.email, 'diver@example.com');
      expect(account.displayName, 'Diver');
    });
  });

  group('network failures', () {
    test('a thrown ClientException wraps as CloudStorageException', () async {
      final mock = MockClient(
        (_) async => throw http.ClientException('connection refused'),
      );
      await expectLater(
        client(mock).getMetadata('/f.json'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_api_client_test.dart`
Expected: FAIL — cannot resolve import `dropbox_api_client.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/cloud_storage/dropbox/dropbox_api_client.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// Account labels from /users/get_current_account.
class DropboxAccount {
  const DropboxAccount({this.email, this.displayName});

  final String? email;
  final String? displayName;
}

/// The subset of Dropbox file metadata the sync layer needs.
class DropboxFileMetadata {
  const DropboxFileMetadata({
    required this.pathLower,
    required this.name,
    required this.serverModified,
    this.size,
  });

  /// Dropbox's canonical lower-cased path; used as the provider fileId.
  final String pathLower;
  final String name;
  final DateTime serverModified;
  final int? size;

  factory DropboxFileMetadata.fromJson(Map<String, Object?> json) =>
      DropboxFileMetadata(
        pathLower: json['path_lower'] as String,
        name: json['name'] as String,
        serverModified: DateTime.parse(json['server_modified'] as String),
        size: json['size'] as int?,
      );
}

/// Thin client for the Dropbox HTTP API v2 (RPC + content endpoints).
///
/// Auth is delegated to callbacks so this class stays a pure HTTP mapper:
/// [getAccessToken] supplies a bearer token (refreshing as needed) and
/// [onAccessTokenRejected] is invoked when Dropbox answers 401 so the
/// owner can invalidate its cache; the request is then retried once.
///
/// Error policy (spec section "Data layout, error handling, edge cases"):
/// - 401 twice   -> auth CloudStorageException ("Reconnect Dropbox").
/// - 429         -> wait Retry-After (default 1 s) and retry once.
/// - not_found   -> null/success where the caller expects absence
///                  (getMetadata, delete); download throws.
/// - insufficient_space -> distinct user-facing message.
/// - anything else non-2xx, and transport errors -> wrapped generic.
class DropboxApiClient {
  DropboxApiClient({
    required Future<String> Function() getAccessToken,
    required void Function() onAccessTokenRejected,
    http.Client? httpClient,
    this.chunkedUploadThresholdBytes = 150 * 1024 * 1024,
    this.uploadChunkBytes = 8 * 1024 * 1024,
    Future<void> Function(Duration)? wait,
  }) : _getAccessToken = getAccessToken,
       _onAccessTokenRejected = onAccessTokenRejected,
       _http = httpClient ?? http.Client(),
       _wait = wait ?? ((d) => Future<void>.delayed(d));

  static final Uri _apiBase = Uri.parse('https://api.dropboxapi.com');
  static final Uri _contentBase = Uri.parse('https://content.dropboxapi.com');

  /// Dropbox's /files/upload hard limit is 150 MB; larger payloads must go
  /// through upload sessions. Injectable so tests exercise the session
  /// path with tiny payloads.
  final int chunkedUploadThresholdBytes;

  /// Session chunk size; Dropbox recommends a multiple of 4 MB.
  final int uploadChunkBytes;

  final Future<String> Function() _getAccessToken;
  final void Function() _onAccessTokenRejected;
  final http.Client _http;
  final Future<void> Function(Duration) _wait;

  Future<DropboxFileMetadata> upload(String path, Uint8List data) async {
    if (data.length > chunkedUploadThresholdBytes) {
      return _uploadChunked(path, data);
    }
    final response = await _send(
      () => _contentRequest(
        '/2/files/upload',
        arg: {'path': path, 'mode': 'overwrite', 'mute': true},
        body: data,
      ),
    );
    // _send only returns null under notFoundIsNull, which is not set here.
    return DropboxFileMetadata.fromJson(_decodeMap(response!));
  }

  Future<Uint8List> download(String path) async {
    final response = await _send(
      () => _contentRequest('/2/files/download', arg: {'path': path}),
      notFoundMessage: 'File not found in Dropbox: $path',
    );
    return response!.bodyBytes;
  }

  /// Metadata for [path], or null when it does not exist.
  Future<DropboxFileMetadata?> getMetadata(String path) async {
    final response = await _send(
      () => _rpcRequest('/2/files/get_metadata', {'path': path}),
      notFoundIsNull: true,
    );
    if (response == null) return null;
    return DropboxFileMetadata.fromJson(_decodeMap(response));
  }

  /// All files directly in [path] ('' is the app-folder root), following
  /// pagination cursors to exhaustion. Folders are omitted.
  Future<List<DropboxFileMetadata>> listFolder({String path = ''}) async {
    final entries = <DropboxFileMetadata>[];
    var response = await _send(
      () => _rpcRequest('/2/files/list_folder', {
        'path': path,
        'recursive': false,
      }),
    );
    while (true) {
      final decoded = _decodeMap(response!);
      for (final entry in decoded['entries'] as List<Object?>) {
        final map = entry as Map<String, Object?>;
        if (map['.tag'] == 'file') {
          entries.add(DropboxFileMetadata.fromJson(map));
        }
      }
      if (decoded['has_more'] != true) return entries;
      final cursor = decoded['cursor'] as String;
      response = await _send(
        () => _rpcRequest('/2/files/list_folder/continue', {'cursor': cursor}),
      );
    }
  }

  /// Deletes [path]. A missing file is success: delete is idempotent for
  /// the sync layer (matching S3 semantics).
  Future<void> delete(String path) async {
    await _send(
      () => _rpcRequest('/2/files/delete_v2', {'path': path}),
      notFoundIsNull: true,
    );
  }

  Future<DropboxAccount> getCurrentAccount() async {
    final response = await _send(
      () => _rpcRequest('/2/users/get_current_account', null),
    );
    final decoded = _decodeMap(response!);
    final name = decoded['name'];
    return DropboxAccount(
      email: decoded['email'] as String?,
      displayName:
          name is Map<String, Object?> ? name['display_name'] as String? : null,
    );
  }

  void close() => _http.close();

  Future<DropboxFileMetadata> _uploadChunked(
    String path,
    Uint8List data,
  ) async {
    final first = Uint8List.sublistView(data, 0, uploadChunkBytes);
    final startResponse = await _send(
      () => _contentRequest(
        '/2/files/upload_session/start',
        arg: {'close': false},
        body: first,
      ),
    );
    final sessionId = _decodeMap(startResponse!)['session_id'] as String;

    var offset = first.length;
    // Append full chunks, leaving at least one byte for finish (Dropbox
    // accepts an empty finish body, but a non-empty one avoids a
    // zero-length edge case).
    while (data.length - offset > uploadChunkBytes) {
      final chunk =
          Uint8List.sublistView(data, offset, offset + uploadChunkBytes);
      final sendOffset = offset;
      await _send(
        () => _contentRequest(
          '/2/files/upload_session/append_v2',
          arg: {
            'cursor': {'session_id': sessionId, 'offset': sendOffset},
            'close': false,
          },
          body: chunk,
        ),
      );
      offset += chunk.length;
    }

    final rest = Uint8List.sublistView(data, offset);
    final finishOffset = offset;
    final finishResponse = await _send(
      () => _contentRequest(
        '/2/files/upload_session/finish',
        arg: {
          'cursor': {'session_id': sessionId, 'offset': finishOffset},
          'commit': {'path': path, 'mode': 'overwrite', 'mute': true},
        },
        body: rest,
      ),
    );
    return DropboxFileMetadata.fromJson(_decodeMap(finishResponse!));
  }

  http.Request _rpcRequest(String path, Map<String, Object?>? body) {
    final request = http.Request('POST', _apiBase.replace(path: path))
      ..headers['Content-Type'] = 'application/json'
      ..body = body == null ? 'null' : jsonEncode(body);
    return request;
  }

  http.Request _contentRequest(
    String path, {
    required Map<String, Object?> arg,
    Uint8List? body,
  }) {
    final request = http.Request('POST', _contentBase.replace(path: path))
      ..headers['Dropbox-API-Arg'] = jsonEncode(arg)
      ..headers['Content-Type'] = 'application/octet-stream'
      ..bodyBytes = body ?? Uint8List(0);
    return request;
  }

  /// Sends [build]'s request with a bearer token, applying the 401 and 429
  /// retry policy. Returns null (instead of throwing) for Dropbox
  /// not_found errors when [notFoundIsNull] is set.
  Future<http.Response?> _send(
    http.Request Function() build, {
    bool notFoundIsNull = false,
    String? notFoundMessage,
  }) async {
    var authRetried = false;
    var rateRetried = false;
    while (true) {
      final token = await _getAccessToken();
      final request = build()..headers['Authorization'] = 'Bearer $token';
      final http.Response response;
      try {
        response = await http.Response.fromStream(await _http.send(request));
      } on Exception catch (e, st) {
        throw CloudStorageException('Could not reach Dropbox', e, st);
      }

      if (response.statusCode == 401) {
        _onAccessTokenRejected();
        if (!authRetried) {
          authRetried = true;
          continue;
        }
        throw CloudStorageException(
          'Dropbox authorization expired. Reconnect Dropbox in the Cloud '
          'Sync settings.',
          _bodySummary(response),
        );
      }

      if (response.statusCode == 429) {
        if (!rateRetried) {
          rateRetried = true;
          final seconds =
              int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
          await _wait(Duration(seconds: seconds));
          continue;
        }
        throw CloudStorageException(
          'Dropbox rate limit exceeded. Try again shortly.',
          _bodySummary(response),
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      final summary = _errorSummary(response);
      if (summary.contains('not_found')) {
        if (notFoundIsNull) return null;
        throw CloudStorageException(
          notFoundMessage ?? 'Dropbox file not found',
          summary,
        );
      }
      if (summary.contains('insufficient_space')) {
        throw CloudStorageException(
          'Dropbox is out of storage space. Free up space in your Dropbox '
          'account.',
          summary,
        );
      }
      throw CloudStorageException(
        'Dropbox request failed (${response.statusCode})',
        summary,
      );
    }
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const CloudStorageException('Unexpected response from Dropbox');
    }
    return decoded;
  }

  /// Dropbox errors are JSON with an error_summary; fall back to the raw
  /// (truncated) body for non-JSON responses.
  static String _errorSummary(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?> &&
          decoded['error_summary'] is String) {
        return decoded['error_summary'] as String;
      }
    } on FormatException {
      // fall through
    }
    return _bodySummary(response);
  }

  static String _bodySummary(http.Response response) {
    final body = response.body;
    return body.length <= 200 ? body : body.substring(0, 200);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/dropbox/dropbox_api_client_test.dart`
Expected: PASS (16 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/dropbox/dropbox_api_client.dart test/core/services/cloud_storage/dropbox/dropbox_api_client_test.dart
git commit -m "feat(sync): add Dropbox API v2 client with error mapping and pagination"
```

---

### Task 5: DropboxStorageProvider

**Files:**
- Create: `lib/core/services/cloud_storage/dropbox_storage_provider.dart`
- Test: `test/core/services/cloud_storage/dropbox_storage_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 2-4 (`DropboxAuthManager`, `DropboxAuthStore`, `DropboxAuthData`, `DropboxApiClient`, `DropboxFileMetadata`), `CloudStorageProvider`/`CloudStorageProviderMixin`/`CloudFileInfo`/`UploadResult`/`CloudStorageException`.
- Produces:

```dart
class DropboxStorageProvider with CloudStorageProviderMixin implements CloudStorageProvider {
  DropboxStorageProvider({DropboxAuthManager? authManager, DropboxApiClient? apiClient});
  // UI-facing, on top of the CloudStorageProvider interface:
  Uri beginAuthorization();
  Future<DropboxAuthData> completeAuthorization(String code);
  Future<DropboxAuthData?> loadAuth();
  // providerId == 'dropbox', providerName == 'Dropbox'
}
```

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/cloud_storage/dropbox_storage_provider_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';

import '../../../support/fake_keychain_storage.dart';

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, Object?> fileEntry(String name) => {
  '.tag': 'file',
  'name': name,
  'path_lower': '/${name.toLowerCase()}',
  'path_display': '/$name',
  'server_modified': '2026-07-02T12:00:00Z',
  'size': 3,
};

void main() {
  late InMemoryKeychain keychain;
  late DropboxAuthStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = DropboxAuthStore(storage: keychain);
  });

  Future<void> connect() =>
      store.save(DropboxAuthData(refreshToken: 'rt', email: 'd@example.com'));

  DropboxStorageProvider provider(MockClient mock) {
    final auth = DropboxAuthManager(
      appKey: 'k',
      store: store,
      httpClient: mock,
      now: () => DateTime.utc(2026, 7, 2, 12),
      verifierGenerator: () => 'a' * 43,
    );
    return DropboxStorageProvider(
      authManager: auth,
      apiClient: DropboxApiClient(
        getAccessToken: auth.getAccessToken,
        onAccessTokenRejected: auth.invalidateAccessToken,
        httpClient: mock,
      ),
    );
  }

  /// Routes the token endpoint and delegates everything else to [handler].
  MockClient mockApi(
    Future<http.Response> Function(http.Request) handler,
  ) => MockClient((request) async {
    if (request.url.path == '/oauth2/token') {
      return json({
        'access_token': 'at',
        'refresh_token': 'rt',
        'expires_in': 14400,
      });
    }
    return handler(request);
  });

  test('identity and availability', () async {
    final p = provider(mockApi((_) async => json({})));
    expect(p.providerId, 'dropbox');
    expect(p.providerName, 'Dropbox');
    expect(await p.isAvailable(), isTrue);
  });

  test('isAuthenticated reflects the stored connection', () async {
    final p = provider(mockApi((_) async => json({})));
    expect(await p.isAuthenticated(), isFalse);
    await connect();
    expect(await p.isAuthenticated(), isTrue);
  });

  test('getUserEmail comes from the stored blob, no network', () async {
    await connect();
    final p = provider(
      mockApi((_) async => throw StateError('no API call expected')),
    );
    expect(await p.getUserEmail(), 'd@example.com');
  });

  test('authenticate throws a "not connected" error when disconnected',
      () async {
    final p = provider(mockApi((_) async => json({})));
    await expectLater(
      p.authenticate(),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          contains('not connected'),
        ),
      ),
    );
  });

  test('authenticate probes the account when connected', () async {
    await connect();
    final paths = <String>[];
    final p = provider(mockApi((request) async {
      paths.add(request.url.path);
      return json({'email': 'd@example.com'});
    }));
    await p.authenticate();
    expect(paths, ['/2/users/get_current_account']);
  });

  test('uploadFile roots bare filenames at the app folder and returns the '
      'path as fileId', () async {
    await connect();
    late Map<String, Object?> arg;
    final p = provider(mockApi((request) async {
      arg = jsonDecode(request.headers['Dropbox-API-Arg']!)
          as Map<String, Object?>;
      return json(fileEntry('submersion_sync.json'));
    }));
    final result = await p.uploadFile(
      Uint8List.fromList([1]),
      'submersion_sync.json',
    );
    expect(arg['path'], '/submersion_sync.json');
    expect(result.fileId, '/submersion_sync.json');
    expect(result.uploadTime, DateTime.utc(2026, 7, 2, 12));
  });

  test('uploadFile respects an explicit folderId', () async {
    await connect();
    late Map<String, Object?> arg;
    final p = provider(mockApi((request) async {
      arg = jsonDecode(request.headers['Dropbox-API-Arg']!)
          as Map<String, Object?>;
      return json(fileEntry('c.json'));
    }));
    await p.uploadFile(Uint8List.fromList([1]), 'c.json',
        folderId: '/changesets');
    expect(arg['path'], '/changesets/c.json');
  });

  test('listFiles maps metadata and applies namePattern', () async {
    await connect();
    final p = provider(mockApi((_) async => json({
          'entries': [fileEntry('submersion_sync.json'), fileEntry('other.txt')],
          'cursor': 'c',
          'has_more': false,
        })));
    final files = await p.listFiles(namePattern: 'submersion_sync');
    expect(files, hasLength(1));
    expect(files.single.id, '/submersion_sync.json');
    expect(files.single.name, 'submersion_sync.json');
    expect(files.single.sizeBytes, 3);
  });

  test('getFileInfo returns null for a missing file; fileExists follows it',
      () async {
    await connect();
    final p = provider(mockApi((_) async =>
        json({'error_summary': 'path/not_found/..', 'error': {}}, 409)));
    expect(await p.getFileInfo('/gone.json'), isNull);
    expect(await p.fileExists('/gone.json'), isFalse);
  });

  test('createFolder and getOrCreateSyncFolder are pure path construction',
      () async {
    await connect();
    final p = provider(
      mockApi((_) async => throw StateError('no API call expected')),
    );
    expect(await p.getOrCreateSyncFolder(), '');
    expect(await p.createFolder('changesets'), '/changesets');
    expect(
      await p.createFolder('device-1', parentFolderId: '/changesets'),
      '/changesets/device-1',
    );
  });

  test('signOut clears the stored connection', () async {
    await connect();
    final p = provider(mockApi((_) async => json({})));
    await p.signOut();
    expect(await store.load(), isNull);
  });

  test('mixin conflict detection matches Dropbox conflicted-copy names', () {
    final p = provider(mockApi((_) async => json({})));
    expect(
      p.isConflictCopy('submersion_sync (conflicted copy 2026-07-02).json'),
      isTrue,
    );
    expect(p.isConflictCopy('submersion_sync.json'), isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/dropbox_storage_provider_test.dart`
Expected: FAIL — cannot resolve import `dropbox_storage_provider.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/cloud_storage/dropbox_storage_provider.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Dropbox implementation of [CloudStorageProvider] over the HTTP API v2.
///
/// The Dropbox app uses "App folder" access: everything lives under the
/// app folder (shown to the user as Apps/Submersion/), whose root is the
/// empty path ''. File IDs are Dropbox lower-cased paths, the way the
/// iCloud provider uses relative paths.
///
/// Semantic mappings onto the interface:
/// - authenticate() requires an existing connection (made via
///   [beginAuthorization]/[completeAuthorization] from the settings UI)
///   and live-probes it with a get_current_account call.
/// - createFolder is pure path construction: Dropbox creates missing
///   parent folders implicitly on upload.
/// - isAuthenticated is presence-only (no network) like the S3 provider,
///   and keychain failures PROPAGATE for the same reason: a locked
///   keychain must not read as "not connected".
class DropboxStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  DropboxStorageProvider({
    DropboxAuthManager? authManager,
    DropboxApiClient? apiClient,
  }) : _auth = authManager ?? DropboxAuthManager() {
    _client = apiClient ??
        DropboxApiClient(
          getAccessToken: _auth.getAccessToken,
          onAccessTokenRejected: _auth.invalidateAccessToken,
        );
  }

  static final _log = LoggerService.forClass(DropboxStorageProvider);

  final DropboxAuthManager _auth;
  late final DropboxApiClient _client;

  @override
  String get providerName => 'Dropbox';

  @override
  String get providerId => 'dropbox';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isAuthenticated() async => (await _auth.loadAuth()) != null;

  /// The authorize URL for the settings UI to open in the browser.
  Uri beginAuthorization() => _auth.beginAuthorization();

  /// Completes the copy-paste OAuth flow with the pasted [code].
  Future<DropboxAuthData> completeAuthorization(String code) =>
      _auth.completeAuthorization(code);

  /// The stored connection (account labels for the UI), or null.
  Future<DropboxAuthData?> loadAuth() => _auth.loadAuth();

  @override
  Future<void> authenticate() async {
    if (await _auth.loadAuth() == null) {
      throw const CloudStorageException(
        'Dropbox is not connected. Connect Dropbox in the Cloud Sync '
        'settings.',
      );
    }
    await _client.getCurrentAccount();
    _log.info('Dropbox probe succeeded');
  }

  @override
  Future<void> signOut() => _auth.disconnect();

  @override
  Future<String?> getUserEmail() async {
    final auth = await _auth.loadAuth();
    return auth?.email ?? auth?.displayName;
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final meta = await _client.upload(_join(folderId, filename), data);
    return UploadResult(fileId: meta.pathLower, uploadTime: meta.serverModified);
  }

  @override
  Future<Uint8List> downloadFile(String fileId) => _client.download(fileId);

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final meta = await _client.getMetadata(fileId);
    return meta == null ? null : _toCloudFileInfo(meta);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final entries = await _client.listFolder(path: folderId ?? '');
    return entries
        .map(_toCloudFileInfo)
        .where((f) => namePattern == null || f.name.contains(namePattern))
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) => _client.delete(fileId);

  @override
  Future<bool> fileExists(String fileId) async =>
      (await _client.getMetadata(fileId)) != null;

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => _join(parentFolderId, folderName);

  /// '' is the app-folder root: with App folder access the whole folder is
  /// ours, so no named subfolder is needed (or created).
  @override
  Future<String> getOrCreateSyncFolder() async => '';

  CloudFileInfo _toCloudFileInfo(DropboxFileMetadata meta) => CloudFileInfo(
    id: meta.pathLower,
    name: meta.name,
    modifiedTime: meta.serverModified,
    sizeBytes: meta.size,
  );

  /// Dropbox paths are absolute and '/'-separated; the app-folder root is
  /// '' but children of it still start with '/'.
  String _join(String? folder, String name) =>
      (folder == null || folder.isEmpty) ? '/$name' : '$folder/$name';
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/dropbox_storage_provider_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/dropbox_storage_provider.dart test/core/services/cloud_storage/dropbox_storage_provider_test.dart
git commit -m "feat(sync): add DropboxStorageProvider implementing CloudStorageProvider"
```

---

### Task 6: Register the provider (enum + Riverpod wiring)

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:14`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:151-169` and end of file
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart:673-684` (`_providerDisplayName` exhaustive switch — this task only makes it compile; the tile comes in Task 7)
- Test: `test/features/settings/presentation/providers/dropbox_registration_test.dart`

**Interfaces:**
- Consumes: Task 5 (`DropboxStorageProvider`, `DropboxAuthData`).
- Produces:
  - `CloudProviderType.dropbox` enum value (persisted by `.name` — the string `'dropbox'` — in sync metadata; must never be renamed).
  - `final dropboxStorageProviderInstanceProvider = Provider<DropboxStorageProvider>(...)`
  - `final dropboxAuthDataProvider = FutureProvider<DropboxAuthData?>(...)`
  - `cloudProviderInstanceFor(CloudProviderType.dropbox)` returns the Dropbox singleton.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/presentation/providers/dropbox_registration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  test('CloudProviderType.dropbox persists under the stable name "dropbox"',
      () {
    expect(CloudProviderType.dropbox.name, 'dropbox');
  });

  test('cloudProviderInstanceFor returns the Dropbox singleton', () {
    final a = cloudProviderInstanceFor(CloudProviderType.dropbox);
    final b = cloudProviderInstanceFor(CloudProviderType.dropbox);
    expect(a, isA<DropboxStorageProvider>());
    expect(identical(a, b), isTrue);
    expect(a.providerId, 'dropbox');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/dropbox_registration_test.dart`
Expected: FAIL — `CloudProviderType` has no member `dropbox`.

- [ ] **Step 3: Make the changes**

In `lib/core/data/repositories/sync_repository.dart` line 14:

```dart
enum CloudProviderType { icloud, googledrive, s3, dropbox }
```

In `lib/features/settings/presentation/providers/sync_providers.dart`, add the import, the singleton next to the existing ones (around line 152), and the switch case:

```dart
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
```

```dart
final _dropboxProvider = DropboxStorageProvider();
```

In `cloudProviderInstanceFor`, add to the switch:

```dart
    case CloudProviderType.dropbox:
      return _dropboxProvider;
```

At the end of the file (after `s3ConfigProvider`), add:

```dart
/// Direct access to the Dropbox provider singleton for the connect UI
/// (begin/complete authorization, account info).
final dropboxStorageProviderInstanceProvider = Provider<DropboxStorageProvider>(
  (ref) => _dropboxProvider,
);

/// The stored Dropbox connection, or null when Dropbox is not connected.
/// Invalidate after connecting or disconnecting.
final dropboxAuthDataProvider = FutureProvider<DropboxAuthData?>((ref) async {
  return ref.watch(dropboxStorageProviderInstanceProvider).loadAuth();
});
```

In `lib/features/settings/presentation/pages/cloud_sync_page.dart`, `_providerDisplayName` (line ~676) — the exhaustive switch now fails to compile; add (using a plain literal for now; Task 7 replaces it with the l10n key):

```dart
      case CloudProviderType.dropbox:
        return 'Dropbox';
```

- [ ] **Step 4: Check for other exhaustiveness breaks, run tests**

Run: `flutter analyze`
Expected: clean. If the analyzer reports other non-exhaustive switches on `CloudProviderType`, add a `dropbox` case following each site's existing pattern (as of writing, `cloudProviderInstanceFor` and `_providerDisplayName` are the only two).

Run: `flutter test test/features/settings/presentation/providers/dropbox_registration_test.dart`
Expected: PASS (2 tests).

Run the neighboring suites that exercise the enum:
`flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart test/core/services/sync/sync_initializer_test.dart` (skip any file that does not exist)
Expected: PASS — `getCloudProvider`'s `firstWhere(..., orElse: googledrive)` and the initializer's equivalent are unaffected by a new value.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A lib test
git commit -m "feat(sync): register Dropbox as a CloudProviderType"
```

---

### Task 7: Settings UI — English strings, Dropbox tile, connect dialog

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (new keys + `@` metadata, alphabetical among the `settings_cloudSync_` keys)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (tile after `_buildS3ProviderTile` at line 469; `_providerDisplayName` switches to the l10n key)
- Create: `lib/features/settings/presentation/widgets/dropbox_connect_dialog.dart`
- Test: `test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart`

**Interfaces:**
- Consumes: Task 5 (`DropboxStorageProvider.beginAuthorization/completeAuthorization/signOut/loadAuth`), Task 6 (`dropboxStorageProviderInstanceProvider`, `dropboxAuthDataProvider`, `CloudProviderType.dropbox`).
- Produces: `class DropboxConnectDialog extends StatefulWidget { const DropboxConnectDialog({required this.provider, this.openUri, super.key}); final DropboxStorageProvider provider; final Future<bool> Function(Uri)? openUri; }` — `showDialog<bool>` returns true when connected.

- [ ] **Step 1: Add English l10n strings**

In `lib/l10n/arb/app_en.arb`, insert alphabetically among the `settings_cloudSync_` keys (values section, near line 5844):

```json
  "settings_cloudSync_dropbox_account_title": "Dropbox account",
  "settings_cloudSync_dropbox_connect_codeLabel": "Authorization code",
  "settings_cloudSync_dropbox_connect_emptyCode": "Enter the authorization code shown in your browser",
  "settings_cloudSync_dropbox_connect_failed": "Could not connect to Dropbox: {error}",
  "settings_cloudSync_dropbox_connect_instructions": "Your browser opened a Dropbox authorization page. Approve access, then paste the code Dropbox shows you here.",
  "settings_cloudSync_dropbox_connect_reopenBrowser": "Reopen browser",
  "settings_cloudSync_dropbox_connect_submit": "Connect",
  "settings_cloudSync_dropbox_connect_title": "Connect Dropbox",
  "settings_cloudSync_dropbox_connectedAs": "Connected as {account}",
  "settings_cloudSync_dropbox_disconnect": "Disconnect",
  "settings_cloudSync_provider_dropbox_subtitle": "Sync via Dropbox (Apps/Submersion)",
  "settings_cloudSync_provider_dropbox_title": "Dropbox",
```

And the metadata entries in the `@` section (alphabetical among the `@settings_cloudSync_` entries, near line 6249):

```json
  "@settings_cloudSync_dropbox_connect_failed": {
    "placeholders": {
      "error": {
        "type": "Object"
      }
    }
  },
  "@settings_cloudSync_dropbox_connectedAs": {
    "placeholders": {
      "account": {
        "type": "Object"
      }
    }
  },
```

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart`; new getters compile (other locales fall back to English until Task 8).

- [ ] **Step 2: Write the failing dialog widget tests**

Create `test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  DropboxStorageProvider provider(MockClient mock) {
    final auth = DropboxAuthManager(
      appKey: 'k',
      store: DropboxAuthStore(storage: InMemoryKeychain()),
      httpClient: mock,
      verifierGenerator: () => 'a' * 43,
    );
    return DropboxStorageProvider(
      authManager: auth,
      apiClient: DropboxApiClient(
        getAccessToken: auth.getAccessToken,
        onAccessTokenRejected: auth.invalidateAccessToken,
        httpClient: mock,
      ),
    );
  }

  MockClient happyMock() => MockClient((request) async {
    if (request.url.path == '/oauth2/token') {
      return http.Response(
        '{"access_token":"at","refresh_token":"rt","expires_in":14400}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      '{"email":"d@example.com","name":{"display_name":"Diver"}}',
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  Future<void> pumpDialog(
    WidgetTester tester,
    DropboxStorageProvider p, {
    List<Uri>? opened,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => DropboxConnectDialog(
                  provider: p,
                  openUri: (uri) async {
                    opened?.add(uri);
                    return true;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the authorize URL on launch and again via Reopen '
      'browser', (tester) async {
    final opened = <Uri>[];
    await pumpDialog(tester, provider(happyMock()), opened: opened);
    expect(opened, hasLength(1));
    expect(opened.single.host, 'www.dropbox.com');

    await tester.tap(find.text('Reopen browser'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(2));
    // Same PKCE verifier both times: identical URL.
    expect(opened[1], opened[0]);
  });

  testWidgets('empty code shows validation error and does not close',
      (tester) async {
    await pumpDialog(tester, provider(happyMock()));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the authorization code shown in your browser'),
      findsOneWidget,
    );
    expect(find.text('Connect Dropbox'), findsOneWidget);
  });

  testWidgets('a valid code connects and pops true', (tester) async {
    final p = provider(happyMock());
    await pumpDialog(tester, p);
    await tester.enterText(find.byType(TextField), '  the-code  ');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Dropbox'), findsNothing);
    expect(await p.isAuthenticated(), isTrue);
  });

  testWidgets('a rejected code surfaces the error inline', (tester) async {
    final mock = MockClient(
      (_) async => http.Response('{"error":"invalid_grant"}', 400),
    );
    await pumpDialog(tester, provider(mock));
    await tester.enterText(find.byType(TextField), 'bad-code');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not connect to Dropbox'), findsOneWidget);
    expect(find.text('Connect Dropbox'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart`
Expected: FAIL — cannot resolve import `dropbox_connect_dialog.dart`.

- [ ] **Step 4: Implement the dialog**

Create `lib/features/settings/presentation/widgets/dropbox_connect_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/utils/l10n_extensions.dart';

/// The copy-paste OAuth dialog: opens the Dropbox authorize page in the
/// system browser and exchanges the pasted code. Pops `true` on success.
///
/// [openUri] is injectable for widget tests; production uses url_launcher.
class DropboxConnectDialog extends StatefulWidget {
  const DropboxConnectDialog({
    required this.provider,
    this.openUri,
    super.key,
  });

  final DropboxStorageProvider provider;
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<DropboxConnectDialog> createState() => _DropboxConnectDialogState();
}

class _DropboxConnectDialogState extends State<DropboxConnectDialog> {
  final _codeController = TextEditingController();
  Uri? _authorizeUri;
  String? _errorText;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    // beginAuthorization generates the PKCE verifier; the same URI (and
    // verifier) is reused by "Reopen browser" so the pasted code always
    // matches the pending verifier.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowser());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openBrowser() async {
    try {
      final uri = _authorizeUri ??= widget.provider.beginAuthorization();
      final open = widget.openUri ??
          (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
      await open(uri);
    } on CloudStorageException catch (e) {
      setState(() => _errorText = e.displayMessage);
    }
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(
        () => _errorText = l10n.settings_cloudSync_dropbox_connect_emptyCode,
      );
      return;
    }
    setState(() {
      _connecting = true;
      _errorText = null;
    });
    try {
      await widget.provider.completeAuthorization(code);
      if (mounted) Navigator.of(context).pop(true);
    } on CloudStorageException catch (e) {
      setState(() {
        _connecting = false;
        _errorText =
            l10n.settings_cloudSync_dropbox_connect_failed(e.displayMessage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_cloudSync_dropbox_connect_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_cloudSync_dropbox_connect_instructions),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            enabled: !_connecting,
            decoration: InputDecoration(
              labelText: l10n.settings_cloudSync_dropbox_connect_codeLabel,
              errorText: _errorText,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _connect(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : _openBrowser,
          child: Text(l10n.settings_cloudSync_dropbox_connect_reopenBrowser),
        ),
        TextButton(
          onPressed: _connecting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child: _connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.settings_cloudSync_dropbox_connect_submit),
        ),
      ],
    );
  }
}
```

Note: the l10n extension import above must match the project's actual extension location. Find it with `grep -rn "extension.*l10n" lib/core --include="*.dart"` and copy the import used by `cloud_sync_page.dart` for `context.l10n`.

- [ ] **Step 5: Run the dialog tests to verify they pass**

Run: `flutter test test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Add the tile to CloudSyncPage**

In `lib/features/settings/presentation/pages/cloud_sync_page.dart`:

Add imports (match the file's existing import grouping):

```dart
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
```

In `_buildProviderSection`, after the `_buildS3ProviderTile(context, ref, selectedProvider),` line (469), add:

```dart
        _buildDropboxProviderTile(context, ref, selectedProvider),
```

Add the tile builder and account dialog after `_buildS3ProviderTile` (around line 557):

```dart
  Widget _buildDropboxProviderTile(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType? selectedProvider,
  ) {
    final l10n = context.l10n;
    final auth = ref.watch(dropboxAuthDataProvider).valueOrNull;
    final isSelected = selectedProvider == CloudProviderType.dropbox;
    final isConnected = auth != null;
    final account = auth?.email ?? auth?.displayName ?? '';

    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: const Icon(Icons.cloud_queue),
        title: Text(l10n.settings_cloudSync_provider_dropbox_title),
        subtitle: Text(
          isConnected
              ? l10n.settings_cloudSync_dropbox_connectedAs(account)
              : l10n.settings_cloudSync_provider_dropbox_subtitle,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                semanticLabel: 'Connected',
              ),
            if (isConnected)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.settings_cloudSync_dropbox_account_title,
                onPressed: () => _showDropboxAccountDialog(context, ref),
              ),
          ],
        ),
        onTap: () async {
          if (isConnected) {
            await _selectProvider(context, ref, CloudProviderType.dropbox);
            return;
          }
          final connected = await showDialog<bool>(
            context: context,
            builder: (_) => DropboxConnectDialog(
              provider: ref.read(dropboxStorageProviderInstanceProvider),
            ),
          );
          ref.invalidate(dropboxAuthDataProvider);
          if (connected == true && context.mounted) {
            await _selectProvider(context, ref, CloudProviderType.dropbox);
          }
        },
      ),
    );
  }

  Future<void> _showDropboxAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final auth = ref.read(dropboxAuthDataProvider).valueOrNull;
    final account = auth?.email ?? auth?.displayName ?? '';
    final disconnect = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_cloudSync_dropbox_account_title),
        content: Text(l10n.settings_cloudSync_dropbox_connectedAs(account)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_cloudSync_dropbox_disconnect),
          ),
        ],
      ),
    );
    if (disconnect != true) return;

    final provider = ref.read(dropboxStorageProviderInstanceProvider);
    await provider.signOut();
    ref.invalidate(dropboxAuthDataProvider);
    // If Dropbox was the active backend, clear the selection so the page
    // cannot show Sync Now armed against a disconnected provider.
    if (ref.read(selectedCloudProviderTypeProvider) ==
        CloudProviderType.dropbox) {
      ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
      await ref.read(syncInitializerProvider).saveProvider(null);
      ref.read(syncStateProvider.notifier).refreshState();
    }
  }
```

In `_providerDisplayName`, replace the Task 6 literal:

```dart
      case CloudProviderType.dropbox:
        return l10n.settings_cloudSync_provider_dropbox_title;
```

- [ ] **Step 7: Run the page tests, format, analyze, commit**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart` (if this file exists)
Expected: PASS — existing tile tests are unaffected; if a test asserts the exact tile count/order, update it to include the Dropbox tile.

```bash
dart format .
flutter analyze
git add -A lib test
git commit -m "feat(sync): add Dropbox tile and connect dialog to Cloud Sync settings"
```

---

### Task 8: Localization sweep and final verification

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (the 12 keys from Task 7, translated; `@` metadata lives only in `app_en.arb`)
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

**Interfaces:**
- Consumes: Task 7's 12 English keys.
- Produces: fully localized strings; no `untranslated` warnings for the new keys.

- [ ] **Step 1: Translate the 12 new keys into each of the 10 locales**

Add the same 12 keys to each locale file, alphabetically in the same position as in `app_en.arb`. Translate naturally per locale ("Dropbox" itself stays untranslated; `{error}`/`{account}` placeholders must appear verbatim). Follow each file's existing tone/formality (e.g. German "Sie" vs "du" — check neighboring `settings_cloudSync_` strings and match).

- [ ] **Step 2: Regenerate and verify no missing translations**

Run: `flutter gen-l10n`
Expected: completes without listing the new keys as untranslated (the project tracks untranslated messages; confirm none of the 12 keys appear).

- [ ] **Step 3: Run the full Dropbox test suite and the settings suites**

Run: `flutter test test/core/services/cloud_storage/dropbox/ test/core/services/cloud_storage/dropbox_storage_provider_test.dart test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart test/features/settings/presentation/providers/dropbox_registration_test.dart`
Expected: PASS, all tests.

- [ ] **Step 4: Whole-project format and analyze**

```bash
dart format .
flutter analyze
```

Expected: no formatting changes, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n
git commit -m "feat(sync): localize Dropbox sync strings into all locales"
```

---

## Post-plan manual work (not executable by an agent)

1. Register the Dropbox app per the runbook in the spec (App folder scope, minimal scopes) and paste the app key into `lib/core/services/cloud_storage/dropbox/dropbox_app.dart`.
2. Manual end-to-end verification: connect + two-device sync (macOS + iPhone) against the development-mode Dropbox app.
3. Before public release: apply for Dropbox production status.

## Verification checklist (final)

- [ ] All Dropbox unit/widget suites pass.
- [ ] `flutter analyze` clean, `dart format .` produces no changes.
- [ ] All 12 l10n keys present in all 11 arb files.
- [ ] `CloudProviderType.dropbox.name == 'dropbox'` (persisted string, never rename).
- [ ] Existing sync suites still pass: run `flutter test test/core/services/sync/` file-by-file if time allows, or at minimum the suites touched by the enum change (Task 6 Step 4).
