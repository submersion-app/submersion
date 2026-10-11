# WebDAV Sync and Media Storage Backend: Design

- Date: 2026-10-10
- Status: Approved (design)
- Issue: #2361
- Related: `2026-06-09-s3-sync-backend-design.md` (the closest precedent),
  `2026-07-10-s3-media-storage-design.md`, `2026-07-24-connected-accounts-dedup-design.md`,
  `2026-08-17-cross-version-sync-compatibility-design.md`

## 1. Background

Self-hosters and privacy-minded divers keep files on Nextcloud, ownCloud, a
Synology or QNAP NAS, or a hosted service that speaks WebDAV (Koofr, pCloud,
Infomaniak kDrive, Fastmail Files, Yandex Disk). None of them can be used for
sync today; the only self-hostable option is S3-compatible storage, which few
of these servers expose.

The sync engine talks only to `CloudStorageProvider`, and the media store only
to `MediaObjectStore`, so one generic WebDAV implementation of each covers all
of these servers. The changeset log is a flat folder in which no two devices
ever write the same file, so the backend needs only put, get, list, delete and
folder creation: no locking and no conditional writes.

## 2. Decision record

| # | Decision | Choice |
|---|----------|--------|
| 1 | Scope | Sync, cloud backups **and** media storage |
| 2 | Client | Hand-rolled WebDAV client over `package:http` + `xml`; no new dependency |
| 3 | Untrusted TLS | Per-config certificate pinning (SHA-256 of the DER), offered from Test connection; no blanket "allow insecure" switch |
| 4 | Media credentials | Its own form on the Media Storage page, with a "Use my sync server" prefill |
| 5 | Large uploads | Streamed single PUT everywhere; Nextcloud chunking v2 above 10 MiB, resumable for media |
| 6 | Cross-version safety | Schema 280 (no-op rung; renumbered from 277, 278 and 279 as main shipped those first), `minimumCompatibleSchemaVersion` raised to 280, and tolerant reads of unknown `AccountKind` values |
| 7 | Tests | In-memory fake WebDAV server only; real servers via a manual checklist (section 12) |
| 8 | Auth | HTTP Basic only |

Approaches considered for decision 2: the `webdav_client` package (built on
`dio`, so it bypasses `TimeoutHttpClient` and `TrustedHttpOverrides`, has no
Nextcloud chunking and does not stream to and from disk the way the
interfaces need) and a Nextcloud-specific client (does not cover the other
servers). Both rejected.

## 3. Goals and non-goals

### Goals

- Sync, cloud backups and media storage through any WebDAV server.
- No change to `SyncService`, the serializer, conflict resolution or the media
  pipeline. End-to-end encryption comes from the existing
  `EncryptingCloudStorageProvider` wrapper.
- Credentials only in `FlutterSecureStorage`, never in SharedPreferences, the
  database or logs.
- Large files are never fully resident in memory.
- Specific, actionable errors, including for self-signed certificates.
- Available on all six platforms.

### Non-goals

- Digest or NTLM authentication.
- ownCloud/oCIS chunking (TUS) and any chunking other than Nextcloud v2.
- `Depth: infinity` PROPFIND (often disabled; the layout never needs it).
- WebDAV locking (`LOCK`/`UNLOCK`).
- Integration tests against real servers in CI.

## 4. Architecture

```text
SyncService ──> CloudStorageProvider
                  └── WebDavStorageProvider ─┐
MediaStore  ──> MediaObjectStore             │
                  └── WebDavMediaObjectStore ┤
                                             └── WebDavClient
                                                   ├── multistatus parser
                                                   ├── TLS pin matcher
                                                   └── NextcloudChunkedUpload
```

### New files

