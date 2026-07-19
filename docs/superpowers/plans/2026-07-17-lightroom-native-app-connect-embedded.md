# Lightroom Native App — Embedded Connect Implementation Plan (Plan 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-tap "Connect with Adobe" flow that signs in with Submersion's own embedded Native App credential and auto-captures the redirect via `flutter_web_auth_2` — so the connect works end-to-end on the owner's account with no Developer Console setup and no copy-paste. This is the slice that unblocks the demo video.

**Architecture:** Builds on Plan 1's refresh-token-optional, per-connection-redirect auth manager. Bundle the public client id + Adobe's generated redirect scheme as constants; capture the OAuth redirect through an injectable wrapper over `flutter_web_auth_2`; a pure-Dart `signInWithEmbeddedCredential` helper does begin→capture→complete; the settings page gains an embedded Connect button that calls it and then runs the existing account-creation path. BYO stays exactly as-is (its dialog is untouched; the BYO wizard is Plan 3).

**Tech Stack:** Dart/Flutter, `flutter_web_auth_2`, `package:http` (+ `MockClient`), Riverpod, existing `AdobeImsAuthManager`.

## Global Constraints

- All Dart code must pass `dart format .` and `flutter analyze` with no changes/issues.
- TDD for the pure-Dart helper (Task 3); native config (Task 5) is device/manual-verified.
- The embedded client id is a **public** value — safe to commit. No secret is involved anywhere.
- Do not change the existing BYO fields/dialog or `_connect()`'s account-creation logic; the embedded path reuses that logic, it does not replace it.
- The redirect scheme registered natively (Task 5), the `callbackScheme` constant (Task 1), and the value passed to `flutter_web_auth_2` (Task 3) must be byte-identical.

---

### Task 1: `flutter_web_auth_2` dependency + embedded credential constants

**Files:**
- Modify: `pubspec.yaml` (dependencies section)
- Create: `lib/core/services/lightroom/lightroom_embedded_credential.dart`
- Test: `test/core/services/lightroom/lightroom_embedded_credential_test.dart`

**Interfaces:**
- Produces: `LightroomEmbeddedCredential.clientId`, `.redirectUri`, `.callbackScheme` (all `static const String`).

- [ ] **Step 1: Add the dependency.** In `pubspec.yaml`, under `dependencies:` (alphabetical, near `flutter_secure_storage`), add:

```yaml
  flutter_web_auth_2: ^4.1.0
```

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: resolves successfully. If `^4.1.0` fails to resolve against the SDK constraints, use the newest 4.x the resolver allows and note it in the commit.

- [ ] **Step 3: Write the failing test** — `lightroom_embedded_credential_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';

void main() {
  test('redirect uri begins with the callback scheme', () {
    expect(
      LightroomEmbeddedCredential.redirectUri.startsWith(
        '${LightroomEmbeddedCredential.callbackScheme}://',
      ),
      isTrue,
    );
  });

  test('client id appears in the redirect uri path', () {
    expect(
      LightroomEmbeddedCredential.redirectUri.contains(
        LightroomEmbeddedCredential.clientId,
      ),
      isTrue,
    );
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/core/services/lightroom/lightroom_embedded_credential_test.dart`
Expected: FAIL — the file/class does not exist yet.

- [ ] **Step 5: Implement** — `lightroom_embedded_credential.dart`:

```dart
/// Submersion's own Adobe Lightroom "OAuth Native App" credential, bundled
/// so users connect by signing in with their Adobe account — no Developer
/// Console setup. The client id is a public value (Native App credentials
/// carry no secret), so it is safe to embed. Adobe generates the redirect
/// scheme per credential. This credential is entitled for its owner and any
/// Adobe IDs allowlisted as Console "beta users" until Adobe grants partner
/// approval, after which it works for every user.
class LightroomEmbeddedCredential {
  const LightroomEmbeddedCredential._();

  static const String clientId = '00f3c953c816414db32d7ee98873040d';

  /// Adobe-generated redirect URI for this Native App credential.
  static const String redirectUri =
      'adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d://adobeid/'
      '00f3c953c816414db32d7ee98873040d';

  /// The scheme part of [redirectUri]. Registered natively (iOS/Android/
  /// macOS) and handed to the in-app auth session as its callback scheme.
  static const String callbackScheme =
      'adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d';
}
```

