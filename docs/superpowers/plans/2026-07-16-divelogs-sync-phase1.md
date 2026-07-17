# divelogs.de Sync — Phase 1 (Account + Pull Dives) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a divelogs.de connected account and a "From divelogs.de" import source that pulls a user's entire divelogs.de logbook into Submersion through the existing universal-import pipeline.

**Architecture:** A new `AccountKind.divelogs` connector account stores username/password/JWT in the keychain via `AccountCredentialsStore`. A REST client (`package:http`, 401-retry-once, single-flight login) fetches dives as JSON; a mapper converts them into the untyped `ImportPayload` entity maps that `UddfEntityImporter` already consumes, so dedup (`ImportDuplicateChecker`), site matching, review UI, and commit are all inherited. A thin wizard adapter subclasses `UniversalAdapter`, replacing the file-selection steps with a sign-in-and-fetch step.

**Tech Stack:** Flutter/Dart, Riverpod (plain, no codegen), Drift, `package:http` (+ `MockClient` for tests), `flutter_secure_storage` via `FallbackSecureStorage`.

**Spec:** `docs/superpowers/specs/2026-07-16-divelogs-de-sync-design.md`

## Global Constraints

- Domain units are canonical metric: depths meters, pressures bar, temps Celsius, weights kg, gas fractions percent 0–100. divelogs.de JSON is assumed metric (spec open question 1) — no conversion layer.
- All work happens in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/divelogs-sync` on branch `worktree-divelogs-sync`. Run all commands from the worktree root. Never touch the main checkout.
- `dart format .` must produce no changes before every commit (pre-push hook enforces; never pipe `flutter analyze` through `tail`).
- No emojis in code, comments, or docs. Commit messages have NO Co-Authored-By line and NO session URL.
- New user-facing strings go into `lib/l10n/arb/app_en.arb` AND all 10 non-English locales (es, fr, de, it, nl, pt, hu, he, zh, ar), then regenerate with `flutter gen-l10n`.
- Run tests per-file (`flutter test <file>`), never the whole suite mid-task (it is long-running).
- API base URL: `https://divelogs.de/api`. Login: `POST /login` multipart form fields `user`, `pass` → JWT. All other calls: `Authorization: Bearer <jwt>`; 401 means token expired or credentials revoked.
- The remote dive id is recorded as `sourceUuid` = `divelogs:<id>` (drives Pass-0 exact dedup and future phases).
- Drift codegen: after any `database.dart` table change run `dart run build_runner build --delete-conflicting-outputs`.

---

### Task 1: `AccountKind.divelogs` enum case + exhaustive switches

**Files:**
- Modify: `lib/core/services/accounts/account_kind.dart`
- Modify: `lib/features/settings/presentation/pages/connected_accounts_page.dart` (~line 76, `_AccountTile._icon`)
- Modify: `lib/core/services/accounts/account_startup_migration.dart` (~line 89 rekey switch, ~line 186 `_labelFor`)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (~line 342, `_legacyKeyFor`)
- Test: `test/core/services/accounts/account_kind_test.dart` (create)

**Interfaces:**
- Consumes: nothing new.
- Produces: `AccountKind.divelogs` (enum value; `cloudProviderType == null`; display label `'divelogs.de'`) used by every later task.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/accounts/account_kind_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';

