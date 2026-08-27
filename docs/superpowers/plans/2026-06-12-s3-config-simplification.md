# S3 Configuration Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink the S3 config form to four visible fields by auto-deriving the region from the endpoint hostname and self-healing wrong regions from server hints.

**Architecture:** A pure `deriveRegion()` function maps endpoint hostnames to regions. `S3ApiClient` gains a one-shot "region hint" replay: when a response carries `x-amz-bucket-region` or an `AuthorizationHeaderMalformed` body, it re-signs with the hinted region, replays once, and reports the correction via a callback. `S3StorageProvider` persists corrections; the form moves Region/Prefix/Path-style into a collapsed Advanced expander.

**Tech Stack:** Flutter/Dart, package:http + MockClient for tests, flutter gen-l10n, Riverpod.

**Spec:** `docs/superpowers/specs/2026-06-12-s3-config-simplification-design.md`

**Branch:** `feat/s3-config-simplification` (create via worktree per CLAUDE.md; run `git submodule update --init --recursive` and `flutter pub get` in a fresh worktree).

**Project rules that apply to every task:** run `dart format lib/ test/` before each commit; verify with whole-project `flutter analyze` (never piped); commit messages without Co-Authored-By lines.

---

## File Map

| File | Change |
|---|---|
| `lib/core/services/cloud_storage/s3/s3_region.dart` | Create — pure region derivation |
| `lib/core/services/cloud_storage/s3/s3_api_client.dart` | Modify — hint extraction, correction replay, callback, error message |
| `lib/core/services/cloud_storage/s3_storage_provider.dart` | Modify — factory typedef, persist callback, testConnection param |
| `lib/features/settings/presentation/pages/s3_config_page.dart` | Modify — Advanced expander, auto region helper, detection snackbar |
| `lib/l10n/arb/app_*.arb` (11 files) + generated `app_localizations*.dart` | Modify — 3 new strings |
| `test/core/services/cloud_storage/s3/s3_region_test.dart` | Create |
| `test/core/services/cloud_storage/s3/s3_api_client_test.dart` | Modify — correction group |
| `test/core/services/cloud_storage/s3_storage_provider_test.dart` | Modify — factory signature, persist tests |
| `test/features/settings/presentation/s3_config_page_test.dart` | Modify — expander tests, factory signature |

---

### Task 1: `deriveRegion` pure function

**Files:**
- Create: `lib/core/services/cloud_storage/s3/s3_region.dart`
- Test: `test/core/services/cloud_storage/s3/s3_region_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/services/cloud_storage/s3/s3_region_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_region.dart';

void main() {
  group('deriveRegion', () {
    test('blank endpoint (AWS proper) defaults to us-east-1', () {
      expect(deriveRegion(''), 'us-east-1');
      expect(deriveRegion('   '), 'us-east-1');
    });

    test('AWS regional endpoint', () {
      expect(
        deriveRegion('https://s3.eu-west-1.amazonaws.com'),
        'eu-west-1',
      );
    });

    test('AWS global endpoint is us-east-1', () {
      expect(deriveRegion('https://s3.amazonaws.com'), 'us-east-1');
    });

    test('AWS dualstack endpoint', () {
      expect(
        deriveRegion('https://s3.dualstack.ap-southeast-2.amazonaws.com'),
        'ap-southeast-2',
      );
    });

    test('AWS legacy dash-form endpoint', () {
      expect(
        deriveRegion('https://s3-us-west-2.amazonaws.com'),
        'us-west-2',
      );
    });

    test('Cloudflare R2 is always auto', () {
      expect(
        deriveRegion('https://a1b2c3d4.r2.cloudflarestorage.com'),
        'auto',
      );
    });

    test('Backblaze B2', () {
      expect(
        deriveRegion('https://s3.us-west-004.backblazeb2.com'),
        'us-west-004',
      );
    });

    test('DigitalOcean Spaces', () {
      expect(deriveRegion('https://nyc3.digitaloceanspaces.com'), 'nyc3');
    });

    test('Wasabi', () {
      expect(
        deriveRegion('https://s3.eu-central-1.wasabisys.com'),
        'eu-central-1',
      );
    });

    test('Scaleway', () {
      expect(deriveRegion('https://s3.fr-par.scw.cloud'), 'fr-par');
    });

    test('unknown hosts (MinIO, NAS) default to us-east-1', () {
      expect(deriveRegion('http://nas.local:9000'), 'us-east-1');
      expect(deriveRegion('https://minio.example.com'), 'us-east-1');
    });

    test('matching is case-insensitive', () {
      expect(
        deriveRegion('HTTPS://S3.EU-WEST-1.AMAZONAWS.COM'),
        'eu-west-1',
      );
    });

    test('unparseable input defaults to us-east-1', () {
      expect(deriveRegion('not a url ::'), 'us-east-1');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/cloud_storage/s3/s3_region_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'submersion/core/services/cloud_storage/s3/s3_region.dart'` (file does not exist).

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/cloud_storage/s3/s3_region.dart`:

```dart
/// Static region derivation from an S3-compatible endpoint.
///
/// Pure function, no I/O. Providers that encode the region in the endpoint
/// hostname (or fix it to a constant) are matched here; everything else
/// falls back to `us-east-1`, which MinIO and region-agnostic servers
/// accept. A wrong guess is healed at request time by S3ApiClient's
/// server-assisted region correction.
String deriveRegion(String endpoint) {
  final trimmed = endpoint.trim();
  if (trimmed.isEmpty) return 'us-east-1';
  final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return 'us-east-1';
  if (host.endsWith('.r2.cloudflarestorage.com')) return 'auto';
  for (final pattern in _regionHostPatterns) {
    final match = pattern.firstMatch(host);
    if (match != null) return match.group(1)!;
  }
  return 'us-east-1';
}

