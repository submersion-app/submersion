# S3-Compatible Sync Storage Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add S3-compatible object storage (AWS S3, MinIO, Cloudflare R2, Backblaze B2, NAS) as a third sync backend behind the existing `CloudStorageProvider` abstraction, with zero changes to the sync engine.

**Architecture:** A hand-rolled SigV4 signer (pure functions) and a minimal five-operation S3 REST client (`PutObject`, `GetObject`, `HeadObject`, `DeleteObject`, `ListObjectsV2`) sit beneath a new `S3StorageProvider`. Credentials live in `FlutterSecureStorage` as one JSON blob. A new `CloudProviderType.s3` enum variant wires into the existing Riverpod provider switch, sync-page tile list, and router. Spec: `docs/superpowers/specs/2026-06-09-s3-sync-backend-design.md`.

**Tech Stack:** Flutter/Dart, Riverpod, `package:http` (^1.2.2, already a dep), `package:crypto` (^3.0.3, already a dep), `package:xml` (^6.5.0, already a dep), `flutter_secure_storage` (^10.0.0, already a dep). **No new pub dependencies.**

**Conventions that bind every task:**

- TDD: write the failing test first, watch it fail, implement, watch it pass.
- After each task: `dart format lib/ test/` must produce no changes (run it before committing).
- Run `flutter analyze` (whole project, no pipes/tail) before each commit.
- Commit messages: conventional commits, **no Co-Authored-By lines**.
- Run specific test files, not broad directories (Bash timeout protection).
- No emojis anywhere. Immutability for entities (`copyWith`, final fields).

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/core/services/cloud_storage/s3/s3_config.dart` | Immutable `S3Config` entity: normalization, validation, JSON round-trip, `copyWith` |
| `lib/core/services/cloud_storage/s3/sigv4_signer.dart` | Pure-function AWS Signature V4 signing (no I/O) |
| `lib/core/services/cloud_storage/s3/s3_api_client.dart` | Five S3 REST operations over `http.Client`; XML parsing; error mapping; one-shot retry |
| `lib/core/services/cloud_storage/s3/s3_credentials_store.dart` | `S3Config` blob persistence in `FlutterSecureStorage` |
| `lib/core/services/cloud_storage/s3_storage_provider.dart` | `S3StorageProvider implements CloudStorageProvider` |
| `lib/features/settings/presentation/pages/s3_config_page.dart` | Configuration form + Test Connection |
| `test/core/services/cloud_storage/s3/s3_config_test.dart` | Entity tests |
| `test/core/services/cloud_storage/s3/sigv4_signer_test.dart` | AWS test-vector tests |
| `test/core/services/cloud_storage/s3/s3_api_client_test.dart` | MockClient tests |
| `test/core/services/cloud_storage/s3/s3_credentials_store_test.dart` | Store tests with fake secure storage |
| `test/core/services/cloud_storage/s3_storage_provider_test.dart` | Provider tests with fakes |
| `test/features/settings/presentation/s3_config_page_test.dart` | Widget tests |

**Modified:**

| File | Change |
|---|---|
| `lib/core/data/repositories/sync_repository.dart:14` | `enum CloudProviderType { icloud, googledrive, s3 }` |
| `lib/features/settings/presentation/providers/sync_providers.dart` | `_s3Provider` singleton, switch arm, `s3StorageProviderInstanceProvider`, `s3ConfigProvider` |
| `lib/features/settings/presentation/pages/cloud_sync_page.dart` | Third provider tile (S3) with configure/select/edit behavior |
| `lib/core/router/app_router.dart:859-863` | Nested route `cloud-sync/s3-config` |
| `lib/l10n/arb/app_en.arb` + 10 locale arbs | ~19 new strings, fully translated |
| `docs/superpowers/specs/2026-06-09-s3-sync-backend-design.md` | Correction: `xml` was already a dependency |

**Key interface being implemented** (`lib/core/services/cloud_storage/cloud_storage_provider.dart`, read it before Task 7): `CloudStorageProvider` with `providerName`, `providerId`, `isAvailable()`, `isAuthenticated()`, `authenticate()`, `signOut()`, `getUserEmail()`, `uploadFile(Uint8List data, String filename, {String? folderId})`, `downloadFile(String fileId)`, `getFileInfo(String fileId)`, `listFiles({String? folderId, String? namePattern})`, `deleteFile(String fileId)`, `fileExists(String fileId)`, `createFolder(String folderName, {String? parentFolderId})`, `getOrCreateSyncFolder()`. Plus `CloudFileInfo(id, name, modifiedTime, sizeBytes)`, `UploadResult(fileId, uploadTime)`, `CloudStorageException(message, [cause, stackTrace])`, and `CloudStorageProviderMixin` (sync filename constants/helpers).

How `SyncService` consumes the provider (do not change `sync_service.dart`): `getOrCreateSyncFolder()` → passed as `folderId:` to `uploadFile(localData, filename, folderId: syncFolder)`; `listFiles(namePattern: 'submersion_sync')`; `downloadFile(file.id)`. So for S3: **fileId = full object key**, `CloudFileInfo.name` = key basename, and the "folder" is the configured key prefix.

---

### Task 0: Branch setup

**Files:** none (git only)

- [ ] **Step 0.1: Create the feature branch from main**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git checkout main && git pull && git checkout -b feat/s3-sync-backend
```

Expected: `Switched to a new branch 'feat/s3-sync-backend'`

---

### Task 1: S3Config entity

**Files:**
- Create: `lib/core/services/cloud_storage/s3/s3_config.dart`
- Test: `test/core/services/cloud_storage/s3/s3_config_test.dart`

- [ ] **Step 1.1: Write the failing tests**

Create `test/core/services/cloud_storage/s3/s3_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

void main() {
  S3Config minio() => S3Config(
    endpoint: 'http://192.168.1.10:9000',
    bucket: 'dive-sync',
    accessKeyId: 'minio-user',
    secretAccessKey: 'minio-secret',
  );

  group('S3Config normalization', () {
    test('defaults: region us-east-1, prefix submersion-sync/', () {
      final config = minio();
      expect(config.region, 'us-east-1');
      expect(config.prefix, 'submersion-sync/');
    });

    test('pathStyle defaults to true for a custom endpoint', () {
      expect(minio().pathStyle, isTrue);
    });

    test('pathStyle defaults to false for AWS (empty endpoint)', () {
      final config = S3Config(
        endpoint: '',
        bucket: 'b',
        accessKeyId: 'a',
        secretAccessKey: 's',
      );
      expect(config.pathStyle, isFalse);
    });

    test('explicit pathStyle overrides the default', () {
      final config = S3Config(
        endpoint: '',
        bucket: 'b',
        accessKeyId: 'a',
        secretAccessKey: 's',
        pathStyle: true,
      );
      expect(config.pathStyle, isTrue);
    });

    test('prefix is normalized: leading slash stripped, trailing added', () {
      final config = minio().copyWith(prefix: '/my/dives');
      expect(config.prefix, 'my/dives/');
    });

    test('empty prefix stays empty (bucket root)', () {
      final config = minio().copyWith(prefix: '');
      expect(config.prefix, '');
    });

    test('endpoint whitespace and trailing slash are trimmed', () {
      final config = minio().copyWith(endpoint: ' http://nas.local:9000/ ');
      expect(config.endpoint, 'http://nas.local:9000');
    });
  });

  group('S3Config derived values', () {
    test('isAws true only when endpoint is empty', () {
      expect(minio().isAws, isFalse);
      expect(minio().copyWith(endpoint: '').isAws, isTrue);
    });

    test('displayHost is the endpoint host for custom endpoints', () {
      expect(minio().displayHost, '192.168.1.10');
    });

    test('displayHost is the regional AWS host for AWS', () {
      final config = minio().copyWith(endpoint: '', region: 'eu-west-1');
      expect(config.displayHost, 's3.eu-west-1.amazonaws.com');
    });

    test('isInsecureEndpoint true only for http://', () {
      expect(minio().isInsecureEndpoint, isTrue);
      expect(
        minio().copyWith(endpoint: 'https://minio.example.com').isInsecureEndpoint,
        isFalse,
      );
      expect(minio().copyWith(endpoint: '').isInsecureEndpoint, isFalse);
    });
  });

  group('S3Config.validate', () {
    test('valid config returns null', () {
      expect(minio().validate(), isNull);
    });

    test('missing bucket / accessKeyId / secretAccessKey are rejected', () {
      expect(minio().copyWith(bucket: '').validate(), isNotNull);
      expect(minio().copyWith(accessKeyId: '').validate(), isNotNull);
      expect(minio().copyWith(secretAccessKey: '').validate(), isNotNull);
    });

    test('non-http(s) endpoint is rejected, empty endpoint accepted', () {
      expect(minio().copyWith(endpoint: 'ftp://nas').validate(), isNotNull);
      expect(minio().copyWith(endpoint: 'not a url').validate(), isNotNull);
      expect(minio().copyWith(endpoint: '').validate(), isNull);
    });
  });

  group('S3Config JSON round-trip', () {
    test('toJson/fromJson preserves every field', () {
      final config = S3Config(
        endpoint: 'https://s3.us-west-004.backblazeb2.com',
        region: 'us-west-004',
        bucket: 'dive-logs',
        prefix: 'devices/',
        pathStyle: false,
        accessKeyId: 'keyid',
        secretAccessKey: 'sekrit',
      );
      final restored = S3Config.fromJson(config.toJson());
      expect(restored.endpoint, config.endpoint);
      expect(restored.region, config.region);
      expect(restored.bucket, config.bucket);
      expect(restored.prefix, config.prefix);
      expect(restored.pathStyle, config.pathStyle);
      expect(restored.accessKeyId, config.accessKeyId);
      expect(restored.secretAccessKey, config.secretAccessKey);
    });
  });

  test('toString does not leak the secret', () {
    expect(minio().toString(), isNot(contains('minio-secret')));
  });
}
```

- [ ] **Step 1.2: Run the tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3/s3_config_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'submersion/core/services/cloud_storage/s3/s3_config.dart'` (file does not exist yet).

- [ ] **Step 1.3: Implement S3Config**

Create `lib/core/services/cloud_storage/s3/s3_config.dart`:

```dart
/// Connection settings for an S3-compatible sync backend.
///
/// Immutable. The public factory normalizes its inputs so every instance
/// holds the invariants: trimmed endpoint without trailing slash, prefix
/// either empty or `segment/` shaped (no leading slash, single trailing
/// slash). An empty [endpoint] means AWS S3 proper, with the host derived
/// from [region].
class S3Config {
  final String endpoint;
  final String region;
  final String bucket;
  final String prefix;
  final bool pathStyle;
  final String accessKeyId;
  final String secretAccessKey;

  const S3Config._({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.prefix,
    required this.pathStyle,
    required this.accessKeyId,
    required this.secretAccessKey,
  });

  factory S3Config({
    required String endpoint,
    String region = 'us-east-1',
    required String bucket,
    String prefix = 'submersion-sync/',
    bool? pathStyle,
    required String accessKeyId,
    required String secretAccessKey,
  }) {
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    return S3Config._(
      endpoint: normalizedEndpoint,
      region: region.trim(),
      bucket: bucket.trim(),
      prefix: _normalizePrefix(prefix),
      pathStyle: pathStyle ?? normalizedEndpoint.isNotEmpty,
      accessKeyId: accessKeyId.trim(),
      secretAccessKey: secretAccessKey,
    );
  }

  static String _normalizeEndpoint(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _normalizePrefix(String raw) {
    var value = raw.trim();
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    if (value.isEmpty) return '';
    if (!value.endsWith('/')) value = '$value/';
    return value;
  }

  /// AWS S3 proper (host derived from [region]) vs a custom endpoint.
  bool get isAws => endpoint.isEmpty;

  /// Host shown in account labels and used as the AWS base host.
  String get displayHost =>
      isAws ? 's3.$region.amazonaws.com' : Uri.parse(endpoint).host;

  /// Plain-HTTP custom endpoint (credentials travel unencrypted).
  bool get isInsecureEndpoint =>
      !isAws && Uri.tryParse(endpoint)?.scheme == 'http';

  /// First validation problem, or null when the config is usable.
  /// UI-facing field errors live in the form; this is the entity-level guard.
  String? validate() {
    if (bucket.isEmpty) return 'Bucket is required';
    if (accessKeyId.isEmpty) return 'Access Key ID is required';
    if (secretAccessKey.isEmpty) return 'Secret Access Key is required';
    if (endpoint.isNotEmpty) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        return 'Endpoint must be a valid http:// or https:// URL';
      }
    }
    return null;
  }

  S3Config copyWith({
    String? endpoint,
    String? region,
    String? bucket,
    String? prefix,
    bool? pathStyle,
    String? accessKeyId,
    String? secretAccessKey,
  }) {
    return S3Config(
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      prefix: prefix ?? this.prefix,
      pathStyle: pathStyle ?? this.pathStyle,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
    );
  }

  Map<String, Object?> toJson() => {
    'endpoint': endpoint,
    'region': region,
    'bucket': bucket,
    'prefix': prefix,
    'pathStyle': pathStyle,
    'accessKeyId': accessKeyId,
    'secretAccessKey': secretAccessKey,
  };

  factory S3Config.fromJson(Map<String, Object?> json) => S3Config(
    endpoint: json['endpoint'] as String? ?? '',
    region: json['region'] as String? ?? 'us-east-1',
    bucket: json['bucket'] as String? ?? '',
    prefix: json['prefix'] as String? ?? '',
    pathStyle: json['pathStyle'] as bool?,
    accessKeyId: json['accessKeyId'] as String? ?? '',
    secretAccessKey: json['secretAccessKey'] as String? ?? '',
  );

  @override
  String toString() =>
      'S3Config(endpoint: $endpoint, region: $region, bucket: $bucket, '
      'prefix: $prefix, pathStyle: $pathStyle, accessKeyId: $accessKeyId, '
      'secretAccessKey: <redacted>)';
}
```

- [ ] **Step 1.4: Run the tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/s3_config_test.dart`
Expected: PASS (all tests green).

