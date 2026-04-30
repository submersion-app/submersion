# Media Source Extension — Phase 3a (URL Bulk Import) Implementation Plan

> Part 1 of 3 (Phase 3a: URL Bulk Import). Phases 3b (Manifests) and 3c
> (Settings & Scan) follow on the same branch
> (`feature/media-source-extension-phase3`).

## Context

Phase 1 added the network schema (`network_credential_hosts` table; new
`media.url`, `media.finalUrl`, `media.subscriptionId`, `media.entryKey`
columns) and the `MediaSourceType.networkUrl` enum value. The `MediaItem`
domain entity already exposes `url`, `finalUrl`, `subscriptionId`, and
`entryKey` fields.

Phase 2 swapped the placeholder Files tab in the photo picker for a working
local-files importer. The same picker still has a placeholder URL tab at
`lib/features/media/presentation/pages/photo_picker_page.dart` (around lines
166-167). A test fossil at
`test/features/media/presentation/pages/photo_picker_page_tab_shell_test.dart`
asserts a `Center` placeholder for the URL tab. Phase 3a swaps that
placeholder for a real URL bulk-import tab.

**Phase 3a covers spec deliverables 1 (URLs mode only), 2, 5, 7, and 9 from
`docs/superpowers/specs/2026-04-25-media-source-extension-design.md` lines
428–552.** Manifest mode (deliverable 1 Manifest, 4, 6) is Phase 3b. Settings
page (deliverable 3) and HTTP scan (deliverable 8) are Phase 3c.

Phase 3a's URL tab segmented control already wires both modes; the Manifest
mode body is a placeholder card that says "Manifest mode arrives in Phase 3b"
so 3b can drop in without UI rewiring.

## Background reading

- Spec: `docs/superpowers/specs/2026-04-25-media-source-extension-design.md`
  lines 428–552.
- Phase 1 schema: `lib/core/database/database.dart` (only `network_credential_hosts`
  + four `media` columns; one grep allowed if anything looks off).
- Phase 2 precedent (these are the templates 3a mirrors, file-by-file):
  - `lib/features/media/presentation/widgets/files_tab.dart` → URL tab UI mirrors this.
  - `lib/features/media/data/services/local_files_diagnostics_service.dart` →
    `NetworkCredentialsService` follows the same shape.
  - `lib/features/media/presentation/providers/files_tab_providers.dart` →
    URL tab providers mirror this (Riverpod 2.x StateNotifier with required
    named-deps constructor from the start).
- `flutter_secure_storage` is already in `pubspec.yaml` from Phase 2.
- `package:http` is likely already in `pubspec.yaml`; verify before adding.
- New pubspec additions expected (engineer to verify and add): `cached_network_image`,
  `video_thumbnail`, `ffmpeg_kit_flutter`.

## Conventions to bake in (Phase 2 lessons)

- **Riverpod 2.x StateNotifierProvider** with required named-deps in the
  constructor from the start — never refactor a positional constructor mid-plan.
- **Wall-clock-as-UTC** for any DateTime parsed from external strings (HTTP
  `Last-Modified`, EXIF `DateTimeOriginal`, manifest `takenAt`). Always
  construct via `DateTime.utc(...)`, never `DateTime.parse(...).toLocal()`.
- **`package:http`'s `MockClient`** for HTTP unit tests. Do NOT
  `// coverage:ignore` HTTP code — tests exercise it through `MockClient`.
- **`// TODO(media): l10n`** marker above every user-visible string until the
  app rolls out an arb pipeline.
- **`// coverage:ignore-start/end`** with a justifying comment, for genuinely
  unreachable branches only: picker callbacks invoked by the OS, gesture
  handlers, host-dependent `Platform.isXxx` branches.
- **`if (!context.mounted) return;`** after every `await` in widget code. The
  analyzer will otherwise warn.
- **Per-task commits**, TDD throughout. Each task is 2–5 minutes with full code
  shown, not "implement X".

## Tasks

### Task 1 — Failing tests for URL parsing/validation utility

Create `test/features/media/data/utils/url_validator_test.dart`. Tests assert
`UrlValidator.parse(line)` returns one of:

- `UrlValidationOk(uri)` — well-formed http(s) absolute URI with non-empty host.
- `UrlValidationEmpty()` — line is whitespace-only.
- `UrlValidationInvalid(message)` — anything else, with a human message.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/utils/url_validator.dart';

