# Google Drive Sync Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Google Drive a complete, fully functional cloud-sync backend on iOS, macOS, Android, Windows, and Linux.

**Architecture:** The existing `GoogleDriveStorageProvider` keeps all its Drive v3 REST logic (appDataFolder). Authentication is extracted behind a `GoogleDriveAuthenticator` seam with two implementations: `GoogleSignInAuthenticator` (iOS/macOS/Android, `google_sign_in` v7) and `DesktopOAuthAuthenticator` (Windows/Linux, loopback OAuth via `googleapis_auth` with refresh-token persistence in `FallbackSecureStorage`). The settings tile is restored and gated by real availability.

**Tech Stack:** Flutter, Riverpod, `google_sign_in` ^7.2.0, `googleapis` ^16.0.0, `googleapis_auth` ^2.0.0, `extension_google_sign_in_as_googleapis_auth` ^3.0.0, `url_launcher` ^6.3.1, `flutter_secure_storage` ^10.0.0, `package:http/testing.dart` MockClient for tests.

**Spec:** `docs/superpowers/specs/2026-07-02-google-drive-sync-backend-design.md`

## Global Constraints

- All work happens in the `google-drive-sync` worktree on branch `worktree-google-drive-sync`. Never touch the main checkout.
- Run `dart format .` (whole repo) before every commit; CI checks the whole project.
- Run `flutter analyze` (whole project, never piped to `tail`) before every commit.
- Run tests as specific files (`flutter test test/path/file_test.dart`), never broad directories (Bash timeout risk).
- No emojis in code, comments, or documentation.
- Commits: conventional-commit style, no `Co-Authored-By` lines.
- New user-facing strings go in `lib/l10n/arb/app_en.arb` AND all 10 other locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then regenerate with `flutter gen-l10n`.
- The desktop OAuth client ID/secret are intentionally committed constants (RFC 8252 section 8.5 — installed-app secrets are non-confidential). This is an approved, documented exception to the "no hardcoded secrets" rule; keep the explanatory comment.
- Existing behavior of the Drive REST methods (query strings, appDataFolder spaces, idempotent name-based upload) must not change.

---

### Task 1: Client config, authenticator interface, and GoogleSignInAuthenticator

No unit tests in this task: `GoogleSignInAuthenticator` is a thin wrapper over the
`GoogleSignIn.instance` platform channel (untestable on the host), the interface is
abstract, and the config is constants. The verification gate is `flutter analyze`.
The moved sign-in logic must be byte-for-byte the same behavior as the current
provider code (`google_drive_storage_provider.dart:43-143`).

**Files:**
- Create: `lib/core/services/cloud_storage/google_drive/google_drive_client_config.dart`
- Create: `lib/core/services/cloud_storage/google_drive/google_drive_authenticator.dart`
- Create: `lib/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces (later tasks depend on these exact names):
  - `GoogleDriveClientConfig.desktopClientId/desktopClientSecret/androidServerClientId: String` (static const), `GoogleDriveClientConfig.hasDesktopClient: bool` (static getter)
  - `abstract class GoogleDriveAuthenticator { Future<void> authenticate(); Future<bool> attemptSilentAuth(); http.Client? get authClient; Future<String?> get userEmail; Future<void> signOut(); Future<void> handleAuthFailure(); }`
  - `class GoogleSignInAuthenticator implements GoogleDriveAuthenticator` with a default constructor.

- [ ] **Step 1: Write `google_drive_client_config.dart`**

```dart
/// OAuth client configuration for Google Drive sync.
///
/// The desktop client ID and secret are committed to source intentionally:
/// Google classifies installed-app client secrets as non-confidential
/// (RFC 8252 section 8.5) -- they ship inside every desktop binary and can
/// not protect anything. Committing them matches standard practice for
/// open-source desktop applications (rclone, the Google Cloud SDK).
///
/// All clients must belong to the same Google Cloud project so every
/// platform shares the same Drive appDataFolder (it is scoped per project,
/// per user); that is what makes cross-device sync work.
class GoogleDriveClientConfig {
  /// OAuth 2.0 "Desktop app" client used by the Windows/Linux loopback
  /// flow. Empty until the client is created in the Google Cloud console;
  /// an empty value disables Google Drive on desktop instead of crashing.
  static const String desktopClientId = '';
  static const String desktopClientSecret = '';

  /// "Web application" client ID passed as serverClientId to
  /// google_sign_in on Android. Empty means initialize() is called without
  /// a serverClientId (sufficient for iOS/macOS, which read GIDClientID
  /// from Info.plist).
  static const String androidServerClientId = '';

  /// True when the Desktop-app client is configured in this build.
  static bool get hasDesktopClient =>
      desktopClientId.isNotEmpty && desktopClientSecret.isNotEmpty;
}
```

- [ ] **Step 2: Write `google_drive_authenticator.dart`**

```dart
import 'package:http/http.dart' as http;

/// Authentication seam for GoogleDriveStorageProvider.
///
/// Two implementations exist: GoogleSignInAuthenticator (iOS/macOS/Android,
/// native google_sign_in flow) and DesktopOAuthAuthenticator (Windows/Linux,
/// loopback OAuth). The boundary is deliberately [http.Client] -- both auth
/// worlds produce an authorized client, and the provider builds its own
/// DriveApi from it, so neither leaks into the Drive REST code.
abstract class GoogleDriveAuthenticator {
  /// Interactive sign-in. May show UI (account sheet or system browser).
  /// Throws CloudStorageException on failure or user cancellation.
  Future<void> authenticate();

  /// Non-interactive re-auth from cached state (google_sign_in lightweight
  /// auth, or a stored refresh token). Never shows UI. Returns false when
  /// re-auth is not possible; must not throw.
  ///
  /// Implementations must not touch secure storage before the user has
  /// opted in by authenticating once (no keychain prompt before opt-in).
  Future<bool> attemptSilentAuth();

  /// The authorized HTTP client, or null when not authenticated.
  http.Client? get authClient;

  /// Signed-in account email, or null when unknown.
  Future<String?> get userEmail;

  /// Sign out and clear stored credentials.
  Future<void> signOut();

  /// Called after an API 401: drop the (stale or revoked) client state so
  /// the next attemptSilentAuth() rebuilds from scratch.
  Future<void> handleAuthFailure();
}
```

- [ ] **Step 3: Write `google_sign_in_authenticator.dart`**

This is the sign-in code currently in `google_drive_storage_provider.dart:43-143`,
moved verbatim apart from: (a) the class wrapper, (b) the Android
`serverClientId` in `_ensureInitialized`, (c) `handleAuthFailure`.
Do not delete the old code from the provider yet — that happens in Task 4.

```dart
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis_auth;
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/logger_service.dart';

/// google_sign_in-backed authenticator for iOS, macOS, and Android.
///
/// Token persistence across launches is handled by google_sign_in's own
/// cache via attemptLightweightAuthentication(); nothing is stored by the
/// app. Silent sign-in is deferred until the user has opted in once
/// (_allowSilentAuth) because it touches the platform keychain.
class GoogleSignInAuthenticator implements GoogleDriveAuthenticator {
  static final _log = LoggerService.forClass(GoogleSignInAuthenticator);

  static const _scopes = [drive.DriveApi.driveAppdataScope];

  // Use the shared instance; configuration is provided per-call via scope
  // hints.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;
  bool _allowSilentAuth = false;
  gapis_auth.AuthClient? _authClient;
  GoogleSignInAccount? _currentUser;

  @override
  http.Client? get authClient => _authClient;

  @override
  Future<String?> get userEmail async => _currentUser?.email;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final serverClientId =
        Platform.isAndroid &&
            GoogleDriveClientConfig.androidServerClientId.isNotEmpty
        ? GoogleDriveClientConfig.androidServerClientId
        : null;
    await _googleSignIn.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  @override
  Future<bool> attemptSilentAuth() async {
    try {
      if (_authClient != null) return true;

      // Defer any silent sign-in (which triggers Keychain access) until the
      // user has explicitly opted in by signing in once.
      if (!_allowSilentAuth) return false;

      await _ensureInitialized();
      final futureAccount = _googleSignIn.attemptLightweightAuthentication();
      if (futureAccount == null) return false;

      final account = await futureAccount;
      if (account == null) return false;

      final authorization = await account.authorizationClient
          .authorizationForScopes(_scopes);
      if (authorization == null) return false;

      _installClient(account, authorization);
      return true;
    } catch (e) {
      _log.warning('Silent sign-in failed: $e');
      return false;
    }
  }