/// Hostname shapes whose first capture group is the region. The AWS
/// pattern covers regional (`s3.{r}.`), dualstack (`s3.dualstack.{r}.`),
/// and legacy dash (`s3-{r}.`) hosts; the bare global endpoint
/// `s3.amazonaws.com` intentionally matches none of them.
final List<RegExp> _regionHostPatterns = [
  RegExp(r'(?:^|\.)s3[.-](?:dualstack\.)?([a-z0-9-]+)\.amazonaws\.com$'),
  RegExp(r'^s3\.([a-z0-9-]+)\.backblazeb2\.com$'),
  RegExp(r'(?:^|\.)([a-z0-9-]+)\.digitaloceanspaces\.com$'),
  RegExp(r'^s3\.([a-z0-9-]+)\.wasabisys\.com$'),
  RegExp(r'^s3\.([a-z0-9-]+)\.scw\.cloud$'),
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/cloud_storage/s3/s3_region_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/s3_region.dart test/core/services/cloud_storage/s3/s3_region_test.dart
flutter analyze
git add lib/core/services/cloud_storage/s3/s3_region.dart test/core/services/cloud_storage/s3/s3_region_test.dart
git commit -m "feat(sync): derive S3 region from endpoint hostname"
```

---

### Task 2: Server-assisted region correction in `S3ApiClient`

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart` (constructor ~31-43, `_target` ~160-182, `_sendWithRetry` ~184-211, `_send` ~230-264, `_xmlErrorCode` ~290-299)
- Test: `test/core/services/cloud_storage/s3/s3_api_client_test.dart`

The client keeps an *effective region* that starts as the configured one. On a failed response carrying a server region hint, it adopts the hint, replays the request once, and fires `onRegionCorrected` if the replay succeeds. `_target` and `_send` read the effective region, so an AWS correction also moves to the right regional host.

- [ ] **Step 1: Write the failing tests**

Add to `test/core/services/cloud_storage/s3/s3_api_client_test.dart` (inside `main()`, after the existing `request shape` group). The XML body helper goes at top level next to `minioConfig()`/`awsConfig()`:

```dart
String malformedAuthBody(String expectedRegion) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Error><Code>AuthorizationHeaderMalformed</Code>'
    '<Message>the region is wrong; expecting $expectedRegion</Message>'
    '<Region>$expectedRegion</Region></Error>';
```

```dart
  group('region correction', () {
    test(
      'adopts x-amz-bucket-region hint, replays on the corrected AWS host, '
      'and reports the correction',
      () async {
        final urls = <String>[];
        final mock = MockClient((request) async {
          urls.add(request.url.toString());
          if (urls.length == 1) {
            return http.Response(
              '',
              301,
              headers: {'x-amz-bucket-region': 'us-west-2'},
            );
          }
          expect(
            request.headers['authorization'],
            contains('/us-west-2/s3/aws4_request'),
          );
          return http.Response('', 200);
        });
        String? corrected;
        final client = S3ApiClient(
          awsConfig(), // configured region: eu-west-1
          httpClient: mock,
          now: () => DateTime.utc(2026, 6, 12),
          retryDelay: Duration.zero,
          onRegionCorrected: (region) => corrected = region,
        );

        await client.putObject('k.json', Uint8List.fromList([1]));

        expect(urls, hasLength(2));
        expect(urls[0], startsWith('https://dive-sync.s3.eu-west-1.amazonaws.com/'));
        expect(urls[1], startsWith('https://dive-sync.s3.us-west-2.amazonaws.com/'));
        expect(corrected, 'us-west-2');
      },
    );

    test(
      'adopts the Region element of an AuthorizationHeaderMalformed body '
      '(R2-style custom endpoint)',
      () async {
        var requests = 0;
        final mock = MockClient((request) async {
          requests++;
          if (requests == 1) {
            return http.Response(malformedAuthBody('auto'), 400);
          }
          expect(
            request.headers['authorization'],
            contains('/auto/s3/aws4_request'),
          );
          return http.Response('', 200);
        });
        String? corrected;
        final client = S3ApiClient(
          minioConfig(),
          httpClient: mock,
          now: () => DateTime.utc(2026, 6, 12),
          retryDelay: Duration.zero,
          onRegionCorrected: (region) => corrected = region,
        );

        await client.putObject('k.json', Uint8List.fromList([1]));

        expect(requests, 2);
        expect(corrected, 'auto');
      },
    );

    test('a failed replay throws and does not report a correction', () async {
      var requests = 0;
      final mock = MockClient((_) async {
        requests++;
        return http.Response(malformedAuthBody('auto'), 400);
      });
      String? corrected;
      final client = S3ApiClient(
        minioConfig(),
        httpClient: mock,
        now: () => DateTime.utc(2026, 6, 12),
        retryDelay: Duration.zero,
        onRegionCorrected: (region) => corrected = region,
      );

      await expectLater(
        client.putObject('k.json', Uint8List.fromList([1])),
        throwsA(isA<CloudStorageException>()),
      );
      expect(requests, 2); // one correction replay, then give up
      expect(corrected, isNull);
    });

    test('a hint equal to the effective region is not replayed', () async {
      var requests = 0;
      final mock = MockClient((_) async {
        requests++;
        return http.Response(malformedAuthBody('eu-west-1'), 400);
      });
      final client = S3ApiClient(
        awsConfig(), // already eu-west-1
        httpClient: mock,
        now: () => DateTime.utc(2026, 6, 12),
        retryDelay: Duration.zero,
      );

      await expectLater(
        client.getObject('k.json'),
        throwsA(isA<CloudStorageException>()),
      );
      expect(requests, 1);
    });

    test('the corrected region sticks for later requests', () async {
      var requests = 0;
      final mock = MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(
            '',
            301,
            headers: {'x-amz-bucket-region': 'us-west-2'},
          );
        }
        expect(
          request.headers['authorization'],
          contains('/us-west-2/s3/aws4_request'),
        );
        return http.Response('', 200);
      });
      final client = S3ApiClient(
        awsConfig(),
        httpClient: mock,
        now: () => DateTime.utc(2026, 6, 12),
        retryDelay: Duration.zero,
      );

      await client.putObject('a.json', Uint8List.fromList([1]));
      await client.putObject('b.json', Uint8List.fromList([2]));
      expect(requests, 3); // 1 hinted failure + replay, then 1 clean send
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: FAIL — `No named parameter with the name 'onRegionCorrected'` (compile error).

- [ ] **Step 3: Implement the correction**

In `lib/core/services/cloud_storage/s3/s3_api_client.dart`:

3a. Replace the constructor and fields (the `this._config` formal becomes a plain parameter so the initializer list can seed `_region`):

```dart
  S3ApiClient(
    S3Config config, {
    http.Client? httpClient,
    DateTime Function()? now,
    Duration retryDelay = const Duration(milliseconds: 500),
    this.onRegionCorrected,
  }) : _config = config,
       _region = config.region,
       _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now,
       _retryDelay = retryDelay;

  final S3Config _config;
  final http.Client _http;
  final DateTime Function() _now;
  final Duration _retryDelay;

  /// Called after a server region hint led to a successful replay, so the
  /// owner can persist the corrected region.
  final void Function(String region)? onRegionCorrected;

  /// Effective signing/addressing region: starts as the configured region
  /// and is updated for the client's lifetime when the server corrects it.
  String _region;
```

3b. In `_target()`, replace both `_config.region` references with `_region`:

```dart
      host = _config.pathStyle
          ? 's3.$_region.amazonaws.com'
          : '${_config.bucket}.s3.$_region.amazonaws.com';
```

3c. In `_send()`, replace `region: _config.region,` with `region: _region,`.

3d. In `_sendWithRetry()`, insert the correction attempt after the first `_send` (the existing `if (response.statusCode < 500) return response;` line stays, now below it):

```dart
      final response = await _send(
        method,
        key,
        queryParams: queryParams,
        body: body,
      );
      if (response.statusCode >= 300) {
        final corrected = await _replayWithRegionHint(
          response,
          method,
          key,
          queryParams,
          body,
        );
        if (corrected != null) return corrected;
      }
      if (response.statusCode < 500) return response;
```

3e. Add the two new private methods (place after `_retry`), and generalize `_xmlErrorCode` into `_xmlElementText`:

```dart
  /// If [response] carries a region hint that differs from the effective
  /// region, adopts it, replays the request once, and reports the
  /// correction when the replay succeeds. Returns null when no correction
  /// applies. A transport exception from the replay propagates to
  /// _sendWithRetry's catch clauses, whose retry then signs with the
  /// already-corrected region.
  Future<http.Response?> _replayWithRegionHint(
    http.Response response,
    String method,
    String key,
    Map<String, String> queryParams,
    Uint8List? body,
  ) async {
    final hint = _regionHint(response);
    if (hint == null || hint == _region) return null;
    _region = hint;
    final replay = await _send(
      method,
      key,
      queryParams: queryParams,
      body: body,
    );
    if (replay.statusCode < 300) onRegionCorrected?.call(hint);
    return replay;
  }

  /// The region the server says it expects: the x-amz-bucket-region
  /// header (301 and most 403 responses), or the Region element of an
  /// AuthorizationHeaderMalformed error body.
  String? _regionHint(http.Response response) {
    final header = response.headers['x-amz-bucket-region'];
    if (header != null && header.isNotEmpty) return header;
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_xmlElementText(body, 'Code') != 'AuthorizationHeaderMalformed') {
      return null;
    }
    final region = _xmlElementText(body, 'Region');
    return (region == null || region.isEmpty) ? null : region;
  }
