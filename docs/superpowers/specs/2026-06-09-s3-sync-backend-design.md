# S3-Compatible Sync Storage Backend — Design

- Date: 2026-06-09
- Status: Approved (design); implementation not started
- Owner: Eric
- Related: builds on the plaintext cloud sync revived by the 2026-06-01 iCloud
  sync spec. Adds a third `CloudStorageProvider` implementation; the sync
  engine itself is unchanged.

## 1. Background

Submersion's cloud sync engine is storage-agnostic: `SyncService` talks only to
the abstract `CloudStorageProvider` interface
(`lib/core/services/cloud_storage/cloud_storage_provider.dart`), and two
implementations exist today — iCloud (Apple platforms, native ubiquity-container
bridge) and Google Drive (OAuth, `googleapis`). Each device writes its own
per-device snapshot (`submersion_sync_<deviceId>.json`) and merges peers' files
using HLC/last-write-wins conflict resolution with tombstoned deletions.

This design adds S3-compatible object storage as a third provider. Motivations:

- **Self-hosting / data ownership.** Users with a NAS (MinIO, Synology), or an
  account on Cloudflare R2, Backblaze B2, Wasabi, or AWS S3, can sync through
  storage they control.
- **Full platform coverage.** S3 is pure HTTPS — no native code, no OAuth
  browser flow. It becomes the first provider that works on **all six
  platforms**, including Windows and Linux where iCloud is unavailable.
- **Testability.** Unlike iCloud (which requires real hardware because ubiquity
  containers do not propagate on the iOS Simulator), S3 sync is fully
  exercisable against a local MinIO container on any dev machine.

The Dart S3 package ecosystem was evaluated and rejected: the canonical `minio`
package has a fork-and-abandon history (`s3_storage`, `s3_dart`, …), and
`aws_s3_api` is three years stale and AWS-centric. The sync engine needs only
five S3 operations, the SigV4 signing protocol has been frozen since 2014, and
all object keys are app-controlled ASCII — so a small hand-rolled client is
lower total risk than a third-party dependency on the path that carries
credentials and dive data.

## 2. Decision record

Decisions made with the owner during design:

| # | Decision | Choice |
|---|----------|--------|
| 1 | Endpoint scope | Any S3-compatible endpoint (AWS, MinIO, R2, B2, NAS), not AWS-only |
| 2 | Payload format | Plaintext JSON, byte-identical to iCloud/Google Drive payloads; no client-side encryption |
| 3 | Client implementation | Hand-rolled SigV4 signer + minimal REST client; zero new dependencies (`xml` was already a dependency) |
| 4 | Configuration UI | Dedicated settings page (`s3_config_page.dart`), not a dialog or inline expansion |
| 5 | Test Connection | Read **and** write probe: capped ListObjectsV2 (max-keys=1) plus PUT, GET, and DELETE of a tiny probe object |
| 6 | Plain `http://` endpoints | Allowed (for trusted-LAN NAS/MinIO) with a visible unencrypted-traffic warning |
| 7 | Provider card label | "S3-Compatible Storage", subtitle "Amazon S3, MinIO, Cloudflare R2, Backblaze B2…" |

## 3. Goals and non-goals

### Goals

- Sync the existing per-device JSON snapshots through any S3-compatible bucket.
- Zero changes to `SyncService`, the serializer, conflict resolution, or the
  sync DB tables. `sync_metadata.sync_provider` is TEXT and simply stores
  `'s3'` — **no database migration**.
- Credentials live only in `FlutterSecureStorage`; never in SharedPreferences,
  the database, or logs.
- Configuration validated up front by a real read+write probe, with specific,
  actionable error messages.
- Available on every platform the app builds for.

### Non-goals (explicitly out of scope)

- **Bucket creation / management.** The bucket must already exist. The IAM
  policy needed is GetObject/PutObject/DeleteObject/ListBucket scoped to the
  prefix — the app never needs more.
- **Client-side encryption.** Users may enable server-side encryption (SSE) on
  their bucket; the app does not encrypt payloads.
- **Multipart upload.** Sync payloads are far below the 5 GB single-PUT limit.
- **Media/blob sync.** Same scope boundary as the existing providers:
  structured records only.
- **Presigned-URL sharing, STS/temporary credentials, IAM role assumption.**
  Static access key + secret only.
- **Completing/validating the Google Drive provider.** Untouched by this work.

## 4. Architecture