  @override
  Future<void> authenticate() async {
    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate(scopeHint: _scopes);
      final authorization = await account.authorizationClient.authorizeScopes(
        _scopes,
      );

      _installClient(account, authorization);
      _allowSilentAuth = true;
      _log.info('Authenticated with Google Drive as ${account.email}');
    } on GoogleSignInException catch (e, stackTrace) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _log.info('Google Sign-In was cancelled by the user');
        throw CloudStorageException(
          'Google Sign-In was cancelled',
          e,
          stackTrace,
        );
      }
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException(
        'Google Sign-In failed: ${e.description ?? e.code.name}',
        e,
        stackTrace,
      );
    } catch (e, stackTrace) {
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException('Google Sign-In failed: $e', e, stackTrace);
    }
  }

  void _installClient(
    GoogleSignInAccount account,
    GoogleSignInClientAuthorization authorization,
  ) {
    _authClient?.close();
    _authClient = authorization.authClient(scopes: _scopes);
    _currentUser = account;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    // Close the auth client if it exists; close is synchronous.
    _authClient?.close();
    _authClient = null;
    _currentUser = null;
    _allowSilentAuth = false;
    _log.info('Signed out from Google Drive');
  }

  @override
  Future<void> handleAuthFailure() async {
    // Drop the stale client; keep _allowSilentAuth so the next
    // attemptSilentAuth() can rebuild authorization without UI.
    _authClient?.close();
    _authClient = null;
  }
}
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!` (the new files compile; nothing references them yet)

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/cloud_storage/google_drive/
git commit -m "feat(sync): add Google Drive authenticator seam and google_sign_in implementation"
```

---

### Task 2: GoogleDriveTokenStore (TDD)

Mirror of `S3CredentialsStore` + its test, storing `googleapis_auth`
`AccessCredentials` JSON. Template: `lib/core/services/cloud_storage/s3/s3_credentials_store.dart`
and `test/core/services/cloud_storage/s3/s3_credentials_store_test.dart` (uses
`InMemoryKeychain` from `test/support/fake_keychain_storage.dart`).

**Files:**
- Create: `lib/core/services/cloud_storage/google_drive/google_drive_token_store.dart`
- Test: `test/core/services/cloud_storage/google_drive/google_drive_token_store_test.dart`

**Interfaces:**
- Consumes: `FallbackSecureStorage` (`lib/core/services/secure_storage/fallback_secure_storage.dart`), `AccessCredentials.toJson()/fromJson()` from `googleapis_auth`.
- Produces: `class GoogleDriveTokenStore { GoogleDriveTokenStore({FlutterSecureStorage? storage}); static const String storageKey = 'sync_gdrive_credentials'; Future<AccessCredentials?> load(); Future<void> save(AccessCredentials credentials); Future<void> clear(); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late GoogleDriveTokenStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = GoogleDriveTokenStore(storage: storage);
  });

  gauth.AccessCredentials creds() => gauth.AccessCredentials(
    gauth.AccessToken(
      'Bearer',
      'at-1',
      DateTime.utc(2026, 7, 2, 12),
    ),
    'rt-1',
    ['https://www.googleapis.com/auth/drive.appdata'],
    idToken: 'id-1',
  );

  test('load returns null when nothing is stored', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the credentials', () async {
    await store.save(creds());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.accessToken.data, 'at-1');
    expect(loaded.refreshToken, 'rt-1');
    expect(loaded.idToken, 'id-1');
    expect(loaded.scopes, ['https://www.googleapis.com/auth/drive.appdata']);
    expect(storage.values.keys, [GoogleDriveTokenStore.storageKey]);
  });

  test('clear removes the blob', () async {
    await store.save(creds());
    await store.clear();
    expect(await store.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('corrupted JSON loads as null instead of throwing', () async {
    storage.values[GoogleDriveTokenStore.storageKey] = 'not-json{';
    expect(await store.load(), isNull);
    // The corrupt blob is preserved, not deleted (save() overwrites it).
    expect(storage.values, isNotEmpty);
  });

  test('valid JSON that is not an object loads as null', () async {
    storage.values[GoogleDriveTokenStore.storageKey] = '[]';
    expect(await store.load(), isNull);
  });

  test('an object with wrong-typed fields loads as null', () async {
    storage.values[GoogleDriveTokenStore.storageKey] = jsonEncode({
      'accessToken': 42,
    });
    expect(await store.load(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/cloud_storage/google_drive/google_drive_token_store_test.dart`
Expected: FAIL — compilation error, `google_drive_token_store.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists the desktop Google Drive OAuth credentials (access token,
/// refresh token, expiry, scopes) as a single JSON blob in the platform
/// keychain. One blob keeps load/save atomic; nothing about the Google
/// Drive setup ever touches SharedPreferences or the database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; save() simply overwrites it.
///
/// Keychain access goes through [FallbackSecureStorage], which retries on
/// the legacy keychain when the ad-hoc no-sandbox build has no access
/// group. Only the desktop authenticator uses this store; the mobile path
/// relies on google_sign_in's own token cache.
class GoogleDriveTokenStore {
  GoogleDriveTokenStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'sync_gdrive_credentials';

  /// The stored credentials, or null when unset or the stored blob is
  /// corrupt. Keychain errors other than a missing entitlement propagate.
  Future<gauth.AccessCredentials?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return gauth.AccessCredentials.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      // AccessToken.fromJson rejects e.g. a non-UTC expiry.
      return null;
    }
  }

  Future<void> save(gauth.AccessCredentials credentials) =>
      _storage.write(key: storageKey, value: jsonEncode(credentials.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/cloud_storage/google_drive/google_drive_token_store_test.dart`