```

Replace `_xmlErrorCode` with:

```dart
  String? _xmlElementText(String body, String element) {
    if (body.isEmpty) return null;
    try {
      return XmlDocument.parse(
        body,
      ).findAllElements(element).firstOrNull?.innerText;
    } on XmlException {
      return null;
    }
  }
```

and update its call site in `_throwFor`:

```dart
    final errorCode = _xmlElementText(
      utf8.decode(response.bodyBytes, allowMalformed: true),
      'Code',
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: PASS (all pre-existing tests plus the 5 new ones).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/s3_api_client.dart test/core/services/cloud_storage/s3/s3_api_client_test.dart
flutter analyze
git add lib/core/services/cloud_storage/s3/s3_api_client.dart test/core/services/cloud_storage/s3/s3_api_client_test.dart
git commit -m "feat(sync): self-heal S3 region from server hints"
```

---

### Task 3: Region-specific `AuthorizationHeaderMalformed` error message

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart` (`_throwFor`, ~line 266)
- Test: `test/core/services/cloud_storage/s3/s3_api_client_test.dart`

When no hint is extractable (or the replay also failed), the user must not be told to "check the access key" for what is a region problem.

- [ ] **Step 1: Write the failing test**

Add inside the `region correction` group:

```dart
    test(
      'AuthorizationHeaderMalformed without a usable hint explains the '
      'region problem',
      () async {
        final mock = MockClient(
          (_) async => http.Response(
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<Error><Code>AuthorizationHeaderMalformed</Code>'
            '<Message>the region is wrong</Message></Error>',
            400,
          ),
        );
        final client = clientWith(minioConfig(), mock);

        await expectLater(
          client.putObject('k.json', Uint8List.fromList([1])),
          throwsA(
            isA<CloudStorageException>().having(
              (e) => e.message,
              'message',
              contains('signature region'),
            ),
          ),
        );
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: FAIL — actual message is `S3 upload failed for "k.json" (HTTP 400)`.

- [ ] **Step 3: Implement**

In `_throwFor`, immediately after `final errorCode = ...;` and before the `if (response.statusCode == 403)` block, add (matched by error code regardless of HTTP status — AWS uses 400, some providers 403):

```dart
    if (errorCode == 'AuthorizationHeaderMalformed') {
      throw const CloudStorageException(
        "S3 rejected the request's signature region. Open Advanced and "
        'set Region to the value your provider expects.',
      );
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/s3_api_client.dart test/core/services/cloud_storage/s3/s3_api_client_test.dart
flutter analyze
git add lib/core/services/cloud_storage/s3/s3_api_client.dart test/core/services/cloud_storage/s3/s3_api_client_test.dart
git commit -m "fix(sync): explain S3 region mismatch instead of access denied"
```

---

### Task 4: Wire `onRegionCorrected` through `S3StorageProvider`

**Files:**
- Modify: `lib/core/services/cloud_storage/s3_storage_provider.dart` (typedef line 10, imports line 1, `authenticate` ~70, `testConnection` ~90, `_requireSession` ~224)
- Modify: `test/core/services/cloud_storage/s3_storage_provider_test.dart` (fake at line 25, factory lambdas at lines 129, 253, 312, 371)
- Modify: `test/features/settings/presentation/s3_config_page_test.dart` (fake at line 42, factory lambda at line 135)

The typedef gains the callback as an optional named parameter. `S3ApiClient.new` still satisfies it (a function with extra optional named parameters is assignable), but every test lambda and both test fakes need a mechanical signature update — do those in this task so the tree compiles.

- [ ] **Step 1: Write the failing tests**

Add to `test/core/services/cloud_storage/s3_storage_provider_test.dart` (new group inside `main()`):

```dart
  group('region correction persistence', () {
    test('persists a server-corrected region without dropping the client', () async {
      store.stored = config(); // region defaults to us-east-1
      void Function(String region)? captured;
      final client = _FakeS3ApiClient(config());
      final correcting = S3StorageProvider(
        store: store,
        apiClientFactory: (_, {onRegionCorrected}) {
          captured = onRegionCorrected;
          return client;
        },
      );

      await correcting.listFiles(); // builds the session client
      expect(captured, isNotNull);
      captured!('eu-west-1');
      await pumpEventQueue();

      expect(store.stored!.region, 'eu-west-1');
      expect(client.closed, isFalse); // live client keeps its connection
      expect((await correcting.listFiles()), isEmpty); // still usable
    });

    test('testConnection forwards corrections to the caller and does not persist', () async {
      void Function(String region)? captured;
      final probing = S3StorageProvider(
        store: store,
        apiClientFactory: (c, {onRegionCorrected}) {
          captured = onRegionCorrected;
          return _FakeS3ApiClient(c);
        },
      );
      final reported = <String>[];

      await probing.testConnection(
        config(),
        onRegionCorrected: reported.add,
      );
      captured!('auto');
      await pumpEventQueue();

      expect(reported, ['auto']);
      expect(store.stored, isNull); // unsaved probe never writes the store
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3_storage_provider_test.dart`
Expected: FAIL — compile error: `The argument type ... can't be assigned to the parameter type 'S3ApiClientFactory'` / `No named parameter with the name 'onRegionCorrected'`.

- [ ] **Step 3: Implement provider changes**

In `lib/core/services/cloud_storage/s3_storage_provider.dart`:

3a. Add `import 'dart:async';` as the first import.

3b. Replace the typedef:

```dart
/// Builds an [S3ApiClient] for a config; injectable for tests.
typedef S3ApiClientFactory =
    S3ApiClient Function(
      S3Config config, {
      void Function(String region)? onRegionCorrected,
    });
```

3c. In `authenticate()`, build the client with the persist callback:

```dart
    final client = _apiClientFactory(
      config,
      onRegionCorrected: (region) => unawaited(_persistCorrectedRegion(region)),
    );
```

3d. Give `testConnection` a pass-through parameter (probing unsaved values must not write the store, so the caller decides what to do):

```dart
  /// Validates [config] with the same live read+write probe as
  /// [authenticate], without touching the stored credentials. Used by the
  /// settings form's Test Connection action on unsaved values.
  /// [onRegionCorrected] reports a server-corrected region to the caller;
  /// nothing is persisted here.
  Future<void> testConnection(
    S3Config config, {
    void Function(String region)? onRegionCorrected,
  }) async {
    final error = config.validate();
    if (error != null) throw CloudStorageException(error);
    final client = _apiClientFactory(
      config,
      onRegionCorrected: onRegionCorrected,
    );
    try {
      await _probe(client, config);
    } finally {
      client.close();
    }
  }
```

3e. In `_requireSession()`, replace the client creation line:

```dart
      return (
        config: config,
        client: _client ??= _apiClientFactory(
          config,
          onRegionCorrected: (region) =>
              unawaited(_persistCorrectedRegion(region)),
        ),
      );
```

3f. Add the persist helper (place after `_requireSession`). It deliberately does NOT call `_invalidate()`: the live client already signs with the corrected region, and closing it mid-operation would break in-flight work (e.g. a paginated list).

```dart
  /// Persists a server-corrected region without invalidating the live
  /// client, which already signs with the correction. A failed persist is
  /// harmless: the correction simply recurs on the next launch.
  Future<void> _persistCorrectedRegion(String region) async {
    final config = _cachedConfig;
    if (config == null || config.region == region) return;
    final updated = config.copyWith(region: region);
    _cachedConfig = updated;
    try {
      await _store.save(updated);
      _log.info('Persisted server-corrected S3 region: $region');
    } catch (e) {
      _log.warning('Could not persist corrected S3 region: $e');
    }
  }
```

3g. Mechanical test updates for the new factory signature:

`test/core/services/cloud_storage/s3_storage_provider_test.dart`:
- Line 25 area — add to `_FakeS3ApiClient`'s fields:

```dart
  @override
  void Function(String region)? onRegionCorrected;
```

- Line 129: `apiClientFactory: (config) {` → `apiClientFactory: (config, {onRegionCorrected}) {`
- Line 253: `apiClientFactory: (_) => client,` → `apiClientFactory: (_, {onRegionCorrected}) => client,`
- Line 312: same change as 253.
- Line 371: `apiClientFactory: (c) {` → `apiClientFactory: (c, {onRegionCorrected}) {`

`test/features/settings/presentation/s3_config_page_test.dart`:
- Add the same `onRegionCorrected` override field to its `_FakeS3ApiClient` (line 42 area).
- Line 135: `apiClientFactory: (_) => apiClient,` → `apiClientFactory: (_, {onRegionCorrected}) => apiClient..onRegionCorrected = onRegionCorrected,`

(The page-test fake's `onRegionCorrected` is a mutable field, so the factory can hand the provider's callback to the fake; Task 6 uses it to simulate a detection.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3_storage_provider_test.dart test/features/settings/presentation/s3_config_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3_storage_provider.dart test/core/services/cloud_storage/s3_storage_provider_test.dart test/features/settings/presentation/s3_config_page_test.dart
flutter analyze
git add lib/core/services/cloud_storage/s3_storage_provider.dart test/core/services/cloud_storage/s3_storage_provider_test.dart test/features/settings/presentation/s3_config_page_test.dart
git commit -m "feat(sync): persist server-corrected S3 region"
```

---

### Task 5: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (s3Config block, lines ~5927-5949) and the 10 other `app_*.arb` files
- Generated: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

ARB keys are kept alphabetically sorted; `@`-metadata sits immediately after its key (see the chart strings near line 79 for the placeholder convention).

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, insert each key at its alphabetical position within the `settings_s3Config_` block:

After `"settings_s3Config_action_testConnection"` (before `_appBar_title`):

```json
  "settings_s3Config_advanced_title": "Advanced",
```

After `"settings_s3Config_field_prefix_label"` (before `_field_region_label`):

```json
  "settings_s3Config_field_region_helperAuto": "Auto-detected: {region}",
  "@settings_s3Config_field_region_helperAuto": {
    "placeholders": {
      "region": {
        "type": "String"
      }
    }
  },
```

After `"settings_s3Config_saved"` (before `_test_success`):

```json
  "settings_s3Config_test_regionDetected": "Region detected: {region}",
  "@settings_s3Config_test_regionDetected": {
    "placeholders": {
      "region": {
        "type": "String"
      }
    }
  },
```

- [ ] **Step 2: Add the 10 translations**

Check whether non-English ARBs carry `@`-metadata: `grep -c '"@' lib/l10n/arb/app_de.arb` — if 0, add string-only entries; if non-zero, mirror the en metadata. Insert the three keys at the same alphabetical positions in each file:

| File | advanced_title | field_region_helperAuto | test_regionDetected |
|---|---|---|---|
| app_ar.arb | متقدم | تم الاكتشاف تلقائيًا: {region} | تم اكتشاف المنطقة: {region} |
| app_de.arb | Erweitert | Automatisch erkannt: {region} | Region erkannt: {region} |
| app_es.arb | Avanzado | Detectado automáticamente: {region} | Región detectada: {region} |
| app_fr.arb | Avancé | Détection automatique : {region} | Région détectée : {region} |
| app_he.arb | מתקדם | זוהה אוטומטית: {region} | זוהה אזור: {region} |
| app_hu.arb | Speciális | Automatikusan észlelve: {region} | Észlelt régió: {region} |
| app_it.arb | Avanzate | Rilevato automaticamente: {region} | Regione rilevata: {region} |
| app_nl.arb | Geavanceerd | Automatisch gedetecteerd: {region} | Regio gedetecteerd: {region} |
| app_pt.arb | Avançado | Detectado automaticamente: {region} | Região detectada: {region} |
| app_zh.arb | 高级 | 自动检测：{region} | 检测到区域：{region} |

- [ ] **Step 3: Regenerate and verify**

```bash
flutter gen-l10n
flutter analyze
```

Expected: gen-l10n exits cleanly; analyze reports no issues. Quick sanity check that the getters exist:

```bash
grep -c "settings_s3Config_advanced_title\|settings_s3Config_field_region_helperAuto\|settings_s3Config_test_regionDetected" lib/l10n/arb/app_localizations_en.dart
```

Expected: at least 3 matches.

- [ ] **Step 4: Commit**

```bash
dart format lib/l10n/
git add lib/l10n/
git commit -m "feat(sync): l10n strings for simplified S3 config form"
```

---

### Task 6: Restructure the form page

**Files:**
- Modify: `lib/features/settings/presentation/pages/s3_config_page.dart`
- Test: `test/features/settings/presentation/s3_config_page_test.dart`

Visible fields: Endpoint, Bucket, Access Key ID, Secret Access Key. Region, Key Prefix, and Path-style move into a collapsed `ExpansionTile`. The region controller starts EMPTY (no more `text: 'us-east-1'`); the effective region is manual-if-nonempty, else `deriveRegion(endpoint)`.

- [ ] **Step 1: Write the failing widget tests**

Add to `test/features/settings/presentation/s3_config_page_test.dart`. First extend `_FakeS3ApiClient` (the `onRegionCorrected` field exists from Task 4) with a correction trigger — replace its `listObjects` with:

```dart
  /// When set, the next listObjects reports this region as a server
  /// correction, mirroring the real client's replay behavior.
  String? correctRegionTo;

  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    if (failListWith != null) throw failListWith!;
    final correction = correctRegionTo;
    if (correction != null) {
      correctRegionTo = null;
      onRegionCorrected?.call(correction);
    }
    calls.add('list:$prefix');
    return const [];
  }
```

Then add a helper next to `fillValidForm` and the new tests:

```dart
  Future<void> expandAdvanced(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('s3-advanced')));
    await tester.tap(find.byKey(const Key('s3-advanced')));
    await tester.pumpAndSettle();
  }

  testWidgets('advanced section is collapsed by default', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('s3-region')), findsNothing);
    expect(find.byKey(const Key('s3-prefix')), findsNothing);
    expect(find.byKey(const Key('s3-path-style')), findsNothing);

    await expandAdvanced(tester);
    expect(find.byKey(const Key('s3-region')), findsOneWidget);
    expect(find.byKey(const Key('s3-prefix')), findsOneWidget);
    expect(find.byKey(const Key('s3-path-style')), findsOneWidget);
  });

  testWidgets('region helper live-derives from the endpoint', (tester) async {
    await pumpPage(tester);
    await expandAdvanced(tester);
    expect(find.text('Auto-detected: us-east-1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://s3.us-west-004.backblazeb2.com',
    );
    await tester.pump();
    expect(find.text('Auto-detected: us-west-004'), findsOneWidget);
  });

  testWidgets('empty region saves the derived value', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://s3.eu-central-2.amazonaws.com',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(store.stored!.region, 'eu-central-2');
  });

  testWidgets('manual region overrides derivation', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await expandAdvanced(tester);
    await tester.enterText(find.byKey(const Key('s3-region')), 'eu-west-2');
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(store.stored!.region, 'eu-west-2');
  });

  testWidgets('test connection adopts and announces a detected region', (
    tester,
  ) async {
    apiClient.correctRegionTo = 'eu-west-1';
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-test')));
    await tester.tap(find.byKey(const Key('s3-test')));
    await tester.pumpAndSettle();

    expect(find.text('Region detected: eu-west-1'), findsOneWidget);
    await expandAdvanced(tester);
    expect(find.text('eu-west-1'), findsOneWidget); // field adopted it
  });

  testWidgets('existing config populates the region field on load', (
    tester,
  ) async {
    store.stored = S3Config(
      endpoint: 'https://s3.example.com',
      region: 'auto',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    );
    await pumpPage(tester);
    await expandAdvanced(tester);
    expect(find.text('auto'), findsOneWidget);
    expect(find.textContaining('Auto-detected'), findsNothing);
  });