```text
SyncService ──> CloudStorageProvider (existing interface, unchanged)
                  ├── ICloudStorageProvider        (existing)
                  ├── GoogleDriveStorageProvider   (existing)
                  └── S3StorageProvider            (new)
                        ├── S3CredentialsStore     (FlutterSecureStorage blob)
                        └── S3ApiClient            (5 ops over package:http)
                              └── SigV4Signer      (pure functions)
```

Cloud layout maps the existing per-device files onto object keys:

```text
s3://<bucket>/<prefix>submersion_sync_<deviceId>.json   (one per device)
```

Default prefix: `submersion-sync/` (user-overridable in the config form).

### New files

| File | Role | ~Lines |
|------|------|-------|
| `lib/core/services/cloud_storage/s3/s3_config.dart` | Immutable `S3Config` entity + validation + `copyWith` + JSON round-trip | 100 |
| `lib/core/services/cloud_storage/s3/sigv4_signer.dart` | Pure-function AWS Signature V4: canonical request → string-to-sign → signing key → `Authorization` header | 150 |
| `lib/core/services/cloud_storage/s3/s3_api_client.dart` | PutObject, GetObject, HeadObject, DeleteObject, ListObjectsV2 over `http.Client`; XML parsing; error mapping; retry | 250 |
| `lib/core/services/cloud_storage/s3/s3_credentials_store.dart` | Load/save/delete the `S3Config` JSON blob in `FlutterSecureStorage` (key `sync_s3_config`) | 60 |
| `lib/core/services/cloud_storage/s3_storage_provider.dart` | `S3StorageProvider implements CloudStorageProvider` | 200 |
| `lib/features/settings/presentation/pages/s3_config_page.dart` | Configuration form + Test Connection | 300 |

No new pub dependencies: `xml` (parses ListObjectsV2 responses), `http`,
`crypto`, and `flutter_secure_storage` were already direct dependencies.

## 5. S3Config and credential storage

```dart
class S3Config {
  final String endpoint;        // '' = AWS (derived: s3.<region>.amazonaws.com)
  final String region;          // default 'us-east-1'
  final String bucket;          // required
  final String prefix;          // default 'submersion-sync/'; '' allowed;
                                // normalized to end with '/' when non-empty
  final bool pathStyle;         // default: true when endpoint is custom,
                                // false (virtual-hosted) for AWS
  final String accessKeyId;     // required
  final String secretAccessKey; // required
}
```

The whole config — including both secrets — is stored as **one JSON blob** in
`FlutterSecureStorage` under `sync_s3_config`. One blob keeps reads/writes
atomic (no split-brain between SharedPreferences and the keychain) and follows
the established secret-blob pattern in
`lib/features/media/data/services/network_credentials_service.dart`.
`S3StorageProvider` caches the parsed config in memory; the cache is
invalidated by `saveConfig` and `signOut`.

Validation rules (form + entity):

- `bucket`, `accessKeyId`, `secretAccessKey` non-empty.
- `endpoint` empty or a parseable `http(s)://` URI. `http://` triggers the
  persistent unencrypted-traffic warning but is accepted.
- `prefix` may be empty; otherwise normalized to a single trailing `/`, no
  leading `/`.

## 6. Interface mapping

How `CloudStorageProvider`'s contract (shaped by OAuth-style providers) maps to
S3 semantics:

| Interface member | S3 behavior |
|---|---|
| `providerId` / `providerName` | `'s3'` / `'S3-Compatible Storage'` |
| `isAvailable()` | `true` on every platform |
| `isAuthenticated()` | `true` iff a config blob exists in secure storage (presence-only; no network — this is called on UI rebuild paths) |
| `authenticate()` | Live probe: capped ListObjectsV2 on the prefix (max-keys=1, read), then PUT, GET, and DELETE of `<prefix>.submersion-probe` (write + read-back). A missing s3:GetObject permission fails the probe. Throws `CloudStorageException` with a specific message on failure |
| `signOut()` | Delete the secure-storage blob; clear in-memory cache |
| `getUserEmail()` | Display label: `<bucket> @ <endpoint host>` (no email concept in S3) |
| `uploadFile(data, filename, {folderId})` | PutObject to key `<folderId ?? prefix><filename>`; returns `UploadResult(fileId: key, uploadTime: now)` |
| `downloadFile(fileId)` | GetObject by key; 404 → `CloudStorageException` |
| `getFileInfo(fileId)` | HeadObject; 404 → `null`; maps `Last-Modified`/`Content-Length` into `CloudFileInfo(id: key, name: basename(key), …)` |
| `listFiles({folderId, namePattern})` | ListObjectsV2 with `prefix=folderId ?? config.prefix`, following `NextContinuationToken` until complete; `namePattern` filtered client-side on the basename |
| `deleteFile(fileId)` | DeleteObject (idempotent; 404 is success) |
| `fileExists(fileId)` | HeadObject → 200/404 |
| `createFolder(...)` / `getOrCreateSyncFolder()` | S3 has no folders: `getOrCreateSyncFolder()` returns the configured prefix; `createFolder(name)` maps to the `<prefix><name>/` sub-prefix (used by cloud backup so database backups do not co-locate with sync files); no probe writes, no zero-byte "directory" objects |