Expected: All 6 tests PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/google_drive/google_drive_token_store.dart test/core/services/cloud_storage/google_drive/
git commit -m "feat(sync): add keychain-backed Google Drive token store"
```

---

### Task 3: DesktopOAuthAuthenticator (TDD)

Loopback OAuth for Windows/Linux. Every external effect is injectable so the
whole class is host-testable: the consent flow, the auto-refreshing-client
builder, the base HTTP client factory, and the browser launcher.

**Files:**
- Create: `lib/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart`
- Test: `test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart`

**Interfaces:**
- Consumes: `GoogleDriveAuthenticator` (Task 1), `GoogleDriveClientConfig` (Task 1), `GoogleDriveTokenStore` (Task 2), `googleapis_auth/auth_io.dart` (`obtainAccessCredentialsViaUserConsent`, `autoRefreshingClient`, `ClientId`, `AccessCredentials`, `AutoRefreshingAuthClient`), `url_launcher_string`.
- Produces: `class DesktopOAuthAuthenticator implements GoogleDriveAuthenticator` with constructor `DesktopOAuthAuthenticator({GoogleDriveTokenStore? tokenStore, ObtainConsentCredentials? obtainConsent, BuildRefreshingClient? buildClient, http.Client Function()? baseClientFactory, Future<void> Function(String url)? launchBrowser})`, plus `static const List<String> scopes`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';

class _MemoryTokenStore implements GoogleDriveTokenStore {
  gauth.AccessCredentials? stored;
  int saves = 0;

  @override
  Future<gauth.AccessCredentials?> load() async => stored;

  @override
  Future<void> save(gauth.AccessCredentials credentials) async {
    stored = credentials;
    saves++;
  }

  @override
  Future<void> clear() async => stored = null;
}

/// The authenticator only uses credentialUpdates, close(), and passes the
/// client through as an http.Client; nothing sends real requests in tests.
class _FakeRefreshingClient extends Fake
    implements gauth.AutoRefreshingAuthClient {
  _FakeRefreshingClient(this.credentials);

  @override
  final gauth.AccessCredentials credentials;

  final StreamController<gauth.AccessCredentials> updates =
      StreamController<gauth.AccessCredentials>.broadcast();

  bool closed = false;

  @override
  Stream<gauth.AccessCredentials> get credentialUpdates => updates.stream;

  @override
  void close() => closed = true;
}

String idTokenWithEmail(String email) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'email': email})));
  return 'header.$payload.signature';
}

gauth.AccessCredentials creds({String? refreshToken, String? idToken}) =>
    gauth.AccessCredentials(
      gauth.AccessToken('Bearer', 'at-1', DateTime.utc(2026, 7, 2, 12)),
      refreshToken,
      DesktopOAuthAuthenticator.scopes,
      idToken: idToken,
    );

void main() {
  late _MemoryTokenStore store;
  late List<http.Request> revokeRequests;

  MockClient baseClient() => MockClient((request) async {
    revokeRequests.add(request);
    return http.Response('{}', 200);
  });

  setUp(() {
    store = _MemoryTokenStore();
    revokeRequests = [];
  });

  DesktopOAuthAuthenticator authenticator({
    gauth.AccessCredentials? consentResult,
    List<_FakeRefreshingClient>? builtClients,
  }) => DesktopOAuthAuthenticator(
    tokenStore: store,
    obtainConsent: (clientId, scopes, client, prompt) async {
      if (consentResult == null) {
        throw Exception('consent should not run in this test');
      }
      prompt('https://accounts.google.com/o/oauth2/auth?fake');
      return consentResult;
    },
    buildClient: (clientId, credentials, base) {
      final fake = _FakeRefreshingClient(credentials);
      builtClients?.add(fake);
      return fake;
    },
    baseClientFactory: baseClient,
    launchBrowser: (url) async {},
  );

  test('attemptSilentAuth returns false with no stored credentials', () async {
    final auth = authenticator();
    expect(await auth.attemptSilentAuth(), isFalse);
    expect(auth.authClient, isNull);
  });

  test('attemptSilentAuth returns false without a refresh token', () async {
    store.stored = creds(refreshToken: null);
    final auth = authenticator();
    expect(await auth.attemptSilentAuth(), isFalse);
  });

  test('attemptSilentAuth installs a client from stored credentials', () async {
    store.stored = creds(
      refreshToken: 'rt-1',
      idToken: idTokenWithEmail('diver@example.com'),
    );
    final built = <_FakeRefreshingClient>[];
    final auth = authenticator(builtClients: built);

    expect(await auth.attemptSilentAuth(), isTrue);
    expect(auth.authClient, isNotNull);
    expect(built, hasLength(1));
    expect(await auth.userEmail, 'diver@example.com');
  });

  test('authenticate stores credentials and installs a client', () async {
    final auth = authenticator(
      consentResult: creds(
        refreshToken: 'rt-9',
        idToken: idTokenWithEmail('new@example.com'),
      ),
    );

    await auth.authenticate();

    expect(store.stored?.refreshToken, 'rt-9');
    expect(auth.authClient, isNotNull);
    expect(await auth.userEmail, 'new@example.com');
  });

  test('a credential update from the refreshing client is persisted', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final built = <_FakeRefreshingClient>[];
    final auth = authenticator(builtClients: built);
    await auth.attemptSilentAuth();

    built.single.updates.add(creds(refreshToken: 'rt-2'));
    await Future<void>.delayed(Duration.zero);

    expect(store.stored?.refreshToken, 'rt-2');
    expect(store.saves, greaterThanOrEqualTo(1));
  });

  test('consent failure surfaces as CloudStorageException', () async {
    final auth = DesktopOAuthAuthenticator(
      tokenStore: store,
      obtainConsent: (clientId, scopes, client, prompt) async =>
          throw Exception('user closed browser'),
      buildClient: (clientId, credentials, base) =>
          _FakeRefreshingClient(credentials),
      baseClientFactory: baseClient,
      launchBrowser: (url) async {},
    );

    expect(auth.authenticate(), throwsA(isA<CloudStorageException>()));
  });

  test('signOut revokes the token and clears the store', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final auth = authenticator();
    await auth.attemptSilentAuth();

    await auth.signOut();

    expect(store.stored, isNull);
    expect(auth.authClient, isNull);
    expect(revokeRequests, hasLength(1));
    expect(revokeRequests.single.url.host, 'oauth2.googleapis.com');
    expect(revokeRequests.single.url.path, '/revoke');
  });

  test('signOut still clears local state when revocation throws', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final auth = DesktopOAuthAuthenticator(
      tokenStore: store,
      obtainConsent: (clientId, scopes, client, prompt) async =>
          throw Exception('unused'),
      buildClient: (clientId, credentials, base) =>
          _FakeRefreshingClient(credentials),
      baseClientFactory: () =>
          MockClient((request) async => throw Exception('offline')),
      launchBrowser: (url) async {},
    );
    await auth.attemptSilentAuth();

    await auth.signOut();

    expect(store.stored, isNull);
    expect(auth.authClient, isNull);
  });

  test('handleAuthFailure clears the client and stored credentials', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final auth = authenticator();
    await auth.attemptSilentAuth();

    await auth.handleAuthFailure();

    expect(auth.authClient, isNull);
    expect(store.stored, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart`
Expected: FAIL — compilation error, `desktop_oauth_authenticator.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Runs the user-consent step of the loopback flow and returns credentials.
typedef ObtainConsentCredentials =
    Future<gauth.AccessCredentials> Function(
      gauth.ClientId clientId,
      List<String> scopes,
      http.Client client,
      void Function(String url) prompt,
    );

/// Builds an auto-refreshing client from stored credentials.
typedef BuildRefreshingClient =
    gauth.AutoRefreshingAuthClient Function(
      gauth.ClientId clientId,
      gauth.AccessCredentials credentials,
      http.Client baseClient,
    );

/// Loopback-OAuth authenticator for Windows and Linux (RFC 8252 section
/// 7.3): binds an ephemeral 127.0.0.1 port, opens the system browser to
/// Google's consent page, and receives the auth code on the local
/// redirect. Credentials persist in [GoogleDriveTokenStore]; cold-launch
/// re-auth is silent via the stored refresh token.
class DesktopOAuthAuthenticator implements GoogleDriveAuthenticator {
  DesktopOAuthAuthenticator({
    GoogleDriveTokenStore? tokenStore,
    ObtainConsentCredentials? obtainConsent,
    BuildRefreshingClient? buildClient,
    http.Client Function()? baseClientFactory,
    Future<void> Function(String url)? launchBrowser,
  }) : _tokenStore = tokenStore ?? GoogleDriveTokenStore(),
       _obtainConsent =
           obtainConsent ?? gauth.obtainAccessCredentialsViaUserConsent,
       _buildClient = buildClient ?? gauth.autoRefreshingClient,
       _baseClientFactory = baseClientFactory ?? http.Client.new,
       _launchBrowser = launchBrowser ?? launchUrlString;

  static final _log = LoggerService.forClass(DesktopOAuthAuthenticator);

  /// openid + email are included so the id_token carries the account email
  /// for the settings tile subtitle; drive.appdata is the only Drive scope.
  static const List<String> scopes = [
    drive.DriveApi.driveAppdataScope,
    'openid',
    'email',
  ];

  static const String _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  final GoogleDriveTokenStore _tokenStore;
  final ObtainConsentCredentials _obtainConsent;
  final BuildRefreshingClient _buildClient;
  final http.Client Function() _baseClientFactory;
  final Future<void> Function(String url) _launchBrowser;

  gauth.AutoRefreshingAuthClient? _authClient;
  StreamSubscription<gauth.AccessCredentials>? _updateSubscription;
  String? _email;

  gauth.ClientId get _clientId => gauth.ClientId(
    GoogleDriveClientConfig.desktopClientId,
    GoogleDriveClientConfig.desktopClientSecret,
  );

  @override
  http.Client? get authClient => _authClient;

  @override
  Future<String?> get userEmail async => _email;

  @override
  Future<void> authenticate() async {
    final base = _baseClientFactory();
    try {
      final credentials = await _obtainConsent(_clientId, scopes, base, (url) {
        unawaited(_launchBrowser(url));
      });
      await _tokenStore.save(credentials);
      _installClient(credentials);
      _log.info('Authenticated with Google Drive via browser consent');
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException('Google Sign-In failed: $e', e, stackTrace);
    } finally {
      base.close();
    }
  }

  @override
  Future<bool> attemptSilentAuth() async {
    try {
      if (_authClient != null) return true;

      final credentials = await _tokenStore.load();
      if (credentials == null || credentials.refreshToken == null) {
        return false;
      }
      _installClient(credentials);
      return true;
    } catch (e) {
      _log.warning('Silent sign-in failed: $e');
      return false;
    }
  }

  void _installClient(gauth.AccessCredentials credentials) {
    _teardownClient();
    final client = _buildClient(_clientId, credentials, _baseClientFactory());
    _updateSubscription = client.credentialUpdates.listen(
      (updated) => unawaited(_tokenStore.save(updated)),
    );
    _authClient = client;
    _email = _emailFromIdToken(credentials.idToken) ?? _email;
  }

  void _teardownClient() {
    unawaited(_updateSubscription?.cancel());
    _updateSubscription = null;
    _authClient?.close();
    _authClient = null;
  }

  @override
  Future<void> signOut() async {
    final credentials = await _tokenStore.load();
    final token =
        credentials?.refreshToken ?? _authClient?.credentials.accessToken.data;
    if (token != null) {
      // Best effort: revocation failure (e.g. offline) must not block
      // local sign-out.
      final base = _baseClientFactory();
      try {
        await base.post(
          Uri.parse(_revokeEndpoint),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: 'token=$token',
        );
      } catch (e) {
        _log.warning('Token revocation failed (ignored): $e');
      } finally {
        base.close();
      }
    }
    _teardownClient();
    _email = null;
    await _tokenStore.clear();
    _log.info('Signed out from Google Drive');
  }

  @override
  Future<void> handleAuthFailure() async {
    // A 401 that survives the auto-refreshing client means the grant was
    // revoked; clear everything so the next attempt re-runs the browser
    // flow instead of looping on a dead refresh token.
    _teardownClient();
    await _tokenStore.clear();
  }

  /// Extracts the email claim from a JWT id_token, or null.
  static String? _emailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    final parts = idToken.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['email'] as String?;
    } on FormatException {
      return null;
    }
  }
}
```