- [ ] **Step 1.5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
flutter analyze
git add lib/core/services/cloud_storage/s3/s3_config.dart test/core/services/cloud_storage/s3/s3_config_test.dart
git commit -m "feat(sync): add S3Config entity for the S3 sync backend"
```

Expected: analyze reports no new issues; commit succeeds.

### Task 2: SigV4 primitives (hashing, key derivation, encoding)

AWS Signature Version 4 is the auth scheme for every S3-compatible service. It is
a deterministic pipeline: hash the payload → build a canonical text form of the
request → hash that into a "string to sign" → HMAC it with a key derived from the
secret. Because it is pure string/bytes work, we test it against AWS's published
worked examples (test vectors) with zero mocks. Vector source (cited in test
comments): AWS docs page "Authenticating Requests (AWS Signature Version 4):
Examples" — `https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-examples.html`
and "deriving a signing key" examples. If a vector test fails, compare
intermediate values against that page before suspecting the test.

**Files:**
- Create: `lib/core/services/cloud_storage/s3/sigv4_signer.dart`
- Test: `test/core/services/cloud_storage/s3/sigv4_signer_test.dart`

- [ ] **Step 2.1: Write the failing tests**

Create `test/core/services/cloud_storage/s3/sigv4_signer_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/sigv4_signer.dart';

// Test vectors from the AWS documentation:
// https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-examples.html
// https://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html
const awsAccessKey = 'AKIAIOSFODNN7EXAMPLE';
const awsSecretKey = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
const emptyPayloadHash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  group('hashing primitives', () {
    test('hexSha256 of empty bytes is the well-known empty hash', () {
      expect(SigV4Signer.hexSha256(const []), emptyPayloadHash);
    });

    test('deriveSigningKey matches the reference HMAC chain', () {
      // Inputs from AWS "Examples of how to derive a signing key": secret
      // above, 20120215, us-east-1, iam. Expected value computed with the
      // Python hmac reference implementation of the SigV4 chain.
      final key = SigV4Signer.deriveSigningKey(
        secretAccessKey: awsSecretKey,
        dateStamp: '20120215',
        region: 'us-east-1',
        service: 'iam',
      );
      expect(
        SigV4Signer.hexEncode(key),
        '004aa806e13dae88b9032d9261bcb04c67d023afadd221e6b0d206e1760e0b5e',
      );
    });
  });

  group('date formatting', () {
    final time = DateTime.utc(2013, 5, 24);
    test('amzDateFormat is yyyyMMddTHHmmssZ', () {
      expect(SigV4Signer.amzDateFormat(time), '20130524T000000Z');
    });
    test('dateStampFormat is yyyyMMdd', () {
      expect(SigV4Signer.dateStampFormat(time), '20130524');
    });
    test('non-UTC input is converted to UTC', () {
      final local = DateTime.utc(2013, 5, 24, 1, 2, 3).toLocal();
      expect(SigV4Signer.amzDateFormat(local), '20130524T010203Z');
    });
  });

  group('uriEncode', () {
    test('keeps unreserved characters', () {
      expect(SigV4Signer.uriEncode('AZaz09-._~'), 'AZaz09-._~');
    });
    test('encodes reserved characters with uppercase hex', () {
      expect(SigV4Signer.uriEncode('a b'), 'a%20b');
      expect(SigV4Signer.uriEncode('a=b'), 'a%3Db');
      expect(SigV4Signer.uriEncode('a/b'), 'a%2Fb');
    });
    test('encodeSlash false preserves path separators', () {
      expect(
        SigV4Signer.uriEncode('sync/file name.json', encodeSlash: false),
        'sync/file%20name.json',
      );
    });
  });

  group('canonicalQueryString', () {
    test('sorts parameters by key and encodes values', () {
      expect(
        SigV4Signer.canonicalQueryString({'prefix': 'J', 'max-keys': '2'}),
        'max-keys=2&prefix=J',
      );
    });
    test('empty map yields empty string', () {
      expect(SigV4Signer.canonicalQueryString(const {}), '');
    });
    test('continuation tokens with special characters are encoded', () {
      expect(
        SigV4Signer.canonicalQueryString({'continuation-token': '1/aGVs bG8='}),
        'continuation-token=1%2FaGVs%20bG8%3D',
      );
    });
  });

  group('payload hashing', () {
    test('hexSha256 of a body matches sha256 of its bytes', () {
      final body = utf8.encode('Welcome to Amazon S3.');
      expect(
        SigV4Signer.hexSha256(body),
        '44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072',
      );
    });
  });
}
```

The last hash (`44ce7dd6...`) is from the AWS PUT-object worked example, whose
body is exactly `Welcome to Amazon S3.`.

- [ ] **Step 2.2: Run the tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3/sigv4_signer_test.dart`
Expected: FAIL — package `sigv4_signer.dart` cannot be resolved.

- [ ] **Step 2.3: Implement the primitives**

Create `lib/core/services/cloud_storage/s3/sigv4_signer.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure-function AWS Signature Version 4 signing for S3-compatible services.
///
/// No I/O and no clock access: the request time is always a parameter, so
/// every function is deterministic and testable against AWS's published
/// worked examples (see sigv4_signer_test.dart for vector sources).
class SigV4Signer {
  SigV4Signer._();

  static const _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  static String hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String hexSha256(List<int> bytes) =>
      sha256.convert(bytes).toString();

  static List<int> hmacSha256(List<int> key, List<int> message) =>
      Hmac(sha256, key).convert(message).bytes;

  /// kSigning = HMAC(HMAC(HMAC(HMAC("AWS4"+secret, date), region), service),
  /// "aws4_request") -- the SigV4 key-derivation chain.
  static List<int> deriveSigningKey({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    String service = 's3',
  }) {
    final kDate = hmacSha256(utf8.encode('AWS4$secretAccessKey'), utf8.encode(dateStamp));
    final kRegion = hmacSha256(kDate, utf8.encode(region));
    final kService = hmacSha256(kRegion, utf8.encode(service));
    return hmacSha256(kService, utf8.encode('aws4_request'));
  }

  /// `20130524T000000Z` -- the x-amz-date header format.
  static String amzDateFormat(DateTime time) {
    final t = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}T${p2(t.hour)}${p2(t.minute)}${p2(t.second)}Z';
  }

  /// `20130524` -- the credential-scope date.
  static String dateStampFormat(DateTime time) {
    final t = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}';
  }

  /// RFC 3986 encoding as SigV4 requires it: unreserved characters pass
  /// through, everything else becomes uppercase %XX; '/' survives only when
  /// [encodeSlash] is false (object-key paths).
  static String uriEncode(String input, {bool encodeSlash = true}) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(input)) {
      final char = String.fromCharCode(byte);
      if (_unreserved.contains(char) || (char == '/' && !encodeSlash)) {
        buffer.write(char);
      } else {
        buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return buffer.toString();
  }

  /// Query parameters sorted by key, each key and value uriEncoded.
  static String canonicalQueryString(Map<String, String> queryParams) {
    final keys = queryParams.keys.toList()..sort();
    return keys
        .map((k) => '${uriEncode(k)}=${uriEncode(queryParams[k]!)}')
        .join('&');
  }
}
```

- [ ] **Step 2.4: Run the tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/sigv4_signer_test.dart`
Expected: PASS.

- [ ] **Step 2.5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
flutter analyze
git add lib/core/services/cloud_storage/s3/sigv4_signer.dart test/core/services/cloud_storage/s3/sigv4_signer_test.dart
git commit -m "feat(sync): add SigV4 hashing, key derivation, and encoding primitives"
```

---

### Task 3: SigV4 canonical request and full signing

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/sigv4_signer.dart` (add three methods)
- Modify: `test/core/services/cloud_storage/s3/sigv4_signer_test.dart` (add vector groups)

- [ ] **Step 3.1: Add the failing vector tests**

Append inside `main()` in `test/core/services/cloud_storage/s3/sigv4_signer_test.dart`:

```dart
  // AWS worked example "GET object" from sig-v4-examples: GET /test.txt on
  // examplebucket with a Range header, signed at 20130524T000000Z.
  group('canonical request and signing (AWS GET object vector)', () {
    final requestTime = DateTime.utc(2013, 5, 24);
    final headers = {
      'host': 'examplebucket.s3.amazonaws.com',
      'range': 'bytes=0-9',
      'x-amz-content-sha256': emptyPayloadHash,
      'x-amz-date': '20130524T000000Z',
    };

    test('canonicalRequest matches the documented form', () {
      final canonical = SigV4Signer.canonicalRequest(
        method: 'GET',
        canonicalUri: '/test.txt',
        queryParams: const {},
        headers: headers,
        payloadHash: emptyPayloadHash,
      );
      expect(canonical, '''
GET
/test.txt

host:examplebucket.s3.amazonaws.com
range:bytes=0-9
x-amz-content-sha256:$emptyPayloadHash
x-amz-date:20130524T000000Z

host;range;x-amz-content-sha256;x-amz-date
$emptyPayloadHash''');
    });

    test('stringToSign embeds the canonical request hash', () {
      final canonical = SigV4Signer.canonicalRequest(
        method: 'GET',
        canonicalUri: '/test.txt',
        queryParams: const {},
        headers: headers,
        payloadHash: emptyPayloadHash,
      );
      final sts = SigV4Signer.stringToSign(
        amzDate: '20130524T000000Z',
        credentialScope: '20130524/us-east-1/s3/aws4_request',
        canonicalRequestStr: canonical,
      );
      expect(sts, '''
AWS4-HMAC-SHA256
20130524T000000Z
20130524/us-east-1/s3/aws4_request
7344ae5b7ee6c3e7e6b0fe0640412a37625d1fbfff95c48bbb2dc43964946972''');
    });

    test('sign produces the documented signature', () {
      final signed = SigV4Signer.sign(
        method: 'GET',
        host: 'examplebucket.s3.amazonaws.com',
        canonicalUri: '/test.txt',
        extraHeaders: const {'range': 'bytes=0-9'},
        payload: const [],
        accessKeyId: awsAccessKey,
        secretAccessKey: awsSecretKey,
        region: 'us-east-1',
        requestTime: requestTime,
      );
      expect(signed['x-amz-date'], '20130524T000000Z');
      expect(signed['x-amz-content-sha256'], emptyPayloadHash);
      expect(
        signed['authorization'],
        contains(
          'Credential=$awsAccessKey/20130524/us-east-1/s3/aws4_request',
        ),
      );
      expect(
        signed['authorization'],
        contains('SignedHeaders=host;range;x-amz-content-sha256;x-amz-date'),
      );
      expect(
        signed['authorization'],
        contains(
          'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
        ),
      );
    });
  });

  // AWS worked example "Get bucket (list objects)": GET /?max-keys=2&prefix=J
  group('signing with query parameters (AWS list objects vector)', () {
    test('sign produces the documented signature', () {
      final signed = SigV4Signer.sign(
        method: 'GET',
        host: 'examplebucket.s3.amazonaws.com',
        canonicalUri: '/',
        queryParams: const {'max-keys': '2', 'prefix': 'J'},
        payload: const [],
        accessKeyId: awsAccessKey,
        secretAccessKey: awsSecretKey,
        region: 'us-east-1',
        requestTime: DateTime.utc(2013, 5, 24),
      );
      expect(
        signed['authorization'],
        contains(
          'Signature=34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
        ),
      );
    });
  });