`CloudFileInfo.name` is the key's basename, so the sync engine's existing
`isSyncFile()` filename matching works unchanged.

## 7. Request signing and transport

### SigV4 signer (`sigv4_signer.dart`)

Pure functions, no I/O:

- Signing key chain: `kDate = HMAC-SHA256("AWS4"+secret, yyyymmdd)` → `kRegion`
  → `kService("s3")` → `kSigning("aws4_request")`.
- Canonical request: method, URI-encoded path, sorted+encoded query string,
  sorted lowercase headers (`host`, `x-amz-date`, `x-amz-content-sha256` at
  minimum), signed-headers list, payload hash.
- `x-amz-content-sha256` carries the real SHA-256 of the payload (payloads are
  in-memory `Uint8List`s; `UNSIGNED-PAYLOAD` is not needed).
- Timestamp passed in as a parameter (testability; no hidden `DateTime.now()`).

### URL construction

- Path-style (default for custom endpoints; required by most MinIO/NAS):
  `https://<endpoint-host>/<bucket>/<key>`
- Virtual-hosted (default for AWS): `https://<bucket>.s3.<region>.amazonaws.com/<key>`
- Empty endpoint ⇒ AWS endpoint derived from region.

### Retry and errors

One automatic retry with a short (~500 ms) backoff on transport errors
(`SocketException`, timeout) and HTTP 5xx. All five operations are idempotent
in our usage, so a duplicate PUT/DELETE is harmless. Failures map to the
existing `CloudStorageException`:

| Condition | Message intent |
|---|---|
| 403 | "Access denied — check access key, secret, and bucket permissions" |
| 403 `RequestTimeTooSkewed` | "Device clock is more than 15 minutes off — fix the system time" |
| 404 (bucket) | "Bucket not found" |
| Connection refused / DNS failure | "Could not reach endpoint <host>" |

The `Authorization` header and secret key are redacted from every log and error
path.

## 8. Wiring changes (existing files)

`CloudProviderType` gains a third variant; Dart's exhaustive `switch` turns the
compiler into the checklist of dispatch points:

- `lib/core/data/repositories/sync_repository.dart:14` —
  `enum CloudProviderType { icloud, googledrive, s3 }`
- `lib/features/settings/presentation/providers/sync_providers.dart` — `_s3Provider`
  singleton + new `switch` arm in `cloudStorageProviderProvider`; a provider
  exposing the shared `S3CredentialsStore` for the config page.
- `lib/core/services/sync/sync_initializer.dart` — `'s3'` in the
  saveProvider/getLastProvider string mapping.
- `lib/features/settings/presentation/pages/cloud_sync_page.dart` — third
  provider card (see §9).
- `lib/core/router/app_router.dart` — route
  `/settings/cloud-sync/s3-config` → `S3ConfigPage` (nested under the existing
  `cloud-sync` route added at `app_router.dart:860`).

## 9. UI design

### Provider card (`cloud_sync_page.dart`)

A third card after iCloud and Google Drive: title **"S3-Compatible Storage"**,
subtitle **"Amazon S3, MinIO, Cloudflare R2, Backblaze B2…"**. Behavior:

- Not yet configured → tapping navigates to `S3ConfigPage`.
- Configured → tapping selects the provider (same flow as the other cards);
  the card shows the account label (`<bucket> @ <host>`) and a trailing edit
  affordance that reopens `S3ConfigPage`.

### `S3ConfigPage`

Form fields, in order: Endpoint URL (helper text: "Leave blank for Amazon
S3"), Region, Bucket, Key prefix, Access Key ID, Secret Access Key (obscured,
visibility toggle), "Use path-style addressing" switch (auto-set when the
endpoint field changes between blank/custom, still user-overridable). Inline
warning banner when the endpoint is `http://`.