void main() {
  group('AccountKind.divelogs', () {
    test('has no cloud provider type (connector kind)', () {
      expect(AccountKind.divelogs.cloudProviderType, isNull);
    });

    test('round-trips through name for DB persistence', () {
      expect(
        AccountKind.values.byName(AccountKind.divelogs.name),
        AccountKind.divelogs,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/accounts/account_kind_test.dart`
Expected: FAIL — compile error, `divelogs` is not a member of `AccountKind`.

- [ ] **Step 3: Add the enum value and update every exhaustive switch**

In `lib/core/services/accounts/account_kind.dart` add the value and the `cloudProviderType` case (`fromCloudProviderType` switches over `CloudProviderType` and needs NO change):

```dart
enum AccountKind {
  dropbox,
  googledrive,
  icloud,
  s3,
  adobeLightroom,
  divelogs;

  CloudProviderType? get cloudProviderType => switch (this) {
    AccountKind.dropbox => CloudProviderType.dropbox,
    AccountKind.googledrive => CloudProviderType.googledrive,
    AccountKind.icloud => CloudProviderType.icloud,
    AccountKind.s3 => CloudProviderType.s3,
    AccountKind.adobeLightroom => null,
    AccountKind.divelogs => null,
  };
  // fromCloudProviderType unchanged
}
```

Then run `flutter analyze` and fix EVERY "missing case" error it reports. Known sites (verify analyze finds no others):

`connected_accounts_page.dart` `_icon` switch — add:
```dart
  AccountKind.divelogs => Icons.travel_explore_outlined,
```

`account_startup_migration.dart` `_labelFor` — add:
```dart
  AccountKind.divelogs => 'divelogs.de',
```
and in the rekey switch (~line 89), add `AccountKind.divelogs` to the group of kinds that have no legacy key to migrate (same treatment as `adobeLightroom`).

`sync_providers.dart` `_legacyKeyFor` — add a case returning `null` (non-sync connector kind).

- [ ] **Step 4: Run test and analyze to verify they pass**

Run: `flutter test test/core/services/accounts/account_kind_test.dart && flutter analyze`
Expected: test PASS; analyze reports no errors.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: add AccountKind.divelogs connector kind"
```

---

### Task 2: `diverId` binding column on `connected_accounts`

**Files:**
- Modify: `lib/core/database/database.dart` (table ~line 1104, `currentSchemaVersion` ~line 2208, `_assertConnectedAccountsSchema` ~line 2354, onUpgrade ladder ~line 5538, beforeOpen backstop ~line 5547)
- Modify: `lib/core/services/accounts/connected_account.dart`
- Modify: `lib/core/data/repositories/connected_accounts_repository.dart`
- Test: extend `test/core/data/repositories/connected_accounts_repository_test.dart` if it exists; otherwise extend `test/core/services/accounts/account_provider_registry_test.dart`'s fixture builders and add repository assertions in a new `test/core/data/repositories/connected_accounts_diver_binding_test.dart` following the DB-test setup used by the existing connected-accounts tests (locate with `grep -rl "ConnectedAccountsRepository" test/`).

**Interfaces:**
- Consumes: Task 1's enum value (tests may use it).
- Produces: `ConnectedAccount.diverId` (`String?` field + constructor param + `copyWith`); `ConnectedAccountsRepository.create({required AccountKind kind, required String label, String? accountIdentifier, String? id, String? diverId})`.

**Schema version:** the ladder moves fast in this repo. Before writing the migration, check the CURRENT `currentSchemaVersion` in this worktree's `database.dart` AND versions claimed by open PRs (`gh pr list --state open --json number,title` + memory `schema-version-ladder`). At plan-writing time the worktree is at 112 with v113/v114 claimed by open PRs #600 and #601, so use **115**. Adjust if the ladder has moved; use one consistent number everywhere below.

- [ ] **Step 1: Write the failing test**

In the located repository test file add:

```dart
test('create persists and round-trips diverId', () async {
  final repo = ConnectedAccountsRepository();
  final account = await repo.create(
    kind: AccountKind.divelogs,
    label: 'divelogs.de',
    accountIdentifier: 'rainer',
    diverId: 'diver-1',
  );
  expect(account.diverId, 'diver-1');
  final loaded = await repo.getById(account.id);
  expect(loaded?.diverId, 'diver-1');
});
```

(Match the file's existing setup — in-memory `DatabaseService` initialization — exactly as its sibling tests do.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test <that file>`
Expected: FAIL — `create` has no `diverId` parameter.

- [ ] **Step 3: Add the column, migration, and self-heal backstop**

In `database.dart`:

1. Table gains a nullable column:
```dart
class ConnectedAccounts extends Table {
  // ... existing columns ...
  TextColumn get diverId => text().nullable()();
```

2. `static const int currentSchemaVersion = 115;` (see Schema version note above).

3. New idempotent helper next to `_assertEquipmentThicknessColumn` (copy its shape exactly):
```dart
Future<void> _assertConnectedAccountsDiverIdColumn() async {
  final cols = await customSelect(
    "PRAGMA table_info('connected_accounts')",
  ).get();
  final hasDiverId = cols.any((c) => c.read<String>('name') == 'diver_id');
  if (cols.isNotEmpty && !hasDiverId) {
    await customStatement(
      'ALTER TABLE connected_accounts ADD COLUMN diver_id TEXT',
    );
  }
}
```

4. In onUpgrade, after the `if (from < 112)` block:
```dart
if (from < 115) {
  await _assertConnectedAccountsDiverIdColumn();
}
if (from < 115) await reportProgress();
```

5. In the `beforeOpen` backstop list, add `await _assertConnectedAccountsDiverIdColumn();` after the existing `_assertEquipmentThicknessColumn()` call.

6. Add `diver_id TEXT` to the `CREATE TABLE IF NOT EXISTS connected_accounts (...)` DDL inside `_assertConnectedAccountsSchema` so fresh self-healed tables include it.

Run codegen: `dart run build_runner build --delete-conflicting-outputs`

In `connected_account.dart` add the field, constructor param, and carry it through `copyWith`:
```dart
final String? diverId;
// constructor: this.diverId,
// copyWith: diverId stays fixed (not a copyWith param — bindings don't change after creation)
```
(In `copyWith`, pass `diverId: diverId` through to the new instance.)

In `connected_accounts_repository.dart`: `create()` gains `String? diverId` and writes `diverId: Value(diverId)` into the companion; `_toDomain` maps `diverId: row.diverId`.

Note: sync serialization needs NO manual change — `sync_data_serializer.dart` uses the drift-generated `ConnectedAccount.fromJson(...).toCompanion(false)` generically (verified at lines 1900 and 2321), so the new column rides along after codegen.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test <repository test file> test/core/services/accounts/ && flutter analyze`
Expected: PASS, no analyze errors.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: bind connected accounts to a diver via diver_id column (v115)"
```

---

### Task 3: Divelogs credentials model + auth manager

**Files:**
- Create: `lib/core/services/divelogs/divelogs_credentials.dart`
- Create: `lib/core/services/divelogs/divelogs_auth_manager.dart`
- Test: `test/core/services/divelogs/divelogs_auth_manager_test.dart`

**Interfaces:**
- Consumes: `AccountCredentialsStore` (`read/write/delete(accountId)`), `package:http`.
- Produces:
  - `DivelogsCredentials({required String username, required String password, String? bearerToken})` with `toJsonString()` / `static DivelogsCredentials? fromJsonString(String?)` / `copyWith({String? bearerToken})`.
  - `DivelogsAuthManager({required AccountCredentialsStore credentials, required String accountId, http.Client? httpClient})` with `Future<String> getToken()`, `void invalidateToken()`, `Future<void> disconnect()`.
  - `static Future<String> DivelogsAuthManager.login({required String username, required String password, http.Client? httpClient})` — unauthenticated; used by the connect step to validate before an account exists.
  - `class DivelogsAuthException implements Exception { final String message; }`

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/divelogs/divelogs_auth_manager_test.dart` (uses the existing `InMemoryKeychain` fake — import path pattern per `test/core/services/accounts/account_credentials_store_test.dart`, e.g. `../../support/fake_keychain_storage.dart` adjusted for depth):

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth_manager.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late AccountCredentialsStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = AccountCredentialsStore(
      storage: keychain as FlutterSecureStorage,
    );
  });

  MockClient loginOk({String token = 'jwt-1', List<http.Request>? log}) =>
      MockClient((req) async {
        log?.add(req);
        expect(req.url.path, '/api/login');
        return http.Response(jsonEncode({'bearer_token': token}), 200);
      });

  Future<void> seedCreds({String? token}) => store.write(
    'acc-1',
    DivelogsCredentials(
      username: 'eric',
      password: 'secret',
      bearerToken: token,
    ).toJsonString(),
  );

  test('login returns token from bearer_token field', () async {
    final token = await DivelogsAuthManager.login(
      username: 'eric',
      password: 'secret',
      httpClient: loginOk(),
    );
    expect(token, 'jwt-1');
  });

  test('login throws DivelogsAuthException on 401', () async {
    final client = MockClient((_) async => http.Response('', 401));
    expect(
      () => DivelogsAuthManager.login(
        username: 'eric',
        password: 'bad',
        httpClient: client,
      ),
      throwsA(isA<DivelogsAuthException>()),
    );
  });

  test('getToken uses persisted token without hitting network', () async {
    await seedCreds(token: 'persisted');
    final manager = DivelogsAuthManager(
      credentials: store,
      accountId: 'acc-1',
      httpClient: MockClient((_) async => fail('no network call expected')),
    );
    expect(await manager.getToken(), 'persisted');
  });

  test('getToken logs in when no token persisted and persists result',
      () async {
    await seedCreds();
    final manager = DivelogsAuthManager(
      credentials: store,
      accountId: 'acc-1',
      httpClient: loginOk(token: 'fresh'),
    );
    expect(await manager.getToken(), 'fresh');
    final blob = DivelogsCredentials.fromJsonString(await store.read('acc-1'));
    expect(blob?.bearerToken, 'fresh');
  });

  test('getToken is single-flight for concurrent callers', () async {
    await seedCreds();
    final log = <http.Request>[];
    final manager = DivelogsAuthManager(
      credentials: store,
      accountId: 'acc-1',
      httpClient: loginOk(log: log),
    );
    final results = await Future.wait([
      manager.getToken(),
      manager.getToken(),
      manager.getToken(),
    ]);
    expect(results.toSet(), {'jwt-1'});
    expect(log.length, 1);
  });

  test('invalidateToken forces a fresh login ignoring persisted token',
      () async {
    await seedCreds(token: 'stale');
    final manager = DivelogsAuthManager(
      credentials: store,
      accountId: 'acc-1',
      httpClient: loginOk(token: 'renewed'),
    );
    expect(await manager.getToken(), 'stale');
    manager.invalidateToken();
    expect(await manager.getToken(), 'renewed');
  });

  test('disconnect deletes the credentials blob', () async {
    await seedCreds(token: 't');
    final manager = DivelogsAuthManager(credentials: store, accountId: 'acc-1');
    await manager.disconnect();
    expect(await store.read('acc-1'), isNull);
  });

  test('getToken throws when not signed in', () async {
    final manager = DivelogsAuthManager(credentials: store, accountId: 'acc-1');
    expect(() => manager.getToken(), throwsA(isA<DivelogsAuthException>()));
  });
}
```

(If `InMemoryKeychain` doesn't implement `FlutterSecureStorage` directly, mirror the constructor usage from `account_credentials_store_test.dart` verbatim instead of casting.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/divelogs/divelogs_auth_manager_test.dart`
Expected: FAIL — files under `lib/core/services/divelogs/` don't exist.

- [ ] **Step 3: Implement the model and manager**

`lib/core/services/divelogs/divelogs_credentials.dart`:

```dart
import 'dart:convert';

/// Keychain payload for a divelogs.de account.
///
/// The password is stored because divelogs.de issues expiring JWTs with no
/// refresh grant; re-login is the only renewal path.
class DivelogsCredentials {
  final String username;
  final String password;
  final String? bearerToken;

  const DivelogsCredentials({
    required this.username,
    required this.password,
    this.bearerToken,
  });

  DivelogsCredentials copyWith({String? bearerToken}) => DivelogsCredentials(
    username: username,
    password: password,
    bearerToken: bearerToken ?? this.bearerToken,
  );

  String toJsonString() => jsonEncode({
    'username': username,
    'password': password,
    if (bearerToken != null) 'bearerToken': bearerToken,
  });

  static DivelogsCredentials? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final username = decoded['username'] as String?;
    final password = decoded['password'] as String?;
    if (username == null || password == null) return null;
    return DivelogsCredentials(
      username: username,
      password: password,
      bearerToken: decoded['bearerToken'] as String?,
    );
  }
}
```

`lib/core/services/divelogs/divelogs_auth_manager.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';

class DivelogsAuthException implements Exception {
  final String message;
  const DivelogsAuthException(this.message);

  @override
  String toString() => 'DivelogsAuthException: $message';
}

/// Owns the divelogs.de JWT lifecycle for one connected account.
///
/// divelogs.de has no OAuth: POST /login with username/password returns a
/// JWT. Renewal is 401-driven — the API client calls [invalidateToken] and
/// retries once, which triggers a fresh login here.
class DivelogsAuthManager {
  DivelogsAuthManager({
    required AccountCredentialsStore credentials,
    required this.accountId,
    http.Client? httpClient,
  }) : _credentials = credentials,
       _http = httpClient ?? http.Client();

  static final Uri loginUri = Uri.parse('https://divelogs.de/api/login');

  final AccountCredentialsStore _credentials;
  final String accountId;
  final http.Client _http;

  String? _cachedToken;
  bool _forceRelogin = false;
  Future<String>? _loginInFlight;

  /// Unauthenticated login. Used by the connect flow to validate credentials
  /// before a ConnectedAccount exists, and internally for renewal.
  static Future<String> login({
    required String username,
    required String password,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final request = http.MultipartRequest('POST', loginUri)
      ..fields['user'] = username
      ..fields['pass'] = password;
    final http.Response response;
    try {
      response = await http.Response.fromStream(await client.send(request));
    } on Exception {
      throw const DivelogsAuthException('Could not reach divelogs.de.');
    }
    if (response.statusCode == 401) {
      throw const DivelogsAuthException(
        'divelogs.de rejected the username or password.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DivelogsAuthException(
        'divelogs.de login failed (HTTP ${response.statusCode}).',
      );
    }
    final token = _extractToken(response.body);
    if (token == null) {
      throw const DivelogsAuthException(
        'divelogs.de login response did not contain a token.',
      );
    }
    return token;
  }

  static String? _extractToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final key in const ['bearer_token', 'token', 'access_token']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } on FormatException {
      // fall through
    }
    return null;
  }

  Future<String> getToken() {
    final cached = _cachedToken;
    if (cached != null) return Future.value(cached);
    return _loginInFlight ??= _resolveToken().whenComplete(() {
      _loginInFlight = null;
    });
  }

  Future<String> _resolveToken() async {
    final stored = DivelogsCredentials.fromJsonString(
      await _credentials.read(accountId),
    );
    if (stored == null) {
      throw const DivelogsAuthException('Not signed in to divelogs.de.');
    }
    final persisted = stored.bearerToken;
    if (!_forceRelogin && persisted != null && persisted.isNotEmpty) {
      _cachedToken = persisted;
      return persisted;
    }
    final token = await login(
      username: stored.username,
      password: stored.password,
      httpClient: _http,
    );
    _forceRelogin = false;
    _cachedToken = token;
    await _credentials.write(
      accountId,
      stored.copyWith(bearerToken: token).toJsonString(),
    );
    return token;
  }

  /// Called by the API client when a request came back 401.
  void invalidateToken() {
    _cachedToken = null;
    _forceRelogin = true;
  }

  Future<void> disconnect() async {
    _cachedToken = null;
    _forceRelogin = false;
    await _credentials.delete(accountId);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/divelogs/divelogs_auth_manager_test.dart`
Expected: PASS (all 8 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib/core/services/divelogs test/core/services/divelogs
git commit -m "feat: add divelogs.de credentials model and JWT auth manager"
```

---

### Task 4: divelogs.de API client + JSON models

**Files:**
- Create: `lib/core/services/divelogs/divelogs_models.dart`
- Create: `lib/core/services/divelogs/divelogs_api_client.dart`
- Test: `test/core/services/divelogs/divelogs_models_test.dart`
- Test: `test/core/services/divelogs/divelogs_api_client_test.dart`

**Interfaces:**
- Consumes: Task 3's `DivelogsAuthManager` shape only via callbacks (client stays auth-agnostic, mirroring `DropboxApiClient`).
- Produces:
  - `class DivelogsSample { final double depth; final double? temperature; }`
  - `class DivelogsTank { final double? o2, he, startPressure, endPressure, volume, workingPressure; final bool dbltank; final String? name; }`
  - `class DivelogsDive { final String? id; final DateTime dateTime; final int durationSeconds; final double maxDepth; final double? meanDepth, latitude, longitude, airTemp, depthTemp, surfaceTemp, weightsKg; final int? sampleRateSeconds, surfaceIntervalSeconds; final List<DivelogsSample> samples; final List<DivelogsTank> tanks; final String? buddy, siteName, location, notes, weather, visibility, boat, dcModel; factory DivelogsDive.fromJson(Map<String, dynamic>) }` — throws `FormatException` when mandatory `date`/`time`/`duration`/`maxdepth` are missing/unparseable.
  - `class DivelogsDivesResult { final List<DivelogsDive> dives; final int skippedCount; }`
  - `class DivelogsApiException implements Exception { final int statusCode; final String message; }`
  - `DivelogsApiClient({required Future<String> Function() getBearerToken, required void Function() onTokenRejected, http.Client? httpClient, Uri? baseUri})` with `Future<Map<String, dynamic>> getUser()` and `Future<DivelogsDivesResult> getAllDives()`.

- [ ] **Step 1: Write failing model tests**

Create `test/core/services/divelogs/divelogs_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';

void main() {
  Map<String, dynamic> minimal() => {
    'id': 4711,
    'date': '2022-09-03',
    'time': '14:42:00',
    'duration': 2808,
    'maxdepth': 12,
  };

  test('parses mandatory fields', () {
    final dive = DivelogsDive.fromJson(minimal());
    expect(dive.id, '4711');
    expect(dive.dateTime, DateTime(2022, 9, 3, 14, 42));
    expect(dive.durationSeconds, 2808);
    expect(dive.maxDepth, 12.0);
    expect(dive.samples, isEmpty);
    expect(dive.tanks, isEmpty);
  });

  test('throws FormatException when a mandatory field is missing', () {
    final json = minimal()..remove('maxdepth');
    expect(() => DivelogsDive.fromJson(json), throwsFormatException);
  });

  test('parses mixed sampledata (bare depths and {d,t} objects)', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'samplerate': 10,
      'sampledata': [
        {'d': 1, 't': 13},
        10,
        {'d': 17, 't': 12},
        0,
      ],
    });
    expect(dive.sampleRateSeconds, 10);
    expect(dive.samples, hasLength(4));
    expect(dive.samples[0].depth, 1.0);
    expect(dive.samples[0].temperature, 13.0);
    expect(dive.samples[1].depth, 10.0);
    expect(dive.samples[1].temperature, isNull);
  });

  test('parses tanks', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'tanks': [
        {
          'o2': 28,
          'he': 0,
          'start_pressure': 214.56,
          'end_pressure': 103,
          'vol': 12,
          'wp': 200,
          'dbltank': false,
          'tankname': 'Main',
        },
      ],
    });
    expect(dive.tanks, hasLength(1));
    final tank = dive.tanks.single;
    expect(tank.o2, 28.0);
    expect(tank.startPressure, 214.56);
    expect(tank.endPressure, 103.0);
    expect(tank.volume, 12.0);
    expect(tank.workingPressure, 200.0);
    expect(tank.name, 'Main');
  });

  test('parses optional metadata fields', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'meandepth': 7.9,
      'buddy': 'Buddy',
      'divesite': 'Shinenead',
      'location': 'Aegypten, Rotes Meer',
      'lat': 24.669683,
      'lng': 35.125225,
      'notes': 'nice dive',
      'weather': 'sunny',
      'visibility': 'good',
      'airtemp': 28,
      'depthtemp': 21,
      'surfacetemp': 26,
      'weights': 4,
      'surface_interval': 3600,
      'dc_model': 'Suunto D6',
    });
    expect(dive.meanDepth, 7.9);
    expect(dive.buddy, 'Buddy');
    expect(dive.siteName, 'Shinenead');
    expect(dive.latitude, closeTo(24.669683, 1e-9));
    expect(dive.depthTemp, 21.0);
    expect(dive.weightsKg, 4.0);
    expect(dive.surfaceIntervalSeconds, 3600);
    expect(dive.dcModel, 'Suunto D6');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/divelogs/divelogs_models_test.dart`
Expected: FAIL — `divelogs_models.dart` doesn't exist.

- [ ] **Step 3: Implement `divelogs_models.dart`**

```dart
/// Typed views over the divelogs.de REST API JSON.
///
/// Field names and semantics follow the OpenAPI spec at
/// https://divelogs.de/api/docs/divelogs-openapi3.json. All values are
/// metric (meters, bar, Celsius, kg).
library;

double? _asDouble(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

int? _asInt(Object? v) => switch (v) {
  num n => n.toInt(),
  String s => int.tryParse(s),
  _ => null,
};

String? _asNonEmptyString(Object? v) {
  if (v is! String) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class DivelogsSample {
  final double depth;
  final double? temperature;

  const DivelogsSample({required this.depth, this.temperature});
}

class DivelogsTank {
  final double? o2;
  final double? he;
  final double? startPressure;
  final double? endPressure;
  final double? volume;
  final double? workingPressure;
  final bool dbltank;
  final String? name;

  const DivelogsTank({
    this.o2,
    this.he,
    this.startPressure,
    this.endPressure,
    this.volume,
    this.workingPressure,
    this.dbltank = false,
    this.name,
  });

  factory DivelogsTank.fromJson(Map<String, dynamic> json) => DivelogsTank(
    o2: _asDouble(json['o2']),
    he: _asDouble(json['he']),
    startPressure: _asDouble(json['start_pressure']),
    endPressure: _asDouble(json['end_pressure']),
    volume: _asDouble(json['vol']),
    workingPressure: _asDouble(json['wp']),
    dbltank: json['dbltank'] == true,
    name: _asNonEmptyString(json['tankname']) ?? _asNonEmptyString(json['tank']),
  );
}

class DivelogsDive {
  final String? id;
  final DateTime dateTime;
  final int durationSeconds;
  final double maxDepth;
  final double? meanDepth;
  final int? sampleRateSeconds;
  final List<DivelogsSample> samples;
  final List<DivelogsTank> tanks;
  final String? buddy;
  final String? siteName;
  final String? location;
  final String? notes;
  final String? weather;
  final String? visibility;
  final String? boat;
  final String? dcModel;
  final double? latitude;
  final double? longitude;
  final double? airTemp;
  final double? depthTemp;
  final double? surfaceTemp;
  final double? weightsKg;
  final int? surfaceIntervalSeconds;

  const DivelogsDive({
    this.id,
    required this.dateTime,
    required this.durationSeconds,
    required this.maxDepth,
    this.meanDepth,
    this.sampleRateSeconds,
    this.samples = const [],
    this.tanks = const [],
    this.buddy,
    this.siteName,
    this.location,
    this.notes,
    this.weather,
    this.visibility,
    this.boat,
    this.dcModel,
    this.latitude,
    this.longitude,
    this.airTemp,
    this.depthTemp,
    this.surfaceTemp,
    this.weightsKg,
    this.surfaceIntervalSeconds,
  });

  factory DivelogsDive.fromJson(Map<String, dynamic> json) {
    final date = _asNonEmptyString(json['date']);
    final time = _asNonEmptyString(json['time']) ?? '00:00:00';
    final duration = _asInt(json['duration']);
    final maxDepth = _asDouble(json['maxdepth']);
    if (date == null || duration == null || maxDepth == null) {
      throw FormatException('divelogs dive missing mandatory fields', json);
    }
    final DateTime dateTime;
    try {
      dateTime = DateTime.parse('$date $time');
    } on FormatException {
      throw FormatException('divelogs dive has unparseable date/time', json);
    }

    final samples = <DivelogsSample>[];
    final sampleData = json['sampledata'];
    if (sampleData is List) {
      for (final entry in sampleData) {
        if (entry is num) {
          samples.add(DivelogsSample(depth: entry.toDouble()));
        } else if (entry is Map) {
          final d = _asDouble(entry['d']);
          if (d != null) {
            samples.add(
              DivelogsSample(depth: d, temperature: _asDouble(entry['t'])),
            );
          }
        }
      }
    }

    final tanks = <DivelogsTank>[];
    final tanksJson = json['tanks'];
    if (tanksJson is List) {
      for (final t in tanksJson) {
        if (t is Map) {
          tanks.add(DivelogsTank.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    final rawId = json['id'] ?? json['dive_id'];
    return DivelogsDive(
      id: rawId == null ? null : '$rawId',
      dateTime: dateTime,
      durationSeconds: duration,
      maxDepth: maxDepth,
      meanDepth: _asDouble(json['meandepth']),
      sampleRateSeconds: _asInt(json['samplerate']),
      samples: samples,
      tanks: tanks,
      buddy: _asNonEmptyString(json['buddy']),
      siteName: _asNonEmptyString(json['divesite']),
      location: _asNonEmptyString(json['location']),
      notes: _asNonEmptyString(json['notes']),
      weather: _asNonEmptyString(json['weather']),
      visibility: _asNonEmptyString(json['visibility']),
      boat: _asNonEmptyString(json['boat']),
      dcModel: _asNonEmptyString(json['dc_model']),
      latitude: _asDouble(json['lat']),
      longitude: _asDouble(json['lng']),
      airTemp: _asDouble(json['airtemp']),
      depthTemp: _asDouble(json['depthtemp']),
      surfaceTemp: _asDouble(json['surfacetemp']),
      weightsKg: _asDouble(json['weights']),
      surfaceIntervalSeconds: _asInt(json['surface_interval']),
    );
  }
}

class DivelogsDivesResult {
  final List<DivelogsDive> dives;
  final int skippedCount;

  const DivelogsDivesResult({required this.dives, this.skippedCount = 0});
}
```

Note: `airtemp`/`weights` examples in the spec show `0` for "not set" — mapping of zero-vs-null is handled in the mapper (Task 5), not here; the model reports what the API sent.

- [ ] **Step 4: Run model tests**

Run: `flutter test test/core/services/divelogs/divelogs_models_test.dart`
Expected: PASS.

- [ ] **Step 5: Write failing API client tests**

Create `test/core/services/divelogs/divelogs_api_client_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';

void main() {
  Map<String, dynamic> diveJson(int id) => {
    'id': id,
    'date': '2022-09-03',
    'time': '14:42:00',
    'duration': 2808,
    'maxdepth': 12,
  };

  DivelogsApiClient client(
    Future<http.Response> Function(http.Request) handler, {
    void Function()? onRejected,
    List<String>? tokens,
  }) {
    final queue = List<String>.from(tokens ?? ['t1']);
    return DivelogsApiClient(
      getBearerToken: () async =>
          queue.length > 1 ? queue.removeAt(0) : queue.first,
      onTokenRejected: onRejected ?? () {},
      httpClient: MockClient(handler),
    );
  }

  test('getAllDives sends bearer header and parses array body', () async {
    late http.Request captured;
    final api = client((req) async {
      captured = req;
      return http.Response(jsonEncode([diveJson(1), diveJson(2)]), 200);
    });
    final result = await api.getAllDives();
    expect(captured.url.toString(), 'https://divelogs.de/api/dives');
    expect(captured.headers['Authorization'], 'Bearer t1');
    expect(result.dives, hasLength(2));
    expect(result.skippedCount, 0);
  });

  test('getAllDives tolerates object body with dives key', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode({'dives': [diveJson(1)]}),
        200,
      ),
    );
    final result = await api.getAllDives();
    expect(result.dives, hasLength(1));
  });

  test('getAllDives skips malformed dives and counts them', () async {
    final api = client(
      (req) async => http.Response(
        jsonEncode([diveJson(1), {'date': '2022-01-01'}]),
        200,
      ),
    );
    final result = await api.getAllDives();
    expect(result.dives, hasLength(1));
    expect(result.skippedCount, 1);
  });

  test('401 invalidates token and retries exactly once', () async {
    var rejections = 0;
    var calls = 0;
    final api = client(
      (req) async {
        calls++;
        if (req.headers['Authorization'] == 'Bearer t1') {
          return http.Response('', 401);
        }
        return http.Response(jsonEncode([diveJson(1)]), 200);
      },
      onRejected: () => rejections++,
      tokens: ['t1', 't2'],
    );
    final result = await api.getAllDives();
    expect(result.dives, hasLength(1));
    expect(rejections, 1);
    expect(calls, 2);
  });

  test('second 401 throws DivelogsApiException', () async {
    final api = client((req) async => http.Response('', 401));
    expect(
      () => api.getAllDives(),
      throwsA(
        isA<DivelogsApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });

  test('getUser returns decoded map', () async {
    final api = client(
      (req) async => http.Response(jsonEncode({'username': 'eric'}), 200),
    );
    final user = await api.getUser();
    expect(user['username'], 'eric');
  });
}
```

- [ ] **Step 6: Run to verify failure, then implement `divelogs_api_client.dart`**

Run: `flutter test test/core/services/divelogs/divelogs_api_client_test.dart` — expect FAIL (file missing). Then:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:submersion/core/services/divelogs/divelogs_models.dart';

class DivelogsApiException implements Exception {
  final int statusCode;
  final String message;
  const DivelogsApiException(this.statusCode, this.message);

  @override
  String toString() => 'DivelogsApiException($statusCode): $message';
}

/// Thin typed wrapper over the divelogs.de REST API.
///
/// Auth is delegated to callbacks (mirrors DropboxApiClient): on 401 the
/// client calls [onTokenRejected] (which invalidates the manager's token)
/// and retries exactly once with a freshly resolved token.
class DivelogsApiClient {
  DivelogsApiClient({
    required Future<String> Function() getBearerToken,
    required void Function() onTokenRejected,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _getBearerToken = getBearerToken,
       _onTokenRejected = onTokenRejected,
       _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://divelogs.de/api');

  final Future<String> Function() _getBearerToken;
  final void Function() _onTokenRejected;
  final http.Client _http;
  final Uri _baseUri;

  Future<Map<String, dynamic>> getUser() async {
    final response = await _get('/user');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const DivelogsApiException(0, 'Unexpected /user response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<DivelogsDivesResult> getAllDives() async {
    final response = await _get('/dives');
    final decoded = jsonDecode(response.body);
    final List<dynamic> rawDives;
    if (decoded is List) {
      rawDives = decoded;
    } else if (decoded is Map && decoded['dives'] is List) {
      rawDives = decoded['dives'] as List;
    } else {
      throw const DivelogsApiException(0, 'Unexpected /dives response');
    }
    final dives = <DivelogsDive>[];
    var skipped = 0;
    for (final raw in rawDives) {
      if (raw is! Map) {
        skipped++;
        continue;
      }
      try {
        dives.add(DivelogsDive.fromJson(Map<String, dynamic>.from(raw)));
      } on FormatException {
        skipped++;
      }
    }
    return DivelogsDivesResult(dives: dives, skippedCount: skipped);
  }

  Future<http.Response> _get(String path) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final http.Response response;
      try {
        response = await _http.get(
          _baseUri.replace(path: '${_baseUri.path}$path'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } on Exception {
        throw const DivelogsApiException(0, 'Could not reach divelogs.de.');
      }
      if (response.statusCode == 401) {
        _onTokenRejected();
        if (!authRetried) {
          authRetried = true;
          continue;
        }
        throw const DivelogsApiException(
          401,
          'divelogs.de sign-in expired. Sign in again in Settings.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DivelogsApiException(
          response.statusCode,
          'divelogs.de API error ${response.statusCode}',
        );
      }
      return response;
    }
  }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/core/services/divelogs/`
Expected: PASS (models + auth manager + api client).

- [ ] **Step 8: Commit**

```bash
dart format .
git add -A lib/core/services/divelogs test/core/services/divelogs
git commit -m "feat: add divelogs.de REST API client with 401-retry and JSON models"
```

---

### Task 5: `LogbookSyncCapable` + `DivelogsAccountAdapter` + registry

**Files:**
- Modify: `lib/core/services/accounts/account_provider_adapter.dart`
- Create: `lib/core/services/accounts/adapters/divelogs_account_adapter.dart`
- Modify: `lib/core/providers/account_providers.dart`
- Test: `test/core/services/accounts/adapters/divelogs_account_adapter_test.dart`

**Interfaces:**
- Consumes: Task 3 (`DivelogsAuthManager`, `DivelogsCredentials`), Task 1 (`AccountKind.divelogs`), `AccountCredentialsStore`.
- Produces: `abstract interface class LogbookSyncCapable {}` (marker; Phase 2 will add members); `DivelogsAccountAdapter({required AccountCredentialsStore credentials, http.Client? httpClient})` with `DivelogsAuthManager authManagerFor(ConnectedAccount account)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/accounts/adapters/divelogs_account_adapter_test.dart`, modeled line-for-line on `dropbox_account_adapter_test.dart`'s setup (InMemoryKeychain + inline `ConnectedAccount` fixtures with `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`):

```dart
// imports per dropbox_account_adapter_test.dart, plus:
// import 'package:submersion/core/services/accounts/adapters/divelogs_account_adapter.dart';
// import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';

void main() {
  late InMemoryKeychain keychain;
  late AccountCredentialsStore store;
  late DivelogsAccountAdapter adapter;

  ConnectedAccount account(String id) => ConnectedAccount(
    id: id,
    kind: AccountKind.divelogs,
    label: 'divelogs.de',
    accountIdentifier: 'eric',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  setUp(() {
    keychain = InMemoryKeychain();
    store = AccountCredentialsStore(storage: keychain);
    adapter = DivelogsAccountAdapter(credentials: store);
  });

  test('kind is divelogs and adapter is LogbookSyncCapable', () {
    expect(adapter.kind, AccountKind.divelogs);
    expect(adapter, isA<LogbookSyncCapable>());
  });

  test('status is needsSignIn without credentials, signedIn with', () async {
    expect(await adapter.status(account('a1')), AccountStatus.needsSignIn);
    await store.write(
      'a1',
      const DivelogsCredentials(username: 'e', password: 'p').toJsonString(),
    );
    expect(await adapter.status(account('a1')), AccountStatus.signedIn);
  });

  test('disconnect deletes only this account credentials', () async {
    await store.write(
      'a1',
      const DivelogsCredentials(username: 'e', password: 'p').toJsonString(),
    );
    await store.write(
      'a2',
      const DivelogsCredentials(username: 'f', password: 'q').toJsonString(),
    );
    await adapter.disconnect(account('a1'));
    expect(await store.read('a1'), isNull);
    expect(await store.read('a2'), isNotNull);
  });

  test('authManagerFor caches one manager per account id', () {
    final m1 = adapter.authManagerFor(account('a1'));
    expect(identical(m1, adapter.authManagerFor(account('a1'))), isTrue);
    expect(identical(m1, adapter.authManagerFor(account('a2'))), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/accounts/adapters/divelogs_account_adapter_test.dart`
Expected: FAIL — adapter file missing.

- [ ] **Step 3: Implement**

In `account_provider_adapter.dart`, append:

```dart
/// Marker: the account syncs with a third-party logbook service
/// (divelogs.de now). Phase 2 adds sync-plan members.
abstract interface class LogbookSyncCapable {}
```

Create `lib/core/services/accounts/adapters/divelogs_account_adapter.dart`:

```dart
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/divelogs/divelogs_auth_manager.dart';

class DivelogsAccountAdapter extends AccountProviderAdapter
    implements LogbookSyncCapable {
  DivelogsAccountAdapter({
    required AccountCredentialsStore credentials,
    http.Client? httpClient,
  }) : _credentials = credentials,
       _httpClient = httpClient;

  final AccountCredentialsStore _credentials;
  final http.Client? _httpClient;
  final Map<String, DivelogsAuthManager> _managers = {};

  @override
  AccountKind get kind => AccountKind.divelogs;

  DivelogsAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _managers.putIfAbsent(
        account.id,
        () => DivelogsAuthManager(
          credentials: _credentials,
          accountId: account.id,
          httpClient: _httpClient,
        ),
      );

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async {
    final blob = await _credentials.read(account.id);
    return (blob == null || blob.isEmpty)
        ? AccountStatus.needsSignIn
        : AccountStatus.signedIn;
  }

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    await authManagerFor(account).disconnect();
    _managers.remove(account.id);
  }
}
```

Register in `account_providers.dart` registry list:

```dart
    DivelogsAccountAdapter(
      credentials: ref.watch(accountCredentialsStoreProvider),
    ),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/accounts/ test/core/providers/account_providers_test.dart && flutter analyze`
Expected: PASS, no analyze errors.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: add divelogs.de account adapter with LogbookSyncCapable marker"
```

---

### Task 6: `DivelogsDiveMapper` — API models to ImportPayload entity maps

**Files:**
- Create: `lib/features/universal_import/data/services/divelogs_dive_mapper.dart`
- Test: `test/features/universal_import/data/services/divelogs_dive_mapper_test.dart`

**Interfaces:**
- Consumes: Task 4's `DivelogsDive`/`DivelogsTank`/`DivelogsSample`; `GasMix` from `package:submersion/features/dive_log/domain/entities/dive.dart`.
- Produces: `class DivelogsDiveMapper { const DivelogsDiveMapper(); Map<String, dynamic> mapDive(DivelogsDive dive); Map<String, dynamic>? mapSite(DivelogsDive dive); static String siteKey(String name); }`

The output keys MUST match what `UddfEntityImporter` reads (verified against `uddf_entity_importer.dart` `_importDives`/`_buildTanks`): `dateTime` (DateTime), `runtime` (Duration), `maxDepth`/`avgDepth`/`waterTemp`/`airTemp` (num), `buddy` (String), `buddyRefs` (List<String>), `notes` (String), `weightUsed` (double, importer appends "Weight used: X kg" to notes), `latitude`/`longitude` (double, becomes `entryLocation`), `diveComputerModel` (String), `surfaceInterval` (Duration), `sourceUuid` (String, feeds `DiveDataSources.source_uuid` and Pass-0 dedup), `site` (`{'uddfId': ..., 'name': ...}` — `uddfId` links to a sites-payload entity), `siteName` (String), `tanks` (list of maps with `gasMix` (GasMix), `startPressure`/`endPressure`/`workingPressure` (num), `volume` (**double**, importer casts `as double?` — always `.toDouble()`), `name`), `profile` (list of `{'timestamp': int seconds, 'depth': double, 'temperature': double?}`). Site payload maps use `name`, `uddfId`, `latitude`, `longitude`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';

void main() {
  const mapper = DivelogsDiveMapper();

  DivelogsDive dive({
    String? id = '4711',
    String? siteName = 'Shinenead',
    double? lat = 24.6,
    double? lng = 35.1,
  }) => DivelogsDive(
    id: id,
    dateTime: DateTime(2022, 9, 3, 14, 42),
    durationSeconds: 2808,
    maxDepth: 12,
    meanDepth: 7.9,
    sampleRateSeconds: 10,
    samples: const [
      DivelogsSample(depth: 1, temperature: 13),
      DivelogsSample(depth: 10),
    ],
    tanks: const [
      DivelogsTank(
        o2: 28,
        he: 0,
        startPressure: 214.56,
        endPressure: 103,
        volume: 12,
        workingPressure: 200,
      ),
    ],
    buddy: 'Buddy',
    siteName: siteName,
    location: 'Aegypten, Rotes Meer',
    notes: 'nice dive',
    weather: 'sunny',
    visibility: 'good',
    dcModel: 'Suunto D6',
    latitude: lat,
    longitude: lng,
    airTemp: 28,
    depthTemp: 21,
    surfaceTemp: 26,
    weightsKg: 4,
    surfaceIntervalSeconds: 3600,
  );

  test('maps core fields with importer-compatible keys', () {
    final map = mapper.mapDive(dive());
    expect(map['dateTime'], DateTime(2022, 9, 3, 14, 42));
    expect(map['runtime'], const Duration(seconds: 2808));
    expect(map['maxDepth'], 12.0);
    expect(map['avgDepth'], 7.9);
    expect(map['waterTemp'], 21.0); // depthtemp wins over surfacetemp
    expect(map['airTemp'], 28.0);
    expect(map['buddy'], 'Buddy');
    expect(map['buddyRefs'], ['Buddy']);
    expect(map['weightUsed'], 4.0);
    expect(map['latitude'], 24.6);
    expect(map['longitude'], 35.1);
    expect(map['diveComputerModel'], 'Suunto D6');
    expect(map['surfaceInterval'], const Duration(seconds: 3600));
    expect(map['sourceUuid'], 'divelogs:4711');
  });

  test('appends weather, visibility, and location to notes', () {
    final notes = mapper.mapDive(dive())['notes'] as String;
    expect(notes, contains('nice dive'));
    expect(notes, contains('Weather: sunny'));
    expect(notes, contains('Visibility: good'));
    expect(notes, contains('Location: Aegypten, Rotes Meer'));
  });

  test('builds profile from samples using samplerate', () {
    final profile = mapper.mapDive(dive())['profile'] as List;
    expect(profile, hasLength(2));
    expect(profile[0], {'timestamp': 0, 'depth': 1.0, 'temperature': 13.0});
    expect(profile[1]['timestamp'], 10);
    expect(profile[1].containsKey('temperature'), isFalse);
  });

  test('builds tank maps with GasMix and double volume', () {
    final tanks = mapper.mapDive(dive())['tanks'] as List;
    final tank = tanks.single as Map<String, dynamic>;
    expect((tank['gasMix'] as GasMix).o2, 28.0);
    expect(tank['startPressure'], 214.56);
    expect(tank['endPressure'], 103.0);
    expect(tank['volume'], isA<double>());
    expect(tank['workingPressure'], 200.0);
  });

  test('links dive to site entity via uddfId and mapSite emits site map', () {
    final d = dive();
    final map = mapper.mapDive(d);
    final site = mapper.mapSite(d)!;
    expect((map['site'] as Map)['uddfId'], site['uddfId']);
    expect(site['name'], 'Shinenead');
    expect(site['latitude'], 24.6);
    expect(site['longitude'], 35.1);
  });

  test('no sourceUuid key when remote id missing', () {
    expect(mapper.mapDive(dive(id: null)).containsKey('sourceUuid'), isFalse);
  });

  test('no site when name missing', () {
    final d = dive(siteName: null);
    expect(mapper.mapSite(d), isNull);
    expect(mapper.mapDive(d).containsKey('site'), isFalse);
  });

  test('zero weights and temps are treated as unset', () {
    final d = DivelogsDive(
      dateTime: DateTime(2022),
      durationSeconds: 60,
      maxDepth: 5,
      weightsKg: 0,
      airTemp: 0,
    );
    final map = mapper.mapDive(d);
    expect(map.containsKey('weightUsed'), isFalse);
    expect(map.containsKey('airTemp'), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/universal_import/data/services/divelogs_dive_mapper_test.dart`
Expected: FAIL — mapper missing.

- [ ] **Step 3: Implement the mapper**

```dart
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Converts divelogs.de API dives into the untyped entity maps consumed by
/// the universal import pipeline (UddfEntityImporter key conventions).
///
/// divelogs.de uses 0 for "not set" on numeric optionals (temps, weights);
/// those are dropped rather than imported as literal zeros.
class DivelogsDiveMapper {
  const DivelogsDiveMapper();

  static String siteKey(String name) =>
      'divelogs-site-${name.trim().toLowerCase()}';

  Map<String, dynamic> mapDive(DivelogsDive dive) {
    final map = <String, dynamic>{
      'dateTime': dive.dateTime,
      'runtime': Duration(seconds: dive.durationSeconds),
      'maxDepth': dive.maxDepth,
      if (dive.meanDepth != null && dive.meanDepth! > 0)
        'avgDepth': dive.meanDepth,
      'notes': _buildNotes(dive),
    };

    final waterTemp = _positive(dive.depthTemp) ?? _positive(dive.surfaceTemp);
    if (waterTemp != null) map['waterTemp'] = waterTemp;
    final airTemp = _positive(dive.airTemp);
    if (airTemp != null) map['airTemp'] = airTemp;
    final weight = _positive(dive.weightsKg);
    if (weight != null) map['weightUsed'] = weight;

    if (dive.buddy != null) {
      map['buddy'] = dive.buddy;
      map['buddyRefs'] = [dive.buddy!];
    }
    if (dive.latitude != null && dive.longitude != null) {
      map['latitude'] = dive.latitude;
      map['longitude'] = dive.longitude;
    }
    if (dive.dcModel != null) map['diveComputerModel'] = dive.dcModel;
    if (dive.surfaceIntervalSeconds != null &&
        dive.surfaceIntervalSeconds! > 0) {
      map['surfaceInterval'] = Duration(seconds: dive.surfaceIntervalSeconds!);
    }
    if (dive.id != null) map['sourceUuid'] = 'divelogs:${dive.id}';

    final siteName = dive.siteName;
    if (siteName != null) {
      map['siteName'] = siteName;
      map['site'] = <String, dynamic>{
        'uddfId': siteKey(siteName),
        'name': siteName,
      };
    }

    final tanks = dive.tanks
        .map(
          (t) => <String, dynamic>{
            'gasMix': GasMix(o2: t.o2 ?? 21.0, he: t.he ?? 0.0),
            if (t.startPressure != null) 'startPressure': t.startPressure,
            if (t.endPressure != null) 'endPressure': t.endPressure,
            if (t.volume != null && t.volume! > 0)
              'volume': t.volume!.toDouble(),
            if (t.workingPressure != null && t.workingPressure! > 0)
              'workingPressure': t.workingPressure,
            if (t.name != null) 'name': t.name,
          },
        )
        .toList();
    if (tanks.isNotEmpty) map['tanks'] = tanks;

    final rate = dive.sampleRateSeconds;
    if (dive.samples.isNotEmpty && rate != null && rate > 0) {
      map['profile'] = [
        for (var i = 0; i < dive.samples.length; i++)
          <String, dynamic>{
            'timestamp': i * rate,
            'depth': dive.samples[i].depth,
            if (dive.samples[i].temperature != null)
              'temperature': dive.samples[i].temperature,
          },
      ];
    }

    return map;
  }

  /// Site entity map for the payload, or null when the dive has no site name.
  Map<String, dynamic>? mapSite(DivelogsDive dive) {
    final name = dive.siteName;
    if (name == null) return null;
    return <String, dynamic>{
      'uddfId': siteKey(name),
      'name': name,
      if (dive.latitude != null) 'latitude': dive.latitude,
      if (dive.longitude != null) 'longitude': dive.longitude,
    };
  }

  double? _positive(double? value) =>
      (value != null && value > 0) ? value : null;

  String _buildNotes(DivelogsDive dive) {
    final parts = <String>[
      if (dive.notes != null) dive.notes!,
      if (dive.weather != null) 'Weather: ${dive.weather}',
      if (dive.visibility != null) 'Visibility: ${dive.visibility}',
      if (dive.boat != null) 'Boat: ${dive.boat}',
      if (dive.location != null) 'Location: ${dive.location}',
    ];
    return parts.join('\n');
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/universal_import/data/services/divelogs_dive_mapper_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib/features/universal_import test/features/universal_import
git commit -m "feat: map divelogs.de dives into universal import entity maps"
```

---

### Task 7: `DivelogsImportService` (payload assembly) + duplicate-checker integration test

**Files:**
- Create: `lib/features/universal_import/data/services/divelogs_import_service.dart`
- Test: `test/features/universal_import/data/services/divelogs_import_service_test.dart`

**Interfaces:**
- Consumes: Task 4 (`DivelogsApiClient`, `DivelogsDivesResult`), Task 6 (`DivelogsDiveMapper`), `ImportPayload`/`ImportWarning`/`ImportEntityType` from `lib/features/universal_import/data/models/`.
- Produces: `class DivelogsImportService { DivelogsImportService({required DivelogsApiClient api}); Future<ImportPayload> fetchAllDives(); }` — payload with `ImportEntityType.dives` + `ImportEntityType.sites` (deduped by `uddfId`), warning entry when dives were skipped, `metadata: {'source': 'divelogs.de', 'diveCount': N}`.

- [ ] **Step 1: Write the failing test**

Use a `MockClient`-backed `DivelogsApiClient` (no network). Include: two dives sharing one site → payload has 2 dive maps and 1 site map; skipped-dive warning surfaces; **duplicate-checker integration**: feed the produced payload plus a matching existing `Dive` into `const ImportDuplicateChecker().check(...)` and assert (a) fuzzy date/time match flags the duplicate, (b) with `existingSourceUuidByDiveId: {'existing-1': 'divelogs:4711'}` Pass-0 flags it with `matchedExistingSource: true` (this is the second-pull idempotency guarantee). Model the checker invocation on `test/features/universal_import/data/services/import_duplicate_checker_test.dart` (empty lists for the non-dive entity params).

```dart
// Key assertions (structure the file like import_duplicate_checker_test.dart):
final payload = await service.fetchAllDives();
expect(payload.entitiesOf(ImportEntityType.dives), hasLength(2));
expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));

final result = const ImportDuplicateChecker().check(
  payload: payload,
  existingDives: [existingDive], // same start time/depth/duration as dive 1
  existingSites: const [], existingTrips: const [],
  existingEquipment: const [], existingBuddies: const [],
  existingDiveCenters: const [], existingCertifications: const [],
  existingTags: const [], existingDiveTypes: const [],
);
expect(result.duplicates[ImportEntityType.dives], contains(0));

final pass0 = const ImportDuplicateChecker().check(
  payload: payload,
  existingDives: [existingDive],
  existingSourceUuidByDiveId: {existingDive.id: 'divelogs:4711'},
  // ... same empty lists ...
);
expect(pass0.diveMatches[0]?.matchedExistingSource, isTrue);
```

- [ ] **Step 2: Run to verify failure, then implement**

```dart
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';

/// Fetches the full divelogs.de logbook and assembles an ImportPayload for
/// the universal import pipeline.
class DivelogsImportService {
  DivelogsImportService({
    required DivelogsApiClient api,
    DivelogsDiveMapper mapper = const DivelogsDiveMapper(),
  }) : _api = api,
       _mapper = mapper;

  final DivelogsApiClient _api;
  final DivelogsDiveMapper _mapper;

  Future<ImportPayload> fetchAllDives() async {
    final result = await _api.getAllDives();

    final diveEntities = <Map<String, dynamic>>[];
    final sitesByKey = <String, Map<String, dynamic>>{};
    for (final dive in result.dives) {
      diveEntities.add(_mapper.mapDive(dive));
      final site = _mapper.mapSite(dive);
      if (site != null) {
        sitesByKey.putIfAbsent(site['uddfId'] as String, () => site);
      }
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveEntities.isNotEmpty) {
      entities[ImportEntityType.dives] = diveEntities;
    }
    if (sitesByKey.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByKey.values.toList();
    }

    return ImportPayload(
      entities: entities,
      warnings: [
        if (result.skippedCount > 0)
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            message:
                '${result.skippedCount} dives could not be read from '
                'divelogs.de and were skipped.',
          ),
      ],
      metadata: {'source': 'divelogs.de', 'diveCount': result.dives.length},
    );
  }
}
```

(Check `ImportWarning`'s actual constructor in `lib/features/universal_import/data/models/` — match its required params, e.g. an `ImportEntityType`/context field if present, by copying an existing construction site from `shearwater_cloud_parser.dart`.)

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/universal_import/data/services/divelogs_import_service_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
dart format .
git add -A lib/features/universal_import test/features/universal_import
git commit -m "feat: assemble divelogs.de import payload with dedup-ready source uuids"
```

---

### Task 8: Wizard adapter + sign-in/fetch step

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (add `ImportSourceType.divelogs`; run `flutter analyze` and add cases to any exhaustive switches over `ImportSourceType` it reports)
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (add `setExternalPayload`)
- Create: `lib/features/import_wizard/data/adapters/divelogs_adapter.dart`
- Create: `lib/features/import_wizard/presentation/widgets/divelogs_fetch_step.dart`
- Test: `test/features/import_wizard/presentation/widgets/divelogs_fetch_step_test.dart`

**Interfaces:**
- Consumes: Tasks 1–7; `UniversalAdapter` (`lib/features/import_wizard/data/adapters/universal_adapter.dart`), `WizardStepDef` (`lib/shared/widgets/wizard/wizard_step_def.dart`), `universalImportNotifierProvider`, `connectedAccountsRepositoryProvider`, `accountCredentialsStoreProvider`, `accountProviderRegistryProvider`, `allDiversProvider` (`lib/features/divers/presentation/providers/diver_providers.dart`).
- Produces: `class DivelogsImportAdapter extends UniversalAdapter` (`sourceType => ImportSourceType.divelogs`, one acquisition step); `divelogsPayloadReadyProvider` (`Provider<bool>`); `DivelogsFetchStep` widget.

- [ ] **Step 1: Add `setExternalPayload` to `UniversalImportNotifier`**

In `universal_import_providers.dart`, add a public method that mirrors the state update at the end of the file-parse completion path (the block around lines 664–724 that sets `payload`, duplicate results, and default selections — reuse `_checkDuplicates` and `_defaultSelections`, copy the `state = state.copyWith(...)` field list from that block exactly, substituting `sourceLabel` for the file name):

```dart
/// Installs a payload produced outside the file-parse path (e.g. a REST
/// source like divelogs.de) and runs the standard duplicate check and
/// default-selection pass so the wizard can proceed to review.
Future<void> setExternalPayload(
  ImportPayload payload, {
  String? sourceLabel,
}) async {
  final dupResult = await _checkDuplicates(payload);
  final selections = _defaultSelections(payload, dupResult);
  state = state.copyWith(
    // copy the exact field list from the parse-completion state update,
    // with payload/dupResult/selections and fileName: sourceLabel
  );
}
```

Write a notifier-level test only if `universal_import_providers` already has one (extend it); otherwise the widget test in Step 3 covers this path.

- [ ] **Step 2: Add the adapter**

`lib/features/import_wizard/data/adapters/divelogs_adapter.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_fetch_step.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

final divelogsPayloadReadyProvider = Provider<bool>(
  (ref) => ref.watch(universalImportNotifierProvider).payload != null,
);

/// Import source that pulls the user's logbook from divelogs.de.
///
/// Reuses the entire universal pipeline (bundle building, duplicate check,
/// commit); only acquisition differs: sign in and fetch instead of a file.
class DivelogsImportAdapter extends UniversalAdapter {
  DivelogsImportAdapter({required super.ref})
    : super(displayName: 'divelogs.de');

  @override
  ImportSourceType get sourceType => ImportSourceType.divelogs;

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Sign In',
      icon: Icons.cloud_download_outlined,
      builder: (context) => const DivelogsFetchStep(),
      canAdvance: divelogsPayloadReadyProvider,
      autoAdvance: true,
    ),
  ];
}
```

(Match `UniversalAdapter`'s actual constructor — if it's `UniversalAdapter({required WidgetRef ref, String? displayName})`, use `super(ref: ref, displayName: 'divelogs.de')`. If `displayName`/`sourceType`/`acquisitionSteps` are not overridable members, make them so — they are plain getters on the base class.)

- [ ] **Step 3: Build the fetch step widget (test-first)**

`DivelogsFetchStep` is a `ConsumerStatefulWidget` with two visual states:

1. **Not connected** (no `AccountKind.divelogs` account, or adapter `status()` is `needsSignIn`): form with username field, password field (obscured), diver dropdown (`allDiversProvider`, default: current active diver — resolve via the same provider `UniversalAdapter.checkDuplicates` uses for `diverId`; grep `diverId` in `universal_adapter.dart` and reuse that provider), and a Connect button. On submit:
   - `DivelogsAuthManager.login(username:, password:)` — validates; on `DivelogsAuthException` show the message inline and stay.
   - Create the account if absent: `repo.create(kind: AccountKind.divelogs, label: 'divelogs.de', accountIdentifier: username, diverId: selectedDiverId)`.
   - Persist credentials: `accountCredentialsStore.write(account.id, DivelogsCredentials(username: ..., password: ..., bearerToken: token).toJsonString())`.
   - Proceed to fetch (state 2).
2. **Connected**: shows "Fetching dives from divelogs.de..." with a progress indicator, immediately runs:
   ```dart
   final adapter = ref.read(accountProviderRegistryProvider)
       .adapterFor(AccountKind.divelogs) as DivelogsAccountAdapter;
   final manager = adapter.authManagerFor(account);
   final api = DivelogsApiClient(
     getBearerToken: manager.getToken,
     onTokenRejected: manager.invalidateToken,
   );
   final payload = await DivelogsImportService(api: api).fetchAllDives();
   await ref.read(universalImportNotifierProvider.notifier)
       .setExternalPayload(payload, sourceLabel: 'divelogs.de');
   ```
   On success the `canAdvance` provider flips true and the wizard auto-advances. On `DivelogsApiException` show the message with a Retry button. If the bound `account.diverId` is non-null and differs from the active diver, show a blocking message ("This divelogs.de account is linked to a different diver profile. Switch divers to import.") instead of fetching.

Widget test (`divelogs_fetch_step_test.dart`): pump the step inside a `ProviderScope` with `accountCredentialsStoreProvider` overridden to an `InMemoryKeychain`-backed store and `connectedAccountsRepositoryProvider` overridden to an in-memory fake (copy the override pattern from `test/features/settings/presentation/pages/connected_accounts_page_test.dart` if present, else from any existing widget test that overrides these providers — locate with `grep -rl "accountCredentialsStoreProvider" test/`). Assert: (a) form shows when no account exists; (b) invalid login (MockClient 401) surfaces the error text and creates no account; (c) successful login creates the account with the selected `diverId` and stores the credentials blob. Follow the repo's widget-test gotchas: `themeAnimationDuration: Duration.zero`, `tester.ensureVisible` before taps, and wrap drift-touching awaits in `tester.runAsync`.

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/features/import_wizard/ && flutter analyze`
Expected: PASS, no errors.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: add divelogs.de import wizard adapter with sign-in and fetch step"
```

---

### Task 9: Route, transfer-page entry, and localization

**Files:**
- Modify: `lib/core/router/app_router.dart` (route + wrapper near `_UniversalImportWizardRoute`, ~line 1341)
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart` (`_ImportSectionContent`, ~line 201)
- Modify: `lib/l10n/arb/app_en.arb` + all 10 non-English arb files (es, fr, de, it, nl, pt, hu, he, zh, ar)
- Test: extend `test/features/transfer/presentation/pages/transfer_page_test.dart` if it exists (locate with `ls test/features/transfer/`); otherwise router smoke coverage comes from the analyzer + existing router tests.

**Interfaces:**
- Consumes: Task 8's `DivelogsImportAdapter`.
- Produces: route `/transfer/divelogs-import` (name `divelogsImport`); transfer-page tile.

- [ ] **Step 1: Add the route wrapper and GoRoute**

In `app_router.dart`, next to `_UniversalImportWizardRoute`:

```dart
class _DivelogsImportWizardRoute extends ConsumerWidget {
  const _DivelogsImportWizardRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedImportWizard(adapter: DivelogsImportAdapter(ref: ref));
  }
}
```

And under the `/transfer` routes (next to `import-wizard`):

```dart
GoRoute(
  path: 'divelogs-import',
  name: 'divelogsImport',
  builder: (context, state) => const _DivelogsImportWizardRoute(),
),
```

- [ ] **Step 2: Add the transfer-page tile**

In `_ImportSectionContent`, duplicate the existing File Import `Card` block, with icon `Icons.travel_explore_outlined`, title `context.l10n.transfer_import_divelogs_title`, subtitle `context.l10n.transfer_import_divelogs_subtitle`, and `onTap: () => context.push('/transfer/divelogs-import')`.

- [ ] **Step 3: Add localization strings**

In `app_en.arb` (match the neighboring `transfer_import_*` key style):

```json
"transfer_import_divelogs_title": "Import from divelogs.de",
"transfer_import_divelogs_subtitle": "Pull your logbook from your divelogs.de account",
"divelogs_signIn_title": "Sign in to divelogs.de",
"divelogs_signIn_username": "Username",
"divelogs_signIn_password": "Password",
"divelogs_signIn_diver": "Import into diver",
"divelogs_signIn_connect": "Connect",
"divelogs_signIn_failed": "Could not sign in: {error}",
"@divelogs_signIn_failed": { "placeholders": { "error": { "type": "String" } } },
"divelogs_fetch_inProgress": "Fetching dives from divelogs.de...",
"divelogs_fetch_retry": "Retry",
"divelogs_fetch_wrongDiver": "This divelogs.de account is linked to a different diver profile. Switch divers to import."
```

Translate every key into all 10 non-English arb files ("divelogs.de" stays untranslated; German translations matter most — divelogs.de's home audience). Replace any hard-coded strings from Task 8's widget with these keys. Run `flutter gen-l10n`.

- [ ] **Step 4: Verify**

Run: `flutter analyze && flutter test test/features/import_wizard/ test/features/transfer/ 2>/dev/null || flutter test test/features/import_wizard/`
Expected: no analyze errors; tests PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: add divelogs.de import entry point, route, and translations"
```

---

### Task 10: Full verification sweep

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: format changes nothing; analyze reports no errors. Fix anything reported.

- [ ] **Step 2: Run the touched test surface**

```bash
flutter test \
  test/core/services/divelogs \
  test/core/services/accounts \
  test/core/providers/account_providers_test.dart \
  test/features/universal_import/data/services \
  test/features/import_wizard
```
Expected: all PASS.

- [ ] **Step 3: Manual smoke (macOS)**

Check no other `flutter run -d macos` session is active first. Launch, then: Transfer → Import from divelogs.de → sign in with a real or test account (or verify the error path with bad credentials) → confirm the review step lists fetched dives → import a couple → re-run the import and confirm they show as already-imported (Pass-0). If no real account is available, note the smoke as pending in the PR description.

- [ ] **Step 4: Commit any fixes**

```bash
dart format .
git add -A
git commit -m "test: divelogs.de phase 1 verification fixes"
```

(Do not push or open a PR — Phase 1 review and PR creation is a separate, user-triggered step.)

---

## Deferred to later phases (do NOT build now)

- `GET /divelist` compare, `DivelogsSyncPlanner`, sync page UI (Phase 2)
- Push mapping/`POST /dives` (Phase 2)
- Gear, certifications (Phase 3), pictures (Phase 4)
- `LogbookSyncCapable` members beyond the marker (Phase 2)

## Open assumptions to confirm with Rainer (do not block)

- Login response token field name (`bearer_token` assumed; client also tries `token`, `access_token`)
- `GET /dives` returns a JSON array (object-with-`dives`-key tolerated)
- Units are metric; `0` means "not set" for temps/weights
- Remote dive `id` field present in GET responses