```

- [ ] **Step 3.2: Run the tests to verify the new groups fail**

Run: `flutter test test/core/services/cloud_storage/s3/sigv4_signer_test.dart`
Expected: FAIL — `canonicalRequest`, `stringToSign`, `sign` are not defined. The Task 2 groups still pass.

- [ ] **Step 3.3: Implement canonicalRequest, stringToSign, sign**

Add to the `SigV4Signer` class in `lib/core/services/cloud_storage/s3/sigv4_signer.dart`:

```dart
  /// The canonical request text: method, encoded path, canonical query
  /// string, canonical headers (lowercased, trimmed, sorted), signed-header
  /// list, payload hash. [headers] must already include `host`.
  static String canonicalRequest({
    required String method,
    required String canonicalUri,
    required Map<String, String> queryParams,
    required Map<String, String> headers,
    required String payloadHash,
  }) {
    final normalized = <String, String>{
      for (final entry in headers.entries)
        entry.key.toLowerCase().trim(): entry.value.trim(),
    };
    final names = normalized.keys.toList()..sort();
    final canonicalHeaders = names.map((n) => '$n:${normalized[n]}\n').join();
    final signedHeaders = names.join(';');
    return [
      method,
      canonicalUri,
      canonicalQueryString(queryParams),
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
  }

  static String stringToSign({
    required String amzDate,
    required String credentialScope,
    required String canonicalRequestStr,
  }) {
    return [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      hexSha256(utf8.encode(canonicalRequestStr)),
    ].join('\n');
  }

  /// Signs one request and returns the headers to send: `host`,
  /// `x-amz-date`, `x-amz-content-sha256`, every entry of [extraHeaders]
  /// (lowercased), and `authorization`. All returned header names are
  /// lowercase; HTTP header names are case-insensitive.
  static Map<String, String> sign({
    required String method,
    required String host,
    required String canonicalUri,
    Map<String, String> queryParams = const {},
    Map<String, String> extraHeaders = const {},
    required List<int> payload,
    required String accessKeyId,
    required String secretAccessKey,
    required String region,
    required DateTime requestTime,
    String service = 's3',
  }) {
    final amzDate = amzDateFormat(requestTime);
    final dateStamp = dateStampFormat(requestTime);
    final payloadHash = hexSha256(payload);

    final headers = <String, String>{
      'host': host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      for (final entry in extraHeaders.entries)
        entry.key.toLowerCase(): entry.value,
    };

    final canonical = canonicalRequest(
      method: method,
      canonicalUri: canonicalUri,
      queryParams: queryParams,
      headers: headers,
      payloadHash: payloadHash,
    );

    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final sts = stringToSign(
      amzDate: amzDate,
      credentialScope: credentialScope,
      canonicalRequestStr: canonical,
    );

    final signingKey = deriveSigningKey(
      secretAccessKey: secretAccessKey,
      dateStamp: dateStamp,
      region: region,
      service: service,
    );
    final signature = hexEncode(hmacSha256(signingKey, utf8.encode(sts)));

    final signedHeaderNames = (headers.keys.toList()..sort()).join(';');
    headers['authorization'] =
        'AWS4-HMAC-SHA256 '
        'Credential=$accessKeyId/$credentialScope,'
        'SignedHeaders=$signedHeaderNames,'
        'Signature=$signature';
    return headers;
  }
```

- [ ] **Step 3.4: Run the tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/sigv4_signer_test.dart`
Expected: PASS — all groups including both vectors. If a vector fails, print
the canonical request and string-to-sign and diff them against the values in
the test file; do not "fix" a vector constant yourself — the controller has
verified every constant in this plan computationally (python3 hmac reference
chain). Report BLOCKED with actual vs expected instead.

- [ ] **Step 3.5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
flutter analyze
git add lib/core/services/cloud_storage/s3/sigv4_signer.dart test/core/services/cloud_storage/s3/sigv4_signer_test.dart
git commit -m "feat(sync): complete SigV4 signing against AWS test vectors"
```

### Task 4: S3ApiClient — transport, URL building, putObject, getObject

The client owns the one subtle correctness rule of this feature: **the bytes on
the wire must be the bytes that were signed.** It therefore builds the request
`Uri` by string concatenation from the same pre-encoded path and canonical query
string that went into the signature, instead of letting `Uri`'s own encoder
re-encode anything.

**Files:**
- Create: `lib/core/services/cloud_storage/s3/s3_api_client.dart`
- Test: `test/core/services/cloud_storage/s3/s3_api_client_test.dart`

- [ ] **Step 4.1: Write the failing tests**

Create `test/core/services/cloud_storage/s3/s3_api_client_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

S3Config minioConfig() => S3Config(
  endpoint: 'http://nas.local:9000',
  bucket: 'dive-sync',
  accessKeyId: 'ak',
  secretAccessKey: 'sk',
);

S3Config awsConfig() => S3Config(
  endpoint: '',
  region: 'eu-west-1',
  bucket: 'dive-sync',
  accessKeyId: 'ak',
  secretAccessKey: 'sk',
);

S3ApiClient clientWith(S3Config config, MockClient mock) => S3ApiClient(
  config,
  httpClient: mock,
  now: () => DateTime.utc(2026, 6, 9, 12),
  retryDelay: Duration.zero,
);

void main() {
  group('request shape', () {
    test('path-style custom endpoint: bucket in path, port preserved', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return http.Response('', 200);
      });
      await clientWith(minioConfig(), mock)
          .putObject('submersion-sync/file.json', Uint8List.fromList([1, 2]));

      expect(seen.method, 'PUT');
      expect(
        seen.url.toString(),
        'http://nas.local:9000/dive-sync/submersion-sync/file.json',
      );
      expect(seen.bodyBytes, [1, 2]);
      expect(seen.headers['authorization'], startsWith('AWS4-HMAC-SHA256 '));
      expect(seen.headers['x-amz-date'], '20260609T120000Z');
      expect(seen.headers['x-amz-content-sha256'], isNotNull);
    });

    test('virtual-hosted AWS: bucket in host, regional endpoint', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return http.Response.bytes([9, 9], 200);
      });
      await clientWith(awsConfig(), mock).getObject('submersion-sync/file.json');

      expect(
        seen.url.toString(),
        'https://dive-sync.s3.eu-west-1.amazonaws.com/submersion-sync/file.json',
      );
    });

    test('AWS with pathStyle forced: bucket in path on regional host', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return http.Response.bytes([9], 200);
      });
      final config = awsConfig().copyWith(pathStyle: true);
      await clientWith(config, mock).getObject('k.json');

      expect(
        seen.url.toString(),
        'https://s3.eu-west-1.amazonaws.com/dive-sync/k.json',
      );
    });
  });

  group('putObject', () {
    test('completes on 200', () async {
      final mock = MockClient((_) async => http.Response('', 200));
      await clientWith(minioConfig(), mock)
          .putObject('k', Uint8List.fromList([1]));
    });

    test('403 throws CloudStorageException mentioning access', () async {
      final mock = MockClient((_) async => http.Response('denied', 403));
      expect(
        () => clientWith(minioConfig(), mock)
            .putObject('k', Uint8List.fromList([1])),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('Access denied'),
          ),
        ),
      );
    });
  });

  group('getObject', () {
    test('returns body bytes on 200', () async {
      final mock = MockClient(
        (_) async => http.Response.bytes([10, 20, 30], 200),
      );
      final bytes = await clientWith(minioConfig(), mock).getObject('k');
      expect(bytes, [10, 20, 30]);
    });

    test('404 throws CloudStorageException naming the key', () async {
      final mock = MockClient((_) async => http.Response('missing', 404));
      expect(
        () => clientWith(minioConfig(), mock).getObject('gone.json'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('gone.json'),
          ),
        ),
      );
    });
  });

  group('retry', () {
    test('retries once after a transport error, then succeeds', () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('connection reset');
        return http.Response('', 200);
      });
      await clientWith(minioConfig(), mock)
          .putObject('k', Uint8List.fromList([1]));
      expect(calls, 2);
    });

    test('retries once after a 5xx, then succeeds', () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        return http.Response('oops', calls == 1 ? 500 : 200);
      });
      await clientWith(minioConfig(), mock)
          .putObject('k', Uint8List.fromList([1]));
      expect(calls, 2);
    });

    test('persistent transport failure surfaces CloudStorageException', () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        throw http.ClientException('refused');
      });
      expect(
        () => clientWith(minioConfig(), mock).getObject('k'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('nas.local'),
          ),
        ),
      );
    });
  });
}
```

- [ ] **Step 4.2: Run the tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: FAIL — `s3_api_client.dart` cannot be resolved.

- [ ] **Step 4.3: Implement the client core**

Create `lib/core/services/cloud_storage/s3/s3_api_client.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/sigv4_signer.dart';

/// Listing entry returned by [S3ApiClient.listObjects].
class S3ObjectInfo {
  final String key;
  final DateTime lastModified;
  final int? size;

  const S3ObjectInfo({
    required this.key,
    required this.lastModified,
    this.size,
  });
}

/// Minimal S3 REST client: the five operations the sync backend needs,
/// signed with SigV4. Throws [CloudStorageException] for every failure so
/// callers never see raw HTTP details. The secret key and Authorization
/// header are never logged or embedded in error messages.
class S3ApiClient {
  S3ApiClient(
    this._config, {
    http.Client? httpClient,
    DateTime Function()? now,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) : _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now,
       _retryDelay = retryDelay;

  final S3Config _config;
  final http.Client _http;
  final DateTime Function() _now;
  final Duration _retryDelay;

  Future<void> putObject(String key, Uint8List bytes) async {
    final response = await _sendWithRetry('PUT', key, body: bytes);
    if (response.statusCode != 200) _throwFor('upload', key, response);
  }

  Future<Uint8List> getObject(String key) async {
    final response = await _sendWithRetry('GET', key);
    if (response.statusCode == 200) return response.bodyBytes;
    if (response.statusCode == 404) {
      throw CloudStorageException('File not found in S3: $key');
    }
    _throwFor('download', key, response);
  }

  Future<S3ObjectInfo?> headObject(String key) async {
    final response = await _sendWithRetry('HEAD', key);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throwFor('inspect', key, response);
    final lastModifiedHeader = response.headers['last-modified'];
    final contentLength = response.headers['content-length'];
    return S3ObjectInfo(
      key: key,
      lastModified: lastModifiedHeader != null
          ? HttpDate.parse(lastModifiedHeader)
          : DateTime.now().toUtc(),
      size: contentLength != null ? int.tryParse(contentLength) : null,
    );
  }

  Future<void> deleteObject(String key) async {
    final response = await _sendWithRetry('DELETE', key);
    // 404 is success for an idempotent delete; S3 itself returns 204 even
    // for keys that never existed, but some compatible servers 404.
    const okStatuses = {200, 204, 404};
    if (!okStatuses.contains(response.statusCode)) {
      _throwFor('delete', key, response);
    }
  }

  Future<List<S3ObjectInfo>> listObjects({String prefix = ''}) async {
    final results = <S3ObjectInfo>[];
    String? continuationToken;
    do {
      final response = await _sendWithRetry(
        'GET',
        '',
        queryParams: {
          'list-type': '2',
          if (prefix.isNotEmpty) 'prefix': prefix,
          if (continuationToken != null)
            'continuation-token': continuationToken,
        },
      );
      if (response.statusCode != 200) _throwFor('list', prefix, response);

      final document = XmlDocument.parse(response.body);
      for (final contents in document.findAllElements('Contents')) {
        final key = contents.getElement('Key')?.innerText;
        final lastModified = contents.getElement('LastModified')?.innerText;
        if (key == null || lastModified == null) continue;
        results.add(
          S3ObjectInfo(
            key: key,
            lastModified: DateTime.parse(lastModified),
            size: int.tryParse(contents.getElement('Size')?.innerText ?? ''),
          ),
        );
      }
      final truncated =
          document.findAllElements('IsTruncated').firstOrNull?.innerText ==
          'true';
      continuationToken = truncated
          ? document.findAllElements('NextContinuationToken').firstOrNull
                ?.innerText
          : null;
    } while (continuationToken != null);
    return results;
  }

  void close() => _http.close();

  /// Scheme/host/port/path for [key], honoring path-style vs virtual-hosted
  /// addressing. The path comes back already SigV4-encoded so the signed
  /// bytes and the wire bytes cannot diverge.
  ({String scheme, String host, int? port, String path}) _target(String key) {
    final String scheme;
    final String host;
    int? port;
    if (_config.isAws) {
      scheme = 'https';
      host = _config.pathStyle
          ? 's3.${_config.region}.amazonaws.com'
          : '${_config.bucket}.s3.${_config.region}.amazonaws.com';
    } else {
      final endpointUri = Uri.parse(_config.endpoint);
      scheme = endpointUri.scheme;
      host = _config.pathStyle
          ? endpointUri.host
          : '${_config.bucket}.${endpointUri.host}';
      if (endpointUri.hasPort) port = endpointUri.port;
    }
    final encodedKey = SigV4Signer.uriEncode(key, encodeSlash: false);
    final path = _config.pathStyle
        ? '/${_config.bucket}${encodedKey.isEmpty ? '/' : '/$encodedKey'}'
        : '/$encodedKey';
    return (scheme: scheme, host: host, port: port, path: path);
  }

  Future<http.Response> _sendWithRetry(
    String method,
    String key, {
    Map<String, String> queryParams = const {},
    Uint8List? body,
  }) async {
    http.Response response;
    try {
      response = await _send(method, key, queryParams: queryParams, body: body);
      if (response.statusCode < 500) return response;
    } on http.ClientException {
      response = await _retry(method, key, queryParams, body);
      return response;
    } on SocketException {
      response = await _retry(method, key, queryParams, body);
      return response;
    } on TimeoutException {
      response = await _retry(method, key, queryParams, body);
      return response;
    }
    // First attempt was a 5xx: retry once, return whatever comes back.
    await Future<void>.delayed(_retryDelay);
    return _send(method, key, queryParams: queryParams, body: body);
  }

  Future<http.Response> _retry(
    String method,
    String key,
    Map<String, String> queryParams,
    Uint8List? body,
  ) async {
    await Future<void>.delayed(_retryDelay);
    try {
      return await _send(method, key, queryParams: queryParams, body: body);
    } on Exception catch (e) {
      throw CloudStorageException(
        'Could not reach S3 endpoint ${_config.displayHost}',
        e,
      );
    }
  }

  Future<http.Response> _send(
    String method,
    String key, {
    Map<String, String> queryParams = const {},
    Uint8List? body,
  }) async {
    final target = _target(key);
    final authority = target.port == null
        ? target.host
        : '${target.host}:${target.port}';
    final canonicalQuery = SigV4Signer.canonicalQueryString(queryParams);
    final uri = Uri.parse(
      '${target.scheme}://$authority${target.path}'
      '${canonicalQuery.isEmpty ? '' : '?$canonicalQuery'}',
    );

    final payload = body ?? Uint8List(0);
    final headers = SigV4Signer.sign(
      method: method,
      host: authority,
      canonicalUri: target.path,
      queryParams: queryParams,
      payload: payload,
      accessKeyId: _config.accessKeyId,
      secretAccessKey: _config.secretAccessKey,
      region: _config.region,
      requestTime: _now(),
    );
    // The http client derives Host from the URL; it must not be set manually.
    headers.remove('host');

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.bodyBytes = body;
    return http.Response.fromStream(await _http.send(request));
  }

  Never _throwFor(String operation, String key, http.Response response) {
    final errorCode = _xmlErrorCode(response.body);
    if (response.statusCode == 403) {
      if (errorCode == 'RequestTimeTooSkewed') {
        throw const CloudStorageException(
          'S3 rejected the request time. The device clock is more than '
          '15 minutes off; correct the system time and try again.',
        );
      }
      throw const CloudStorageException(
        'Access denied. Check the access key, secret key, and bucket '
        'permissions.',
      );
    }
    if (response.statusCode == 404 && errorCode == 'NoSuchBucket') {
      throw CloudStorageException('Bucket "${_config.bucket}" not found');
    }
    throw CloudStorageException(
      'S3 $operation failed for "$key" (HTTP ${response.statusCode})',
    );
  }

  String? _xmlErrorCode(String body) {
    if (body.isEmpty) return null;
    try {
      return XmlDocument.parse(body).findAllElements('Code').firstOrNull
          ?.innerText;
    } on XmlException {
      return null;
    }
  }
}
```

- [ ] **Step 4.4: Run the tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: PASS.

- [ ] **Step 4.5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
flutter analyze
git add lib/core/services/cloud_storage/s3/s3_api_client.dart test/core/services/cloud_storage/s3/s3_api_client_test.dart
git commit -m "feat(sync): add minimal SigV4-signed S3 API client (put/get, retry)"
```

---

### Task 5: S3ApiClient — head, delete, list with pagination, error detail

`headObject`, `deleteObject`, and `listObjects` were implemented in Task 4's
file (the implementation is cohesive); this task adds the tests that pin their
behavior, which is where the regressions would hide. If any test exposes a bug,
fix the implementation here.

**Files:**
- Modify: `test/core/services/cloud_storage/s3/s3_api_client_test.dart` (add groups)
- Possibly modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart` (bug fixes only)

- [ ] **Step 5.1: Add the failing/pinning tests**

Append inside `main()` in `test/core/services/cloud_storage/s3/s3_api_client_test.dart`:

```dart
  group('headObject', () {
    test('parses key, last-modified, and size from headers', () async {
      final mock = MockClient(
        (_) async => http.Response(
          '',
          200,
          headers: {
            'last-modified': 'Wed, 03 Jun 2026 10:15:30 GMT',
            'content-length': '2048',
          },
        ),
      );
      final info = await clientWith(minioConfig(), mock).headObject('k.json');
      expect(info, isNotNull);
      expect(info!.key, 'k.json');
      expect(info.lastModified, DateTime.utc(2026, 6, 3, 10, 15, 30));
      expect(info.size, 2048);
    });

    test('returns null on 404', () async {
      final mock = MockClient((_) async => http.Response('', 404));
      expect(await clientWith(minioConfig(), mock).headObject('k'), isNull);
    });
  });