Implementation notes for the engineer:
- `gauth.obtainAccessCredentialsViaUserConsent` and `gauth.autoRefreshingClient`
  come from `package:googleapis_auth/auth_io.dart`. If their signatures differ
  from the typedefs (extra named params like `hostedDomain`), wrap them in a
  closure in the constructor initializer instead of tear-offs, e.g.
  `obtainConsent ?? (id, s, c, p) => gauth.obtainAccessCredentialsViaUserConsent(id, s, c, p)`.
- `handleAuthFailure` clearing the store is the desktop revoked-grant recovery
  path from the spec (provider retries silent auth once after 401; if that
  fails the user is asked to sign in again and the next sign-in re-prompts).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart`
Expected: All 9 tests PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart
git commit -m "feat(sync): add desktop loopback OAuth authenticator for Google Drive"
```

---

### Task 4: Refactor GoogleDriveStorageProvider onto the seam, with 401 retry and error mapping (TDD)

The provider keeps all Drive REST behavior, drops its embedded google_sign_in
code, takes a `GoogleDriveAuthenticator` (default chosen by platform), gains a
`_run` wrapper (one silent re-auth retry on 401) and quota/offline error
mapping, and gates desktop availability on `GoogleDriveClientConfig`.

**Files:**
- Modify: `lib/core/services/cloud_storage/google_drive_storage_provider.dart` (full rewrite below)
- Test: `test/core/services/cloud_storage/google_drive_storage_provider_test.dart` (new)

**Interfaces:**
- Consumes: `GoogleDriveAuthenticator` (Task 1), `GoogleSignInAuthenticator` (Task 1), `DesktopOAuthAuthenticator` (Task 3), `GoogleDriveClientConfig` (Task 1).
- Produces: `GoogleDriveStorageProvider({GoogleDriveAuthenticator? authenticator})` — the no-arg construction in `sync_providers.dart:152` keeps compiling unchanged. `isAvailable()` returns `GoogleDriveClientConfig.hasDesktopClient` on Windows/Linux, true elsewhere (Task 5 and the UI rely on this).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';

class _FakeAuthenticator implements GoogleDriveAuthenticator {
  _FakeAuthenticator(this._client);

  http.Client? _client;
  int authenticateCalls = 0;
  int silentAuthCalls = 0;
  int authFailures = 0;
  bool silentAuthResult = true;
  bool signedOut = false;

  @override
  http.Client? get authClient => _client;

  @override
  Future<void> authenticate() async => authenticateCalls++;

  @override
  Future<bool> attemptSilentAuth() async {
    silentAuthCalls++;
    return silentAuthResult;
  }

  @override
  Future<void> handleAuthFailure() async => authFailures++;

  @override
  Future<void> signOut() async {
    signedOut = true;
    _client = null;
  }

  @override
  Future<String?> get userEmail async => 'diver@example.com';
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// Minimal fake Drive v3 backend. List responses are keyed by a substring
/// of the q query parameter (folder lookups contain the folder mimeType,
/// file lookups contain the file name).
class _FakeDrive {
  final List<http.Request> requests = [];
  final Map<String, List<Map<String, Object?>>> listResponses = {};
  int failuresRemaining = 0;
  int failureStatus = 401;
  String failureReason = 'authError';