```

Also update the existing `'path-style auto-enables when a custom endpoint is entered'` test: insert `await expandAdvanced(tester);` immediately after `await pumpPage(tester);` (the switch now lives inside the expander). Check for other tests touching `s3-region`, `s3-prefix`, or `s3-path-style` with `grep -n "s3-region\|s3-prefix\|s3-path-style" test/features/settings/presentation/s3_config_page_test.dart` and give each the same treatment.

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/features/settings/presentation/s3_config_page_test.dart`
Expected: new tests FAIL (`s3-advanced` key not found); pre-existing tests still pass.

- [ ] **Step 3: Implement the page changes**

In `lib/features/settings/presentation/pages/s3_config_page.dart`:

3a. Add the import:

```dart
import 'package:submersion/core/services/cloud_storage/s3/s3_region.dart';
```

3b. The region controller starts empty, and rebuilds track its text (for helper visibility):

```dart
  final _regionController = TextEditingController();
```

```dart
  @override
  void initState() {
    super.initState();
    _endpointController.addListener(_onEndpointChanged);
    _regionController.addListener(_onRegionChanged);
    _loadExisting();
  }

  void _onRegionChanged() => setState(() {});
```

3c. Replace `_buildConfig()`:

```dart
  S3Config _buildConfig() {
    final manualRegion = _regionController.text.trim();
    return S3Config(
      endpoint: _endpointController.text,
      region: manualRegion.isEmpty
          ? deriveRegion(_endpointController.text)
          : manualRegion,
      bucket: _bucketController.text,
      prefix: _prefixController.text,
      pathStyle: _pathStyle,
      accessKeyId: _accessKeyController.text,
      secretAccessKey: _secretKeyController.text,
    );
  }
```

