# divelogs.de Import: Design

Date: 2026-09-25
Status: Approved design, pending spec review
Supersedes: the two-way sync design in PR #603
(`docs/superpowers/specs/2026-07-16-divelogs-de-sync-design.md` on branch
`worktree-divelogs-sync`)

## Goal

Let a diver pull their divelogs.de logbook into Submersion through the existing
import wizard: dives (with profiles), dive sites, gear, certifications, the
links between dives and gear, and dive photos. Re-running the import is safe:
dives already imported are recognised and skipped, and nothing is duplicated.

## Scope

In scope:

- Sign in to divelogs.de, fetch the logbook, review, import.
- Dives, sites, equipment, certifications, dive-to-gear links, photos.
- Idempotent re-import.

Out of scope (dropped from PR #603):

- Pushing anything to divelogs.de (dives, gear, certifications, photos).
- The compare/sync page, `GET /divelist`, the sync planners and push services.
- `AccountKind.divelogs`, a Connected Accounts roster entry, and
  `LogbookSyncCapable`.
- The `connected_accounts.diver_id` column. This design needs no schema change.
- Certification scan images (their download URLs are undocumented).

## Background

PR #603 implemented a four-phase two-way sync in July and August 2026. By
September it was 1,334 commits behind main and conflicted in 29 files, and its
photo pull copied pictures into app storage, which the links-only media rule
(2026-09-02) now forbids. The owner chose to rebuild on a fresh branch as an
import-only feature in one PR. The self-contained layers of #603 (API client,
models, mappers) are ported; its integration with the wizard is rebuilt against
current main.

Main has since gained two cloud importers, Suunto and Garmin, that set the
pattern this design follows for sign-in and placement.

## User flow

Transfer page, Cloud section: a new "divelogs.de" card beside Suunto and
Garmin. It opens `/transfer/import-cloud/divelogs`, which hosts
`UnifiedImportWizard(adapter: DivelogsImportAdapter(...))`.

Wizard steps:

1. **Sign In** (new). Username and password. If a cached session still
   works, the step signs straight in and advances, like Suunto; going back
   to it shows "Signed in as <user>" with a Sign out button.
2. **Fetch** (new). Fetches the whole logbook in one go. Has an "Include
   photos" switch, on by default, shown on desktop only. Shows counts when done.
3. **Divers** (existing UniversalAdapter step, hidden for a single diver).
4. **Photos** (existing `PhotoFolderStep`, hidden when there are no photos).
   The user picks a writable folder or skips.
5. **Review, Import, Summary** (added by the wizard, unchanged).

## Architecture

### Approach

`DivelogsImportAdapter` subclasses `UniversalAdapter`. It replaces the
file-oriented acquisition steps (Select File, Confirm Source, Map Fields) with
Sign In and Fetch, and keeps Divers and Photos. Everything downstream is
reused: bundle building, duplicate checks for every entity type, the
multi-diver split, consolidation, and linking skipped duplicates to existing
rows.

Alternatives considered and rejected:

- A standalone `ImportSourceAdapter` like Suunto's: it would duplicate bundle
  building, entity dedupe, importer calls and photo linking, and drift.
- Converting the fetch result to UDDF and loading it as a file: a lossy round
  trip with spurious format detection.

The subclass overrides only `sourceType`, `displayName`, `acquisitionSteps`
and the new photo hook. A test pins the step list so a future UniversalAdapter
change that affects it fails loudly.

### Components

| Unit | Location | Responsibility |
| --- | --- | --- |
| `DivelogsApiClient` | `lib/core/services/divelogs/divelogs_api_client.dart` | `POST /login`; `GET /dives`, `/gear`, `/geartypes`, `/certifications`, `/pictures/{id}`; authorized picture download. One retry after a 401 via `DivelogsAuth`. Ported from #603 without post or divelist code. |
| `DivelogsAuth` | `lib/core/services/divelogs/divelogs_auth.dart` | Single-flight login. Holds the password in memory for the wizard's lifetime only, to renew an expired token. |
| `DivelogsSessionStore` | `lib/core/services/divelogs/divelogs_session_store.dart` | Keychain blob under key `divelogs_session`: username and JWT. Never the password. Modeled on `SuuntoSessionStore`. |
| `divelogs_models.dart` | `lib/core/services/divelogs/` | Tolerant JSON models: dive, gear item, certification, picture. Ported, minus the divelist entry. |
| `DivelogsDiveMapper` | `lib/features/universal_import/data/services/` | Dive JSON to payload dive map. Ported. Sets `sourceUuid = divelogs-<id>`. |
| `DivelogsReferenceMappers` | `lib/features/universal_import/data/services/` | Geartype to `EquipmentType` (German synonyms), organisation to agency, name to level. Moved from `divelogs_sync/data/mappers`. |
| `DivelogsImportService` | `lib/features/universal_import/data/services/` | Orchestrates the fetch into an `ImportPayload` plus warnings, and the per-dive picture listing. |
| `DivelogsImportAdapter` | `lib/features/import_wizard/data/adapters/divelogs_import_adapter.dart` | The subclass described above, and the photo-download hook. |
| `DivelogsSignInStep`, `DivelogsFetchStep` | `lib/features/import_wizard/presentation/widgets/` | Step widgets and their state providers. |

New enum value: `ImportSourceType.divelogs`.

### Changes to shared code

1. **`UniversalImportNotifier.setExternalPayload`.** Injects a payload built
   outside file parsing. It must leave the notifier in the same state
   `_parseAndCheckDuplicates` produces for a parsed file: set `sourcePayload`
   and `payload`, apply `_applySurfacingPressureRule`, run
   `_checkDuplicatesOrEmpty`, reset the diver mapping, and reset photo state.
   The shared normalization is factored so both paths call one function.
   It also records the pending remote photo count.
