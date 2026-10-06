# Media Linking and Storage Program Design

Date: 2026-07-12
Status: Approved pending review
Scope: Program-level design (umbrella spec). Each phase gets its own
detailed spec and implementation plan before any code is written.

## 1. Background: the system as it exists today

Submersion's media system has two independent layers that are sound in
architecture but confusing in presentation.

### Layer 1: Links (where a photo comes from)

Every attached photo or video is one row in the `media` table. The
`sourceType` column discriminates five mechanisms; a link stores a
pointer, not bytes.

| Source type | UI name | Pointer | Cross-device today |
| --- | --- | --- | --- |
| `platformGallery` | Photo library (Apple/Google Photos) | `platformAssetId` | Partial: gallery search fallback by filename/timestamp |
| `localFile` | Local files (hidden behind diagnostics toggle) | path or security-scoped bookmark | No: bookmarks are device-local |
| `networkUrl` | URL | `url` | Yes over HTTP; per-host credentials are per-device |
| `manifestEntry` | Manifest subscriptions (Atom/JSON/CSV) | `url` + `subscriptionId`/`entryKey` | Rows yes; subscriptions do not sync, so other devices never poll |
| `serviceConnector` | Lightroom | `connectorAccountId` + `remoteAssetId` | Via Media Storage fallback; sign-in per device |

Resolution goes through `MediaSourceResolverRegistry` (one resolver per
source type) into `MediaItemView`.

### Layer 2: Media Storage (where a copy of the bytes lives)