  group('deleteObject', () {
    test('204 and 404 both complete without throwing', () async {
      for (final status in [204, 404]) {
        final mock = MockClient((_) async => http.Response('', status));
        await clientWith(minioConfig(), mock).deleteObject('k');
      }
    });
  });

  group('listObjects', () {
    const pageOne = '''
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>dive-sync</Name>
  <Prefix>submersion-sync/</Prefix>
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>token-1</NextContinuationToken>
  <Contents>
    <Key>submersion-sync/submersion_sync_device-a.json</Key>
    <LastModified>2026-06-01T10:00:00.000Z</LastModified>
    <Size>2048</Size>
  </Contents>
  <Contents>
    <Key>submersion-sync/submersion_sync_device-b.json</Key>
    <LastModified>2026-06-02T11:30:00.000Z</LastModified>
    <Size>4096</Size>
  </Contents>
</ListBucketResult>''';

    const pageTwo = '''
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>dive-sync</Name>
  <Prefix>submersion-sync/</Prefix>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>submersion-sync/submersion_sync_device-c.json</Key>
    <LastModified>2026-06-03T09:00:00.000Z</LastModified>
    <Size>1024</Size>
  </Contents>
</ListBucketResult>''';

    test('follows continuation tokens across pages', () async {
      final seenUrls = <Uri>[];
      final mock = MockClient((request) async {
        seenUrls.add(request.url);
        final isSecondPage =
            request.url.queryParameters['continuation-token'] == 'token-1';
        return http.Response(isSecondPage ? pageTwo : pageOne, 200);
      });

      final objects = await clientWith(minioConfig(), mock)
          .listObjects(prefix: 'submersion-sync/');

      expect(objects, hasLength(3));
      expect(objects[0].key, 'submersion-sync/submersion_sync_device-a.json');
      expect(objects[0].lastModified, DateTime.utc(2026, 6, 1, 10));
      expect(objects[0].size, 2048);
      expect(objects[2].key, 'submersion-sync/submersion_sync_device-c.json');

      expect(seenUrls, hasLength(2));
      expect(seenUrls[0].queryParameters['list-type'], '2');
      expect(seenUrls[0].queryParameters['prefix'], 'submersion-sync/');
      expect(seenUrls[1].queryParameters['continuation-token'], 'token-1');
    });

    test('list URL targets the bucket root, not an object', () async {
      late Uri seen;
      final mock = MockClient((request) async {
        seen = request.url;
        return http.Response(pageTwo, 200);
      });
      await clientWith(minioConfig(), mock).listObjects(prefix: 'p/');
      expect(seen.path, '/dive-sync/');
    });
  });

  group('error code mapping', () {
    test('RequestTimeTooSkewed surfaces a clock message', () async {
      const skewBody = '''
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>RequestTimeTooSkewed</Code>
  <Message>The difference between the request time and the current time is too large.</Message>
</Error>''';
      final mock = MockClient((_) async => http.Response(skewBody, 403));
      expect(
        () => clientWith(minioConfig(), mock).getObject('k'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('clock'),
          ),
        ),
      );
    });

    test('NoSuchBucket surfaces the bucket name', () async {
      const noBucketBody = '''
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>NoSuchBucket</Code>
  <Message>The specified bucket does not exist</Message>
</Error>''';
      final mock = MockClient((_) async => http.Response(noBucketBody, 404));
      expect(
        () => clientWith(minioConfig(), mock).listObjects(prefix: 'p/'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('dive-sync'),
          ),
        ),
      );
    });

    test('error messages never contain the secret key', () async {
      final mock = MockClient((_) async => http.Response('x', 403));
      try {
        await clientWith(minioConfig(), mock).getObject('k');
        fail('expected CloudStorageException');
      } on CloudStorageException catch (e) {
        expect(e.toString(), isNot(contains('sk')));
      }
    });
  });
```

Note on the last test: the config's secret is the literal `sk`, so the
assertion guards against the secret (or the Authorization header that embeds
its signature) leaking into messages.

- [ ] **Step 5.2: Run the tests**

Run: `flutter test test/core/services/cloud_storage/s3/s3_api_client_test.dart`
Expected: PASS if Task 4's implementation is correct; otherwise fix
`s3_api_client.dart` until green. Likely first failure: the empty-key list URL
(`/dive-sync/` path) — verify `_target('')` produces `'/dive-sync/'` for
path-style and `'/'` for virtual-hosted.

- [ ] **Step 5.3: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
flutter analyze
git add -A lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
git commit -m "test(sync): pin S3 client head/delete/list, pagination, error mapping"
```

### Task 6: S3CredentialsStore

One JSON blob in `FlutterSecureStorage` holds the whole `S3Config`, secrets
included — atomic read/write, no split-brain between stores. Same pattern as
`lib/features/media/data/services/network_credentials_service.dart`.

**Files:**
- Create: `lib/core/services/cloud_storage/s3/s3_credentials_store.dart`
- Test: `test/core/services/cloud_storage/s3/s3_credentials_store_test.dart`

- [ ] **Step 6.1: Write the failing tests**

Create `test/core/services/cloud_storage/s3/s3_credentials_store_test.dart`.
The fake overrides only the three methods the store uses; the override
signatures must match flutter_secure_storage 10.x exactly (note `AppleOptions`
for both `iOptions` and `mOptions`):

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';