- [ ] **Step 6: Run test to verify it passes, then commit**

Run: `flutter test test/core/services/lightroom/lightroom_embedded_credential_test.dart`
Expected: PASS.

```bash
dart format lib/core/services/lightroom/lightroom_embedded_credential.dart test/core/services/lightroom/lightroom_embedded_credential_test.dart
git add pubspec.yaml pubspec.lock lib/core/services/lightroom/lightroom_embedded_credential.dart test/core/services/lightroom/lightroom_embedded_credential_test.dart
git commit -m "feat(lightroom): flutter_web_auth_2 dep + embedded Native App credential constants"
```

---

### Task 2: Redirect-capture wrapper + provider

**Files:**
- Create: `lib/core/services/lightroom/lightroom_redirect_capture.dart`
- Modify: `lib/features/media/presentation/providers/lightroom_providers.dart` (add provider)

**Interfaces:**
- Produces:
  - `abstract class LightroomRedirectCapture { Future<String> capture({required Uri authorizeUrl, required String callbackScheme}); }`
  - `class FlutterWebAuthRedirectCapture implements LightroomRedirectCapture` — delegates to `flutter_web_auth_2`.
  - `final lightroomRedirectCaptureProvider = Provider<LightroomRedirectCapture>(...)` — overridable in tests.

- [ ] **Step 1: Implement the wrapper** — `lightroom_redirect_capture.dart`:

```dart
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Opens an in-app browser auth session for [authorizeUrl] and completes
/// when the OS routes the custom-scheme callback ([callbackScheme]) back to
/// the app, returning the full redirected URL. Abstract so widget tests
/// inject a fake instead of driving a real platform channel.
abstract class LightroomRedirectCapture {
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  });
}

/// Production implementation backed by flutter_web_auth_2. Runs a
/// non-ephemeral session so the Adobe IMS cookie persists and later
/// re-auth is usually a silent redirect.
class FlutterWebAuthRedirectCapture implements LightroomRedirectCapture {
  const FlutterWebAuthRedirectCapture();

  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) {
    return FlutterWebAuth2.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: callbackScheme,
      options: const FlutterWebAuth2Options(preferEphemeral: false),
    );
  }
}
```

- [ ] **Step 2: Add the provider** to `lightroom_providers.dart` (after `lightroomAuthManagerProvider`):

```dart
/// The redirect capturer for the embedded connect flow. Overridden with a
/// fake in tests.
final lightroomRedirectCaptureProvider = Provider<LightroomRedirectCapture>(
  (ref) => const FlutterWebAuthRedirectCapture(),
);
```

Add the import at the top of `lightroom_providers.dart`:

```dart
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';
```

- [ ] **Step 3: Analyze and commit**

Run: `flutter analyze lib/core/services/lightroom/lightroom_redirect_capture.dart lib/features/media/presentation/providers/lightroom_providers.dart`
Expected: No issues.

```bash
dart format lib/core/services/lightroom/lightroom_redirect_capture.dart lib/features/media/presentation/providers/lightroom_providers.dart
git add lib/core/services/lightroom/lightroom_redirect_capture.dart lib/features/media/presentation/providers/lightroom_providers.dart
git commit -m "feat(lightroom): injectable redirect-capture wrapper over flutter_web_auth_2"
```

---

### Task 3: `signInWithEmbeddedCredential` helper (pure Dart, TDD)

**Files:**
- Create: `lib/core/services/lightroom/lightroom_embedded_connect.dart`
- Test: `test/core/services/lightroom/lightroom_embedded_connect_test.dart`