| File | Role |
|------|------|
| `lib/core/services/cloud_storage/webdav/webdav_preset.dart` | `WebDavPreset` enum: URL templates, hints, `supportsNextcloudChunking` |
| `lib/core/services/cloud_storage/webdav/webdav_config.dart` | Immutable `WebDavConfig`: DAV root derivation, validation, `copyWith`, JSON |
| `lib/core/services/cloud_storage/webdav/webdav_credentials_store.dart` | Legacy keychain blob `sync_webdav_config` (parameterized key, like `S3CredentialsStore`) |
| `lib/core/services/cloud_storage/webdav/webdav_multistatus.dart` | Pure PROPFIND response parser |
| `lib/core/services/cloud_storage/webdav/webdav_tls.dart` | Fingerprint formatting, pin matcher, certificate details |
| `lib/core/services/cloud_storage/webdav/webdav_client.dart` | PROPFIND, GET, PUT, DELETE, MKCOL, MOVE; `ensureCollection`; streaming; retry; error mapping |
| `lib/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart` | Chunking v2 with resume state |
| `lib/core/services/cloud_storage/webdav_storage_provider.dart` | `CloudStorageProvider` |
| `lib/core/services/media_store/webdav_media_object_store.dart` | `MediaObjectStore` |
| `lib/core/services/accounts/adapters/webdav_account_adapter.dart` | `SyncCapable` + `MediaStoreCapable` |
| `lib/features/settings/presentation/pages/webdav_config_page.dart` | Sync configuration page |
| `lib/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart` | Trust dialog, shared with the media form |
| `lib/features/media_store/presentation/widgets/webdav_media_form.dart` | Media Storage form (kept out of the already oversized `media_storage_page.dart`) |
| `test/helpers/fake_webdav_server.dart` | In-memory DAV tree behind `MockClient` |

### Wiring

- `CloudProviderType.webdav` and `AccountKind.webdav`, with an arm in every
  exhaustive switch over either enum (account kind mapping, account identity,
  startup migration, provider instances, legacy credential mirroring, Cloud
  Sync display names, Connected Accounts icon, setup wizard names,
  `buildMediaObjectStore`).
- `providerId` is `'webdav'`, equal to the enum name, because the id round
  trips through `LibraryMovedMarker`, `EstablishedProviderStore`, changeset
  cursors and the cleanup offer's `CloudProviderType.values` lookup.
- Route `/settings/cloud-sync/webdav-config` beside `s3-config`.
- `webdavProviderInstance` singleton in `cloud_provider_instances.dart`, so the
  headless background isolate can sync from keychain credentials.
- `ensureAccountForProviderType` gets a WebDAV branch deriving the account
  from the legacy store, like S3; `AccountDeduplicator._canonicalIdFor` gets
  the matching branch.
- `webdavNaturalKey(config)` is the normalized DAV root plus folder, with no
  credentials, so two devices configured for the same folder share one
  deterministic account id.
- `WebDavAccountAdapter` registered in `account_providers.dart`; per-account
  credentials in `AccountCredentialsStore`, mirrored to the legacy key.
- Signing out of sync only deselects WebDAV; the hand-entered settings stay
  until Remove (the S3 behaviour).

## 5. Configuration

```dart
class WebDavConfig {
  final WebDavPreset preset;
  final String serverUrl;        // as entered; ignored by fixed-host presets
  final String username;
  final String password;         // or app password
  final String folder;           // default 'Submersion'; nested paths allowed
  final String? nextcloudUserId; // resolved once via current-user-principal
  final String? pinnedCertSha256;// lowercase hex of SHA-256(DER), or null
}
```

| Preset | User enters | DAV root |
|---|---|---|
| Nextcloud | `https://cloud.example.com` | `<url>/remote.php/dav/files/<userId>/` |
| ownCloud | `https://cloud.example.com` | `<url>/remote.php/dav/files/<user>/` |
| Synology | `https://nas.local:5006` | `<url>/` (hint: enable WebDAV Server; HTTPS port 5006) |
| Koofr | nothing | `https://app.koofr.net/dav/Koofr/` |
| pCloud | US or EU | `https://webdav.pcloud.com/` or `https://ewebdav.pcloud.com/` |
| Fastmail | nothing | `https://myfiles.fastmail.com/` |
| Yandex | nothing | `https://webdav.yandex.com/` |
| Other | the full DAV URL | as entered |