void main() {
  group('UrlValidator.parse', () {
    test('accepts https URL', () {
      final result = UrlValidator.parse('https://example.com/a.jpg');
      expect(result, isA<UrlValidationOk>());
      expect((result as UrlValidationOk).uri.host, 'example.com');
    });

    test('accepts http URL', () {
      expect(
        UrlValidator.parse('http://example.com/a.jpg'),
        isA<UrlValidationOk>(),
      );
    });

    test('returns empty for whitespace-only line', () {
      expect(UrlValidator.parse('   '), isA<UrlValidationEmpty>());
    });

    test('rejects non-http schemes', () {
      final result = UrlValidator.parse('file:///tmp/a.jpg');
      expect(result, isA<UrlValidationInvalid>());
    });

    test('rejects relative URLs', () {
      expect(
        UrlValidator.parse('/some/path.jpg'),
        isA<UrlValidationInvalid>(),
      );
    });

    test('rejects malformed URLs', () {
      expect(
        UrlValidator.parse('https://[::not-an-ip]/x'),
        isA<UrlValidationInvalid>(),
      );
    });

    test('rejects URL without host', () {
      expect(
        UrlValidator.parse('https:///foo'),
        isA<UrlValidationInvalid>(),
      );
    });

    test('trims trailing whitespace before parsing', () {
      expect(
        UrlValidator.parse('  https://example.com/a.jpg  '),
        isA<UrlValidationOk>(),
      );
    });
  });
}
```

**Run:** `flutter test test/features/media/data/utils/url_validator_test.dart`
— expect all 8 tests to fail (file does not exist yet).

**Commit:** `test(media): add failing tests for URL validator`

### Task 2 — Implement URL validator

Create `lib/features/media/data/utils/url_validator.dart`:

```dart
// TODO(media): l10n — error strings here are user-visible.

sealed class UrlValidationResult {
  const UrlValidationResult();
}

class UrlValidationOk extends UrlValidationResult {
  const UrlValidationOk(this.uri);
  final Uri uri;
}

class UrlValidationEmpty extends UrlValidationResult {
  const UrlValidationEmpty();
}

class UrlValidationInvalid extends UrlValidationResult {
  const UrlValidationInvalid(this.message);
  final String message;
}

class UrlValidator {
  const UrlValidator._();

  static UrlValidationResult parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const UrlValidationEmpty();
    final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException catch (e) {
      return UrlValidationInvalid('Malformed URL: ${e.message}');
    }
    if (!uri.isAbsolute) {
      return const UrlValidationInvalid('URL must be absolute');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlValidationInvalid(
        'Unsupported scheme: ${uri.scheme} (must be http or https)',
      );
    }
    if (uri.host.isEmpty) {
      return const UrlValidationInvalid('URL must include a host');
    }
    return UrlValidationOk(uri);
  }
}
```

**Run:** `flutter test test/features/media/data/utils/url_validator_test.dart`
— expect 8 passing.

**Commit:** `feat(media): add URL validator for bulk import`

### Task 3 — Failing tests for NetworkCredentialsRepository

Create `test/features/media/data/repositories/network_credentials_repository_test.dart`.
Use Drift's `NativeDatabase.memory()` to spin up a fresh DB; the repository
talks to `network_credential_hosts`.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';

void main() {
  late AppDatabase db;
  late NetworkCredentialsRepository repo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = NetworkCredentialsRepository(db: db);
  });
  tearDown(() async => db.close());

  test('upsert inserts a new host row', () async {
    final id = await repo.upsert(
      hostname: 'example.com',
      authType: 'basic',
      displayName: 'Example',
    );
    expect(id, isPositive);
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.first.hostname, 'example.com');
    expect(all.first.authType, 'basic');
  });

  test('upsert by hostname updates existing row', () async {
    await repo.upsert(hostname: 'example.com', authType: 'basic');
    await repo.upsert(
      hostname: 'example.com',
      authType: 'bearer',
      displayName: 'New name',
    );
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.first.authType, 'bearer');
    expect(all.first.displayName, 'New name');
  });

  test('findByHostname returns null when missing', () async {
    expect(await repo.findByHostname('missing.example'), isNull);
  });

  test('findByHostname returns row when present', () async {
    await repo.upsert(hostname: 'example.com', authType: 'basic');
    final row = await repo.findByHostname('example.com');
    expect(row, isNotNull);
  });

  test('delete removes the row', () async {
    final id = await repo.upsert(
      hostname: 'example.com',
      authType: 'basic',
    );
    await repo.delete(id);
    expect(await repo.list(), isEmpty);
  });

  test('touchLastUsed updates lastUsedAt', () async {
    final id = await repo.upsert(
      hostname: 'example.com',
      authType: 'basic',
    );
    await repo.touchLastUsed(id);
    final row = await repo.findById(id);
    expect(row?.lastUsedAt, isNotNull);
  });
}
```

**Run:** `flutter test test/features/media/data/repositories/network_credentials_repository_test.dart`
— expect failures (repository does not exist).

**Commit:** `test(media): add failing tests for NetworkCredentialsRepository`

### Task 4 — Implement NetworkCredentialsRepository

Create `lib/features/media/data/repositories/network_credentials_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';

class NetworkCredentialsRepository {
  NetworkCredentialsRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<int> upsert({
    required String hostname,
    required String authType,
    String? displayName,
  }) async {
    final existing = await findByHostname(hostname);
    if (existing != null) {
      await (_db.update(_db.networkCredentialHosts)
            ..where((t) => t.id.equals(existing.id)))
          .write(NetworkCredentialHostsCompanion(
        authType: Value(authType),
        displayName: Value(displayName),
      ));
      return existing.id;
    }
    return _db.into(_db.networkCredentialHosts).insert(
          NetworkCredentialHostsCompanion.insert(
            hostname: hostname,
            authType: authType,
            displayName: Value(displayName),
          ),
        );
  }

  Future<List<NetworkCredentialHost>> list() =>
      _db.select(_db.networkCredentialHosts).get();

  Future<NetworkCredentialHost?> findByHostname(String hostname) async {
    return (_db.select(_db.networkCredentialHosts)
          ..where((t) => t.hostname.equals(hostname)))
        .getSingleOrNull();
  }

  Future<NetworkCredentialHost?> findById(int id) =>
      (_db.select(_db.networkCredentialHosts)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> delete(int id) =>
      (_db.delete(_db.networkCredentialHosts)..where((t) => t.id.equals(id)))
          .go();

  Future<void> touchLastUsed(int id) async {
    await (_db.update(_db.networkCredentialHosts)
          ..where((t) => t.id.equals(id)))
        .write(NetworkCredentialHostsCompanion(
      lastUsedAt: Value(DateTime.now().toUtc()),
    ));
  }
}
```