class _MemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  late _MemorySecureStorage storage;
  late S3CredentialsStore store;

  setUp(() {
    storage = _MemorySecureStorage();
    store = S3CredentialsStore(storage: storage);
  });

  S3Config config() => S3Config(
    endpoint: 'http://nas.local:9000',
    bucket: 'dive-sync',
    accessKeyId: 'ak',
    secretAccessKey: 'sk',
  );

  test('load returns null when nothing is stored', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the config', () async {
    await store.save(config());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.endpoint, 'http://nas.local:9000');
    expect(loaded.bucket, 'dive-sync');
    expect(loaded.secretAccessKey, 'sk');
    expect(storage.values.keys, [S3CredentialsStore.storageKey]);
  });

  test('clear removes the blob', () async {
    await store.save(config());
    await store.clear();
    expect(await store.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('corrupted JSON loads as null instead of throwing', () async {
    storage.values[S3CredentialsStore.storageKey] = 'not-json{';
    expect(await store.load(), isNull);
  });
}
```

- [ ] **Step 6.2: Run the tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3/s3_credentials_store_test.dart`
Expected: FAIL — `s3_credentials_store.dart` cannot be resolved.

- [ ] **Step 6.3: Implement the store**

Create `lib/core/services/cloud_storage/s3/s3_credentials_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

/// Persists the S3 sync configuration -- secrets included -- as a single
/// JSON blob in the platform keychain. One blob keeps load/save atomic;
/// nothing about the S3 setup ever touches SharedPreferences or the
/// database.
class S3CredentialsStore {
  S3CredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String storageKey = 'sync_s3_config';

  /// The stored config, or null when unset or unreadable.
  Future<S3Config?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      return S3Config.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(S3Config config) =>
      _storage.write(key: storageKey, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
```

- [ ] **Step 6.4: Run the tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3/s3_credentials_store_test.dart`
Expected: PASS. If the fake fails to compile with an "invalid override" error,
diff the option-parameter types against the installed package:
`~/.pub-cache/hosted/pub.dev/flutter_secure_storage-10.0.0/lib/flutter_secure_storage.dart` lines 134-260.

- [ ] **Step 6.5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/s3/ test/core/services/cloud_storage/s3/
flutter analyze
git add lib/core/services/cloud_storage/s3/s3_credentials_store.dart test/core/services/cloud_storage/s3/s3_credentials_store_test.dart
git commit -m "feat(sync): persist S3 config as a secure-storage blob"
```

---

### Task 7: S3StorageProvider

The adapter between the generic `CloudStorageProvider` contract and the S3
client. Key semantic mappings (from the spec, section 6): fileId = full object
key; folders are the configured key prefix; `authenticate()` is a live
read+write probe; `getUserEmail()` is repurposed as the account label.

**Files:**
- Create: `lib/core/services/cloud_storage/s3_storage_provider.dart`
- Test: `test/core/services/cloud_storage/s3_storage_provider_test.dart`

- [ ] **Step 7.1: Write the failing tests**

Create `test/core/services/cloud_storage/s3_storage_provider_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';

class _MemoryCredentialsStore implements S3CredentialsStore {
  S3Config? stored;

  @override
  Future<S3Config?> load() async => stored;

  @override
  Future<void> save(S3Config config) async => stored = config;

  @override
  Future<void> clear() async => stored = null;
}

/// Records calls; serves canned objects.
class _FakeS3ApiClient implements S3ApiClient {
  _FakeS3ApiClient(this.config);

  final S3Config config;
  final List<String> calls = [];
  final Map<String, Uint8List> objects = {};
  List<S3ObjectInfo> listing = [];
  bool closed = false;

  @override
  Future<void> putObject(String key, Uint8List bytes) async {
    calls.add('put:$key');
    objects[key] = bytes;
  }

  @override
  Future<Uint8List> getObject(String key) async {
    calls.add('get:$key');
    final data = objects[key];
    if (data == null) throw CloudStorageException('File not found in S3: $key');
    return data;
  }

  @override
  Future<S3ObjectInfo?> headObject(String key) async {
    calls.add('head:$key');
    if (!objects.containsKey(key)) return null;
    return S3ObjectInfo(
      key: key,
      lastModified: DateTime.utc(2026, 6, 9),
      size: objects[key]!.length,
    );
  }

  @override
  Future<void> deleteObject(String key) async {
    calls.add('delete:$key');
    objects.remove(key);
  }

  @override
  Future<List<S3ObjectInfo>> listObjects({String prefix = ''}) async {
    calls.add('list:$prefix');
    return listing;
  }

  @override
  void close() => closed = true;
}

void main() {
  late _MemoryCredentialsStore store;
  late List<_FakeS3ApiClient> builtClients;
  late S3StorageProvider provider;

  S3Config config() => S3Config(
    endpoint: 'http://nas.local:9000',
    bucket: 'dive-sync',
    accessKeyId: 'ak',
    secretAccessKey: 'sk',
  );

  setUp(() {
    store = _MemoryCredentialsStore();
    builtClients = [];
    provider = S3StorageProvider(
      store: store,
      apiClientFactory: (config) {
        final client = _FakeS3ApiClient(config);
        builtClients.add(client);
        return client;
      },
    );
  });

  group('identity and availability', () {
    test('providerId and providerName', () {
      expect(provider.providerId, 's3');
      expect(provider.providerName, 'S3-Compatible Storage');
    });

    test('isAvailable is true everywhere', () async {
      expect(await provider.isAvailable(), isTrue);
    });

    test('isAuthenticated reflects config presence', () async {
      expect(await provider.isAuthenticated(), isFalse);
      store.stored = config();
      expect(await provider.isAuthenticated(), isTrue);
    });

    test('getUserEmail is the bucket @ host label', () async {
      store.stored = config();
      expect(await provider.getUserEmail(), 'dive-sync @ nas.local');
    });

    test('getUserEmail is null when unconfigured', () async {
      expect(await provider.getUserEmail(), isNull);
    });
  });

  group('authenticate', () {
    test('throws a clear error when unconfigured', () {
      expect(
        () => provider.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('not configured'),
          ),
        ),
      );
    });

    test('runs the read+write probe: list, put probe, delete probe', () async {
      store.stored = config();
      await provider.authenticate();
      final client = builtClients.single;
      expect(client.calls, [
        'list:submersion-sync/',
        'put:submersion-sync/.submersion-probe',
        'delete:submersion-sync/.submersion-probe',
      ]);
    });
  });

  group('testConnection', () {
    test('rejects an invalid config before any network call', () async {
      await expectLater(
        provider.testConnection(config().copyWith(bucket: '')),
        throwsA(isA<CloudStorageException>()),
      );
      expect(builtClients, isEmpty);
    });

    test('probes the given config without persisting it', () async {
      await provider.testConnection(config());
      expect(store.stored, isNull);
      expect(builtClients.single.closed, isTrue);
      expect(builtClients.single.calls.first, startsWith('list:'));
    });
  });

  group('file operations', () {
    setUp(() => store.stored = config());

    test('uploadFile keys under the folderId and returns the key', () async {
      final result = await provider.uploadFile(
        Uint8List.fromList([1]),
        'submersion_sync_dev-a.json',
        folderId: 'submersion-sync/',
      );
      expect(result.fileId, 'submersion-sync/submersion_sync_dev-a.json');
      expect(
        builtClients.single.calls,
        contains('put:submersion-sync/submersion_sync_dev-a.json'),
      );
    });

    test('uploadFile falls back to the configured prefix', () async {
      final result = await provider.uploadFile(
        Uint8List.fromList([1]),
        'f.json',
      );
      expect(result.fileId, 'submersion-sync/f.json');
    });

    test('downloadFile fetches by full key', () async {
      store.stored = config();
      await provider.uploadFile(Uint8List.fromList([7]), 'f.json');
      final bytes = await provider.downloadFile('submersion-sync/f.json');
      expect(bytes, [7]);
    });

    test('listFiles maps keys to basenames and filters by namePattern', () async {
      final client = _FakeS3ApiClient(config());
      provider = S3StorageProvider(
        store: store,
        apiClientFactory: (_) => client,
      );
      client.listing = [
        S3ObjectInfo(
          key: 'submersion-sync/submersion_sync_dev-a.json',
          lastModified: DateTime.utc(2026, 6, 1),
          size: 10,
        ),
        S3ObjectInfo(
          key: 'submersion-sync/unrelated.txt',
          lastModified: DateTime.utc(2026, 6, 2),
          size: 5,
        ),
      ];
      final files = await provider.listFiles(namePattern: 'submersion_sync');
      expect(files, hasLength(1));
      expect(files.single.id, 'submersion-sync/submersion_sync_dev-a.json');
      expect(files.single.name, 'submersion_sync_dev-a.json');
      expect(files.single.sizeBytes, 10);
    });

    test('getFileInfo returns null for a missing key', () async {
      expect(await provider.getFileInfo('submersion-sync/nope.json'), isNull);
    });

    test('fileExists mirrors headObject', () async {
      await provider.uploadFile(Uint8List.fromList([1]), 'f.json');
      expect(await provider.fileExists('submersion-sync/f.json'), isTrue);
      expect(await provider.fileExists('submersion-sync/nope.json'), isFalse);
    });

    test('folders resolve to the configured prefix', () async {
      expect(await provider.getOrCreateSyncFolder(), 'submersion-sync/');
      expect(await provider.createFolder('anything'), 'submersion-sync/');
    });
  });

  group('config lifecycle', () {
    test('signOut clears the store and authentication', () async {
      store.stored = config();
      expect(await provider.isAuthenticated(), isTrue);
      await provider.signOut();
      expect(store.stored, isNull);
      expect(await provider.isAuthenticated(), isFalse);
    });

    test('saveConfig invalidates the cached client', () async {
      store.stored = config();
      await provider.uploadFile(Uint8List.fromList([1]), 'f.json');
      expect(builtClients, hasLength(1));

      await provider.saveConfig(config().copyWith(bucket: 'other-bucket'));
      await provider.uploadFile(Uint8List.fromList([2]), 'g.json');

      expect(builtClients, hasLength(2));
      expect(builtClients.last.config.bucket, 'other-bucket');
    });
  });
}
```

- [ ] **Step 7.2: Run the tests to verify they fail**

Run: `flutter test test/core/services/cloud_storage/s3_storage_provider_test.dart`
Expected: FAIL — `s3_storage_provider.dart` cannot be resolved.

- [ ] **Step 7.3: Implement the provider**

Create `lib/core/services/cloud_storage/s3_storage_provider.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Builds an [S3ApiClient] for a config; injectable for tests.
typedef S3ApiClientFactory = S3ApiClient Function(S3Config config);

/// S3-compatible object storage implementation of [CloudStorageProvider]
/// (AWS S3, MinIO, Cloudflare R2, Backblaze B2, NAS appliances).
///
/// Semantic mappings onto the OAuth-shaped interface:
/// - fileId is the full object key; "folders" are the configured key prefix
///   (S3 has no folders, so createFolder is a lookup, not a write).
/// - authenticate() is a live read+write probe of the stored config.
/// - getUserEmail() returns the account label `<bucket> @ <host>`.
class S3StorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  static final _log = LoggerService.forClass(S3StorageProvider);

  /// Basename of the temporary object written and removed by the probe.
  static const String probeObjectName = '.submersion-probe';

  S3StorageProvider({
    S3CredentialsStore? store,
    S3ApiClientFactory? apiClientFactory,
  }) : _store = store ?? S3CredentialsStore(),
       _apiClientFactory = apiClientFactory ?? S3ApiClient.new;

  final S3CredentialsStore _store;
  final S3ApiClientFactory _apiClientFactory;

  S3Config? _cachedConfig;
  S3ApiClient? _client;

  @override
  String get providerName => 'S3-Compatible Storage';

  @override
  String get providerId => 's3';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isAuthenticated() async => (await _loadConfig()) != null;

  /// The stored configuration, for the settings UI. Null when unset.
  Future<S3Config?> loadConfig() => _loadConfig();

  /// Persists [config] and drops the cached client so the next operation
  /// uses the new settings.
  Future<void> saveConfig(S3Config config) async {
    await _store.save(config);
    _invalidate();
  }

  @override
  Future<void> authenticate() async {
    final config = await _loadConfig();
    if (config == null) {
      throw const CloudStorageException(
        'S3 is not configured. Open the S3 settings and enter your '
        'bucket details.',
      );
    }
    await _probe(_apiClientFactory(config), config);
    _log.info('S3 probe succeeded for bucket ${config.bucket}');
  }

  /// Validates [config] with the same live read+write probe as
  /// [authenticate], without touching the stored credentials. Used by the
  /// settings form's Test Connection action on unsaved values.
  Future<void> testConnection(S3Config config) async {
    final error = config.validate();
    if (error != null) throw CloudStorageException(error);
    final client = _apiClientFactory(config);
    try {
      await _probe(client, config);
    } finally {
      client.close();
    }
  }

  /// Read permission (list) then write permission (put + delete of a tiny
  /// probe object under the prefix). Shared by [authenticate] and
  /// [testConnection] so the two paths cannot drift.
  Future<void> _probe(S3ApiClient client, S3Config config) async {
    await client.listObjects(prefix: config.prefix);
    final probeKey = '${config.prefix}$probeObjectName';
    await client.putObject(probeKey, Uint8List.fromList('probe'.codeUnits));
    await client.deleteObject(probeKey);
  }

  @override
  Future<void> signOut() async {
    await _store.clear();
    _invalidate();
  }

  @override
  Future<String?> getUserEmail() async {
    final config = await _loadConfig();
    if (config == null) return null;
    return '${config.bucket} @ ${config.displayHost}';
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final config = await _requireConfig();
    final client = _requireClient(config);
    final key = '${folderId ?? config.prefix}$filename';
    await client.putObject(key, data);
    return UploadResult(fileId: key, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final client = _requireClient(await _requireConfig());
    return client.getObject(fileId);
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final client = _requireClient(await _requireConfig());
    final info = await client.headObject(fileId);
    return info == null ? null : _toCloudFileInfo(info);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final config = await _requireConfig();
    final client = _requireClient(config);
    final objects = await client.listObjects(
      prefix: folderId ?? config.prefix,
    );
    return objects
        .map(_toCloudFileInfo)
        // Some servers list the bare prefix as a zero-length "directory"
        // object whose basename is empty; it is never a sync file.
        .where((f) => f.name.isNotEmpty)
        .where((f) => namePattern == null || f.name.contains(namePattern))
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final client = _requireClient(await _requireConfig());
    await client.deleteObject(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async {
    final client = _requireClient(await _requireConfig());
    return (await client.headObject(fileId)) != null;
  }

  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) =>
      getOrCreateSyncFolder();

  @override
  Future<String> getOrCreateSyncFolder() async =>
      (await _requireConfig()).prefix;

  CloudFileInfo _toCloudFileInfo(S3ObjectInfo info) => CloudFileInfo(
    id: info.key,
    name: info.key.split('/').last,
    modifiedTime: info.lastModified,
    sizeBytes: info.size,
  );

  Future<S3Config?> _loadConfig() async =>
      _cachedConfig ??= await _store.load();

  Future<S3Config> _requireConfig() async {
    final config = await _loadConfig();
    if (config == null) {
      throw const CloudStorageException('S3 is not configured');
    }
    return config;
  }

  S3ApiClient _requireClient(S3Config config) =>
      _client ??= _apiClientFactory(config);

  void _invalidate() {
    _client?.close();
    _client = null;
    _cachedConfig = null;
  }
}
```

- [ ] **Step 7.4: Run the tests to verify they pass**

Run: `flutter test test/core/services/cloud_storage/s3_storage_provider_test.dart`
Expected: PASS.

- [ ] **Step 7.5: Format, analyze, commit**

```bash
dart format lib/core/services/cloud_storage/ test/core/services/cloud_storage/
flutter analyze
git add lib/core/services/cloud_storage/s3_storage_provider.dart test/core/services/cloud_storage/s3_storage_provider_test.dart
git commit -m "feat(sync): add S3StorageProvider implementing CloudStorageProvider"
```

### Task 8: Enum variant and Riverpod wiring

Adding the enum variant makes the compiler enumerate every dispatch point:
Dart switches over `CloudProviderType` without a `default` clause become
analyzer errors until handled. The persistence paths need no code change —
`SyncInitializer.saveProvider`/`getLastProvider` round-trip `provider.name`
(`'s3'`) generically, and `sync_metadata.sync_provider` is TEXT.

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:14`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart`
- Test: `test/core/services/sync/sync_provider_type_test.dart` (create)

- [ ] **Step 8.1: Write the failing test**

Create `test/core/services/sync/sync_provider_type_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';

void main() {
  test('CloudProviderType has an s3 variant whose persisted name is s3', () {
    // SyncInitializer persists provider.name to SharedPreferences and
    // sync_metadata.sync_provider; this pins the wire string.
    expect(
      CloudProviderType.values.map((p) => p.name),
      containsAll(['icloud', 'googledrive', 's3']),
    );
  });
}
```

- [ ] **Step 8.2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/sync_provider_type_test.dart`
Expected: FAIL — the values list has no `s3` name.

- [ ] **Step 8.3: Add the enum variant**

In `lib/core/data/repositories/sync_repository.dart` line 14, change:

```dart
enum CloudProviderType { icloud, googledrive }
```

to:

```dart
enum CloudProviderType { icloud, googledrive, s3 }
```

- [ ] **Step 8.4: Let the analyzer enumerate the dispatch points**

Run: `flutter analyze`
Expected: an error in `sync_providers.dart` — the `switch (providerType)` in
`cloudStorageProviderProvider` is no longer exhaustive. Also run
`rg -n "switch" $(rg -ln "CloudProviderType" lib/ test/)` and confirm no other
exhaustive switch exists (as of writing, that switch is the only one; the
provider tiles in `cloud_sync_page.dart` are explicit calls, not a switch).

- [ ] **Step 8.5: Wire the S3 provider into sync_providers.dart**

In `lib/features/settings/presentation/providers/sync_providers.dart`:

Add imports (with the existing cloud_storage imports near the top):

```dart
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
```

Below the existing singletons (`_googleDriveProvider` / `_icloudProvider`, currently lines 98-100):

```dart
final _s3Provider = S3StorageProvider();
```

Add the switch arm in `cloudStorageProviderProvider`:

```dart
    case CloudProviderType.s3:
      return _s3Provider;
```

Append near the other provider definitions (end of file is fine):

```dart
/// Direct access to the S3 provider singleton for the configuration UI
/// (load/save config, test connection).
final s3StorageProviderInstanceProvider = Provider<S3StorageProvider>(
  (ref) => _s3Provider,
);

/// The stored S3 configuration, or null when S3 has not been set up.
/// Invalidate after saving or removing the configuration.
final s3ConfigProvider = FutureProvider<S3Config?>((ref) async {
  return ref.watch(s3StorageProviderInstanceProvider).loadConfig();
});
```

- [ ] **Step 8.6: Verify analyzer and tests are green**

```bash
flutter analyze
flutter test test/core/services/sync/sync_provider_type_test.dart
flutter test test/core/services/cloud_storage/s3_storage_provider_test.dart
```

Expected: analyze clean; both test files pass. If other existing test files
switch over `CloudProviderType`, the analyzer run above lists them — add a
`case CloudProviderType.s3:` arm mirroring the googledrive arm in each.

- [ ] **Step 8.7: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add -A lib/core/data/repositories/sync_repository.dart lib/features/settings/presentation/providers/sync_providers.dart test/core/services/sync/sync_provider_type_test.dart
git commit -m "feat(sync): register CloudProviderType.s3 and the S3 provider singleton"
```

---

### Task 9: Localization — every new string in en plus all 10 locales

Project rule: new strings are translated in **all** locales, never left as
English fallbacks. The template is `lib/l10n/arb/app_en.arb` (keys sorted
alphabetically — insert at the correct sort position, near the existing
`settings_cloudSync_appBar_title` and `settings_…` keys). Reuse
`common_action_save` and `common_action_cancel`; do not add new save/cancel
keys. Technical terms (Amazon S3, MinIO, Bucket, Access Key ID, Secret Access
Key, path-style) intentionally stay untranslated in every locale, matching
industry convention.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

- [ ] **Step 9.1: Add the English template keys**

Insert into `lib/l10n/arb/app_en.arb` (alphabetical positions):

```json
"settings_cloudSync_provider_s3_edit": "Edit S3 configuration",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2, and more",
"settings_cloudSync_provider_s3_title": "S3-Compatible Storage",
"settings_s3Config_action_remove": "Remove Configuration",
"settings_s3Config_action_testConnection": "Test Connection",
"settings_s3Config_appBar_title": "S3-Compatible Storage",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Leave blank for Amazon S3",
"settings_s3Config_field_endpoint_label": "Endpoint URL",
"settings_s3Config_field_pathStyle_label": "Use path-style addressing",
"settings_s3Config_field_pathStyle_subtitle": "Required by most MinIO and NAS servers",
"settings_s3Config_field_prefix_label": "Key prefix",
"settings_s3Config_field_region_label": "Region",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Remove",
"settings_s3Config_remove_confirm_body": "Sync via S3 will stop on this device. Your data in the bucket is not deleted.",
"settings_s3Config_remove_confirm_title": "Remove S3 configuration?",
"settings_s3Config_removed": "S3 configuration removed",
"settings_s3Config_saved": "S3 configuration saved",
"settings_s3Config_test_success": "Connection successful",
"settings_s3Config_validation_endpointInvalid": "Enter a valid http:// or https:// URL",
"settings_s3Config_validation_required": "Required",
"settings_s3Config_warning_http": "This endpoint uses plain HTTP. Credentials and dive data will travel unencrypted; use only on a trusted network.",
```

- [ ] **Step 9.2: Add the translations to each locale arb**

Insert the same 24 keys (same alphabetical placement) with these values.

`app_de.arb` (German):

```json
"settings_cloudSync_provider_s3_edit": "S3-Konfiguration bearbeiten",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 und mehr",
"settings_cloudSync_provider_s3_title": "S3-kompatibler Speicher",
"settings_s3Config_action_remove": "Konfiguration entfernen",
"settings_s3Config_action_testConnection": "Verbindung testen",
"settings_s3Config_appBar_title": "S3-kompatibler Speicher",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Für Amazon S3 leer lassen",
"settings_s3Config_field_endpoint_label": "Endpunkt-URL",
"settings_s3Config_field_pathStyle_label": "Path-Style-Adressierung verwenden",
"settings_s3Config_field_pathStyle_subtitle": "Von den meisten MinIO- und NAS-Servern benötigt",
"settings_s3Config_field_prefix_label": "Schlüssel-Präfix",
"settings_s3Config_field_region_label": "Region",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Entfernen",
"settings_s3Config_remove_confirm_body": "Die Synchronisierung über S3 wird auf diesem Gerät beendet. Ihre Daten im Bucket werden nicht gelöscht.",
"settings_s3Config_remove_confirm_title": "S3-Konfiguration entfernen?",
"settings_s3Config_removed": "S3-Konfiguration entfernt",
"settings_s3Config_saved": "S3-Konfiguration gespeichert",
"settings_s3Config_test_success": "Verbindung erfolgreich",
"settings_s3Config_validation_endpointInvalid": "Gültige http://- oder https://-URL eingeben",
"settings_s3Config_validation_required": "Erforderlich",
"settings_s3Config_warning_http": "Dieser Endpunkt verwendet unverschlüsseltes HTTP. Zugangsdaten und Tauchdaten werden unverschlüsselt übertragen; nur in vertrauenswürdigen Netzwerken verwenden.",
```

`app_es.arb` (Spanish):

```json
"settings_cloudSync_provider_s3_edit": "Editar configuración de S3",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 y más",
"settings_cloudSync_provider_s3_title": "Almacenamiento compatible con S3",
"settings_s3Config_action_remove": "Eliminar configuración",
"settings_s3Config_action_testConnection": "Probar conexión",
"settings_s3Config_appBar_title": "Almacenamiento compatible con S3",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Dejar en blanco para Amazon S3",
"settings_s3Config_field_endpoint_label": "URL del endpoint",
"settings_s3Config_field_pathStyle_label": "Usar direccionamiento path-style",
"settings_s3Config_field_pathStyle_subtitle": "Requerido por la mayoría de servidores MinIO y NAS",
"settings_s3Config_field_prefix_label": "Prefijo de claves",
"settings_s3Config_field_region_label": "Región",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Eliminar",
"settings_s3Config_remove_confirm_body": "La sincronización mediante S3 se detendrá en este dispositivo. Los datos del bucket no se eliminan.",
"settings_s3Config_remove_confirm_title": "¿Eliminar la configuración de S3?",
"settings_s3Config_removed": "Configuración de S3 eliminada",
"settings_s3Config_saved": "Configuración de S3 guardada",
"settings_s3Config_test_success": "Conexión correcta",
"settings_s3Config_validation_endpointInvalid": "Introduce una URL http:// o https:// válida",
"settings_s3Config_validation_required": "Obligatorio",
"settings_s3Config_warning_http": "Este endpoint usa HTTP sin cifrar. Las credenciales y los datos de buceo viajarán sin cifrar; úselo solo en una red de confianza.",
```

`app_fr.arb` (French):

```json
"settings_cloudSync_provider_s3_edit": "Modifier la configuration S3",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 et plus",
"settings_cloudSync_provider_s3_title": "Stockage compatible S3",
"settings_s3Config_action_remove": "Supprimer la configuration",
"settings_s3Config_action_testConnection": "Tester la connexion",
"settings_s3Config_appBar_title": "Stockage compatible S3",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Laisser vide pour Amazon S3",
"settings_s3Config_field_endpoint_label": "URL du point de terminaison",
"settings_s3Config_field_pathStyle_label": "Utiliser l'adressage path-style",
"settings_s3Config_field_pathStyle_subtitle": "Requis par la plupart des serveurs MinIO et NAS",
"settings_s3Config_field_prefix_label": "Préfixe de clés",
"settings_s3Config_field_region_label": "Région",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Supprimer",
"settings_s3Config_remove_confirm_body": "La synchronisation via S3 s'arrêtera sur cet appareil. Vos données dans le bucket ne sont pas supprimées.",
"settings_s3Config_remove_confirm_title": "Supprimer la configuration S3 ?",
"settings_s3Config_removed": "Configuration S3 supprimée",
"settings_s3Config_saved": "Configuration S3 enregistrée",
"settings_s3Config_test_success": "Connexion réussie",
"settings_s3Config_validation_endpointInvalid": "Saisissez une URL http:// ou https:// valide",
"settings_s3Config_validation_required": "Obligatoire",
"settings_s3Config_warning_http": "Ce point de terminaison utilise HTTP non chiffré. Les identifiants et les données de plongée transiteront en clair ; à n'utiliser que sur un réseau de confiance.",
```

`app_it.arb` (Italian):

```json
"settings_cloudSync_provider_s3_edit": "Modifica configurazione S3",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 e altri",
"settings_cloudSync_provider_s3_title": "Archiviazione compatibile S3",
"settings_s3Config_action_remove": "Rimuovi configurazione",
"settings_s3Config_action_testConnection": "Prova connessione",
"settings_s3Config_appBar_title": "Archiviazione compatibile S3",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Lascia vuoto per Amazon S3",
"settings_s3Config_field_endpoint_label": "URL endpoint",
"settings_s3Config_field_pathStyle_label": "Usa indirizzamento path-style",
"settings_s3Config_field_pathStyle_subtitle": "Richiesto dalla maggior parte dei server MinIO e NAS",
"settings_s3Config_field_prefix_label": "Prefisso delle chiavi",
"settings_s3Config_field_region_label": "Regione",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Rimuovi",
"settings_s3Config_remove_confirm_body": "La sincronizzazione tramite S3 si interromperà su questo dispositivo. I dati nel bucket non vengono eliminati.",
"settings_s3Config_remove_confirm_title": "Rimuovere la configurazione S3?",
"settings_s3Config_removed": "Configurazione S3 rimossa",
"settings_s3Config_saved": "Configurazione S3 salvata",
"settings_s3Config_test_success": "Connessione riuscita",
"settings_s3Config_validation_endpointInvalid": "Inserisci un URL http:// o https:// valido",
"settings_s3Config_validation_required": "Obbligatorio",
"settings_s3Config_warning_http": "Questo endpoint usa HTTP non cifrato. Credenziali e dati delle immersioni viaggeranno in chiaro; usalo solo su una rete affidabile.",
```

`app_nl.arb` (Dutch):

```json
"settings_cloudSync_provider_s3_edit": "S3-configuratie bewerken",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 en meer",
"settings_cloudSync_provider_s3_title": "S3-compatibele opslag",
"settings_s3Config_action_remove": "Configuratie verwijderen",
"settings_s3Config_action_testConnection": "Verbinding testen",
"settings_s3Config_appBar_title": "S3-compatibele opslag",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Laat leeg voor Amazon S3",
"settings_s3Config_field_endpoint_label": "Endpoint-URL",
"settings_s3Config_field_pathStyle_label": "Path-style-adressering gebruiken",
"settings_s3Config_field_pathStyle_subtitle": "Vereist door de meeste MinIO- en NAS-servers",
"settings_s3Config_field_prefix_label": "Sleutelvoorvoegsel",
"settings_s3Config_field_region_label": "Regio",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Verwijderen",
"settings_s3Config_remove_confirm_body": "Synchronisatie via S3 stopt op dit apparaat. Je gegevens in de bucket worden niet verwijderd.",
"settings_s3Config_remove_confirm_title": "S3-configuratie verwijderen?",
"settings_s3Config_removed": "S3-configuratie verwijderd",
"settings_s3Config_saved": "S3-configuratie opgeslagen",
"settings_s3Config_test_success": "Verbinding geslaagd",
"settings_s3Config_validation_endpointInvalid": "Voer een geldige http://- of https://-URL in",
"settings_s3Config_validation_required": "Verplicht",
"settings_s3Config_warning_http": "Dit endpoint gebruikt onversleuteld HTTP. Inloggegevens en duikgegevens worden onversleuteld verzonden; gebruik dit alleen op een vertrouwd netwerk.",
```

`app_pt.arb` (Portuguese):

```json
"settings_cloudSync_provider_s3_edit": "Editar configuração do S3",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 e mais",
"settings_cloudSync_provider_s3_title": "Armazenamento compatível com S3",
"settings_s3Config_action_remove": "Remover configuração",
"settings_s3Config_action_testConnection": "Testar conexão",
"settings_s3Config_appBar_title": "Armazenamento compatível com S3",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Deixe em branco para Amazon S3",
"settings_s3Config_field_endpoint_label": "URL do endpoint",
"settings_s3Config_field_pathStyle_label": "Usar endereçamento path-style",
"settings_s3Config_field_pathStyle_subtitle": "Exigido pela maioria dos servidores MinIO e NAS",
"settings_s3Config_field_prefix_label": "Prefixo de chaves",
"settings_s3Config_field_region_label": "Região",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Remover",
"settings_s3Config_remove_confirm_body": "A sincronização via S3 será interrompida neste dispositivo. Seus dados no bucket não são excluídos.",
"settings_s3Config_remove_confirm_title": "Remover a configuração do S3?",
"settings_s3Config_removed": "Configuração do S3 removida",
"settings_s3Config_saved": "Configuração do S3 salva",
"settings_s3Config_test_success": "Conexão bem-sucedida",
"settings_s3Config_validation_endpointInvalid": "Insira um URL http:// ou https:// válido",
"settings_s3Config_validation_required": "Obrigatório",
"settings_s3Config_warning_http": "Este endpoint usa HTTP sem criptografia. Credenciais e dados de mergulho trafegarão sem criptografia; use apenas em uma rede confiável.",
```

`app_hu.arb` (Hungarian):

```json
"settings_cloudSync_provider_s3_edit": "S3-konfiguráció szerkesztése",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 és továbbiak",
"settings_cloudSync_provider_s3_title": "S3-kompatibilis tároló",
"settings_s3Config_action_remove": "Konfiguráció eltávolítása",
"settings_s3Config_action_testConnection": "Kapcsolat tesztelése",
"settings_s3Config_appBar_title": "S3-kompatibilis tároló",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "Amazon S3 esetén hagyja üresen",
"settings_s3Config_field_endpoint_label": "Végpont URL",
"settings_s3Config_field_pathStyle_label": "Path-style címzés használata",
"settings_s3Config_field_pathStyle_subtitle": "A legtöbb MinIO- és NAS-kiszolgálóhoz szükséges",
"settings_s3Config_field_prefix_label": "Kulcs-előtag",
"settings_s3Config_field_region_label": "Régió",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "Eltávolítás",
"settings_s3Config_remove_confirm_body": "Az S3-on keresztüli szinkronizálás leáll ezen az eszközön. A bucketben lévő adatok nem törlődnek.",
"settings_s3Config_remove_confirm_title": "Eltávolítja az S3-konfigurációt?",
"settings_s3Config_removed": "S3-konfiguráció eltávolítva",
"settings_s3Config_saved": "S3-konfiguráció mentve",
"settings_s3Config_test_success": "Sikeres kapcsolat",
"settings_s3Config_validation_endpointInvalid": "Adjon meg érvényes http:// vagy https:// URL-t",
"settings_s3Config_validation_required": "Kötelező",
"settings_s3Config_warning_http": "Ez a végpont titkosítatlan HTTP-t használ. A hitelesítő adatok és a merülési adatok titkosítatlanul utaznak; csak megbízható hálózaton használja.",
```

`app_zh.arb` (Chinese, Simplified):

```json
"settings_cloudSync_provider_s3_edit": "编辑 S3 配置",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3、MinIO、Cloudflare R2、Backblaze B2 等",
"settings_cloudSync_provider_s3_title": "S3 兼容存储",
"settings_s3Config_action_remove": "移除配置",
"settings_s3Config_action_testConnection": "测试连接",
"settings_s3Config_appBar_title": "S3 兼容存储",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "存储桶",
"settings_s3Config_field_endpoint_helper": "使用 Amazon S3 时留空",
"settings_s3Config_field_endpoint_label": "终端节点 URL",
"settings_s3Config_field_pathStyle_label": "使用路径样式寻址",
"settings_s3Config_field_pathStyle_subtitle": "大多数 MinIO 和 NAS 服务器需要此项",
"settings_s3Config_field_prefix_label": "键前缀",
"settings_s3Config_field_region_label": "区域",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "移除",
"settings_s3Config_remove_confirm_body": "此设备上将停止通过 S3 同步。存储桶中的数据不会被删除。",
"settings_s3Config_remove_confirm_title": "移除 S3 配置？",
"settings_s3Config_removed": "S3 配置已移除",
"settings_s3Config_saved": "S3 配置已保存",
"settings_s3Config_test_success": "连接成功",
"settings_s3Config_validation_endpointInvalid": "请输入有效的 http:// 或 https:// URL",
"settings_s3Config_validation_required": "必填",
"settings_s3Config_warning_http": "此终端节点使用未加密的 HTTP。凭证和潜水数据将以明文传输；仅在可信网络中使用。",
```

`app_ar.arb` (Arabic):

```json
"settings_cloudSync_provider_s3_edit": "تحرير إعدادات S3",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3 وMinIO وCloudflare R2 وBackblaze B2 وغيرها",
"settings_cloudSync_provider_s3_title": "تخزين متوافق مع S3",
"settings_s3Config_action_remove": "إزالة الإعدادات",
"settings_s3Config_action_testConnection": "اختبار الاتصال",
"settings_s3Config_appBar_title": "تخزين متوافق مع S3",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "الحاوية (Bucket)",
"settings_s3Config_field_endpoint_helper": "اتركه فارغًا لاستخدام Amazon S3",
"settings_s3Config_field_endpoint_label": "عنوان URL لنقطة النهاية",
"settings_s3Config_field_pathStyle_label": "استخدام العنونة بنمط المسار (path-style)",
"settings_s3Config_field_pathStyle_subtitle": "مطلوب لمعظم خوادم MinIO وNAS",
"settings_s3Config_field_prefix_label": "بادئة المفاتيح",
"settings_s3Config_field_region_label": "المنطقة",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "إزالة",
"settings_s3Config_remove_confirm_body": "ستتوقف المزامنة عبر S3 على هذا الجهاز. لن تُحذف بياناتك في الحاوية.",
"settings_s3Config_remove_confirm_title": "هل تريد إزالة إعدادات S3؟",
"settings_s3Config_removed": "تمت إزالة إعدادات S3",
"settings_s3Config_saved": "تم حفظ إعدادات S3",
"settings_s3Config_test_success": "نجح الاتصال",
"settings_s3Config_validation_endpointInvalid": "أدخل عنوان URL صالحًا يبدأ بـ http:// أو https://",
"settings_s3Config_validation_required": "مطلوب",
"settings_s3Config_warning_http": "تستخدم نقطة النهاية هذه HTTP غير مشفّر. ستنتقل بيانات الاعتماد وبيانات الغوص دون تشفير؛ استخدمه فقط على شبكة موثوقة.",
```

`app_he.arb` (Hebrew):

```json
"settings_cloudSync_provider_s3_edit": "עריכת תצורת S3",
"settings_cloudSync_provider_s3_subtitle": "Amazon S3, MinIO, Cloudflare R2, Backblaze B2 ועוד",
"settings_cloudSync_provider_s3_title": "אחסון תואם S3",
"settings_s3Config_action_remove": "הסרת התצורה",
"settings_s3Config_action_testConnection": "בדיקת חיבור",
"settings_s3Config_appBar_title": "אחסון תואם S3",
"settings_s3Config_field_accessKeyId_label": "Access Key ID",
"settings_s3Config_field_bucket_label": "Bucket",
"settings_s3Config_field_endpoint_helper": "השאירו ריק עבור Amazon S3",
"settings_s3Config_field_endpoint_label": "כתובת URL של נקודת הקצה",
"settings_s3Config_field_pathStyle_label": "שימוש במיעון path-style",
"settings_s3Config_field_pathStyle_subtitle": "נדרש על ידי רוב שרתי MinIO ו-NAS",
"settings_s3Config_field_prefix_label": "קידומת מפתחות",
"settings_s3Config_field_region_label": "אזור",
"settings_s3Config_field_secretAccessKey_label": "Secret Access Key",
"settings_s3Config_remove_confirm_action": "הסרה",
"settings_s3Config_remove_confirm_body": "הסנכרון דרך S3 ייפסק במכשיר זה. הנתונים שלכם ב-bucket לא יימחקו.",
"settings_s3Config_remove_confirm_title": "להסיר את תצורת S3?",
"settings_s3Config_removed": "תצורת S3 הוסרה",
"settings_s3Config_saved": "תצורת S3 נשמרה",
"settings_s3Config_test_success": "החיבור הצליח",
"settings_s3Config_validation_endpointInvalid": "יש להזין כתובת http:// או https:// תקינה",
"settings_s3Config_validation_required": "שדה חובה",
"settings_s3Config_warning_http": "נקודת קצה זו משתמשת ב-HTTP לא מוצפן. פרטי הגישה ונתוני הצלילה יועברו ללא הצפנה; השתמשו רק ברשת מהימנה.",
```

- [ ] **Step 9.3: Regenerate localizations and verify**

```bash
flutter gen-l10n
flutter analyze
```

Expected: gen-l10n exits 0 and regenerates `lib/l10n/arb/app_localizations*.dart`
with the 24 new getters; analyze is clean. If gen-l10n reports untranslated
keys for any locale, a locale file is missing a key — fix before continuing.

- [ ] **Step 9.4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): add S3 sync settings strings in en and all 10 locales"
```

### Task 10: S3ConfigPage

A dedicated settings form. Design points from the spec (section 9): Test
Connection probes the *form's unsaved values* via `testConnection`; Save
persists, selects `CloudProviderType.s3`, records the last provider, and pops;
the path-style switch auto-tracks whether the endpoint is custom until the
user touches it; plain `http://` endpoints show a warning banner but are
allowed.

**Files:**
- Create: `lib/features/settings/presentation/pages/s3_config_page.dart`
- Test: `test/features/settings/presentation/s3_config_page_test.dart`

- [ ] **Step 10.1: Write the failing widget tests**

Create `test/features/settings/presentation/s3_config_page_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MemoryCredentialsStore implements S3CredentialsStore {
  S3Config? stored;

  @override
  Future<S3Config?> load() async => stored;

  @override
  Future<void> save(S3Config config) async => stored = config;

  @override
  Future<void> clear() async => stored = null;
}

class _FakeS3ApiClient implements S3ApiClient {
  final List<String> calls = [];

  @override
  Future<void> putObject(String key, Uint8List bytes) async =>
      calls.add('put:$key');

  @override
  Future<Uint8List> getObject(String key) async => Uint8List(0);

  @override
  Future<S3ObjectInfo?> headObject(String key) async => null;

  @override
  Future<void> deleteObject(String key) async => calls.add('delete:$key');

  @override
  Future<List<S3ObjectInfo>> listObjects({String prefix = ''}) async {
    calls.add('list:$prefix');
    return const [];
  }

  @override
  void close() {}
}

void main() {
  late _MemoryCredentialsStore store;
  late _FakeS3ApiClient apiClient;
  late S3StorageProvider provider;

  setUp(() {
    store = _MemoryCredentialsStore();
    apiClient = _FakeS3ApiClient();
    provider = S3StorageProvider(
      store: store,
      apiClientFactory: (_) => apiClient,
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          s3StorageProviderInstanceProvider.overrideWithValue(provider),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: S3ConfigPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.enterText(find.byKey(const Key('s3-bucket')), 'dive-sync');
    await tester.enterText(find.byKey(const Key('s3-access-key')), 'ak');
    await tester.enterText(find.byKey(const Key('s3-secret-key')), 'sk');
    await tester.pump();
  }

  testWidgets('empty form shows required errors and saves nothing', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(3));
    expect(store.stored, isNull);
  });

  testWidgets('plain http endpoint shows the unencrypted warning', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('s3-http-warning')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(find.byKey(const Key('s3-http-warning')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.pump();
    expect(find.byKey(const Key('s3-http-warning')), findsNothing);
  });

  testWidgets('path-style auto-enables when a custom endpoint is entered', (
    tester,
  ) async {
    await pumpPage(tester);
    Switch pathStyleSwitch() => tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('s3-path-style')),
        matching: find.byType(Switch),
      ),
    );
    expect(pathStyleSwitch().value, isFalse);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(pathStyleSwitch().value, isTrue);
  });

  testWidgets('save persists the config and selects the S3 provider', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(store.stored, isNotNull);
    expect(store.stored!.bucket, 'dive-sync');
    expect(store.stored!.prefix, 'submersion-sync/');
    expect(store.stored!.pathStyle, isTrue);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(S3ConfigPage)),
    );
    expect(
      container.read(selectedCloudProviderTypeProvider),
      CloudProviderType.s3,
    );
    expect(find.text('S3 configuration saved'), findsOneWidget);
  });

  testWidgets('test connection probes without persisting', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-test')));
    await tester.tap(find.byKey(const Key('s3-test')));
    await tester.pumpAndSettle();

    expect(find.text('Connection successful'), findsOneWidget);
    expect(store.stored, isNull);
    expect(apiClient.calls.first, startsWith('list:'));
  });

  testWidgets('remove clears an existing configuration after confirm', (
    tester,
  ) async {
    store.stored = S3Config(
      endpoint: 'http://nas.local:9000',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    );
    await pumpPage(tester);

    await tester.ensureVisible(find.byKey(const Key('s3-remove')));
    await tester.tap(find.byKey(const Key('s3-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove S3 configuration?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('s3-remove-confirm')));
    await tester.pumpAndSettle();

    expect(store.stored, isNull);
  });
}
```

- [ ] **Step 10.2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/presentation/s3_config_page_test.dart`
Expected: FAIL — `s3_config_page.dart` cannot be resolved.

- [ ] **Step 10.3: Implement the page**

Create `lib/features/settings/presentation/pages/s3_config_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Configuration form for the S3-compatible sync backend: endpoint, region,
/// bucket, key prefix, credentials, and addressing style, with a live
/// read+write Test Connection probe against the unsaved form values.
class S3ConfigPage extends ConsumerStatefulWidget {
  const S3ConfigPage({super.key});

  @override
  ConsumerState<S3ConfigPage> createState() => _S3ConfigPageState();
}

class _S3ConfigPageState extends ConsumerState<S3ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController(text: 'us-east-1');
  final _bucketController = TextEditingController();
  final _prefixController = TextEditingController(text: 'submersion-sync/');
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();

  bool _pathStyle = false;
  // Once the user flips the switch manually it stops auto-tracking the
  // endpoint field.
  bool _pathStyleTouched = false;
  bool _secretVisible = false;
  bool _busy = false;
  bool _hasExistingConfig = false;

  @override
  void initState() {
    super.initState();
    _endpointController.addListener(_onEndpointChanged);
    _loadExisting();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _regionController.dispose();
    _bucketController.dispose();
    _prefixController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final existing = await ref
        .read(s3StorageProviderInstanceProvider)
        .loadConfig();
    if (!mounted || existing == null) return;
    setState(() {
      _endpointController.text = existing.endpoint;
      _regionController.text = existing.region;
      _bucketController.text = existing.bucket;
      _prefixController.text = existing.prefix;
      _accessKeyController.text = existing.accessKeyId;
      _secretKeyController.text = existing.secretAccessKey;
      _pathStyle = existing.pathStyle;
      _pathStyleTouched = true;
      _hasExistingConfig = true;
    });
  }

  void _onEndpointChanged() {
    final isCustom = _endpointController.text.trim().isNotEmpty;
    setState(() {
      if (!_pathStyleTouched) _pathStyle = isCustom;
    });
  }

  bool get _isInsecureEndpoint =>
      _endpointController.text.trim().startsWith('http://');

  S3Config _buildConfig() {
    final region = _regionController.text.trim();
    return S3Config(
      endpoint: _endpointController.text,
      region: region.isEmpty ? 'us-east-1' : region,
      bucket: _bucketController.text,
      prefix: _prefixController.text,
      pathStyle: _pathStyle,
      accessKeyId: _accessKeyController.text,
      secretAccessKey: _secretKeyController.text,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(s3StorageProviderInstanceProvider)
          .testConnection(_buildConfig());
      _showSnack(context.l10n.settings_s3Config_test_success);
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(s3StorageProviderInstanceProvider)
          .saveConfig(_buildConfig());
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.s3;
      await ref
          .read(syncInitializerProvider)
          .saveProvider(CloudProviderType.s3);
      ref.invalidate(s3ConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_s3Config_saved);
      // Root-safe in widget tests; pops the pushed route in the app.
      await Navigator.maybePop(context);
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_s3Config_remove_confirm_title),
        content: Text(l10n.settings_s3Config_remove_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            key: const Key('s3-remove-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settings_s3Config_remove_confirm_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(s3StorageProviderInstanceProvider).signOut();
      if (ref.read(selectedCloudProviderTypeProvider) ==
          CloudProviderType.s3) {
        ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
        await ref.read(syncInitializerProvider).saveProvider(null);
      }
      ref.invalidate(s3ConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_s3Config_removed);
      await Navigator.maybePop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_s3Config_appBar_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_isInsecureEndpoint)
              Card(
                key: const Key('s3-http-warning'),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.settings_s3Config_warning_http),
                      ),
                    ],
                  ),
                ),
              ),
            TextFormField(
              key: const Key('s3-endpoint'),
              controller: _endpointController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_endpoint_label,
                helperText: l10n.settings_s3Config_field_endpoint_helper,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) return null;
                final uri = Uri.tryParse(trimmed);
                final valid =
                    uri != null &&
                    (uri.scheme == 'http' || uri.scheme == 'https') &&
                    uri.host.isNotEmpty;
                return valid
                    ? null
                    : l10n.settings_s3Config_validation_endpointInvalid;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-region'),
              controller: _regionController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_region_label,
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-bucket'),
              controller: _bucketController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_bucket_label,
              ),
              autocorrect: false,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
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
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-access-key'),
              controller: _accessKeyController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_accessKeyId_label,
              ),
              autocorrect: false,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-secret-key'),
              controller: _secretKeyController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_secretAccessKey_label,
                suffixIcon: IconButton(
                  icon: Icon(
                    _secretVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _secretVisible = !_secretVisible),
                ),
              ),
              obscureText: !_secretVisible,
              autocorrect: false,
              validator: (value) => (value ?? '').isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
            ),
            SwitchListTile(
              key: const Key('s3-path-style'),
              title: Text(l10n.settings_s3Config_field_pathStyle_label),
              subtitle: Text(l10n.settings_s3Config_field_pathStyle_subtitle),
              value: _pathStyle,
              onChanged: (value) => setState(() {
                _pathStyle = value;
                _pathStyleTouched = true;
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('s3-test'),
                    onPressed: _busy ? null : _testConnection,
                    child: Text(l10n.settings_s3Config_action_testConnection),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('s3-save'),
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.common_action_save),
                  ),
                ),
              ],
            ),
            if (_hasExistingConfig) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('s3-remove'),
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.settings_s3Config_action_remove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 10.4: Run the tests to verify they pass**