**Interfaces:**
- Consumes: `AdobeImsAuthManager` (Plan 1), `LightroomRedirectCapture` (Task 2), `LightroomEmbeddedCredential` (Task 1).
- Produces: `Future<LightroomAuthData> signInWithEmbeddedCredential({required AdobeImsAuthManager authManager, required LightroomRedirectCapture capture})` — runs begin→capture→complete and returns the persisted auth (tokens saved to the manager's store, as the copy-paste dialog does today).

- [ ] **Step 1: Write the failing test** — `lightroom_embedded_connect_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_connect.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';

import '../../../support/fake_keychain_storage.dart';

class _FakeCapture implements LightroomRedirectCapture {
  _FakeCapture(this.result);
  final String result;
  Uri? seenUrl;
  String? seenScheme;
  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) async {
    seenUrl = authorizeUrl;
    seenScheme = callbackScheme;
    return result;
  }
}

void main() {
  test('embedded sign-in authorizes with the bundled credential and '
      'persists tokens', () async {
    final requests = <http.Request>[];
    final mock = MockClient((req) async {
      requests.add(req);
      return http.Response(
        jsonEncode({'access_token': 'at1', 'expires_in': 3600}),
        200,
      );
    });
    final manager = AdobeImsAuthManager(
      store: LightroomAuthStore(storage: InMemoryKeychain()),
      httpClient: mock,
      now: () => DateTime.utc(2026, 7, 17, 12),
      verifierGenerator: () => 'a' * 43,
    );
    final capture = _FakeCapture(
      '${LightroomEmbeddedCredential.redirectUri}?code=thecode',
    );

    final data = await signInWithEmbeddedCredential(
      authManager: manager,
      capture: capture,
    );

    // The authorize URL carried the embedded client id, and the capturer was
    // given the embedded callback scheme.
    expect(
      capture.seenUrl!.queryParameters['client_id'],
      LightroomEmbeddedCredential.clientId,
    );
    expect(capture.seenScheme, LightroomEmbeddedCredential.callbackScheme);
    // Tokens were exchanged and persisted; no refresh token is fine.
    expect(data.clientId, LightroomEmbeddedCredential.clientId);
    expect(data.redirectUri, LightroomEmbeddedCredential.redirectUri);
    final body = Uri.splitQueryString(requests.single.body);
    expect(body['code'], 'thecode');
    expect(body['redirect_uri'], LightroomEmbeddedCredential.redirectUri);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/lightroom/lightroom_embedded_connect_test.dart`
Expected: FAIL — `signInWithEmbeddedCredential` does not exist.

- [ ] **Step 3: Implement** — `lightroom_embedded_connect.dart`:

```dart
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';

/// Signs in with Submersion's bundled Native App credential: builds the IMS
/// authorize URL, opens an in-app auth session via [capture], and exchanges
/// the returned redirect for tokens. Tokens are persisted on [authManager]'s
/// store (the legacy connect-time key), exactly like the BYO copy-paste
/// dialog, so the settings page's existing account-creation path runs next.
Future<LightroomAuthData> signInWithEmbeddedCredential({
  required AdobeImsAuthManager authManager,
  required LightroomRedirectCapture capture,
}) async {
  final authorizeUrl = authManager.beginAuthorization(
    clientId: LightroomEmbeddedCredential.clientId,
    redirectUri: LightroomEmbeddedCredential.redirectUri,
  );
  final redirected = await capture.capture(
    authorizeUrl: authorizeUrl,
    callbackScheme: LightroomEmbeddedCredential.callbackScheme,
  );
  return authManager.completeAuthorization(redirected);
}
```

- [ ] **Step 4: Run test to verify it passes, then commit**

Run: `flutter test test/core/services/lightroom/lightroom_embedded_connect_test.dart`
Expected: PASS.

```bash
dart format lib/core/services/lightroom/lightroom_embedded_connect.dart test/core/services/lightroom/lightroom_embedded_connect_test.dart
git add lib/core/services/lightroom/lightroom_embedded_connect.dart test/core/services/lightroom/lightroom_embedded_connect_test.dart
git commit -m "feat(lightroom): signInWithEmbeddedCredential helper (begin/capture/complete)"
```

---

### Task 4: Wire the embedded "Connect with Adobe" button into the settings page

**Files:**
- Modify: `lib/features/settings/presentation/pages/lightroom_settings_page.dart`
- Add strings: `lib/l10n/arb/app_en.arb` + the 10 other locale ARBs (`settings_lightroom_connectEmbedded`, e.g. "Connect with Adobe").

**Interfaces:**
- Consumes: `signInWithEmbeddedCredential` (Task 3), `lightroomRedirectCaptureProvider` (Task 2).

- [ ] **Step 1: Extract the shared post-sign-in work.** In `lightroom_settings_page.dart`, factor the body of `_connect()` after the dialog returns (lines 58–111: fetch account/catalog, create/reuse the row, rekey creds, invalidate) into a private method:

```dart
Future<void> _finishConnect() async {
  final l10n = context.l10n;
  setState(() => _busy = true);
  try {
    final authManager = ref.read(lightroomAuthManagerProvider);
    final api = ref.read(lightroomApiClientProvider);
    final account = await api.getAccount();
    final catalogId = await api.getCatalogId();
    final auth = await authManager.loadAuth();
    if (auth != null) {
      await authManager.updateAuth(
        auth.copyWith(
          catalogId: catalogId,
          displayName: account.fullName,
          email: account.email,
        ),
      );
    }
    final repo = ref.read(connectedAccountsRepositoryProvider);
    final existing = await repo.getByKind(AccountKind.adobeLightroom);
    final target =
        existing ??
        await repo.create(
          kind: AccountKind.adobeLightroom,
          label: account.fullName ?? account.email ?? 'Adobe account',
          accountIdentifier: catalogId,
        );
    await ref.read(accountCredentialsStoreProvider).rekeyFromLegacy(
          legacyKey: LightroomAuthStore.storageKey,
          accountId: target.id,
          overwrite: true,
        );
    ref.invalidate(lightroomAccountProvider);
    ref.invalidate(lightroomDeviceStatusProvider);
  } on Exception catch (e) {
    if (!mounted) return;
    final message = switch (e) {
      CloudStorageException(:final displayMessage) => displayMessage,
      _ => e.toString(),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.settings_lightroom_connect_failed(message)),
      ),
    );
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

Then make the existing `_connect()` end with: after `if (connected != true || !mounted) return;`, call `await _finishConnect();` (removing the duplicated body).

- [ ] **Step 2: Add the embedded connect method**:

```dart
Future<void> _connectEmbedded() async {
  final authManager = ref.read(lightroomAuthManagerProvider);
  final capture = ref.read(lightroomRedirectCaptureProvider);
  setState(() => _busy = true);
  try {
    await signInWithEmbeddedCredential(
      authManager: authManager,
      capture: capture,
    );
  } on Exception catch (e) {
    if (!mounted) return;
    final message = switch (e) {
      CloudStorageException(:final displayMessage) => displayMessage,
      _ => e.toString(),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.settings_lightroom_connect_failed(message)),
      ),
    );
    setState(() => _busy = false);
    return;
  }
  if (!mounted) return;
  await _finishConnect();
}
```

Add the imports at the top of the file:

```dart
import 'package:submersion/core/services/lightroom/lightroom_embedded_connect.dart';
```

- [ ] **Step 3: Add the primary button** to `_disconnectedBody`, above the existing client-id `TextField` (which stays as the BYO path). Insert after `Text(l10n.settings_lightroom_subtitle)` + spacing:

```dart
        FilledButton.icon(
          onPressed: _busy ? null : _connectEmbedded,
          icon: const Icon(Icons.link),
          label: Text(l10n.settings_lightroom_connectEmbedded),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.settings_lightroom_advancedByo,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
```

(`settings_lightroom_advancedByo` = a short header like "Use your own Adobe credentials".)

- [ ] **Step 4: Add the localized strings.** In `lib/l10n/arb/app_en.arb`:

```json
"settings_lightroom_connectEmbedded": "Connect with Adobe",
"@settings_lightroom_connectEmbedded": { "description": "Primary button to connect Lightroom with the app's bundled Adobe credential" },
"settings_lightroom_advancedByo": "Use your own Adobe credentials",
"@settings_lightroom_advancedByo": { "description": "Header for the advanced BYO client-id connect path" },
```

Add the same two keys with translated values to each of the 10 other locale ARBs (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`), then regenerate: `flutter gen-l10n`.