Actions:

- **Test Connection** — runs the same read+write probe as `authenticate()`,
  but via a transient `S3ApiClient` built from the *form's current values*
  (not yet saved), so a bad edit can be tested without clobbering a working
  stored config; shows success or the specific mapped error. The probe logic
  lives in one shared method so the two paths cannot drift.
- **Save** — validates, persists via `S3CredentialsStore`, selects
  `CloudProviderType.s3`, records `'s3'` as the last provider, pops back to
  the sync page.
- **Remove Configuration** (when editing an existing config via the S3 form) —
  the explicit destructive path: clears the blob via `signOut()` and
  deselects the provider. **Sign Out** on the generic cloud-sync page for an
  already-configured S3 provider only deselects the provider and does **not**
  delete the stored credentials, so the hand-entered endpoint/key/secret
  survive a provider switch and are available to re-select without
  re-entering them.

### Localization

Every new string is added to `lib/l10n/app_en.arb` **and translated in all 10
non-English locales**, then codegen is regenerated — per project convention
(no English fallbacks).

## 10. Testing strategy

TDD throughout; tests mirror `lib/` structure under `test/`.

- **Signer:** unit tests against AWS's published SigV4 test-vector suite —
  canonical request, string-to-sign, and final signature as hex-string
  assertions; plus query-string canonicalization for ListObjectsV2.
- **API client:** `package:http` `MockClient` tests per operation — request
  shape (path-style vs virtual-hosted URL, signed/required headers) and
  response handling (ListObjectsV2 XML fixtures including an
  `IsTruncated`/`NextContinuationToken` page, 403/404/5xx mapping, retry
  fires exactly once on a transient failure).
- **Provider:** tests over a fake `S3ApiClient` — fileId↔key mapping, folder
  no-ops returning the prefix, the authenticate probe sequence
  (list→put→get→delete), `signOut` clearing the store and cache, presence-only
  `isAuthenticated`.
- **Credentials store:** JSON round-trip with a mocked `FlutterSecureStorage`.
- **Config page:** widget test for validation (required fields, http warning,
  prefix normalization).
- **Manual verification:** (a) local MinIO via Docker — configure, Test
  Connection, full two-instance sync round-trip including a deletion and a
  conflict; (b) real AWS S3 with a minimally-scoped IAM key; (c) `flutter
  analyze`, `dart format`, full `flutter test` green.

## 11. Risks and mitigations

- **SigV4 correctness** is the main implementation risk. Mitigated by the
  pure-function signer tested against AWS's official vectors, app-controlled
  ASCII key space (no exotic canonical-encoding cases), and MinIO integration
  testing.
- **Device clock skew** breaks SigV4 (15-minute window) — surfaced with a
  dedicated error message rather than a generic auth failure.
- **`flutter_secure_storage` on Linux** depends on libsecret/keyring being
  present at runtime. Failure surfaces as a clear error, not a crash; document
  the requirement in the user-facing setup help.
- **Pending `feat/icloud-sync-diagnostic` branch** (HLC hardening) touches the
  sync engine, not the storage layer; overlap is limited to trivially merged
  enum/init lines. This work is based on `main`.
- **Config staleness in the provider singleton** — addressed by in-memory
  cache invalidation on `saveConfig`/`signOut` (§5).
- **Vestigial sync_metadata columns** — `sync_provider`/`remote_file_id` are
  never written non-null by any current code path. The S3 sign-out branch
  still clears them exactly like the standard sign-out (it skips only the
  provider's credential deletion), so metadata behavior is uniform across
  providers.

## 12. Success criteria

1. A user can configure MinIO (LAN, `http://`, path-style) and AWS S3
   (virtual-hosted, `https://`) entirely from the UI, and Test Connection
   reports accurate success/failure for: good config, wrong secret, read-only
   key, missing bucket, unreachable host.
2. Two app instances pointed at one bucket converge: records propagate both
   directions, deletions propagate without resurrection, and concurrent edits
   resolve per the existing HLC rules — byte-identical payload format to the
   other providers.
3. No changes to `SyncService`, the serializer, or any DB schema.
4. Secrets appear nowhere outside `FlutterSecureStorage` (verified by grep of
   logs during a sync run).
5. `flutter analyze`, `dart format`, and the full test suite pass.