The content-addressed object store (PR #550, phases 1-4): S3, Dropbox,
Google Drive, iCloud backends behind `MediaObjectStore`. It is not a
sixth link source. Rows keep their native `sourceType`; the store is a
fallback engaged only when the native pointer cannot resolve on this
device (`MediaStoreResolver`, deliberately not registered in the source
registry). Upload eligibility: `{platformGallery, localFile,
serviceConnector}`. URLs and manifest entries are excluded (already
network-reachable); signatures are inline BLOBs.

### Problems this program addresses

1. Provider coupling: Dropbox/Google Drive/iCloud media storage reuses
   the data-sync provider's auth session, so media storage cannot use a
   different provider than sync (S3 is already independent).
2. Per-device setup does not propagate: manifest subscriptions,
   Lightroom accounts, and network-host credentials are per-device.
   The `MediaSubscriptions` doc comment claims synced; the serializer
   does not include it.
3. Media Storage connection is a manual settings action on every
   device, even though a synced secret-free store descriptor exists
   that could drive a prompt.
4. Surface fragmentation: five settings pages (Media Sources, Network
   Sources, Lightroom, Media Storage, Cloud Sync) plus a Files tab
   hidden behind a diagnostics toggle. Nothing explains the
   link-versus-storage distinction.
5. Dead behavior: `NetworkFetchPipeline.ingest` accepts and ignores
   `autoMatch`, so URL photos never auto-attach to dives.
6. No handling for files on network volumes: a `localFile` row on an
   unmounted SMB/NFS share is indistinguishable from a deleted file.

## 2. Goals

1. Media Storage provider is independently choosable from the sync
   provider, including two different S3 endpoints.
2. Setup performed on one device propagates to others as secret-free
   descriptors, with the other device prompted to sign in or confirm.
3. One coherent settings area and a guided setup flow make the whole
   system understandable and configurable by a non-expert user.
4. Files on OS-mounted network shares degrade gracefully when the
   volume is offline, and the model leaves a clean seam for a future
   in-app SMB/NFS client.

## 3. Non-goals

- No in-app SMB/NFS client in this program (seam only).
- No removal of any existing link source; all five remain first-class.
- No change to the media-store object layout (`smv1/...`) or the
  content-addressed pipeline semantics.
- No syncing of secrets, ever. Tokens and keys stay in each device's
  keychain.

## 4. Program structure

Four phases, each with its own spec, plan, and PR cycle, merging to
main independently:

| Phase | Delivers | Depends on |
| --- | --- | --- |
| 1. Connected Accounts | Account layer; media/sync decoupling | none |
| 2. Cross-device descriptors | Descriptor sync + device-B prompts | 1 |
| 3. Photos & Media hub + wizard | Unified settings, guided setup, behavior fixes | 1, 2 |
| 4. Network files v1 | Offline-volume resilience + SMB seam | 1 (model only) |

## 5. Phase 1: Connected Accounts

### Concept

An account is a linked credentialed endpoint: a Dropbox login, a
Google login, an S3 endpoint+bucket configuration, an Adobe/Lightroom
login, or the OS iCloud identity (a credential-less pseudo-account,
Apple platforms only). Accounts are instances, not singletons: two
different S3 endpoints are two accounts. Features (Data Sync, Media
Storage, media source connectors) select an account by id, which is
what makes independent provider choice fall out naturally.

### Data model

New synced, secret-free table `connected_accounts`:

- `id` TEXT primary key (UUID)
- `kind` TEXT: `dropbox` | `googledrive` | `icloud` | `s3` |
  `adobeLightroom` (future: `immich`, `smb`, ...)
- `label` TEXT: user-visible name
- `account_identifier` TEXT: email, catalog id, or endpoint+bucket
  hint; used for display and duplicate detection
- `created_at`, `updated_at`, `hlc`

Secrets never enter the database. Each device stores credentials in
its keychain under a per-account key (`account_<id>_credentials`).
"Signed in on this device" is derived (keychain probe + validity
check), not stored in the synced table.

The existing per-device `connector_accounts` table (Lightroom) migrates
into `connected_accounts` and is retired. Lightroom already proved this
shape (account row + keychain `credentialsRef`); Phase 1 promotes the
pattern to an app-level layer.

### Auth registry

`AccountProviderRegistry` maps `kind` to an adapter exposing
`connect()`, `disconnect()`, `status()`, plus capability interfaces
consumed by features:

- `SyncCapable`: yields a sync `StorageProvider`
- `MediaStoreCapable`: yields a `MediaObjectStore`
- `MediaSourceCapable`: yields a media source connector (Lightroom
  now; Immich/SMB later)

Existing auth managers (`DropboxAuthManager`, Google Drive's
`AuthClient`, `AdobeImsAuthManager`, the sync and media-store S3
credential stores) refactor from provider singletons to per-account
instances behind the registry.

### Feature rewiring

- Data Sync stores the selected account id instead of a bare
  `CloudProviderType`. Per-provider sync cursors and the
  backend-switch epoch safety (#327) become per-account keyed, with
  migration of existing keys.
- `MediaStoreAttachState` gains `accountId`. `buildMediaObjectStore`
  resolves credentials through the registry rather than reaching into
  sync's auth stores. This single change severs the media/sync
  provider coupling.
- Lightroom providers consume a `MediaSourceCapable` account.

### Migration

On upgrade, existing configured state auto-creates account rows: the
active sync provider becomes one account; a configured media-store S3
config becomes one account; each Lightroom connector account becomes
one account. Existing keychain entries are re-keyed to the per-account
scheme. No re-authentication is required.

Schema: next free version on the ladder (v107 at time of writing),
idempotent DDL plus beforeOpen re-assert, per repo convention.

## 6. Phase 2: Cross-device descriptors and prompts

### What syncs

- `connected_accounts` (from Phase 1) and `media_stores` (already
  synced) form the base.
- `media_subscriptions` is added to the sync serializer, making the
  existing doc comment true. Per-device poll state
  (`media_subscription_state`) stays local.
- Lightroom scan configuration (album filter, auto-poll toggle) moves
  from SharedPreferences to synced storage keyed by account id, so a
  second device behaves identically after sign-in. The existing
  `remoteAssetId` dedup already makes multi-device scanning
  idempotent.

### Device-B experience

One "finish setting up this device" mechanism instead of scattered
surprises. On startup and on hub visit, compute pending setup items:

- The library has a media store, but this device is not attached.
- Account X exists in the roster, but this device has no credentials
  for it (and a feature or media row references it).

Surface as a dismissible banner in the Photos & Media hub plus a
one-time prompt. Dismissals are recorded per device; the system never
nags. Manifest subscriptions need no prompt: they start polling
automatically; credentialed hosts appear as needs-sign-in items.

## 7. Phase 3: Photos & Media hub and guided setup

### Settings restructure

- Top-level Connected Accounts page, used by both Sync and Media.
- One Photos & Media hub replaces Media Sources, Network Sources,
  Lightroom, and Media Storage as entry points, with two labeled
  groups:
  - "Where photos come from": Photo library (permission status),
    Lightroom (status + scan settings), Local files (the Files tab
    promoted to a real page, out of the diagnostics toggle), Network
    sources (URLs + manifest feeds, kept as an Advanced sub-page).
  - "Where copies are kept": Media Storage status card (provider,
    account, backfill), Transfers, upload policies.
- Cloud Sync settings selects from Connected Accounts.

### Guided setup

A short wizard (PageView pattern proven in the #523 onboarding):
pick sources, sign in to accounts as needed, choose storage, done.
Reachable from the hub's empty state, from device-B prompts, and
re-runnable at any time.

### Behavior fixes folded in

- Wire URL/manifest ingest's `autoMatch` so those photos auto-attach
  by timestamp via the same `DivePhotoMatcher` used by gallery, files,
  and Lightroom: one consistent matching story across all sources.
- Promote the Files tab out of the diagnostics toggle.
- All new strings localized in all 11 locales.

## 8. Phase 4: Network files v1

`localFile` rows gain volume awareness. On desktop, distinguish "file
deleted" from "volume not mounted" by checking mount-point/path-prefix
existence. An unmounted volume produces an "offline volume"
placeholder, is never marked orphaned, and recovers automatically when
the share remounts. Verify/cleanup passes skip offline volumes. Mobile
document-provider files already behave this way via bookmarks.

The future in-app SMB/NFS client is reserved as a `MediaSourceCapable`
account kind (`smb`): a connector like Lightroom, not a new mechanism.
Design note only; not built in this program.

## 9. Error handling

One taxonomy across features consuming accounts: failures map to
`needsSignIn | unavailable | transient | fatal`. `needsSignIn` flows
into the device-B prompt system rather than dead-ending. The
media-store worker's existing suspend-on-auth-loss behavior
generalizes: any feature holding an account reference suspends its
background work and surfaces a needs-sign-in item when credentials
disappear or expire.

## 10. Testing strategy

- Per-adapter contract tests reusing existing fakes (FakeS3Server,
  FakeDropboxServer, FakeDriveServer) against the
  `AccountProviderRegistry` capability interfaces.
- Migration tests for each schema bump (idempotent DDL + beforeOpen
  re-assert; the newest migration test holds the exact
  currentSchemaVersion tripwire per ladder convention).
- Sync round-trip tests for each newly synced table (serializer
  registration guard test catches missed sites).
- Wizard and hub widget tests; device-B prompt logic unit tests.
- Cross-device scenarios via fake servers (attach on A, resolve on B).

## 11. Open questions (to settle in phase specs)

1. iCloud pseudo-account representation: one implicit account row
   auto-created on Apple platforms, or no row with `kind`-level
   selection. To settle in the Phase 1 spec.
2. Whether Lightroom scan config becomes columns on
   `connected_accounts` or a small synced key-value table. To settle
   in the Phase 2 spec.
3. Exact wizard step list and which steps are skippable. To settle in
   the Phase 3 spec.
4. Windows/Linux mount-detection specifics (UNC paths, autofs). To
   settle in the Phase 4 spec.