  MockClient client() => MockClient((request) async {
    requests.add(request);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      return http.Response(
        jsonEncode({
          'error': {
            'code': failureStatus,
            'message': 'fake failure',
            'errors': [
              {'reason': failureReason, 'message': 'fake failure'},
            ],
          },
        }),
        failureStatus,
        headers: _jsonHeaders,
      );
    }
    final path = request.url.path;
    if (request.method == 'GET' && path == '/drive/v3/files') {
      final q = request.url.queryParameters['q'] ?? '';
      for (final entry in listResponses.entries) {
        if (q.contains(entry.key)) {
          return http.Response(
            jsonEncode({'files': entry.value}),
            200,
            headers: _jsonHeaders,
          );
        }
      }
      return http.Response(
        jsonEncode({'files': <Object?>[]}),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'POST' && path == '/upload/drive/v3/files') {
      return http.Response(
        jsonEncode({'id': 'created-1', 'name': 'created'}),
        200,
        headers: _jsonHeaders,
      );
    }
    if ((request.method == 'PATCH' || request.method == 'PUT') &&
        path.startsWith('/upload/drive/v3/files/')) {
      return http.Response(
        jsonEncode({'id': path.split('/').last, 'name': 'updated'}),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'POST' && path == '/drive/v3/files') {
      return http.Response(
        jsonEncode({'id': 'folder-created-1', 'name': 'Submersion Sync'}),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      if (request.url.queryParameters['alt'] == 'media') {
        return http.Response.bytes([1, 2, 3], 200);
      }
      return http.Response(
        jsonEncode({
          'id': path.split('/').last,
          'name': 'meta.json',
          'modifiedTime': '2026-07-02T10:00:00.000Z',
          'size': '3',
        }),
        200,
        headers: _jsonHeaders,
      );
    }
    if (request.method == 'DELETE') {
      return http.Response('', 204);
    }
    return http.Response('unexpected ${request.method} $path', 500);
  });
}

const _folderQueryKey = "mimeType = 'application/vnd.google-apps.folder'";

void main() {
  late _FakeDrive drive;
  late _FakeAuthenticator auth;
  late GoogleDriveStorageProvider provider;

  setUp(() {
    drive = _FakeDrive();
    drive.listResponses[_folderQueryKey] = [
      {'id': 'folder-7', 'name': 'Submersion Sync'},
    ];
    auth = _FakeAuthenticator(drive.client());
    provider = GoogleDriveStorageProvider(authenticator: auth);
  });

  test('isAvailable is platform + desktop-config gated', () async {
    final expected = (Platform.isWindows || Platform.isLinux)
        ? GoogleDriveClientConfig.hasDesktopClient
        : true;
    expect(await provider.isAvailable(), expected);
  });

  test('isAuthenticated delegates to silent auth when no client yet', () async {
    final unauthenticated = GoogleDriveStorageProvider(
      authenticator: _FakeAuthenticator(null)..silentAuthResult = false,
    );
    expect(await unauthenticated.isAuthenticated(), isFalse);
  });

  test('getUserEmail delegates to the authenticator', () async {
    expect(await provider.getUserEmail(), 'diver@example.com');
  });

  test('upload creates a new file when none exists by that name', () async {
    final result = await provider.uploadFile(
      Uint8List.fromList([1, 2]),
      'ssv1.dev.cs.000001.json',
    );
    expect(result.fileId, 'created-1');
    expect(
      drive.requests.any(
        (r) => r.method == 'POST' && r.url.path == '/upload/drive/v3/files',
      ),
      isTrue,
    );
  });

  test('upload updates in place when the name already exists', () async {
    drive.listResponses["name = 'ssv1.dev.manifest.json'"] = [
      {'id': 'existing-9', 'name': 'ssv1.dev.manifest.json'},
    ];
    final result = await provider.uploadFile(
      Uint8List.fromList([1, 2]),
      'ssv1.dev.manifest.json',
    );
    expect(result.fileId, 'existing-9');
    expect(
      drive.requests.any(
        (r) => r.url.path == '/upload/drive/v3/files/existing-9',
      ),
      isTrue,
    );
  });

  test('the sync folder id is cached across calls', () async {
    await provider.uploadFile(Uint8List.fromList([1]), 'a.json');
    await provider.uploadFile(Uint8List.fromList([2]), 'b.json');
    final folderQueries = drive.requests.where(
      (r) => (r.url.queryParameters['q'] ?? '').contains(_folderQueryKey),
    );
    expect(folderQueries, hasLength(1));
  });

  test('download returns the file bytes', () async {
    final bytes = await provider.downloadFile('file-1');
    expect(bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('listFiles maps Drive results to CloudFileInfo', () async {
    drive.listResponses['ssv1.'] = [
      {
        'id': 'f1',
        'name': 'ssv1.dev.cs.000001.json',
        'modifiedTime': '2026-07-01T00:00:00.000Z',
        'size': '10',
      },
    ];
    final files = await provider.listFiles(namePattern: 'ssv1.');
    expect(files, hasLength(1));
    expect(files.single.id, 'f1');
    expect(files.single.sizeBytes, 10);
  });

  test('deleteFile issues a DELETE', () async {
    await provider.deleteFile('f1');
    expect(drive.requests.last.method, 'DELETE');
    expect(drive.requests.last.url.path, '/drive/v3/files/f1');
  });

  test('a 401 triggers one silent re-auth and a retry', () async {
    drive.failuresRemaining = 1;
    final files = await provider.listFiles(namePattern: 'ssv1.');
    expect(files, isEmpty);
    expect(auth.authFailures, 1);
    expect(auth.silentAuthCalls, 1);
  });

  test('a 401 with failed re-auth surfaces a sign-in-again error', () async {
    drive.failuresRemaining = 1;
    auth.silentAuthResult = false;
    expect(
      () => provider.listFiles(namePattern: 'ssv1.'),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          contains('sign in'),
        ),
      ),
    );
  });

  test('quota exhaustion maps to a storage-is-full error', () async {
    drive.failuresRemaining = 1;
    drive.failureStatus = 403;
    drive.failureReason = 'storageQuotaExceeded';
    expect(
      () => provider.listFiles(namePattern: 'ssv1.'),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          contains('storage is full'),
        ),
      ),
    );
  });

  test('signOut resets provider caches and delegates', () async {
    await provider.uploadFile(Uint8List.fromList([1]), 'a.json');
    await provider.signOut();
    expect(auth.signedOut, isTrue);
    expect(await provider.getFileInfo('x'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/cloud_storage/google_drive_storage_provider_test.dart`
Expected: FAIL — `GoogleDriveStorageProvider` has no `authenticator` parameter.

- [ ] **Step 3: Rewrite the provider**

Replace the entire contents of
`lib/core/services/cloud_storage/google_drive_storage_provider.dart` with:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Google Drive implementation of CloudStorageProvider
///
/// Uses the Drive API's appDataFolder for app-specific storage.
/// This folder is hidden from the user and only accessible by this app.
///
/// Authentication is delegated to a [GoogleDriveAuthenticator]:
/// google_sign_in on iOS/macOS/Android, loopback OAuth on Windows/Linux.
class GoogleDriveStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  GoogleDriveStorageProvider({GoogleDriveAuthenticator? authenticator})
    : _authenticator = authenticator ?? _defaultAuthenticator();

  static final _log = LoggerService.forClass(GoogleDriveStorageProvider);

  static GoogleDriveAuthenticator _defaultAuthenticator() =>
      (Platform.isWindows || Platform.isLinux)
      ? DesktopOAuthAuthenticator()
      : GoogleSignInAuthenticator();

  final GoogleDriveAuthenticator _authenticator;
  drive.DriveApi? _driveApi;
  String? _syncFolderId;

  @override
  String get providerName => 'Google Drive';

  @override
  String get providerId => 'googledrive';

  @override
  Future<bool> isAvailable() async {
    // Mobile and macOS OAuth config is compile-time (Info.plist / Android
    // client registration). Desktop needs the committed Desktop-app client;
    // a build without it degrades to a hidden tile instead of crashing.
    if (Platform.isWindows || Platform.isLinux) {
      return GoogleDriveClientConfig.hasDesktopClient;
    }
    return true;
  }

  @override
  Future<bool> isAuthenticated() async {
    if (_api != null) return true;
    if (await _authenticator.attemptSilentAuth()) {
      return _api != null;
    }
    return false;
  }

  @override
  Future<void> authenticate() async {
    await _authenticator.authenticate();
    _driveApi = null; // rebuilt lazily from the fresh auth client
    if (_api == null) {
      throw const CloudStorageException(
        'Google Sign-In did not produce an authorized client',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _authenticator.signOut();
    _driveApi = null;
    _syncFolderId = null;
  }

  @override
  Future<String?> getUserEmail() => _authenticator.userEmail;

  /// The Drive API bound to the authenticator's current client, or null
  /// when not authenticated. Rebuilt lazily so a re-auth (new client)
  /// transparently produces a new API instance.
  drive.DriveApi? get _api {
    final client = _authenticator.authClient;
    if (client == null) {
      _driveApi = null;
      return null;
    }
    return _driveApi ??= drive.DriveApi(client);
  }

  drive.DriveApi get _requireApi {
    final api = _api;
    if (api == null) {
      throw const CloudStorageException('Not authenticated with Google Drive');
    }
    return api;
  }

  /// Runs a Drive operation with a single 401 retry: access tokens expire
  /// hourly mid-session, so one silent re-auth disambiguates a stale token
  /// from a revoked grant. On a revoked grant the authenticator clears its
  /// stored state and the user is asked to sign in again.
  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 401) rethrow;
      _log.info('Drive API returned 401; attempting silent re-auth');
      await _authenticator.handleAuthFailure();
      _driveApi = null;
      if (!await _authenticator.attemptSilentAuth()) {
        throw CloudStorageException(
          'Google Drive sign-in expired. Please sign in again.',
          e,
        );
      }
      return await operation();
    }
  }

  /// Maps a Drive error to a CloudStorageException with an actionable
  /// message where one exists (quota); otherwise a generic wrapper.
  CloudStorageException _mapDriveError(
    String operation,
    Object e,
    StackTrace stackTrace,
  ) {
    if (e is drive.DetailedApiRequestError &&
        e.status == 403 &&
        e.errors.any((d) => d.reason == 'storageQuotaExceeded')) {
      return CloudStorageException(
        'Google Drive storage is full',
        e,
        stackTrace,
      );
    }
    return CloudStorageException('$operation failed: $e', e, stackTrace);
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    try {
      return await _run(() async {
        final targetFolder = folderId ?? await getOrCreateSyncFolder();

        // Check if file already exists
        final existingFile = await _findFile(filename, targetFolder);

        drive.File result;
        final media = drive.Media(Stream.fromIterable([data]), data.length);

        if (existingFile != null) {
          // Update existing file
          result = await _requireApi.files.update(
            drive.File(),
            existingFile.id!,
            uploadMedia: media,
          );
          _log.info('Updated file: $filename (${result.id})');
        } else {
          // Create new file
          final fileMetadata = drive.File()
            ..name = filename
            ..parents = [targetFolder];

          result = await _requireApi.files.create(
            fileMetadata,
            uploadMedia: media,
          );
          _log.info('Created file: $filename (${result.id})');
        }

        return UploadResult(fileId: result.id!, uploadTime: DateTime.now());
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to upload file: $filename',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Upload', e, stackTrace);
    }
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    try {
      return await _run(() async {
        final response = await _requireApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );

        if (response is! drive.Media) {
          throw const CloudStorageException('Invalid download response');
        }

        final chunks = <List<int>>[];
        await for (final chunk in response.stream) {
          chunks.add(chunk);
        }

        final allBytes = chunks.expand((x) => x).toList();
        _log.info('Downloaded file: $fileId (${allBytes.length} bytes)');
        return Uint8List.fromList(allBytes);
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to download file: $fileId',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Download', e, stackTrace);
    }
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    try {
      return await _run(() async {
        final file =
            await _requireApi.files.get(
                  fileId,
                  $fields: 'id,name,modifiedTime,size',
                )
                as drive.File;

        return CloudFileInfo(
          id: file.id!,
          name: file.name!,
          modifiedTime: file.modifiedTime ?? DateTime.now(),
          sizeBytes: file.size != null ? int.tryParse(file.size!) : null,
        );
      });
    } catch (e) {
      _log.warning('Failed to get file info: $fileId - $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    try {
      return await _run(() async {
        final targetFolder = folderId ?? await getOrCreateSyncFolder();

        var query = "'$targetFolder' in parents and trashed = false";
        if (namePattern != null) {
          query += " and name contains '$namePattern'";
        }

        final fileList = await _requireApi.files.list(
          spaces: 'appDataFolder',
          q: query,
          $fields: 'files(id,name,modifiedTime,size)',
        );

        return (fileList.files ?? [])
            .where((f) => f.id != null && f.name != null)
            .map(
              (f) => CloudFileInfo(
                id: f.id!,
                name: f.name!,
                modifiedTime: f.modifiedTime ?? DateTime.now(),
                sizeBytes: f.size != null ? int.tryParse(f.size!) : null,
              ),
            )
            .toList();
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error('Failed to list files', error: e, stackTrace: stackTrace);
      throw _mapDriveError('List files', e, stackTrace);
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    try {
      await _run(() => _requireApi.files.delete(fileId));
      _log.info('Deleted file: $fileId');
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete file: $fileId',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Delete', e, stackTrace);
    }
  }

  @override
  Future<bool> fileExists(String fileId) async {
    try {
      await _run(() => _requireApi.files.get(fileId, $fields: 'id'));
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    try {
      return await _run(() async {
        final folderMetadata = drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [parentFolderId ?? 'appDataFolder'];

        final folder = await _requireApi.files.create(folderMetadata);
        _log.info('Created folder: $folderName (${folder.id})');
        return folder.id!;
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create folder: $folderName',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Create folder', e, stackTrace);
    }
  }

  @override
  Future<String> getOrCreateSyncFolder() async {
    // Return cached folder ID if available
    if (_syncFolderId != null) {
      return _syncFolderId!;
    }

    try {
      return await _run(() async {
        // Look for existing sync folder
        const query =
            "name = '${CloudStorageProviderMixin.syncFolderName}' "
            "and mimeType = 'application/vnd.google-apps.folder' "
            "and 'appDataFolder' in parents "
            "and trashed = false";

        final fileList = await _requireApi.files.list(
          spaces: 'appDataFolder',
          q: query,
          $fields: 'files(id,name)',
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          _syncFolderId = fileList.files!.first.id!;
          _log.info('Found existing sync folder: $_syncFolderId');
          return _syncFolderId!;
        }

        // Create new sync folder
        _syncFolderId = await createFolder(
          CloudStorageProviderMixin.syncFolderName,
          parentFolderId: 'appDataFolder',
        );
        return _syncFolderId!;
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get/create sync folder',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Get/create sync folder', e, stackTrace);
    }
  }

  /// Find a file by name in a specific folder
  Future<drive.File?> _findFile(String filename, String folderId) async {
    try {
      final query =
          "name = '$filename' "
          "and '$folderId' in parents "
          "and trashed = false";

      final fileList = await _requireApi.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'files(id,name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first;
      }
      return null;
    } on drive.DetailedApiRequestError {
      // Let auth errors reach _run's 401 handling instead of masking them
      // as "file not found" (which would create a duplicate).
      rethrow;
    } catch (e) {
      _log.warning('Failed to find file: $filename - $e');
      return null;
    }
  }
}
```

Behavior deltas vs. the old file, all intentional (verify nothing else changed):
1. Auth methods delegate to the authenticator; Drive REST bodies are unchanged.
2. `_run` wraps every REST call with one 401 retry.
3. `_findFile` rethrows `DetailedApiRequestError` instead of swallowing it, so
   an expired token during upload cannot silently fork a duplicate file.
4. `_mapDriveError` adds the quota message.
5. `isAvailable()` is platform/config gated.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/google_drive_storage_provider_test.dart`
Expected: All 13 tests PASS.

- [ ] **Step 5: Run the neighboring suites (regression)**

Run: `flutter test test/core/services/cloud_storage/cloud_storage_provider_test.dart test/core/services/sync/sync_provider_type_test.dart`
Expected: PASS (enum membership and mixin behavior unchanged).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/cloud_storage/google_drive_storage_provider.dart test/core/services/cloud_storage/google_drive_storage_provider_test.dart
git commit -m "refactor(sync): Google Drive provider on authenticator seam with 401 retry and error mapping"
```

---

### Task 5: Availability providers and capabilities wiring (TDD)

Expose availability and the signed-in email to the UI as Riverpod providers,
and make the dead `supportsGoogleDrive` capability flag agree with the real
gating so the two cannot diverge.

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (add two providers near `cloudProviderInstanceFor`, around line 170)
- Modify: `lib/features/settings/presentation/providers/storage_providers.dart:44`
- Test: `test/features/settings/presentation/providers/google_drive_ui_providers_test.dart` (new)

**Interfaces:**
- Consumes: `cloudProviderInstanceFor`, `selectedCloudProviderTypeProvider`, `syncStateProvider` (all existing in `sync_providers.dart`), `GoogleDriveClientConfig`.
- Produces: `googleDriveAvailableProvider: FutureProvider<bool>`, `googleDriveAccountEmailProvider: FutureProvider<String?>` (Task 6 UI watches these and tests override them).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  test('googleDriveAccountEmailProvider is null when Drive not selected', () async {
    final container = ProviderContainer(
      overrides: [
        selectedCloudProviderTypeProvider.overrideWith(
          (ref) => CloudProviderType.icloud,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(googleDriveAccountEmailProvider.future),
      isNull,
    );
  });

  test('googleDriveAvailableProvider resolves without authentication', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Must not throw and must not require sign-in; the exact value is
    // platform-dependent (config-gated on Windows/Linux, true elsewhere).
    expect(
      await container.read(googleDriveAvailableProvider.future),
      isA<bool>(),
    );
  });
}
```

Note: if `ProviderContainer` needs base overrides (e.g. SharedPreferences) to
construct these providers, reuse the pattern from existing provider tests in
`test/features/settings/presentation/providers/`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/google_drive_ui_providers_test.dart`
Expected: FAIL — the two providers are undefined.

- [ ] **Step 3: Add the providers to `sync_providers.dart`** (after `cloudProviderInstanceFor`, before `cloudStorageProviderProvider`)

```dart
/// Whether Google Drive can be offered on this platform/build. True on
/// iOS/macOS/Android; on Windows/Linux only when the Desktop-app OAuth
/// client is compiled in (GoogleDriveClientConfig).
final googleDriveAvailableProvider = FutureProvider<bool>((ref) {
  return cloudProviderInstanceFor(CloudProviderType.googledrive).isAvailable();
});

/// Signed-in Google account email for the provider tile subtitle, or null
/// when Google Drive is not the selected provider or no account is known.
/// Watches syncStateProvider so connect/sign-out refresh the subtitle.
final googleDriveAccountEmailProvider = FutureProvider<String?>((ref) async {
  final type = ref.watch(selectedCloudProviderTypeProvider);
  if (type != CloudProviderType.googledrive) return null;
  ref.watch(syncStateProvider);
  return cloudProviderInstanceFor(
    CloudProviderType.googledrive,
  ).getUserEmail();
});
```

- [ ] **Step 4: Wire the capability flag in `storage_providers.dart`**

Replace line 44 (`supportsGoogleDrive: true, // All platforms`) with:

```dart
        // Mirrors GoogleDriveStorageProvider.isAvailable(): compile-time
        // config on mobile/macOS, Desktop-app client required on desktop.
        supportsGoogleDrive:
            !(Platform.isWindows || Platform.isLinux) ||
            GoogleDriveClientConfig.hasDesktopClient,
```

Add the import at the top of the file:

```dart
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/google_drive_ui_providers_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/presentation/providers/ test/features/settings/presentation/providers/google_drive_ui_providers_test.dart
git commit -m "feat(sync): Google Drive availability and account-email providers, capability wiring"
```

---

### Task 6: Restore the Google Drive tile in Cloud Sync settings (TDD)

Remove the hide/coercion, add the tile with email subtitle, add the desktop
browser-wait dialog, add three localized strings to all 11 locales, and update
the widget tests that assert the tile is hidden.

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`)
- Test: `test/features/settings/presentation/pages/cloud_sync_page_test.dart`

**Interfaces:**
- Consumes: `googleDriveAvailableProvider`, `googleDriveAccountEmailProvider` (Task 5); existing `_buildProviderSection`, `_selectProvider`, `pumpPage` test harness.
- Produces: l10n keys `settings_cloudSync_googleDrive_desktopNotConfigured`, `settings_cloudSync_googleDrive_browserWait_title`, `settings_cloudSync_googleDrive_browserWait_message`.

- [ ] **Step 1: Update the two existing widget tests that assert hidden**

In `test/features/settings/presentation/pages/cloud_sync_page_test.dart`:

(a) In the base-render test (around line 554), change:

```dart
      expect(find.text('Google Drive'), findsNothing);
```

to:

```dart
      expect(find.text('Google Drive'), findsOneWidget);
```

(b) Replace the test `'persisted googledrive selection reads as no provider since the tile is hidden'` (around line 810) entirely with:

```dart
    testWidgets('persisted googledrive selection selects the tile', (
      tester,
    ) async {
      await pumpPage(
        tester,
        selectedProvider: CloudProviderType.googledrive,
        googleDriveEmail: 'diver@example.com',
      );

      // The Google Drive tile shows the connected check icon.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // The subtitle shows the signed-in account.
      expect(find.text('diver@example.com'), findsOneWidget);
      // Sync Now is enabled (no coercion to "no provider" anymore).
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sync Now'),
      );
      expect(button.onPressed, isNotNull);
    });
```

(c) Add two new tests in the provider-selection group:

```dart
    testWidgets('Google Drive tile is disabled when unavailable', (
      tester,
    ) async {
      await pumpPage(tester, googleDriveAvailable: false);

      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Google Drive'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('tapping Google Drive authenticates and connects', (
      tester,
    ) async {
      final fake = FakeCloudStorageProvider();
      await pumpPage(tester, cloudProvider: fake);

      await tester.tap(find.text('Google Drive'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Connected to'), findsOneWidget);
    });
```

Reuse the file's existing import of `FakeCloudStorageProvider` if present;
otherwise import `../../../../support/fake_cloud_storage_provider.dart`.
Follow how existing tests route `cloudProvider:` through `pumpPage`.

(d) Extend `pumpPage` with two parameters and overrides:

```dart
    bool googleDriveAvailable = true,
    String? googleDriveEmail,
```

and inside the `overrides:` list:

```dart
          googleDriveAvailableProvider.overrideWith(
            (ref) async => googleDriveAvailable,
          ),
          googleDriveAccountEmailProvider.overrideWith(
            (ref) async => googleDriveEmail,
          ),
```

- [ ] **Step 2: Run tests to verify the new expectations fail**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: FAIL — 'Google Drive' not found (tile still hidden), plus the new tests fail.

- [ ] **Step 3: Add the l10n strings**

In `lib/l10n/arb/app_en.arb`, next to the existing
`settings_cloudSync_provider_googleDrive` entries (around line 5845), add:

```json
  "settings_cloudSync_googleDrive_desktopNotConfigured": "Not available in this build",
  "settings_cloudSync_googleDrive_browserWait_title": "Continue in your browser",
  "settings_cloudSync_googleDrive_browserWait_message": "Finish signing in to Google in your web browser, then return to Submersion.",
```

Translate all three strings into each of the 10 other locale files
(`app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh`),
matching each file's existing tone and formality for the settings strings,
then run:

```bash
flutter gen-l10n
```

- [ ] **Step 4: Edit `cloud_sync_page.dart`**

(a) Remove the coercion in `build` (lines 55-62). Replace:

```dart
    // Google Drive is hidden until its integration is implemented, but a
    // persisted selection or SyncRepository's fallback can still surface
    // `googledrive`. Treat it as no provider so the page can never show
    // Sync Now enabled with no selected tile.
    final rawProvider = ref.watch(selectedCloudProviderTypeProvider);
    final selectedProvider = rawProvider == CloudProviderType.googledrive
        ? null
        : rawProvider;
```

with:

```dart
    final selectedProvider = ref.watch(selectedCloudProviderTypeProvider);
```

(b) In `_buildProviderSection` (around line 466), replace the hidden-tile
comment with the tile call, so the children read:

```dart
        _buildProviderTile(
          context,
          ref,
          provider: CloudProviderType.icloud,
          title: 'iCloud',
          subtitle: 'Sync via Apple iCloud',
          icon: Icons.cloud,
          isSelected: selectedProvider == CloudProviderType.icloud,
          isAvailable: isApple && !iCloudUnsupported,
          disabledSubtitle: iCloudDisabledSubtitle,
        ),
        _buildGoogleDriveProviderTile(context, ref, selectedProvider),
        _buildS3ProviderTile(context, ref, selectedProvider),
```

(c) Add the tile builder after `_buildProviderTile`:

```dart
  Widget _buildGoogleDriveProviderTile(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType? selectedProvider,
  ) {
    final l10n = context.l10n;
    final isSelected = selectedProvider == CloudProviderType.googledrive;
    // Render from AsyncValue.value so a provider reload does not flash the
    // tile through a disabled state.
    final isAvailable =
        ref.watch(googleDriveAvailableProvider).value ?? false;
    final email = ref.watch(googleDriveAccountEmailProvider).value;

    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: const Icon(Icons.add_to_drive),
        title: Text(l10n.settings_cloudSync_provider_googleDrive),
        subtitle: Text(
          !isAvailable
              ? l10n.settings_cloudSync_googleDrive_desktopNotConfigured
              : (isSelected && email != null
                    ? email
                    : l10n.settings_cloudSync_provider_googleDrive_subtitle),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: Colors.green,
                semanticLabel: 'Connected',
              )
            : null,
        enabled: isAvailable,
        onTap: isAvailable
            ? () => _selectProvider(context, ref, CloudProviderType.googledrive)
            : null,
      ),
    );
  }
```

(d) Desktop browser-wait dialog. Add imports at the top of the file:

```dart
import 'dart:async';
import 'dart:io';
```

In `_selectProvider`, replace the line:

```dart
      await cloudProvider.authenticate();
```

with:

```dart
      await _authenticateWithBrowserWait(context, cloudProvider, provider);
```

and add the method:

```dart
  /// On desktop, Google Drive authentication round-trips through the
  /// system browser (loopback OAuth); keep a cancellable waiting dialog up
  /// while it completes so the page does not look frozen. Other providers
  /// and platforms authenticate directly.
  Future<void> _authenticateWithBrowserWait(
    BuildContext context,
    CloudStorageProvider cloudProvider,
    CloudProviderType provider,
  ) async {
    final needsDialog =
        provider == CloudProviderType.googledrive &&
        (Platform.isWindows || Platform.isLinux);
    if (!needsDialog) {
      await cloudProvider.authenticate();
      return;
    }

    var dialogUp = true;
    final auth = cloudProvider.authenticate().whenComplete(() {
      if (dialogUp && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(false);
      }
    });
    final cancelled =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              dialogContext.l10n.settings_cloudSync_googleDrive_browserWait_title,
            ),
            content: Text(
              dialogContext
                  .l10n
                  .settings_cloudSync_googleDrive_browserWait_message,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
            ],
          ),
        ) ??
        false;
    dialogUp = false;
    if (cancelled) {
      // Abandon the pending flow; the loopback listener times out on its
      // own. Swallow its eventual error so nothing surfaces later.
      unawaited(auth.catchError((_) {}));
      throw const CloudStorageException('Google Sign-In was cancelled');
    }
    await auth;
  }
```

`CloudStorageException` needs importing if not already imported:
`import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';`

- [ ] **Step 5: Run the widget tests**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: All tests PASS (including the updated and new ones). Note the file
has Apple-only tap tests; run on the macOS dev machine.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/presentation/pages/cloud_sync_page.dart lib/l10n/ test/features/settings/presentation/pages/cloud_sync_page_test.dart
git commit -m "feat(sync): restore Google Drive provider tile with availability gating and desktop browser flow"
```

---

### Task 7: macOS OAuth configuration

No unit tests (plist/entitlements); the gate is a successful macOS build.
google_sign_in on macOS reuses the existing iOS OAuth client.

**Files:**
- Modify: `macos/Runner/Info.plist`
- Modify: `macos/Runner/DebugProfile.entitlements`
- Modify: `macos/Runner/Release.entitlements`

- [ ] **Step 1: Read the iOS client values**

```bash
/usr/libexec/PlistBuddy -c "Print :GIDClientID" ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" ios/Runner/Info.plist
```

Note the `GIDClientID` (`<number>-<hash>.apps.googleusercontent.com`) and the
reversed URL scheme (`com.googleusercontent.apps.<number>-<hash>`).

- [ ] **Step 2: Add both to `macos/Runner/Info.plist`**

Inside the top-level `<dict>`, add (substituting the two values read in
Step 1):

```xml
	<key>GIDClientID</key>
	<string>VALUE-FROM-STEP-1.apps.googleusercontent.com</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>com.googleusercontent.apps.VALUE-FROM-STEP-1</string>
			</array>
		</dict>
	</array>
```

If `macos/Runner/Info.plist` already has a `CFBundleURLTypes` array, append the
inner `<dict>` to it instead of adding a second array.

- [ ] **Step 3: Add the Keychain Sharing entitlement**

google_sign_in on macOS requires the Keychain Sharing capability. In BOTH
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`,
add inside the `<dict>`:

```xml
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)com.google.GIDSignIn</string>
	</array>
```

- [ ] **Step 4: Verify the build**

```bash
plutil -lint macos/Runner/Info.plist
flutter build macos --debug
```

Expected: lint OK; build succeeds. (Memory note: if the build fails with
"cannot find X" after plugin changes, run `pod install` in `macos/`.)

- [ ] **Step 5: Commit**

```bash
git add macos/Runner/
git commit -m "feat(sync): configure Google Sign-In OAuth on macOS"
```

---

### Task 8: Google Cloud console clients and committed constants — REQUIRES USER

The engineer cannot do this alone: the user must create OAuth clients in the
Google Cloud console (project `433819313354`). Walk them through Appendix A of
the spec (`docs/superpowers/specs/2026-07-02-google-drive-sync-backend-design.md`),
then commit the resulting IDs.

- [ ] **Step 1: Consent screen + API check (user, with guidance)**

Per spec Appendix A.1: confirm the OAuth consent screen is configured, the
`drive.appdata` scope needs no verification, test users are added if the app
is in Testing status, and the Google Drive API is enabled.

- [ ] **Step 2: Android clients (user, with guidance)**

Per spec Appendix A.2: create Android OAuth clients for the debug and release
SHA-1s, plus one Web application client. Debug SHA-1 command:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1
```

Collect: the Web client ID (this becomes `androidServerClientId`).

- [ ] **Step 3: Desktop client (user, with guidance)**

Per spec Appendix A.3: create one "Desktop app" OAuth client. Collect its
client ID and client secret.

- [ ] **Step 4: Fill the constants**

In `lib/core/services/cloud_storage/google_drive/google_drive_client_config.dart`,
replace the three empty strings with the collected values. Keep the
RFC 8252 comment.

- [ ] **Step 5: Verify, format, commit**

```bash
flutter analyze
flutter test test/core/services/cloud_storage/google_drive_storage_provider_test.dart
dart format .
git add lib/core/services/cloud_storage/google_drive/google_drive_client_config.dart
git commit -m "feat(sync): register Google Drive OAuth clients for Android and desktop"
```

---

### Task 9: Manual test checklist doc and final verification sweep

**Files:**
- Create: `docs/superpowers/specs/2026-07-02-google-drive-sync-manual-test-checklist.md`

- [ ] **Step 1: Write the checklist file**

```markdown
# Google Drive Sync — Manual Device Test Checklist

Run on real hardware per platform: macOS, iPhone or iPad, Android device,
Windows, Linux. All items must pass before Google Drive sync is considered
done (acceptance gate from the 2026-07-02 design spec).

For each platform:

- [ ] 1. Fresh sign-in from Settings > Cloud Sync (native account sheet on
      iOS/macOS/Android; system browser + return on Windows/Linux). Tile
      shows the account email after connecting.
- [ ] 2. Cold-launch silent auth: force-quit, relaunch, run Sync Now.
      No sign-in prompt, no keychain dialog, sync succeeds.
- [ ] 3. Two-device round-trip: edit a dive on device A, Sync Now on A
      then B; the change appears on B. Repeat in the other direction.
- [ ] 4. Sign out (Advanced > Sign Out): tile deselects, subsequent
      launches show no keychain prompts.
- [ ] 5. Revoke access at myaccount.google.com > Security > Third-party
      access, then Sync Now: a "sign in again" error appears; re-auth
      via the tile recovers and sync works.
- [ ] 6. (Apple platforms) Backend switch iCloud -> Google Drive: the
      departure confirmation appears, the moved-marker lands on iCloud,
      and the per-provider cursor does not read stale (first Drive sync
      is a full first-contact sync, not an incremental continuation).
- [ ] 7. (Windows/Linux) Cancel the browser dialog mid-sign-in: the tile
      stays unselected, no credentials are stored, retrying works.

Cross-platform matrix (any two platforms with different auth paths, e.g.
macOS + Windows): items 1-3 passing proves both OAuth clients land in the
same appDataFolder (same Google Cloud project).
```

- [ ] **Step 2: Final verification sweep**

```bash
dart format .
flutter analyze
flutter test \
  test/core/services/cloud_storage/google_drive_storage_provider_test.dart \
  test/core/services/cloud_storage/google_drive/google_drive_token_store_test.dart \
  test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart \
  test/features/settings/presentation/providers/google_drive_ui_providers_test.dart \
  test/features/settings/presentation/pages/cloud_sync_page_test.dart \
  test/core/services/cloud_storage/cloud_storage_provider_test.dart \
  test/core/services/sync/sync_provider_type_test.dart
```

Expected: format makes no changes, analyze clean, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-07-02-google-drive-sync-manual-test-checklist.md
git commit -m "docs(sync): manual device test checklist for Google Drive sync"
```

- [ ] **Step 4: Hand off**

Report completion; the user runs the manual checklist on hardware. PR via
`git push -u origin worktree-google-drive-sync --no-verify` (worktree
pre-push hook runs against the main tree — known issue) and `gh pr create`,
when the user asks for it.
