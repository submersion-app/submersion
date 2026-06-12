# S3 Configuration Simplification — Design

**Date:** 2026-06-12
**Status:** Approved
**Builds on:** `2026-06-09-s3-sync-backend-design.md`

## Problem

The S3-Compatible Storage configuration page shows seven inputs: Endpoint
URL, Region, Bucket, Key Prefix, Access Key ID, Secret Access Key, and a
Path-style switch. The Region field confuses anyone not using AWS S3:
Cloudflare R2 needs the literal string `auto`, Backblaze B2 needs the region
already embedded in its endpoint hostname, and MinIO and DigitalOcean Spaces
ignore the value entirely. Users should not need to understand AWS Signature
Version 4 credential scopes to configure sync.

Region cannot simply be deleted: SigV4 embeds it in the signing-key
derivation and credential scope (`sigv4_signer.dart`), and for AWS proper
(blank endpoint) it determines the request host
`s3.{region}.amazonaws.com` (`s3_api_client.dart`).

## Decisions (settled with user)

1. **Scope:** Simplify the whole form, not just Region. Visible fields
   become Endpoint URL, Bucket, Access Key ID, Secret Access Key. Region,
   Key Prefix, and Path-style move into a collapsed Advanced section.
2. **Discovery:** Server-assisted region correction. When a request fails
   with a region hint, re-sign with the hinted region, replay once, and
   persist the correction.
3. **Form shape:** Minimal form plus Advanced expander. No provider preset
   dropdown; provider detection happens silently from the endpoint
   hostname.

## 1. Form structure (`s3_config_page.dart`)

Visible, in order: HTTP warning card (existing, conditional), Endpoint URL,
Bucket, Access Key ID, Secret Access Key, Advanced expander, Test
Connection / Save buttons, Remove link (existing, conditional). All
existing validators, the busy state, snackbars, and save/remove flows are
unchanged.

The Advanced section is an `ExpansionTile`, collapsed by default,
containing in order: Region, Key Prefix, Path-style switch.

Region field behavior:

- New config: field empty; helper text shows the live auto-derived value,
  e.g. "Auto-detected: us-west-004", recomputed as the endpoint changes.
- Typing a value overrides auto-detection (manual wins). Same "touched"
  pattern as the existing path-style switch.
- Existing config: stored region is loaded into the field as-is (it may
  have been server-corrected; show it honestly).
- `_buildConfig()`: region = trimmed field text if non-empty, else
  `deriveRegion(endpoint)`.

Key Prefix and Path-style keep their current defaults and auto-derivation
(`submersion-sync/`; path-style auto-on for custom endpoints), merely
relocated into Advanced.

## 2. Static derivation (`s3_region.dart`, new file)

Pure function, no I/O: `String deriveRegion(String endpoint)`.

| Endpoint hostname pattern | Derived region |
|---|---|
| blank (AWS proper) | `us-east-1` |
| `s3.{r}.amazonaws.com` / `s3.dualstack.{r}.amazonaws.com` | `{r}` |
| `{account}.r2.cloudflarestorage.com` | `auto` |
| `s3.{r}.backblazeb2.com` | `{r}` |
| `{r}.digitaloceanspaces.com` | `{r}` |
| `s3.{r}.wasabisys.com` | `{r}` |
| `s3.{r}.scw.cloud` | `{r}` |
| anything else (MinIO, Garage, Ceph, unknown) | `us-east-1` |

Matching is on the parsed URI host, case-insensitive; ports are ignored.
Unparseable endpoints fall through to `us-east-1`.

## 3. Server-assisted correction (`s3_api_client.dart`)

Hint sources, checked on any non-2xx response:

- `x-amz-bucket-region` response header (AWS sends it on 301 and most 403s).
- `<Region>` element in an XML error body whose `<Code>` is
  `AuthorizationHeaderMalformed` (AWS, R2, and B2 all emit this shape).

Behavior:

- The client keeps an effective region, initialized from
  `S3Config.region`. `_target()` and `_send()` read the effective region,
  so an AWS correction also rebuilds the host.
- On a hinted failure where hint != effective region: adopt the hint,
  replay the request once. If the replay fails, throw via the normal
  `_throwFor` path — no loops. The adopted region persists for the
  client's lifetime so subsequent requests sign correctly first try.
- New optional constructor parameter
  `void Function(String region)? onRegionCorrected`, invoked after a
  correction leads to a successful replay.

Callback wiring in `s3_storage_provider.dart`:

- Runtime sync client: persist `config.copyWith(region: corrected)` via
  the credentials store so the fix sticks across launches.
- `testConnection`: surface the correction to the form, which updates the
  Advanced Region field and shows a "Region detected: {region}" snackbar.

A manually-entered wrong region is also corrected — correction only fires
after the server has rejected the request, so honoring the hint strictly
beats failing.

## 4. Error handling polish

A response whose error code is `AuthorizationHeaderMalformed` (typically
HTTP 400) currently falls through to the generic "S3 {operation} failed"
message, and a 403 variant reports "Access denied. Check the access key,
secret key, and bucket permissions." — misdirection either way. Matched by
error code regardless of status, it gets a region-specific message instead.
English copy (client-layer exception, hardcoded English like all other
`CloudStorageException` messages): "S3 rejected the request's signature
region. Open Advanced and set Region to the value your provider expects."

## 5. Unchanged / out of scope

- `S3Config` shape, JSON format, normalization, and the `us-east-1`
  fallback: untouched. Saved configs load with zero migration.
- SigV4 signing, endpoint validation, prefix normalization: untouched.
- No provider preset dropdown, no region dropdown, no endpoint
  autocomplete.

## 6. l10n

New strings: Advanced section title, region auto-detected helper (with
`{region}` placeholder), region detected snackbar (with `{region}`
placeholder). The malformed-auth error message lives in the client layer,
which uses hardcoded English exceptions, so it is not localized. All new
strings translated into the 10 non-English locales and codegen regenerated
(project rule: no English fallbacks).

## 7. Testing (TDD)

- `s3_region_test.dart`: one case per pattern row above, plus port,
  mixed-case host, and unparseable endpoint cases.
- `s3_api_client` tests: correction replay on 301+header and 400+XML body;
  AWS host rebuilt after correction; single-replay guard (second failure
  throws); `onRegionCorrected` fired on success, not on failed replay;
  no correction when hint equals current region.
- Widget tests: Advanced collapsed by default; four visible fields; region
  helper live-updates with endpoint; manual region overrides derivation;
  existing-config load populates Advanced; test-connection correction
  updates the field and shows the snackbar.
- Existing `s3_config_page` tests updated for the new layout (fields now
  inside the expander must be revealed before interaction).