**Run:** the same test command — expect 6 passing.

**Commit:** `feat(media): add NetworkCredentialsRepository`

### Task 5 — Failing tests for NetworkCredentialsService

Create `test/features/media/data/services/network_credentials_service_test.dart`.
Inject a fake `FlutterSecureStorage` (an in-memory map). The service composes
the repository + secure storage, exposes:

- `Future<void> save({hostname, authType, username?, password?, token?, displayName?})`
- `Future<Map<String, String>?> headersFor(Uri uri)` — null if no creds.
- `Future<void> delete(int id)`
- `Future<List<NetworkCredentialHost>> list()`

```dart
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};
  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async => _store[key];
  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async => _store.remove(key);
  // Other members not exercised — throw to surface accidental calls.
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;
  late NetworkCredentialsRepository repo;
  late _FakeSecureStorage storage;
  late NetworkCredentialsService service;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = NetworkCredentialsRepository(db: db);
    storage = _FakeSecureStorage();
    service = NetworkCredentialsService(repository: repo, storage: storage);
  });
  tearDown(() async => db.close());

  test('save+headersFor returns Basic auth header', () async {
    await service.save(
      hostname: 'example.com',
      authType: 'basic',
      username: 'eric',
      password: 'hunter2',
    );
    final headers = await service.headersFor(Uri.parse('https://example.com/x'));
    expect(headers, isNotNull);
    expect(headers!['Authorization'], startsWith('Basic '));
  });

  test('save+headersFor returns Bearer auth header', () async {
    await service.save(
      hostname: 'example.com',
      authType: 'bearer',
      token: 'abc.def.ghi',
    );
    final headers = await service.headersFor(Uri.parse('https://example.com/x'));
    expect(headers!['Authorization'], 'Bearer abc.def.ghi');
  });

  test('headersFor returns null when no creds for host', () async {
    expect(
      await service.headersFor(Uri.parse('https://other.example/x')),
      isNull,
    );
  });

  test('headersFor caches across calls', () async {
    await service.save(
      hostname: 'example.com',
      authType: 'bearer',
      token: 't',
    );
    await service.headersFor(Uri.parse('https://example.com/a'));
    // Mutate storage directly; cached value should still be returned.
    await storage.delete(key: 'media_network_cred_example.com');
    final headers = await service.headersFor(Uri.parse('https://example.com/b'));
    expect(headers!['Authorization'], 'Bearer t');
  });

  test('delete removes both row and secret', () async {
    await service.save(
      hostname: 'example.com',
      authType: 'bearer',
      token: 't',
    );
    final hosts = await service.list();
    await service.delete(hosts.first.id);
    expect(await service.list(), isEmpty);
    expect(
      await service.headersFor(Uri.parse('https://example.com/x')),
      isNull,
    );
  });

  test('save throws on invalid combo', () async {
    expect(
      () => service.save(hostname: 'example.com', authType: 'basic'),
      throwsArgumentError,
    );
    expect(
      () => service.save(hostname: 'example.com', authType: 'bearer'),
      throwsArgumentError,
    );
  });
}
```

**Run:** the same test command — expect failures.

**Commit:** `test(media): add failing tests for NetworkCredentialsService`

### Task 6 — Implement NetworkCredentialsService

Create `lib/features/media/data/services/network_credentials_service.dart`:

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';

class NetworkCredentialsService {
  NetworkCredentialsService({
    required NetworkCredentialsRepository repository,
    required FlutterSecureStorage storage,
  })  : _repo = repository,
        _storage = storage;

  final NetworkCredentialsRepository _repo;
  final FlutterSecureStorage _storage;
  final Map<String, Map<String, String>> _headerCache = {};

  static const _keyPrefix = 'media_network_cred_';

  Future<void> save({
    required String hostname,
    required String authType,
    String? username,
    String? password,
    String? token,
    String? displayName,
  }) async {
    if (authType == 'basic') {
      if (username == null || password == null) {
        throw ArgumentError('Basic auth requires username + password');
      }
    } else if (authType == 'bearer') {
      if (token == null) {
        throw ArgumentError('Bearer auth requires token');
      }
    } else {
      throw ArgumentError('Unsupported authType: $authType');
    }

    await _repo.upsert(
      hostname: hostname,
      authType: authType,
      displayName: displayName,
    );
    final secret = jsonEncode({
      'authType': authType,
      'username': username,
      'password': password,
      'token': token,
    });
    await _storage.write(key: _keyPrefix + hostname, value: secret);
    _headerCache.remove(hostname);
  }