Validation: username and password non-empty; URL a parseable `http(s)://` URI
where the preset needs one; folder trimmed of leading and trailing slashes,
with no `..` segments. `http://` is accepted with the same persistent
unencrypted-traffic warning S3 shows. Each path segment is percent-encoded
when building URLs.

The Nextcloud user id can differ from the login name (an email login, LDAP).
Test connection and Save resolve it once with a PROPFIND for
`current-user-principal` on `<url>/remote.php/dav/` and store it; both the
`files/<id>/` and `uploads/<id>/` paths use it. When resolution fails the login
name is used.

## 6. Remote layout and operation mapping

```text
<davRoot>/<folder>/                   sync folder: flat changeset log and legacy snapshots
<davRoot>/<folder>/<backupFolder>/    cloud backups (createFolder)
<davRoot>/<mediaFolder>/smv1/...      media store (own config; default "Submersion Media")
```

A `fileId` is the path relative to the DAV root (the S3 key analogue);
`CloudFileInfo.name` is its decoded basename, so `isSyncFile` and the
encryption wrapper's AAD name lookup work unchanged.

| Interface | WebDAV |
|---|---|
| `isAvailable` | `true` everywhere |
| `isAuthenticated` | Config blob present (no network) |
| `authenticate` / `testConnection` | PROPFIND Depth 0 on the DAV root, `ensureCollection(folder)`, then PUT, GET, DELETE of `<folder>/.submersion-probe` |
| `getUserEmail` | `<user> @ <host>` |
| `listFiles` | PROPFIND Depth 1 on the folder; collections and the folder itself dropped; `namePattern` filtered on the client |
| `getFileInfo` / `fileExists` | PROPFIND Depth 0; 404 gives null / false |
| `uploadFile` | PUT bytes; on 409 (missing parent) `ensureCollection` and retry once |
| `uploadFileFromPath` | Streamed PUT (`http.StreamedRequest` fed by `File.openRead()`, explicit Content-Length); Nextcloud above 10 MiB uses chunking |
| `downloadFile` | GET |
| `downloadToFile` | Streamed GET into the destination; partial file deleted on failure |
| `deleteFile` | DELETE; 404 is success |
| `createFolder` / `getOrCreateSyncFolder` | MKCOL each missing level; 405 (exists) is success; created paths cached per client |

Media store:

- `putFile` / `getFile` stream as above, with `ensureCollection` on the parent
  (cached, so `smv1/objects/ab/` is created once per client).
- `list(prefix)` splits the prefix at its last `/`: Depth 1 PROPFIND on the
  directory part, filter on the name part. A prefix ending in `/` walks the
  subtree with Depth 1 PROPFINDs (never `Depth: infinity`).
- `head` is PROPFIND Depth 0; `delete` is idempotent.
- `abandonResume` and `reapStaleUploadSessions` act only on Nextcloud chunked
  uploads (section 8); elsewhere they no-op and return 0.
- `MediaStoreService.connectWebDav` mirrors `connectS3`: probe, marker
  adoption, credential write, attach state, synced store descriptor.
- Media credentials live only in the account's per-account keychain blob.
  Every WebDAV media attachment carries an account id, so the runtime
  resolves the store through the adapter, and there is no legacy
  single-key media blob (a rollback build cannot read WebDAV anyway).

PROPFIND requests ask for `resourcetype`, `getcontentlength` and
`getlastmodified`. `href` values may be absolute URLs or absolute paths, may be
percent-encoded, and collections may or may not carry a trailing slash; the
parser normalizes all of these relative to the DAV root. `getlastmodified` is
RFC 1123 with whole-second precision; sync ordering comes from HLCs inside the
payloads, so nothing depends on sub-second times.