3d. Replace `_testConnection()` (captures the `l10n` object before the await — the same pattern `_remove` already uses — because the detected-region message is only known after the async gap):

```dart
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    String? detectedRegion;
    try {
      await ref
          .read(s3StorageProviderInstanceProvider)
          .testConnection(
            _buildConfig(),
            onRegionCorrected: (region) => detectedRegion = region,
          );
      final detected = detectedRegion;
      if (detected != null) {
        _regionController.text = detected;
        _showSnack(l10n.settings_s3Config_test_regionDetected(detected));
      } else {
        _showSnack(l10n.settings_s3Config_test_success);
      }
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(
        '${l10n.settings_s3Config_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

3e. In `build()`, delete the three relocated widgets — the Region `TextFormField` (with its preceding `SizedBox`), the Key Prefix `TextFormField` (with its preceding `SizedBox`), and the `SwitchListTile` — and insert the expander between the Secret Access Key field and the buttons row:

```dart
            ExpansionTile(
              key: const Key('s3-advanced'),
              title: Text(l10n.settings_s3Config_advanced_title),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                TextFormField(
                  key: const Key('s3-region'),
                  controller: _regionController,
                  decoration: InputDecoration(
                    labelText: l10n.settings_s3Config_field_region_label,
                    helperText: _regionController.text.trim().isEmpty
                        ? l10n.settings_s3Config_field_region_helperAuto(
                            deriveRegion(_endpointController.text),
                          )
                        : null,
                  ),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('s3-prefix'),
                  controller: _prefixController,
                  decoration: InputDecoration(
                    labelText: l10n.settings_s3Config_field_prefix_label,
                  ),
                  autocorrect: false,
                ),
                SwitchListTile(
                  key: const Key('s3-path-style'),
                  title: Text(l10n.settings_s3Config_field_pathStyle_label),
                  subtitle: Text(
                    l10n.settings_s3Config_field_pathStyle_subtitle,
                  ),
                  value: _pathStyle,
                  onChanged: (value) => setState(() {
                    _pathStyle = value;
                    _pathStyleTouched = true;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
```

(`shape`/`collapsedShape: const Border()` suppress the M3 outline the tile otherwise draws when expanded. `_loadExisting` stays unchanged — it populates the stored region as-is, which reads as a manual value and hides the auto helper, per spec.)

3f. Update the doc comment on the class to match the new layout:

```dart
/// Configuration form for the S3-compatible sync backend. Endpoint,
/// bucket, and credentials up front; region, key prefix, and addressing
/// style live in a collapsed Advanced section with auto-derived defaults,
/// and a live read+write Test Connection probe (which also adopts
/// server-detected regions) runs against the unsaved form values.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/s3_config_page_test.dart`
Expected: PASS (all pre-existing plus 6 new).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/settings/presentation/pages/s3_config_page.dart test/features/settings/presentation/s3_config_page_test.dart
flutter analyze
git add lib/features/settings/presentation/pages/s3_config_page.dart test/features/settings/presentation/s3_config_page_test.dart
git commit -m "feat(sync): simplify S3 config form with auto-detected region"
```

---

### Task 7: Final verification sweep

**Files:** none new.

- [ ] **Step 1: Run the affected test files together**

```bash
flutter test test/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3_storage_provider_test.dart test/features/settings/presentation/s3_config_page_test.dart
```

Expected: all pass.

- [ ] **Step 2: Whole-project analyze and format check**

```bash
flutter analyze
dart format --set-exit-if-changed lib/ test/
```

Expected: no issues; format exits 0 with no changes.

- [ ] **Step 3: Commit any stragglers**

Only if step 2 changed files: `git add -A && git commit -m "chore: format"`. Otherwise nothing to do — the branch is ready for review/PR (pre-push hooks run the full suite).