  Future<Map<String, String>?> headersFor(Uri uri) async {
    final host = uri.host;
    final cached = _headerCache[host];
    if (cached != null) return cached;
    final raw = await _storage.read(key: _keyPrefix + host);
    if (raw == null) return null;
    final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final headers = <String, String>{};
    if (map['authType'] == 'basic') {
      final token = base64Encode(
        utf8.encode('${map['username']}:${map['password']}'),
      );
      headers['Authorization'] = 'Basic $token';
    } else if (map['authType'] == 'bearer') {
      headers['Authorization'] = 'Bearer ${map['token']}';
    }
    _headerCache[host] = headers;
    final row = await _repo.findByHostname(host);
    if (row != null) await _repo.touchLastUsed(row.id);
    return headers;
  }

  Future<void> delete(int id) async {
    final row = await _repo.findById(id);
    if (row == null) return;
    await _repo.delete(id);
    await _storage.delete(key: _keyPrefix + row.hostname);
    _headerCache.remove(row.hostname);
  }

  Future<List<NetworkCredentialHost>> list() => _repo.list();
}
```

**Run:** the same test command — expect 6 passing.

**Commit:** `feat(media): add NetworkCredentialsService with secure storage`

### Task 7 — Failing tests for NetworkUrlResolver

Create `test/features/media/data/services/network_url_resolver_test.dart`.
Use `MockClient` from `package:http/testing.dart` — never `coverage:ignore`
HTTP code.

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

class _StubCreds implements NetworkCredentialsService {
  _StubCreds(this.headers);
  final Map<String, String>? headers;
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => headers;
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('NetworkUrlResolver.fetch', () {
    test('returns BytesData on 200', () async {
      final body = utf8.encode('hello');
      final client = MockClient((req) async => http.Response.bytes(
            body,
            200,
            headers: {'content-type': 'image/jpeg'},
          ));
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      final result = await resolver.fetch(Uri.parse('https://example.com/a.jpg'));
      expect(result, isA<NetworkBytesOk>());
      final ok = result as NetworkBytesOk;
      expect(ok.bytes, body);
      expect(ok.contentType, 'image/jpeg');
    });

    test('returns Unauthenticated on 401', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      expect(
        await resolver.fetch(Uri.parse('https://example.com/a.jpg')),
        isA<NetworkBytesUnauthenticated>(),
      );
    });

    test('attaches credentials when host is known', () async {
      Map<String, String>? seenHeaders;
      final client = MockClient((req) async {
        seenHeaders = req.headers;
        return http.Response.bytes(const [1, 2, 3], 200);
      });
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds({'Authorization': 'Bearer x'}),
      );
      await resolver.fetch(Uri.parse('https://example.com/a.jpg'));
      expect(seenHeaders!['Authorization'], 'Bearer x');
    });

    test('records finalUrl when redirect chain ends elsewhere', () async {
      // 3 redirects then 200.
      var hops = 0;
      final client = MockClient((req) async {
        hops += 1;
        if (hops < 3) {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://cdn.example.com/a.jpg'},
          );
        }
        return http.Response.bytes(const [1], 200);
      });
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      final result = await resolver.fetch(
        Uri.parse('https://example.com/a.jpg'),
      );
      final ok = result as NetworkBytesOk;
      expect(ok.finalUrl, 'https://cdn.example.com/a.jpg');
    });

    test('aborts after 5 redirects', () async {
      final client = MockClient((req) async => http.Response(
            '',
            302,
            headers: {'location': 'https://example.com/loop'},
          ));
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      expect(
        await resolver.fetch(Uri.parse('https://example.com/start')),
        isA<NetworkBytesError>(),
      );
    });

    test('returns NetworkError on >= 500', () async {
      final client = MockClient((req) async => http.Response('', 503));
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      expect(
        await resolver.fetch(Uri.parse('https://example.com/a.jpg')),
        isA<NetworkBytesError>(),
      );
    });
  });
}
```

**Run:** `flutter test test/features/media/data/services/network_url_resolver_test.dart`
— expect failures.

**Commit:** `test(media): add failing tests for NetworkUrlResolver`

### Task 8 — Implement NetworkUrlResolver

Create `lib/features/media/data/services/network_url_resolver.dart`. The
resolver returns a sealed `NetworkBytesResult` so the caller never holds a
session reference and can write to disk freely.

```dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

sealed class NetworkBytesResult {
  const NetworkBytesResult();
}

class NetworkBytesOk extends NetworkBytesResult {
  const NetworkBytesOk({
    required this.bytes,
    required this.contentType,
    required this.finalUrl,
  });
  final Uint8List bytes;
  final String? contentType;
  final String finalUrl;
}

class NetworkBytesUnauthenticated extends NetworkBytesResult {
  const NetworkBytesUnauthenticated();
}

class NetworkBytesError extends NetworkBytesResult {
  const NetworkBytesError(this.message);
  final String message;
}

class NetworkUrlResolver {
  NetworkUrlResolver({
    required http.Client client,
    required NetworkCredentialsService credentials,
    int maxRedirects = 5,
  })  : _client = client,
        _credentials = credentials,
        _maxRedirects = maxRedirects;

  final http.Client _client;
  final NetworkCredentialsService _credentials;
  final int _maxRedirects;

  Future<NetworkBytesResult> fetch(
    Uri uri, {
    Map<String, String>? extraHeaders,
  }) async {
    var current = uri;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final headers = <String, String>{
        ...?extraHeaders,
        ...?await _credentials.headersFor(current),
      };
      final http.Response response;
      try {
        response = await _client.get(current, headers: headers);
      } catch (e) {
        return NetworkBytesError('transport: $e');
      }
      final code = response.statusCode;
      if (code == 401) return const NetworkBytesUnauthenticated();
      if (code >= 300 && code < 400) {
        final loc = response.headers['location'];
        if (loc == null) return NetworkBytesError('$code without Location');
        current = current.resolve(loc);
        continue;
      }
      if (code >= 200 && code < 300) {
        return NetworkBytesOk(
          bytes: response.bodyBytes,
          contentType: response.headers['content-type'],
          finalUrl: current.toString(),
        );
      }
      return NetworkBytesError('HTTP $code');
    }
    return const NetworkBytesError('Too many redirects');
  }
}
```

Note: `package:http`'s default `Client` already follows redirects, but
`MockClient` does not, so this implementation handles redirects manually for
testability.

**Run:** the same test command — expect 6 passing.

**Commit:** `feat(media): add NetworkUrlResolver for HTTP-fetched media`

### Task 9 — Failing tests for UrlMetadataExtractor

Create `test/features/media/data/services/url_metadata_extractor_test.dart`.
Stub the resolver and assert correct delegation. EXIF extraction is delegated
to the existing `ExifExtractor`; tests stub that.

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';

class _StubResolver implements NetworkUrlResolver {
  _StubResolver(this._results);
  final List<NetworkBytesResult> _results;
  int _i = 0;
  @override
  Future<NetworkBytesResult> fetch(Uri uri, {Map<String, String>? extraHeaders}) async =>
      _results[_i++];
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('range request fills metadata when EXIF present', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        NetworkBytesOk(
          bytes: Uint8List.fromList(const [/* fake jpeg with exif */]),
          contentType: 'image/jpeg',
          finalUrl: 'https://example.com/a.jpg',
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(
        takenAt: null,
        width: 4032,
        height: 3024,
      ),
    );
    final result = await extractor.extract(Uri.parse('https://example.com/a.jpg'));
    expect(result.width, 4032);
    expect(result.finalUrl, 'https://example.com/a.jpg');
  });

  test('falls back to full GET when range request returns 416', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        const NetworkBytesError('HTTP 416'),
        NetworkBytesOk(
          bytes: Uint8List.fromList(const []),
          contentType: 'image/jpeg',
          finalUrl: 'https://example.com/a.jpg',
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(Uri.parse('https://example.com/a.jpg'));
    expect(result.finalUrl, 'https://example.com/a.jpg');
  });

  test('returns failure when both attempts fail', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        const NetworkBytesError('boom'),
        const NetworkBytesError('boom'),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(Uri.parse('https://example.com/a.jpg'));
    expect(result.failure, isNotNull);
  });

  test('flags videos for full download', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        NetworkBytesOk(
          bytes: Uint8List.fromList(const []),
          contentType: 'video/mp4',
          finalUrl: 'https://example.com/a.mp4',
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(Uri.parse('https://example.com/a.mp4'));
    expect(result.requiresFullDownload, isTrue);
  });

  test('parses Last-Modified as UTC wall-clock', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        NetworkBytesOk(
          bytes: Uint8List.fromList(const []),
          contentType: 'image/jpeg',
          finalUrl: 'https://example.com/a.jpg',
          lastModified: DateTime.utc(2024, 4, 12, 14, 32, 0),
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(Uri.parse('https://example.com/a.jpg'));
    expect(result.takenAt, DateTime.utc(2024, 4, 12, 14, 32, 0));
  });
}
```

(The `lastModified` field is added to `NetworkBytesOk` in this task; update
tests in Task 7 if not added there.)

**Run:** the test command — expect failures.

**Commit:** `test(media): add failing tests for UrlMetadataExtractor`

### Task 10 — Implement UrlMetadataExtractor

Create `lib/features/media/data/services/url_metadata_extractor.dart`:

```dart
import 'dart:typed_data';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';

typedef ExifExtractFn = Future<ExtractedMetadata> Function(Uint8List bytes);

class UrlExtractionResult {
  const UrlExtractionResult({
    required this.url,
    required this.finalUrl,
    this.takenAt,
    this.width,
    this.height,
    this.lat,
    this.lon,
    this.contentType,
    this.requiresFullDownload = false,
    this.failure,
  });

  final String url;
  final String finalUrl;
  final DateTime? takenAt;
  final int? width;
  final int? height;
  final double? lat;
  final double? lon;
  final String? contentType;
  final bool requiresFullDownload;
  final String? failure;
}

class UrlMetadataExtractor {
  UrlMetadataExtractor({
    required NetworkUrlResolver resolver,
    required ExifExtractFn exifExtract,
  })  : _resolver = resolver,
        _exif = exifExtract;

  final NetworkUrlResolver _resolver;
  final ExifExtractFn _exif;