## 7. Certificate pinning

Each `WebDavClient` builds its own `HttpClient`, so the app's global
`AppHttpOverrides` (proxy support and the Windows root store) still applies.
Its certificate check is registered with
`AppHttpOverrides.setBadCertificateCallback`, because the overrides open
direct and SOCKS5 TLS sockets themselves and dart:io never consults the
client's own `badCertificateCallback` there. Dart invokes the check only for
certificates that fail normal verification:

- No pin stored: record the certificate, return false, and throw
  `WebDavUntrustedCertificateException` (a `CloudStorageException`) with host,
  port, SHA-256 fingerprint, subject, issuer and validity.
- Pin stored: accept only when the host and port match the configured server
  and `sha256(cert.der)` equals the pin.
- Pin stored but a different untrusted certificate presented: the same
  exception with `pinMismatch: true`; the dialog shows both fingerprints.

On that exception, Test connection and Save open a dialog showing the
fingerprint as colon-separated uppercase hex, subject, issuer and expiry, with
**Trust this certificate** and **Cancel**. Trust stores the pin in the config
and re-runs the test. The settings page shows "Trusted certificate:
AB:CD:..." with **Forget** while a pin is stored. A server that later gets a
CA-valid certificate never reaches the callback, so a stale pin is harmless.

The pin is therefore a trust exception for one certificate that fails normal
verification, not strict pinning: a renewed self-signed certificate shows both
fingerprints before it is accepted, while a CA-valid replacement is accepted by
normal verification without the dialog. That is deliberate, since the system's
trust store already vouches for it, and strict pinning would break every
server that moves to a public certificate.
The media form uses the same dialog.

## 8. Nextcloud chunking v2

Used when the preset is Nextcloud and the file exceeds 10 MiB:

1. MKCOL `remote.php/dav/uploads/<userId>/submersion-<uuid>` with a
   `Destination:` header naming the final URL.
2. PUT chunks of 10 MiB named `00001`, `00002`, ... each with `Destination`
   and `OC-Total-Length`.
3. MOVE `<uploadDir>/.file` to the destination with `Destination`,
   `OC-Total-Length` and `Overwrite: T`.

Resume (media): the resume state JSON is
`{v: 1, transferId, chunkSize, total, dest}`. On replay with a matching
`total` and `dest`, a Depth 1 PROPFIND of the upload directory skips chunks
already present at full size; a missing directory (Nextcloud expires them
after about 24 hours) restarts the upload. Backups use the same path without
resume state.

Fallback: if MKCOL on `uploads/` answers 404, 405 or 501, the client uses a
single PUT for the rest of its life.

MOVE retry: if a retried MOVE finds the source gone, a destination of the
expected size counts as success.

Cleanup: `abandonResume` deletes the upload directory named in the state;
`reapStaleUploadSessions` lists `uploads/<userId>/` and deletes `submersion-*`
directories older than the cutoff.

## 9. Transport, retry and errors

- Deadlines: the `TimeoutHttpClient` connect, response, upload and idle
  deadlines.
- Retry: the S3 policy (up to 6 attempts, jittered backoff) on transport
  errors, 5xx other than 507, 429 and 423, for PROPFIND, GET, PUT, DELETE,
  MKCOL and MOVE (MOVE per section 8).
- Redirects: `package:http` follows redirects only for GET and HEAD, so the
  client disables automatic following everywhere and reports any 3xx.

| Response | Message | Media kind |
|---|---|---|
| 401 | The server rejected the username or password. If the account uses two-factor sign-in, create an app password. | auth |
| 403 | No permission for this folder. | auth |
| 404 on the DAV root | No WebDAV folder at this address. Check the server type and URL. | fatal |
| 405 or non-multistatus reply to PROPFIND | This address is not a WebDAV endpoint. | fatal |
| 3xx | The server redirected to `<location>`. Use that address instead. | fatal |
| 413 | The server refused a file of N MB as too large. Raise its upload limit. | fatal |
| 507 | The server is out of storage. | fatal |
| Untrusted certificate | Section 7 | auth |
| Socket error or timeout | Could not reach `<host>`. | transient |