- [ ] **Step 5: Verify and commit**

Run: `flutter analyze lib/features/settings/presentation/pages/lightroom_settings_page.dart`
Run: `flutter test test/features/settings/presentation/pages/lightroom_settings_page_test.dart`
Expected: analyze clean; existing settings tests still pass (the BYO fields and `_connect` behavior are unchanged; `_finishConnect` is the same logic extracted).

```bash
dart format lib/features/settings/presentation/pages/lightroom_settings_page.dart lib/l10n/arb/
git add lib/features/settings/presentation/pages/lightroom_settings_page.dart lib/l10n/arb/
git commit -m "feat(lightroom): one-tap embedded Connect with Adobe on the settings page"
```

---

### Task 5: Register the embedded custom scheme natively (iOS / Android / macOS)

**Files:**
- Modify: `ios/Runner/Info.plist` (`CFBundleURLTypes`)
- Modify: `android/app/src/main/AndroidManifest.xml` (`MainActivity` intent-filter)
- Modify: `macos/Runner/Info.plist` (`CFBundleURLTypes`)

**Interfaces:** none (native config). Verified on-device, not by unit test.

- [ ] **Step 1: iOS.** In `ios/Runner/Info.plist`, add a second dict to the existing `CFBundleURLTypes` array (which already holds the Google Sign-In scheme):