  Future<UrlExtractionResult> extract(Uri uri) async {
    final rangeAttempt = await _resolver.fetch(
      uri,
      extraHeaders: {'Range': 'bytes=0-65535'},
    );
    if (rangeAttempt is NetworkBytesUnauthenticated) {
      return UrlExtractionResult(
        url: uri.toString(),
        finalUrl: uri.toString(),
        failure: 'unauthenticated',
      );
    }
    if (rangeAttempt is NetworkBytesOk) {
      return _fromBytes(uri, rangeAttempt);
    }
    final fullAttempt = await _resolver.fetch(uri);
    if (fullAttempt is NetworkBytesOk) {
      return _fromBytes(uri, fullAttempt);
    }
    if (fullAttempt is NetworkBytesUnauthenticated) {
      return UrlExtractionResult(
        url: uri.toString(),
        finalUrl: uri.toString(),
        failure: 'unauthenticated',
      );
    }
    return UrlExtractionResult(
      url: uri.toString(),
      finalUrl: uri.toString(),
      failure: (fullAttempt as NetworkBytesError).message,
    );
  }

  Future<UrlExtractionResult> _fromBytes(
    Uri uri,
    NetworkBytesOk ok,
  ) async {
    final isVideo = ok.contentType?.startsWith('video/') ?? false;
    if (isVideo) {
      return UrlExtractionResult(
        url: uri.toString(),
        finalUrl: ok.finalUrl,
        contentType: ok.contentType,
        requiresFullDownload: true,
        takenAt: ok.lastModified,
      );
    }
    final exif = await _exif(ok.bytes);
    return UrlExtractionResult(
      url: uri.toString(),
      finalUrl: ok.finalUrl,
      contentType: ok.contentType,
      width: exif.width,
      height: exif.height,
      takenAt: exif.takenAt ?? ok.lastModified,
      lat: exif.lat,
      lon: exif.lon,
    );
  }
}
```

Add a `lastModified` field to `NetworkBytesOk` (Task 8) and parse the
`Last-Modified` header in `NetworkUrlResolver`. Use
`DateTime.utc(...)`-style construction; `HttpDate.parse` returns a UTC
`DateTime`.

**Run:** the test command — expect 5 passing.

**Commit:** `feat(media): add UrlMetadataExtractor with range + full-GET fallback`

### Task 11 — Failing tests for network fetch pipeline

Create `test/features/media/data/services/network_fetch_pipeline_test.dart`.
The pipeline:

- Synchronously inserts a `MediaItem` row per URL with `lastVerifiedAt = null`,
  `sourceType = networkUrl`.
- Queues background metadata fill, 4-concurrent + per-host throttle
  (max 1 every 250 ms per host).
- On success, updates the row with extracted metadata + `lastVerifiedAt = now`.
- On failure, sets `isOrphaned = true` and writes a `media_fetch_diagnostics` row.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
// ... (a stub extractor that controls per-call results + a fake clock)

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('synchronous insert fills url+sourceType, leaves lastVerifiedAt null',
      () async {
    // ...
  });

  test('background success patches row + sets lastVerifiedAt', () async {
    // ...
  });

  test('background failure sets isOrphaned + writes diagnostics row', () async {
    // ...
  });

  test('respects 4-concurrent fan-out', () async {
    // Stubbed extractor counts active calls; assert peak <= 4.
  });

  test('throttles same host to 1 per 250ms', () async {
    // Drive a fake clock; assert second call to same host waits.
  });
}
```

**Run:** the test command — expect failures.

**Commit:** `test(media): add failing tests for network fetch pipeline`

### Task 12 — Implement network fetch pipeline

Create `lib/features/media/data/services/network_fetch_pipeline.dart`:

- `Future<List<int>> ingest(List<Uri> urls, {bool autoMatch = true})` returns
  newly-created `MediaItem` IDs, all with `lastVerifiedAt = null`.
- Internally enqueues each ID for background metadata fill via a
  `Stream.fromIterable(...).asyncMap(...)`-style worker pool with semaphore-
  limited concurrency (4) and per-host last-call timestamps (`Map<String, DateTime>`).
- Background worker calls `UrlMetadataExtractor.extract(uri)`, updates the row
  with the result, and sets `lastVerifiedAt = DateTime.now().toUtc()`.
- On `failure != null`, sets `isOrphaned = true` and inserts a
  `media_fetch_diagnostics` row.

```dart
class NetworkFetchPipeline {
  NetworkFetchPipeline({
    required AppDatabase db,
    required UrlMetadataExtractor extractor,
    int maxConcurrent = 4,
    Duration perHostMinInterval = const Duration(milliseconds: 250),
    DateTime Function() now = _defaultNow,
  })  : _db = db,
        _extractor = extractor,
        _maxConcurrent = maxConcurrent,
        _perHostMinInterval = perHostMinInterval,
        _now = now;

  // ... fields, _semaphore, _hostLastCall map, etc.

  Future<List<int>> ingest(List<Uri> urls, {bool autoMatch = true}) async {
    final ids = <int>[];
    for (final uri in urls) {
      final id = await _db.into(_db.mediaItems).insert(
        MediaItemsCompanion.insert(
          sourceType: 'networkUrl',
          url: Value(uri.toString()),
          isOrphaned: const Value(false),
        ),
      );
      ids.add(id);
    }
    // Fire-and-forget background fill so callers see rows immediately.
    unawaited(_runFill(ids, urls));
    return ids;
  }

  Future<void> _runFill(List<int> ids, List<Uri> urls) async {
    // ... bounded concurrency + per-host throttle.
  }
}

DateTime _defaultNow() => DateTime.now().toUtc();
```