Run: `flutter test test/features/settings/presentation/s3_config_page_test.dart`
Expected: PASS (6 tests). If `sharedPreferencesProvider` lives elsewhere than
`settings_providers.dart`, follow the import in `sync_providers.dart:16` and
fix the test import.

- [ ] **Step 10.5: Format, analyze, commit**

```bash
dart format lib/features/settings/ test/features/settings/
flutter analyze
git add lib/features/settings/presentation/pages/s3_config_page.dart test/features/settings/presentation/s3_config_page_test.dart
git commit -m "feat(settings): add S3 configuration page with live connection test"
```

---

### Task 11: Provider tile and route

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (provider section, lines 387-426)
- Modify: `lib/core/router/app_router.dart` (cloud-sync route, lines 859-863)

- [ ] **Step 11.1: Add the S3 tile to the provider section**

In `lib/features/settings/presentation/pages/cloud_sync_page.dart`, add the
import (with the other cloud_storage/settings imports):

```dart
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
```

In `_buildProviderSection` (line 392), append a third entry to the `children:`
list, after the googledrive `_buildProviderTile(...)` call:

```dart
        _buildS3ProviderTile(context, ref, selectedProvider),
```

Then add the builder method below `_buildProviderTile` (after line 459).
Unlike iCloud/Google Drive, the S3 tile has three states: unconfigured (tap
opens the form), configured (tap connects exactly like the other providers),
and an always-available edit affordance:

```dart
  Widget _buildS3ProviderTile(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType? selectedProvider,
  ) {
    final l10n = context.l10n;
    final S3Config? config = ref.watch(s3ConfigProvider).valueOrNull;
    final isSelected = selectedProvider == CloudProviderType.s3;
    final isConfigured = config != null;

    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: const Icon(Icons.dns),
        title: Text(l10n.settings_cloudSync_provider_s3_title),
        subtitle: Text(
          isConfigured
              ? '${config.bucket} @ ${config.displayHost}'
              : l10n.settings_cloudSync_provider_s3_subtitle,
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
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings_cloudSync_provider_s3_edit,
              onPressed: () => context.push('/settings/cloud-sync/s3-config'),
            ),
          ],
        ),
        onTap: () {
          if (isConfigured) {
            _selectProvider(context, ref, CloudProviderType.s3);
          } else {
            context.push('/settings/cloud-sync/s3-config');
          }
        },
      ),
    );
  }
```

- [ ] **Step 11.2: Nest the s3-config route**

In `lib/core/router/app_router.dart`, add the import (with the other settings
page imports near line 75):

```dart
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
```

Change the cloud-sync route (lines 859-863) from:

```dart
              GoRoute(
                path: 'cloud-sync',
                name: 'cloudSync',
                builder: (context, state) => const CloudSyncPage(),
              ),
```