The server's own detail (status line, a bounded excerpt of the body) goes in
`cause`, so `CloudStorageException.displayMessage` and
`MediaStoreException.toString` show it. Passwords never appear in messages or
logs.

## 10. Cross-version safety

`AccountKind.name` is stored in the synced `connected_accounts.kind` column,
and builds before this one parse it with `AccountKind.values.byName`, which
throws on `webdav`. v1.8.1 (schema 260) is already held by the current floor
(275). To hold beta builds at schema 275 and 276 as well:

- Schema version 280 (renumbered from 277, 278 and 279, which main took for
  the documents store, the visibility range and dive computer connections): a no-op rung in `lib/core/database/migrations/` (never in
  `database.dart`).
- `minimumCompatibleSchemaVersion` raised to 280, with a doc-comment entry:
  a new `AccountKind` value is a new value in an existing synced column that
  older readers decode with a throwing lookup.
- `ConnectedAccountsRepository` skips rows whose kind it does not know, with a
  logged warning, instead of throwing, so any future kind is harmless to this
  build and later ones.
- The cross-version roundtrip test's declared key list is extended for 280 (no new keys: 280 adds no column).

## 11. UI

- Cloud Sync page: a "WebDAV" tile, subtitle "Nextcloud, ownCloud, Synology,
  Koofr…", with a gear to edit. Tapping selects WebDAV when configured,
  otherwise opens the config page.
- WebDAV config page: server type, server URL (hidden for fixed-host presets;
  a US/EU choice for pCloud), username, password (obscured, with a show toggle
  and an app-password hint), folder, the resolved DAV root (read only), the
  `http://` warning, the trusted-certificate row, and Test connection, Save,
  Remove.
- Setup wizard: a WebDAV card that opens the config page on the root
  navigator, as S3 does.
- Media Storage page: a "WebDAV" segment showing `WebDavMediaForm` (same
  fields, folder default "Submersion Media"), with **Use my sync server** when
  WebDAV sync is configured; it copies server type, URL, user, password, user
  id and pin, and keeps the media folder.
- Connected Accounts: a WebDAV icon.
- Strings under `settings_webdavConfig_*`, `settings_cloudSync_provider_webdav_*`
  and `settings_mediaStorage_webdav_*`, translated in all 11 locales.

## 12. Testing

Automated (fake server only):

- `fake_webdav_server.dart`: an in-memory tree supporting PROPFIND Depth 0 and
  1, GET, PUT (409 on a missing parent), DELETE, MKCOL (405 when present, 409
  on a missing parent), MOVE, Nextcloud `uploads/` and
  `current-user-principal`, with injectable status codes, redirects, 413 and
  stalls.
- Unit: presets and DAV root derivation, config validation and JSON, the
  multistatus parser (absolute and path hrefs, percent-encoding, trailing
  slashes, missing sizes), the pin matcher, client error mapping, retry and
  redirect handling, streamed PUT Content-Length, chunking (happy path,
  resume, expired directory, fallback, MOVE retry, reaping), the provider
  contract, the media store contract, the account adapter,
  `webdavNaturalKey`, tolerant unknown-kind reads, the 280 migration and the
  floor constant.
- Widget: config page (test, save, trust dialog, forget pin), Cloud Sync tile,
  wizard card, media form and prefill.

Manual checklist (real servers, before release):

- Nextcloud with an app password: sync, backup above 10 MiB (chunked), media
  video upload interrupted and resumed.
- Nextcloud with an email login (user id resolution).
- Synology with its self-signed certificate: trust, sync, then a changed
  certificate shows the mismatch dialog.
- Koofr: sync and media.
- Plain `http://` server on a LAN: warning shown, sync works.
- Encrypted sync enabled on WebDAV: payloads are sealed.