**Run:** the test command — expect 5 passing.

**Commit:** `feat(media): add network fetch pipeline (sync insert + background fill)`

### Task 13 — Failing widget tests for URL tab + sign-in sheet + commit/undo

Create `test/features/media/presentation/widgets/url_tab_test.dart`. Cover:

1. Segmented control shows two options (URLs/Manifest); Manifest body is the
   placeholder card.
2. Multi-line text field validates each line; invalid lines show inline error.
3. "Add URL" single-line entry appends to the staged set.
4. Auto-match-by-date checkbox is on by default.
5. "Add" button is disabled when the staged set is empty / has any invalid lines.
6. Tapping "Add" calls the StateNotifier's `commit()` and shows success snackbar
   with "Undo".
7. Tapping "Undo" calls `undoCommit(ids)`.
8. On a 401 path (test fakes the resolver), a "Sign in" badge appears; tapping
   it opens the sign-in sheet.
9. Saving the sign-in sheet calls `NetworkCredentialsService.save(...)` and
   re-runs the failed URLs.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/url_tab.dart';
// ... fakes for providers

void main() {
  testWidgets('renders mode segmented control with URLs default', (tester) async {
    // ...
  });
  testWidgets('per-line validation marks invalid URL inline', (tester) async {
    // ...
  });
  testWidgets('Add button disabled when any invalid line', (tester) async {
    // ...
  });
  testWidgets('autoMatchByDate checkbox is on by default', (tester) async {
    // ...
  });
  testWidgets('committing calls notifier.commit and shows undo snack', (tester) async {
    // ...
  });
  testWidgets('undo calls notifier.undoCommit(ids)', (tester) async {
    // ...
  });
  testWidgets('401 surfaces Sign in badge', (tester) async {
    // ...
  });
  testWidgets('saving sign-in sheet calls credentials.save()', (tester) async {
    // ...
  });
}
```

**Run:** `flutter test test/features/media/presentation/widgets/url_tab_test.dart`
— expect failures.

**Commit:** `test(media): add failing widget tests for URL tab + sign-in sheet`

### Task 14 — Implement URL tab providers (StateNotifier with commit/undo)

Create `lib/features/media/presentation/providers/url_tab_providers.dart`.
Mirror `files_tab_providers.dart`. Riverpod 2.x StateNotifier with
required-named-deps from the start:

```dart
class UrlTabState {
  const UrlTabState({
    this.mode = UrlTabMode.urls,
    this.draftLines = const [],
    this.autoMatchByDate = true,
    this.committedIds = const [],
    this.lastError,
    this.unauthenticatedHosts = const {},
  });
  // ... copyWith, == / hashCode
}

enum UrlTabMode { urls, manifest }

class UrlTabNotifier extends StateNotifier<UrlTabState> {
  UrlTabNotifier({
    required NetworkFetchPipeline pipeline,
    required NetworkCredentialsService credentials,
  })  : _pipeline = pipeline,
        _credentials = credentials,
        super(const UrlTabState());

  final NetworkFetchPipeline _pipeline;
  final NetworkCredentialsService _credentials;

  void setMode(UrlTabMode mode) =>
      state = state.copyWith(mode: mode);

  void setDraft(String text) {
    final lines = text.split('\n');
    state = state.copyWith(draftLines: lines);
  }

  void appendSingle(String url) {
    state = state.copyWith(draftLines: [...state.draftLines, url]);
  }

  void setAutoMatchByDate(bool value) =>
      state = state.copyWith(autoMatchByDate: value);

  Future<List<int>> commit() async {
    final uris = state.draftLines
        .map(UrlValidator.parse)
        .whereType<UrlValidationOk>()
        .map((r) => r.uri)
        .toList(growable: false);
    final ids = await _pipeline.ingest(
      uris,
      autoMatch: state.autoMatchByDate,
    );
    state = state.copyWith(committedIds: ids, draftLines: const []);
    return ids;
  }

  Future<void> undoCommit(List<int> ids) async {
    await _pipeline.deleteIds(ids);
    state = state.copyWith(committedIds: const []);
  }

  Future<void> saveCredentials({
    required String hostname,
    required String authType,
    String? username,
    String? password,
    String? token,
    String? displayName,
  }) async {
    await _credentials.save(
      hostname: hostname,
      authType: authType,
      username: username,
      password: password,
      token: token,
      displayName: displayName,
    );
    state = state.copyWith(
      unauthenticatedHosts: {...state.unauthenticatedHosts}..remove(hostname),
    );
  }
}

final urlTabNotifierProvider =
    StateNotifierProvider<UrlTabNotifier, UrlTabState>((ref) {
  return UrlTabNotifier(
    pipeline: ref.watch(networkFetchPipelineProvider),
    credentials: ref.watch(networkCredentialsServiceProvider),
  );
});
```

Also create the supporting provider declarations
(`networkFetchPipelineProvider`, `networkCredentialsServiceProvider`) here or
in a sibling `network_providers.dart`.

**Run:** widget tests still fail (UI not built). Check analyzer is clean.

**Commit:** `feat(media): add URL tab Riverpod providers (commit/undo, sign-in)`

### Task 15 — Implement URL tab widget + sign-in sheet + review pane

Create:

- `lib/features/media/presentation/widgets/url_tab.dart` — segmented control,
  multi-line field, per-line validation, "Add URL" single-line, auto-match
  checkbox, "Add" button. Manifest mode body is a placeholder Card with
  text `// TODO(media): l10n` "Manifest mode arrives in Phase 3b".