```xml
			<dict>
				<key>CFBundleTypeRole</key>
				<string>Editor</string>
				<key>CFBundleURLName</key>
				<string>app.submersion.lightroom</string>
				<key>CFBundleURLSchemes</key>
				<array>
					<string>adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d</string>
				</array>
			</dict>
```

- [ ] **Step 2: Android.** In `android/app/src/main/AndroidManifest.xml`, add an intent-filter inside the existing `<activity android:name=".MainActivity" …>` block (a callback activity is provided by flutter_web_auth_2, but registering the scheme on MainActivity is the documented setup; follow the flutter_web_auth_2 README for the exact `com.linusu.flutter_web_auth_2.CallbackActivity` entry, adding it inside `<application>`):

```xml
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d" />
            </intent-filter>
        </activity>
```

- [ ] **Step 3: macOS.** In `macos/Runner/Info.plist`, add (or extend) `CFBundleURLTypes`:

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>app.submersion.lightroom</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 4: Device verification (manual, owner account).** On macOS (or iOS): run the app, Settings → Photos & Media → Lightroom → **Connect with Adobe**, sign in with the owner's Adobe ID, approve. The browser must return to the app automatically (no paste) and the account must appear connected. Then run a trip scan and confirm a photo attaches. **This is the run that produces the demo video.**

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml macos/Runner/Info.plist
git commit -m "chore(lightroom): register embedded Adobe redirect scheme (iOS/Android/macOS)"
```

---

## Self-Review

**Spec coverage (`2026-07-17-lightroom-native-app-connect-design.md`):**
- §2 "add flutter_web_auth_2 / capture wrapper" → Tasks 1–2. "embedded default client id" → Task 1. "native scheme registration" → Task 5. "one-tap Connect" → Task 4.
- §4 "flutter_web_auth_2.authenticate with callbackUrlScheme; non-ephemeral" → Task 2. "beginAuthorization(clientId, redirectUri) → capture → completeAuthorization" → Task 3.
- §6 iOS/Android/macOS custom-scheme capture → Task 5. **Windows/Linux desktop capture is deferred** (design §6 open item — loopback-vs-OS-scheme-vs-copy-paste); on those platforms the embedded button will surface the capture error until that lands. Track as Plan 2b.
- §8 entitlement error (embedded, pre-approval, non-owner) → surfaced via the snackbar in Task 4's `_connectEmbedded` catch; a dedicated "pending approval" message is a Task-4 follow-up if the raw Adobe error reads poorly during beta.

**Deferred (not gaps):** the BYO setup wizard (Plan 3), removing `clientSecret` from the UI/manager (Plan 3, once the BYO wizard replaces the raw secret field), and Windows/Linux capture (Plan 2b).

**Placeholder scan:** none — every code step is complete. Bracketed items in Task 4 Step 4 (translated ARB values) are per-locale translations to author, not code placeholders.

**Type consistency:** `LightroomRedirectCapture.capture({authorizeUrl, callbackScheme})` is defined in Task 2 and called identically in Task 3; `signInWithEmbeddedCredential({authManager, capture})` defined in Task 3 and called in Task 4; `LightroomEmbeddedCredential.{clientId,redirectUri,callbackScheme}` defined in Task 1 and used in Tasks 3–5 with the same scheme string throughout.