to:

```dart
              GoRoute(
                path: 'cloud-sync',
                name: 'cloudSync',
                builder: (context, state) => const CloudSyncPage(),
                routes: [
                  GoRoute(
                    path: 's3-config',
                    name: 's3Config',
                    builder: (context, state) => const S3ConfigPage(),
                  ),
                ],
              ),
```

- [ ] **Step 11.3: Verify analyze and the settings test suites**

```bash
flutter analyze
flutter test test/features/settings/presentation/s3_config_page_test.dart
flutter test test/features/settings/presentation
```

Expected: analyze clean; the new test file passes; existing settings
presentation tests still pass (the new tile reads `s3ConfigProvider`, which
resolves to null in tests that override nothing — the tile renders its
unconfigured state and breaks nothing). If an existing cloud_sync_page test
pumps the page with a fixed widget list expectation, update it for the third
tile.

- [ ] **Step 11.4: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/features/settings/presentation/pages/cloud_sync_page.dart lib/core/router/app_router.dart
git commit -m "feat(settings): surface the S3 provider tile and config route"
```

### Task 12: Full verification, spec correction, manual MinIO round-trip

**Files:**
- Modify: `docs/superpowers/specs/2026-06-09-s3-sync-backend-design.md` (dependency correction)

- [ ] **Step 12.1: Run the full quality gate**

```bash
dart format lib/ test/
flutter analyze
flutter test
```

Expected: format changes nothing, analyze is clean, all tests pass. `flutter
test` over the whole suite is long — give the command a 10-minute timeout. If
it times out anyway, run `flutter test test/core` and `flutter test
test/features` separately (and any remaining top-level test directories shown
by `ls test/`).

- [ ] **Step 12.2: Correct the spec's dependency claim**

During implementation it turned out `xml` was already in `pubspec.yaml`
(line 86), so the feature adds zero new dependencies. Fix the two places the
spec says otherwise.

In `docs/superpowers/specs/2026-06-09-s3-sync-backend-design.md`, change the
decision-record row:

```text
| 3 | Client implementation | Hand-rolled SigV4 signer + minimal REST client; only new dependency is the pure-Dart `xml` package |
```

to:

```text
| 3 | Client implementation | Hand-rolled SigV4 signer + minimal REST client; zero new dependencies (`xml` was already a dependency) |
```

and change the paragraph after the new-files table:

```text
New pub dependency: `xml` (pure Dart, parses ListObjectsV2 responses). `http`,
`crypto`, and `flutter_secure_storage` are already direct dependencies.
```

to:

```text
No new pub dependencies: `xml` (parses ListObjectsV2 responses), `http`,
`crypto`, and `flutter_secure_storage` were already direct dependencies.
```

Commit:

```bash
git add docs/superpowers/specs/2026-06-09-s3-sync-backend-design.md
git commit -m "docs(sync): correct S3 spec - xml was already a dependency"
```

- [ ] **Step 12.3: Manual verification against MinIO (spec success criteria 1, 2, 4)**

Start a local MinIO and create a bucket:

```bash
docker run -d --name submersion-minio -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=submersion -e MINIO_ROOT_PASSWORD=submersion-secret \
  minio/minio server /data --console-address ":9001"

docker run --rm --network host --entrypoint /bin/sh minio/mc -c \
  "mc alias set local http://localhost:9000 submersion submersion-secret && mc mb local/submersion-test"
```

(If the `mc` one-liner fails, open `http://localhost:9001`, log in with
`submersion` / `submersion-secret`, and create bucket `submersion-test` in the
console.)

Run the app (`flutter run -d macos`) and walk this checklist:

1. Settings → Cloud Sync → tap "S3-Compatible Storage" → the config form
   opens. Enter endpoint `http://localhost:9000` (the HTTP warning banner must
   appear and path-style must auto-enable), bucket `submersion-test`, access
   key `submersion`, secret `submersion-secret`.
2. Test Connection → "Connection successful". Then verify the failure
   messages are specific: wrong secret → access denied; bucket `nope` →
   bucket not found; `docker stop submersion-minio` → could not reach
   endpoint (then `docker start submersion-minio`).
3. Save → back on the sync page, the tile subtitle reads
   `submersion-test @ localhost` and the tile is selected. Run Sync Now →
   completes. In the MinIO console confirm the object
   `submersion-sync/submersion_sync_<deviceId>.json` exists and no probe
   object remains.
4. Second device: `flutter run` on the iOS Simulator (S3 needs no ubiquity
   container, so the Simulator is a valid sync peer — unlike iCloud).
   Configure the same bucket, sync, and confirm data from the Mac appears.
   Edit a dive on one device and sync both; delete a record and confirm the
   deletion propagates without resurrection on the next two syncs.

- [ ] **Step 12.4: Optional AWS S3 spot-check (spec success criterion 1)**

With a real AWS account, create a bucket and an IAM user restricted to it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::YOUR-BUCKET"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::YOUR-BUCKET/submersion-sync/*"
    }
  ]
}
```

In the app: leave endpoint blank, set the bucket's region, enter the IAM
key pair (path-style stays off). Test Connection must pass and a sync must
upload the per-device file over `https`.

- [ ] **Step 12.5: Finish the branch**

All tasks complete and verified. Use the superpowers:finishing-a-development-branch
skill to choose merge vs PR for `feat/s3-sync-backend`.

---

## Execution notes

- **Task order is the dependency order**: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 →
  10 → 11 → 12. Task 9 (l10n) must precede Task 10/11, which reference the
  generated getters. Tasks 1-7 never touch existing files, so the app builds
  and ships unchanged until Task 8 flips the enum.
- **Per-task commits are pre-authorized** on the feature branch (plan
  approval + subagent-driven execution). No Co-Authored-By lines.
- **If `flutter analyze` reports pre-existing issues** unrelated to a task's
  change, do not fix them in this branch; note them and move on.
- **Reference docs**: spec at
  `docs/superpowers/specs/2026-06-09-s3-sync-backend-design.md`; SigV4 vectors
  at `https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-examples.html`.