- `lib/features/media/presentation/widgets/url_review_pane.dart` — mirrors
  `FileReviewPane`. Reads from `mediaItemsForCommitProvider.family(ids)` so
  it shows shimmer for any item with `lastVerifiedAt == null`, then thumbnails
  via `cached_network_image` (Task 16).
- `lib/features/media/presentation/widgets/network_signin_sheet.dart` —
  hostname read-only, auth type segmented control, conditional fields,
  Save button calls `urlTabNotifierProvider.notifier.saveCredentials(...)`.

Always guard async gaps:

```dart
final ids = await ref.read(urlTabNotifierProvider.notifier).commit();
if (!context.mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  // TODO(media): l10n
  content: Text('Added ${ids.length} URLs'),
  action: SnackBarAction(
    // TODO(media): l10n
    label: 'Undo',
    onPressed: () => ref
        .read(urlTabNotifierProvider.notifier)
        .undoCommit(ids),
  ),
));
```

**Run:** widget tests now pass.

**Commit:** `feat(media): add URL tab UI, review pane, and sign-in sheet`

### Task 16 — Wire `cached_network_image` with auth headers + caps

Add `cached_network_image` to `pubspec.yaml`. Create
`lib/features/media/presentation/widgets/network_thumbnail.dart`:

```dart
class NetworkThumbnail extends ConsumerWidget {
  const NetworkThumbnail({super.key, required this.url, this.size = 96});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(networkCredentialsServiceProvider);
    return FutureBuilder<Map<String, String>?>(
      future: credentials.headersFor(Uri.parse(url)),
      builder: (context, snap) {
        return CachedNetworkImage(
          imageUrl: url,
          httpHeaders: snap.data,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => const UnavailableMediaPlaceholder(),
        );
      },
    );
  }
}
```

Configure caches at app startup via
`DefaultCacheManager`-style configuration (500 MB disk, 75 MB memory, defaults
declared in a constants file `lib/features/media/data/network_cache_config.dart`).
Phase 3c will surface these as Settings; for 3a they're constants.

Add a unit test
`test/features/media/data/network_cache_config_test.dart` asserting the
defaults: `kDiskCacheCapBytes == 500 * 1024 * 1024`,
`kMemoryCacheCapBytes == 75 * 1024 * 1024`.

**Run:** `flutter test test/features/media/data/network_cache_config_test.dart`
— passes; widget test for review pane now exercises `NetworkThumbnail`.

**Commit:** `feat(media): wire cached_network_image with auth + LRU caps`

### Task 17 — Swap picker URL placeholder + update fossil test

Open `lib/features/media/presentation/pages/photo_picker_page.dart` (URL
placeholder at lines ~166-167). Replace the placeholder `Center(...)` with
`const UrlTab()`.

Update the fossil at
`test/features/media/presentation/pages/photo_picker_page_tab_shell_test.dart`:
the URL tab assertion changes from "shows Center placeholder" to "renders
`UrlTab`" (`expect(find.byType(UrlTab), findsOneWidget);`).

**Run:** `flutter test test/features/media/presentation/pages/photo_picker_page_tab_shell_test.dart`
— passes.

**Commit:** `feat(media): swap URL placeholder for new URL tab in picker`

### Task 18 — Final: format, analyze, full-suite test

```bash
dart format lib/ test/
flutter analyze
flutter test
```

Expect: zero formatter changes, zero analyzer warnings, all tests green.

**Commit:** `chore(media): format + analyze pass for Phase 3a`

## Out of scope (do NOT do these in 3a)

- Manifest parsing / Manifest mode (Phase 3b).
- Subscription polling (Phase 3b).
- Settings → Network Sources page (Phase 3c).
- HTTP scan action (Phase 3c).
- "Trust this host" cert override (Phase 3c, advanced).

## Acceptance criteria for Phase 3a

- A user can paste 50 image URLs in the URL tab, see rows appear immediately
  with shimmer placeholders, and watch thumbnails fill in over the next minute.
- A 401 response surfaces a "Sign in" badge; opening the sheet, saving Basic
  or Bearer creds, and re-running the URLs succeeds.
- All URL tab + resolver + extractor + pipeline tests pass with
  `MockClient`-driven HTTP — no `coverage:ignore` on HTTP code.
- Picker page test fossil now asserts `UrlTab` renders, not a placeholder.
- `flutter analyze` clean. `dart format .` no-op. Full `flutter test` green.

## Pubspec additions to expect

The engineer should verify each is present and add if missing:

- `cached_network_image` (Task 16)
- `video_thumbnail` (Task 10 / video metadata)
- `ffmpeg_kit_flutter` (Task 10 / video duration)

`flutter_secure_storage` and `package:http` are already in `pubspec.yaml` from
Phase 2.
