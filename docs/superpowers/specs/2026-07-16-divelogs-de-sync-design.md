# divelogs.de Sync — Design

Date: 2026-07-16
Status: Approved design, pending implementation plan
Roadmap: FEATURE_ROADMAP.md section 13.2 ("Upload to divelogs.de", planned v2.0)
Contact: Rainer (divelogs.de developer, mail@divelogs.de) — offered API support and testing

## Summary

User-triggered, two-way, create-only sync between Submersion and divelogs.de,
modeled on the sync that divelogs.de already has with Subsurface and Diving Log.
A user connects their divelogs.de account once; from then on a sync action
compares the two logbooks by date/time and lets the user pull dives missing
locally and push dives missing remotely. Scope covers everything the divelogs
API exposes — dives, gear, certifications, and pictures — delivered in four
phases, each independently shippable.

## The divelogs.de API

OpenAPI spec: https://divelogs.de/api/docs/divelogs-openapi3.json
(Swagger UI at https://www.divelogs.de/api/docs/). Base URL: `https://divelogs.de/api`.

- Auth: `POST /login` (multipart form, `user` + `pass`) returns a JWT bearer
  token. No OAuth, no refresh grant. All other endpoints take
  `Authorization: Bearer <jwt>`.
- Dives are plain JSON (not UDDF). Mandatory fields: `date`, `time`,
  `duration` (seconds), `maxdepth`. Optional: `meandepth`, `sampledata`
  (array of depths, or `{d, t}` objects for depth+temperature), `samplerate`,
  `tanks[]` (`o2`, `he`, `start_pressure`, `end_pressure`, `vol`, `wp`,
  `dbltank`, `tankname`), `buddy` (string), `divesite`/`location` (strings),
  `lat`/`lng`, `notes`, `weather`, `visibility`, `weights`, `airtemp`,
  `surfacetemp`, `depthtemp`, `dc_model`, `gearitems` (array of remote gear
  IDs), `boat`, `surface_interval`.
- Endpoints: `GET /divelist` (short list), `GET /dives` (all, full detail),
  `GET /dives/{dive_id_list}` (batched detail), `POST /dives` (bulk create),
  `POST /dive`, `GET/PUT/DELETE /dive/{id}`, `GET/POST/PUT/DELETE` for
  `/gear`, `/certifications`, `GET /geartypes`,
  `GET/POST /pictures/{dive_id}`, `DELETE /pictures/{picture_id}`.
- No pagination or rate limits documented. Dedup convention across existing
  integrations: match dives by date+time.

The divelogs dive model is lossier than Submersion's: one profile channel
(depth + optional temperature), buddy and site are bare strings, no deco/CCR
data, no multi-computer sources. Push is therefore a projection; pull is an
enrichment problem (strings matched to real Site/Buddy entities by the
existing import pipeline).

## Decisions

| Decision | Choice |
|----------|--------|
| Scope | Two-way, user-triggered sync (Rainer's model) |
| Sync semantics | Stateless, create-only. Diff by date/time each sync; never update or delete on either side. Idempotent by construction. |
| Entities | Everything: dives, gear, certifications, pictures — phased |
| Sync UX | Compare first, then a review screen with per-item toggles before commit |
| Diver scope | Account is bound to one Submersion diver at connect time (default: active diver); multiple divelogs accounts may coexist |
| Collaboration | Eric implements; Rainer advises (API behavior, test account, fixtures) |
| Architecture | Approach A: connected-account adapter + dedicated sync feature module; pull rides the universal import pipeline |

## Phasing

| Phase | Content | Ships alone? |
|-------|---------|--------------|
| 1 | `AccountKind.divelogs`, adapter, API client, connect flow, **pull dives** via the import wizard | Yes — covers the migration use case |
| 2 | **Push dives** + unified compare/review sync page | Yes |
| 3 | Gear + certifications, both directions | Yes |
| 4 | Pictures, both directions | Yes — independently droppable |

Each phase is a separate PR.

## Architecture

### Account and authentication (Phase 1)

- `AccountKind.divelogs` added to `lib/core/services/accounts/account_kind.dart`
  (`cloudProviderType` → null; connector kind, like Adobe Lightroom).
- `DivelogsAccountAdapter` in
  `lib/core/services/accounts/adapters/divelogs_account_adapter.dart`,
  implementing `AccountProviderAdapter` plus a new capability interface
  `LogbookSyncCapable` (named generically; divelogs is its first
  implementation). Registered in `accountProviderRegistryProvider`
  (`lib/core/providers/account_providers.dart`).
- Credentials: keychain blob via `AccountCredentialsStore`
  (`account_<id>_credentials`) holding
  `{username, password, bearerToken, tokenObtainedAt}`. The password must be
  stored because JWTs expire and there is no refresh grant; the client
  re-logins transparently on 401 with single-flight de-duplication (pattern:
  `DropboxAuthManager._refreshInFlight`). Credentials are device-local; other
  devices show `needsSignIn` until the user re-enters the password there.
- Connect flow: dialog (pattern: `dropbox_connect_dialog.dart`) with
  username, password, and a diver picker defaulting to the active diver.
  Validates via `/login` + `GET /user`. Creates a `ConnectedAccount` with
  `accountIdentifier` = divelogs username.
- Diver binding: new nullable `diverId` column on the `connected_accounts`
  table (used only by connector kinds). The table is synced and HLC-stamped,
  and diver IDs are library-scoped, so the binding travels with the library.
  Schema migration takes the next free version — v113 at time of writing;
  re-verify the ladder when implementation starts.
- Connected Accounts page: add the `AccountKind.divelogs` icon case in
  `_AccountTile` and route the tile's tap to the sync page (Phase 2) or the
  import flow (Phase 1).

### Sync engine

New feature module `lib/features/divelogs_sync/` (`data/`, `domain/`,
`presentation/`):

- `DivelogsApiClient` (`data/api/`) — thin typed wrapper over the REST
  endpoints. No business logic. Owns auth header injection and 401 re-login.
- `DivelogsSyncPlanner` (`domain/services/`) — builds a `SyncPlan`:
  1. Fetch `GET /divelist` (cheap match keys only).
  2. Load local dive summaries for the bound diver
     (`DiveRepositoryImpl.getDiveSummaries`).
  3. Match both directions with the existing `MatchScorer`
     (`lib/core/matching/match_scorer.dart`) configured like `DiveMatcher`
     (#494): time-gated (zero band ±15 min), depth and duration refine the
     score. Remote-only → pull candidates; local-only → push candidates;
     matched pairs → skipped.
- Compare uses only the short divelist; full dive detail is fetched only for
  dives the user commits to pulling (`GET /dives/{id_list}`, batched). This
  keeps compare cost independent of logbook size (read-amplification lesson
  from #358).

### Pull path (Phase 1)

- `DivelogsImportMapper` (`data/mappers/`) converts divelogs JSON dives into
  the existing `ImportPayload` structure, then the standard pipeline takes
  over: `ImportDuplicateChecker` → review step → commit, identical to a file
  import. Entry point: a "From divelogs.de" source in the unified import
  wizard (an `ImportSourceAdapter` in
  `lib/features/import_wizard/data/adapters/`).
- Field mapping:
  - `date` + `time` → `entryTime`; `duration` → runtime; `maxdepth`,
    `meandepth` → depths. API units assumed metric (open question 1).
  - `sampledata` + `samplerate` → `DiveProfilePoint` list
    (timestamp = index × samplerate; `{d, t}` objects carry temperature).
  - `tanks[]` → `DiveTank` (`o2`/`he` → `GasMix`, pressures, `vol`, `wp`);
    `dbltank` semantics: open question 4.
  - `divesite`/`location` + `lat`/`lng` → `ImportEntityType.diveSites`
    entity; existing site matcher (name + 100 m haversine) links or creates.
  - `buddy` string → buddy entity candidate (name-only, as other importers).
  - `weather`, `visibility`, `notes`, temps, `weights`, `dc_model` →
    corresponding dive/condition fields.
  - Provenance: `importSource = 'divelogs.de'`, `importId = <remote dive id>`.
    Pass 0 of `ImportDuplicateChecker` (exact source-key match) then makes
    re-pulls instant no-ops, and the recorded remote ID leaves the door open
    for future edit propagation without re-matching.

### Push path (Phase 2)

- `DivelogsExportMapper` projects a domain `Dive` to divelogs JSON. Lossy by
  design: primary computer's profile channel only (depth + temperature),
  tanks, site name + GPS, buddy names joined to one string, notes, temps,
  weights, `dc_model` from the dive's computer.
- Commit via `POST /dives` bulk, chunked (~50 dives per request; open
  question 5), small courtesy delay between chunks.
- Nothing is written back onto the local dive after a push (stateless model);
  the next compare matches it by date/time.

### Sync page (Phase 2)

`presentation/pages/divelogs_sync_page.dart`: shows account status, a
Compare/Sync action, then the plan as two sections — "Pull from divelogs.de"
and "Push to divelogs.de" — all items checked by default with per-dive
toggles, one commit button with progress. Pull commits reuse the import
wizard's progress/summary machinery. All displayed values respect the active
diver's unit settings.

### Gear and certifications (Phase 3)

- Gear: `GET /gear` ↔ `gear` table. Match by normalized name (+ gear type
  via `GET /geartypes` where mappable). Create-only both ways. On pull, the
  `gearitems` ID array on remote dives resolves to dive-gear links. On push,
  gear is created remotely before dives that reference it, within the same
  commit (the API returns created IDs).
- Certifications: `GET/POST /certifications` ↔ Submersion certifications.
  Match by (agency, level name, date). Agency/level strings map through
  `CertificationLevelCatalog.levelsFor(agency, ensure:)` where recognized;
  otherwise import as free-text levels.

### Pictures (Phase 4)

Per-dive, only for dives already matched. Pull: download into the dive's
media, dedup by content hash. Push: upload originals for user-selected dives.
Touches the media store; last and independently droppable.

## Error handling

- Auth: 401 mid-sync → one silent re-login; if that fails, abort with
  `AccountStatus.needsSignIn` on the tile. No rollback needed — every created
  entity is independent.
- Partial failure: chunked pushes stop at the failed chunk and report
  "pushed N of M". Re-running sync resumes naturally: already-pushed dives
  now match and drop out of the plan. Re-pulls are no-ops via Pass 0
  source-key dedup.
- Network/server errors: surfaced through the import wizard's error
  presentation; no automatic retries beyond the single auth retry.
- Malformed remote data: mapper is defensive; a dive that fails mapping is
  skipped and counted in the summary, never aborts the batch.
- Rate limiting: none documented; treat HTTP 429/5xx as stop-and-report.

## Testing

- Unit: mappers both directions (fixture round-trip asserting the lossy
  projection is stable); `DivelogsSyncPlanner` diff logic (match/no-match,
  same-time-different-depth, ±15 min boundary); API client over a mocked
  HTTP layer (login, 401 re-login single-flight, chunking).
- Fixtures: representative JSON from Rainer (with `{d,t}` sampledata,
  multi-tank, umlaut-heavy site names) under `test/fixtures/divelogs/`.
- Widget: connect dialog validation; sync review page selection behavior.
- Integration: end-to-end pull through `ImportDuplicateChecker` with an
  in-memory DB, asserting site linking and second-pull idempotency.

## Open questions for Rainer (refine, don't block, Phase 1)

1. Units — metric everywhere in the JSON (m, bar, degrees C, kg)? Any locale
   variance?
2. JWT lifetime, and is `POST /login` rate-limited?
3. `GET /divelist` response shape (not in the spec) — does it include
   duration and maxdepth?
4. `dbltank` semantics — is `vol` the single-cylinder volume or the doubled
   total?
5. Reasonable bulk-push chunk size, and any request-size limits?
6. Picture upload format/size constraints (Phase 4).
7. A test account (or sandbox) Submersion CI/dev can use.

## Out of scope

- Updating or deleting dives on either side (create-only model).
- Automatic/background sync — always user-triggered.
- Round-tripping through UDDF (the API speaks its own JSON; direct mappers
  are simpler and lossless relative to what the API can carry).
- Multi-account merge semantics beyond the per-diver binding.