2. **Photos step visibility.** `universalAdapterNoPhotosProvider` and
   `universalAdapterPhotosReadyProvider` also consider pending remote photos,
   so the Photos step appears and requires a folder choice (or skip) exactly
   as it does for ZIP-bundled photos. The folder picker and
   `chooseBundledPhotoFolder` are reused unchanged.
3. **Photo hook in `UniversalAdapter.performImport`.** A protected method,
   `attachAdditionalPhotos`, runs after the existing bundled and resolved
   photo attach. It receives `photoDiveIds` (payload dive index to the dive
   that ended up in the database, including the existing dive behind a
   skipped or consolidated duplicate), `removedDiveIds`, `diveStartById`, the
   chosen folder and the cancel token. The default returns 0, so behaviour for
   every other source is unchanged. Its result is added to the attached-photo
   count in the summary.

### Data flow

1. Sign In: `POST /login` (multipart) returns a JWT. The session store saves
   username and token; `DivelogsAuth` keeps the password in memory.
2. Fetch: `GET /dives`, `/gear`, `/geartypes`, `/certifications`. If "Include
   photos" is on, `GET /pictures/{id}` for each dive (metadata only, no bytes).
   `DivelogsImportService` builds the `ImportPayload` (dives, sites, equipment,
   certifications, gear links via `equipmentRefs`) and warnings, and a map from
   payload dive index to picture descriptors, held by the adapter.
3. `setExternalPayload` normalizes state and runs duplicate checks.
4. Divers, Photos and Review run as for any universal import.
5. Import: the importer writes entities. Then `attachAdditionalPhotos` in the
   divelogs adapter, for each dive index that survived (not in
   `removedDiveIds`) and has pictures: download each picture to a temp file
   named after the picture's own filename, call
   `ImportPhotoLinker.linkBundled` into the chosen folder, delete the temp
   file. Photos are only downloaded for dives that were imported or matched,
   never for deselected ones.

### Idempotency

- Dives: `sourceUuid = divelogs-<id>`. The dash matters:
  `DiveRepository._looksLikeSourceUuid` only treats keys containing `-` as
  source UUIDs, so a bare or colon-joined id would never hit the duplicate
  checker's Pass 0 exact-match. Pass 0 matches default to skip.
- Sites, equipment and certifications: the universal duplicate checker's
  existing rules (name or proximity for sites, name and type for equipment,
  name and agency for certifications). Duplicates start deselected, and a
  skipped duplicate links the dive to the existing row.
- Photos: `exportBundledPhoto` reuses a file with the same name and identical
  bytes, and `ImportPhotoLinker` skips a path already linked to the dive.
  Re-import downloads the bytes again but creates no new files or links.

## Error handling

Sign-in and token expiry:

- A 401 from `/login` is shown inline on Sign In as bad credentials. Network
  errors are shown inline with retry.
- A 401 elsewhere triggers one re-login with the in-memory password. If there
  is no password (session restored from the keychain) or the retry fails, the
  session is cleared. During Fetch the user is sent back to Sign In with a
  "session expired" message. At import time the remaining photo downloads are
  counted as failed; the import itself continues.
- The password, the JWT and the `Authorization` header are never logged.

Fetch:

- `GET /dives` failing is fatal to the step: an error with Retry, surfaced
  through `ImportStepFailure` so the wizard does not advance.
- `/gear`, `/certifications` failing each become a coded `ImportWarning`
  (new codes `gearUnavailable`, `certificationsUnavailable`), shown on the
  Fetch step right away and as a notice in the import Summary; the import
  proceeds without that data. `/geartypes` failing is silent.
  Unknown gear types degrade to `EquipmentType.other` silently.
- Per-dive `/pictures` failures collapse into one warning with a count
  (code `photoListingsUnavailable`).
- A dive missing required fields (date, time) is dropped and counted in a
  warning. Unknown fields are ignored.

Photos at import time:

- Each failed download or write is counted; the summary reports how many
  photos could not be downloaded. Photo failures never fail the import.
- The download loop honours the wizard's cancel token. Temp files are deleted
  in a `finally`.

Platform:

- The folder picker is desktop-only today, so on mobile the "Include photos"
  switch is hidden and no picture listing runs.

## Testing

TDD, one test file per unit.

- Ported and trimmed from #603: API client (`MockClient`: 401 retry once,
  tolerant decoding), auth single-flight, models, dive mapper, reference
  mappers, import service degradation per endpoint.
- Session store round trip with fake secure storage; the password is never
  written.
- Pass 0: import a `divelogs-<id>` dive, check again, assert an exact source
  match.
- Notifier: `setExternalPayload` yields the same normalized state as the file
  path for an equivalent payload.
- Adapter: pinned step list; `attachAdditionalPhotos` default returns 0
  (existing UniversalAdapter tests unchanged); divelogs override with a fake
  downloader and the real linker on a temp directory downloads only for
  surviving dives, skips removed dives, dedupes on a second run, counts
  failures, and deletes temp files.
- Widgets: Sign In (bad credentials, cached session), Fetch (switch hidden on
  mobile, fatal and degraded errors), Transfer card, route.
- `test/architecture/` guards; new l10n keys in all 11 locales.

## Delivery

- One GitHub issue ("Import logbook from divelogs.de"); the PR body says
  `Closes #<issue>`.
- One PR from branch `feature/divelogs-import`. Once it is open, PR #603 is
  closed with a comment pointing to it.

## Open questions for divelogs.de (carried from #603)

The parsers stay tolerant wherever these are unanswered: units, JWT lifetime,
the `/pictures` response shape, `dbltank` semantics, and picture size limits.
