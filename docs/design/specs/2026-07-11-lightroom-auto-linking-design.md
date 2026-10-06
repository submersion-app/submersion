# Lightroom Cloud Auto-Linking — Design

Date: 2026-07-11
Status: Approved pending user review
Prerequisite: PR #550 (Media Store phase 1, `worktree-s3-media-store`) merged to main. All integration points below bind to code introduced by that PR; the implementation worktree must branch from a main that contains it. If final-merge names drift from this spec, reconcile at plan time.

## 1. Overview

Connect a diver's Adobe Lightroom cloud catalog to Submersion and automatically link photos and videos to dives by capture time. Linked assets display on all synced devices via the Media Store, carry depth/temperature enrichment, and retain provenance to the Lightroom original.

### Decisions (settled during brainstorming)

| Question | Decision |
| --- | --- |
| Storage model | Reference + cached rendition. The original stays in Adobe's cloud; Submersion stores the 2048px rendition in the user's Media Store. |
| Trigger | Manual scan (per dive / trip / all) plus periodic auto-poll with a per-device cursor. |
| Match UX | Auto-attach confident matches; ambiguous matches go to a review queue. |
| Scan scope | Whole catalog by capture date, with an optional album filter in connector settings. |
| API credentials | BYO Adobe client ID (user creates their own Adobe Developer Console integration). If Adobe later grants Submersion a partner key, it becomes the embedded default and BYO remains a fallback. |
| Video depth | Match + thumbnail + duration badge + "Open in Lightroom". No playback. |

### Non-goals (v1)

- Downloading originals or RAW files.
- Video playback.
- Writing anything back to Lightroom (keywords, albums, ratings).
- An embedded Submersion-owned Adobe client ID.
- Coordinated multi-device polling (any device may connect; dedup makes concurrent scans safe, but each polls independently).

### External constraint

The Lightroom cloud API is officially available only to "entitled partner applications". Development-tier client IDs work for the developer's own Adobe account. BYO client ID makes the feature usable today for the maintainer and power users without waiting on Adobe partner approval. Connect-flow errors from Adobe are surfaced verbatim (see §7).

## 2. Architecture summary

Lightroom is an **acquisition source**, not a permanent live dependency. The connector matches assets to dives, creates `media` rows, and feeds rendition bytes into the Media Store pipeline once. After that, the photo behaves like any other store-backed media item on every device; the Lightroom reference remains only for provenance and "Open in Lightroom".

The design deliberately adds **no new pipelines**. It fills two sockets that already exist:

1. `MediaSourceResolverRegistry` (`lib/features/media/data/services/media_source_resolver_registry.dart`) has no resolver registered for `MediaSourceType.serviceConnector` — the new connector resolver takes that slot.
2. `MediaUploadPipeline` (#550, `lib/features/media_store/data/media_upload_pipeline.dart`) materializes upload bytes via `_registry.resolverFor(item.sourceType)` and gates on an `_eligibleSources` set (`platformGallery`, `localFile`). Adding `serviceConnector` to that set makes the existing queue worker download the rendition (through the resolver), hash it, dedup via `head()`, upload it, and stamp `content_hash`/`remote_uploaded_at` — retry/backoff included.

One resolver is therefore the single source of Lightroom bytes for both display and store upload.

## 3. Components

New code lives under `lib/features/media/` (connector + resolver) and `lib/core/services/` (auth), following the Dropbox-provider precedent.

| Component | Role | Modeled on |
| --- | --- | --- |
| `oauth_pkce.dart` (shared) | `generateCodeVerifier()` / `codeChallengeS256()` promoted from `lib/core/services/cloud_storage/dropbox/dropbox_pkce.dart` to a shared core location; Dropbox imports the shared copy (move, not fork). | existing file |
| `AdobeImsAuthManager` | OAuth2 + PKCE against Adobe IMS. Copy-paste auth-code flow (no per-platform redirect URIs). In-memory access-token cache, single-flight refresh, `disconnect()`. Refresh token + client ID in secure storage behind `ConnectorAccounts.credentialsRef`. | `dropbox_auth_manager.dart` |
| `LightroomApiClient` | REST client: get catalog, list albums, list assets (paginated; `captured_after`; `subtype=image;video`; album-scoped listing), fetch renditions (`thumbnail2x`, `2048`), build "Open in Lightroom" web URLs. Strips the `while (1) {}` abuse-guard prefix from every JSON response before parsing. | `dropbox_api_client.dart` |
| `LightroomScanService` | Orchestrates scan: build dive time windows, query candidate assets, dedup, match, create rows / suggestions, enrich, enqueue store transfer, advance cursor. | `TripMediaScanner` |
| `ConnectorMediaResolver` | Registered under `MediaSourceType.serviceConnector`; dispatches by the account's `connectorType` (v1: only `lightroom`). `resolve()` downloads the 2048 rendition to a cache file and returns `FileData`; `resolveThumbnail()` returns `thumbnail2x` bytes; `canResolveOnThisDevice` is true only when the referenced `ConnectorAccounts` row exists and holds valid credentials. | `MediaSourceResolver` interface |
| `DivePhotoMatcher` extension | Existing matcher (`lib/features/media/domain/services/dive_photo_matcher.dart`) extended to report match confidence (see §6) instead of only a winning dive. | existing service |
| Settings UI | Lightroom connect page (client ID field, PKCE flow, account display, album filter picker, auto-poll toggle, disconnect) plus "Scan Lightroom" actions on dive and trip screens. | `dropbox_connect_dialog.dart`, `s3_config_page.dart` |

## 4. Data model

No main-database migration in the expected case. The schema-version ladder is congested (v103 = #550; v104 claimed by the weight planner; v105 expected for 3D flythrough), so staying off it is a design goal.

- **Connector account**: one `ConnectorAccounts` row (`database.dart`, not synced, per-device): `connectorType='lightroom'`, `displayName` = Adobe account name, `credentialsRef` → secure storage entry holding client ID + refresh token. `baseUrl` unused (fixed Adobe endpoints).
- **Media rows**: existing v72 columns — `sourceType=serviceConnector`, `connectorAccountId`, `remoteAssetId` (Lightroom asset ID), `takenAt`, `originalFilename`, `width`/`height`, `durationSeconds` (video), `latitude`/`longitude` when the asset carries GPS — plus #550's `content_hash`, `content_size_bytes`, `remote_uploaded_at`, `remote_thumb_uploaded_at` once the rendition reaches the store.
- **Per-device connector state** (poll cursor, last scan time, album filter selection, auto-poll enabled): SharedPreferences keyed by connector account ID, following #550's `media_store_attach_state.dart` precedent. Keeps per-device state out of the synced schema and makes "which device polls" a non-problem.
- **Ambiguous-match suggestions**: reuse `PendingPhotoSuggestions` (`database.dart`), storing the Lightroom asset ID in its asset-key column. If implementation finds the table cannot represent connector suggestions without schema help (e.g. it needs `connectorAccountId` or candidate-dive references), extend it with nullable columns in the next free schema version at that time; this is the only candidate migration.

Rendition bytes are cached and evicted by #550's `MediaCacheStore` pools; no bespoke Lightroom cache.

## 5. Data flow

### Connect

Settings → Media Sources → Lightroom → paste Adobe client ID → `AdobeImsAuthManager.beginAuthorization()` opens the IMS authorize URL in the browser → user signs in, copies the auth code back → `completeAuthorization(code)` exchanges it (PKCE) → refresh token stored → client fetches catalog ID and account name → `ConnectorAccounts` row created. Album filter and auto-poll are configurable afterward on the same page.

### Scan (manual or poll)

1. **Windows.** Build candidate capture-time windows from dives: `[entryTime − 30 min, exitTime + 60 min]` (the existing `DivePhotoMatcher` window). Manual scan scopes windows to the selected dive, trip, or all dives; poll scopes to the incremental cursor (below).
2. **Query.** List assets filtered to the album selection (if any) and to `subtype=image;video`, paginated. Parse `captureDate` with `parseExternalDateAsWallClockUtc` (`lib/core/util/wall_clock_utc.dart`) — Lightroom capture dates are EXIF wall-clock values, which lands exactly on the dive tables' wall-clock-as-UTC convention.
3. **Dedup.** Skip any asset whose Lightroom asset ID already appears as a `remoteAssetId` on a media row (synced via HLC, so this covers rows created by other devices) or on a live pending suggestion. This runs before row creation and makes re-scans and concurrent multi-device scans idempotent.
4. **Match.** Feed `(assetId, takenAt)` to the extended `DivePhotoMatcher` (§6). Confident → create linked media row, run `EnrichmentService` for depth/temp at capture time, enqueue a store transfer via the #550 enqueue provider. Ambiguous → create pending suggestion carrying the candidate dive(s). No match → ignore.
5. **Cursor.** The poll cursor only advances past assets actually processed, so a mid-scan failure resumes without gaps.

**Incremental poll strategy:** preferred parameter is the assets listing's updated-since/captured-after cursor so late uploads of old photos are caught. Exact parameter support must be verified against the live API during implementation; the specified fallback (correct, just less efficient) is: poll re-queries the capture windows of dives from the last N days plus all assets `captured_after` the previous poll time. The scan service takes the query strategy as an injected policy so the fallback swap touches one seam.

### Rendition → store

`MediaUploadPipeline` (existing #550 worker, `serviceConnector` added to `_eligibleSources`) picks the queued entry up: materializes bytes via `ConnectorMediaResolver.resolve()` (= 2048 rendition download), computes SHA-256, `head()`-dedups, uploads thumb-first, stamps the row. Failures retry with backoff and go terminal after 5 attempts, exactly like local media. A missing rendition (Adobe generates them lazily) is a retryable failure, not terminal.

If no Media Store is attached, the resolver still serves display bytes on the connected device from the local cache; when a store is attached later, #550's backfill sweep (`media_backfill_service.dart`) picks the rows up because they are enqueue-eligible.

### Display

Any device: `MediaItemView` → registry. Connected device resolves via `ConnectorMediaResolver` (cache-first). Other devices have no `serviceConnector` credentials, so #550's `MediaStoreResolver` fallback serves the store object — those devices never touch Adobe. Videos render thumbnail + duration badge; tap offers "Open in Lightroom" (web URL). Photos may also offer "Open in Lightroom" as a secondary action.

### Disconnect

Deletes the `ConnectorAccounts` row and secure-storage secrets. Media rows, store objects, and cache entries are untouched: photos keep displaying everywhere via the store (the #550 graceful-degradation principle). Reconnecting creates a fresh account row and cursor; scan dedup (step 3) makes that idempotent.

## 6. Matching rules

`DivePhotoMatcher` currently returns the winning dive for a timestamp within `[entry − 30 min, exit + 60 min]`, tie-broken by closeness to entry. It gains a confidence-bearing result:

- **Confident** — the capture time falls inside exactly one dive's extended window, or inside multiple extended windows but exactly one dive's *core* window (entry to exit). Auto-attach.
- **Ambiguous** — the capture time falls inside two or more dives' extended windows with no unique core-window hit (typical repetitive-dive boat day: surface-interval shots land in dive N's post-margin and dive N+1's pre-margin). Pending suggestion listing candidate dives ordered by closeness to entry; one-tap confirm or dismiss.
- **No match** — outside every window. Ignored.

The extension is shared: `TripMediaScanner` (device-gallery scanning) can adopt the same ambiguity queue later without new matcher work.

Enrichment (`EnrichmentService`) runs at attach time (auto or confirmed suggestion) and records `matchConfidence` and `timestampOffsetSeconds` in `MediaEnrichment` as it does today for picker imports.

## 7. Error handling

- **Token refresh failure / revoked consent**: connector enters a needs-reauth state (badge on the settings tile, scan actions surface it). Polling suspends. No data is deleted; display continues via cache/store.
- **BYO client misconfiguration** (bad client ID, missing Lightroom entitlement on the Adobe project): the connect flow shows Adobe's error verbatim plus a link to setup docs. Power-user feature; honest errors over translation.
- **Rate limits / transient network**: asset-listing calls use bounded retry inside the scan; rendition downloads inherit the transfer queue's backoff. Scan failures leave the cursor un-advanced past the failure point.
- **Missing/late renditions**: retryable transfer failure.
- **Store absent or suspended** (bucket wiped / `store.json` mismatch): connector behavior unchanged on the connected device; cross-device display resumes when the store does. No Lightroom-specific handling.
- **Catalog oddities** (asset without `captureDate`): skipped and counted; scan summary reports "N assets skipped (no capture time)".

## 8. Settings & UI surface

- **Settings → Media Sources → Lightroom**: connect flow, account name, album filter (multi-select of Lightroom albums, default all), auto-poll toggle + interval, last-scan status line, needs-reauth badge, disconnect.
- **Dive detail / trip overview**: "Scan Lightroom" action alongside existing photo actions (hidden when no connector account exists).
- **Suggestions queue**: the `PendingPhotoSuggestions` table exists but currently has no rendering surface anywhere in the app, so this feature builds one — a suggestions row in the dive detail media section with per-suggestion confirm/dismiss. (The table needs nullable `connectorAccountId`/`remoteAssetId` columns; that is the feature's one schema migration.)
- **Media items**: store badge behavior from #550 applies unchanged; Lightroom items additionally get "Open in Lightroom".
- All new strings localized in `app_en.arb` plus the 10 other locales; unit-bearing values respect diver unit settings (enrichment display already does).

## 9. Testing

- **Unit**: shared PKCE helpers (existing Dropbox tests move with the file); `AdobeImsAuthManager` token lifecycle with a fake HTTP layer; `LightroomApiClient` against canned JSON fixtures *including the `while (1) {}` prefix and pagination links*; `LightroomScanService` matching/dedup/cursor-advance/failure-resume with an in-memory API fake; `DivePhotoMatcher` confidence matrix (core hit, extended-margin hit, overlap, no match).
- **Integration**: scan → row + enrichment + queue enqueue against `InMemoryMediaObjectStore` (from #550's tests); pipeline processes a `serviceConnector` entry end-to-end (resolver fake returning fixture bytes) and stamps the row; two-device dedup (scan on A, HLC sync, scan on B creates nothing).
- **Widget**: connect dialog happy path + verbatim-error path; suggestions confirm/dismiss; `MediaItemView` renders a Lightroom item via resolver on the connected device and via store fallback with the registry entry absent (mirror `media_item_view_store_fallback_test.dart`). Observe the drift/fakeAsync trap: wrap post-pump database awaits in `tester.runAsync`.
- **Manual**: real Adobe account with a development-tier client ID — connect, scan a trip, verify auto-attach + suggestion + cross-device display through a real store. This is the only place the live API's poll-parameter question (§5) gets settled.

## 10. Risks

- **Adobe API access tightening**: BYO keys depend on Adobe continuing to let individual developers create Lightroom Services integrations for their own accounts. If that closes, the feature degrades to unusable for new connections but nothing else in the app is affected (acquisition-source architecture).
- **Rendition ≠ original**: a photo linked from Lightroom and later imported from disk as an original will not content-address-dedup (different bytes). Accepted; inherent to the reference model.
- **#550 drift**: if the merged PR renames the integration points cited here, reconcile at implementation-plan time; the architecture does not depend on the names.
