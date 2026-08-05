# Synced Media Upload Quality

Status: design approved (brainstorm 2026-07-24). Amends
`docs/superpowers/specs/2026-07-20-adjustable-media-upload-quality-design.md`
(Phase A, PR #666) and its Phase B video-transcoding follow-on
(`2026-07-21-video-transcoding-phase-b-design.md`, PRs #668/#669/#673/#674).

## 1. Problem

Phase A shipped upload quality as an **opt-in, per-device, per-media-type**
setting stored in `SharedPreferences` alongside the Media Store's transport
flags (`media_store_policies.dart`). That filing was wrong, and the codebase
already contains the evidence.

The *outcome* of the quality decision is synced: `remoteCompressedUploadedAt`,
`compressedLevel`, and `compressedSizeBytes` are columns on the synced `media`
table (schema v133). The *input* is not. Every device therefore writes to
shared library state using a private, unshared rule.

Combined with the locked **replace-not-supplement** decision (a non-`Original`
level uploads a rendition *instead of* the original, which then never leaves
the device) and **first-writer-wins** (one rendition per hash), this produces a
library whose archival fidelity is decided by an accident of timing:

1. The phone is set to `Small` to save cellular data. It attaches a photo,
   uploads a 1080px rendition, and stamps `compressedLevel: 'small'`. The
   original never leaves the phone.
2. The Mac, set to `Original`, never held that photo. Nothing re-uploads a
   full-fidelity copy.
3. The library permanently holds a 1080px copy of a photo the user believes is
   archived -- and *which device happened to hold the file* decided that.

The inverse is equally wrong: a user deliberately sets `Small` on their phone,
then sets up a new laptop. The laptop defaults to `Original` (Phase A's
`_readQuality` fallback), silently reverting library policy, because defaults
reset per install while a synced setting would be inherited.

## 2. The distinction

The five knobs on `MediaStorePolicies` are not the same kind of thing:

| Knob | Question it answers | Correct home |
| --- | --- | --- |
| `autoUpload` | May this device spend bandwidth unattended? | device-local |
| `photosOnCellular` | May this device spend metered bandwidth on photos? | device-local |
| `videosOnCellular` | May this device spend metered bandwidth on video? | device-local |
| `photoQuality` | What bytes should the library permanently contain? | **synced** |
| `videoQuality` | What bytes should the library permanently contain? | **synced** |

The first three are about this device's radio and battery. The last two are not
preferences about a device at all: they decide the archival fidelity of shared
library content, and merely happen to be entered on a device.

## 3. Goals

1. Photo and video upload quality become **library-wide synced settings**, so
   every device uploads at the same level and the library is internally
   consistent.
2. The three transport flags stay **device-local**, and `MediaStorePolicies`'
   class documentation becomes true again.
3. The boundary is enforced by types, not by a comment: two classes, two
   backends, one purpose each.
4. **No schema migration and no schema-version bump.** The synced `settings`
   key-value table absorbs two new keys.
5. A device that cannot honor the library's level says so in the UI rather than
   silently uploading originals.

## 4. Non-goals

- **No per-device quality override.** The per-item `override_level` already in
  `media_transfer_queue` covers "upload *this one* at a different level," which
  is the case a device override would have served.
- **No migration or adoption logic.** Phase A has not shipped in a release, so
  no user holds a stored preference worth preserving. Orphaned
  `media_store_photo_quality` / `media_store_video_quality` keys may exist on
  development machines; removal code that only ever runs on our own laptops is
  not worth writing.
- **No bulk re-compress.** Unchanged from Phase A: still deferred.
- **No change to rendition storage, the ceiling rule, first-writer-wins, or the
  `smv1/renditions/` namespace.**

## 5. Architecture

Approach: **split along the boundary**, rather than swapping
`MediaStorePolicies`' backend in place. Swapping in place would leave one class
straddling two backends with a class doc that is false for two of its five
methods.

A load-bearing fact makes the split cheap: the upload pipeline's **only** use
of `MediaStorePolicies` is `qualityFor` at `media_upload_pipeline.dart:172`.
The cellular and auto-upload flags gate the *worker*, never the pipeline. So
this is a dependency **swap**, not an addition.

It also removes Phase A's trap #1 as a side effect. Today the pipeline's
default `MediaStorePolicies()` reads `SharedPreferences` on every upload, a
hidden runtime dependency that forced `SharedPreferences.setMockInitialValues`
into every pipeline-building test (and broke `media_store_end_to_end_test`).
After the swap the pipeline holds an injectable quality policy and does not
touch preferences at all.

### 5.1 New: `MediaUploadQualityPolicy`

`lib/core/services/media_store/media_upload_quality_policy.dart`

```
MediaUploadQualityPolicy({AppSettingsRepository? settings})
  Future<MediaUploadQuality> photoUploadQuality()
  Future<void>               setPhotoUploadQuality(MediaUploadQuality)
  Future<MediaUploadQuality> videoUploadQuality()
  Future<void>               setVideoUploadQuality(MediaUploadQuality)
  Future<MediaUploadQuality> qualityFor(MediaType)
```

The same five-method surface that leaves `MediaStorePolicies`, using the same
optional-injection idiom (`MediaStorePolicies(SharedPreferences?)` becomes
`MediaUploadQualityPolicy(AppSettingsRepository?)`). It owns the two setting
keys, the enum parse/serialize, and the `original` fallback.

It sits beside `media_store_policies.dart`, which already imports feature types
(`MediaItem`, `MediaUploadQuality`) from `core/`, so the import *direction* is
established precedent. Note the edge is nonetheless heavier than that
precedent: this imports a repository from `features/settings/`, not an enum.
The alternative -- duplicating the `insertOnConflictUpdate` +
`markRecordPending` body inside the policy to avoid the dependency -- was
rejected as roughly twenty lines of copied sync-plumbing that would drift from
`AppSettingsRepository` the first time the settings write path changes. One
import is the cheaper coupling.

Dart's implicit interfaces mean a test fake is
`implements AppSettingsRepository` with no new abstraction.

Setting keys: `media_upload_quality_photo`, `media_upload_quality_video`.
Values are `MediaUploadQuality.name`, matching Phase A's persistence format.

### 5.2 Changed: `AppSettingsRepository`

Gains generic raw accessors:

```
Future<String?> getRawSetting(String key)
Future<void>    setRawSetting(String key, String value)
```

Body shape copies the existing methods exactly: `insertOnConflictUpdate` into
`settings`, then `markRecordPending(entityType: 'settings', recordId: key)`,
then `SyncEventBus.notifyLocalChange()`.

Generic rather than four typed methods because the table *is* a key-value
store, and `getNavPrimaryIdsRaw` already establishes the "raw accessor, caller
normalizes" idiom. Key names stay with the policy that owns their meaning.

### 5.3 Changed: `MediaStorePolicies`

Delete `photoQualityKey`, `videoQualityKey`, the four quality methods,
`qualityFor`, `_readQuality`, and the now-unused `MediaType` /
`MediaUploadQuality` imports. Update the class doc: three flags, all genuinely
device-local, and the "must not ride a database restore" claim becomes true
again for everything it still holds.

### 5.4 Changed: upload pipeline

`MediaStorePolicies? policies` becomes `MediaUploadQualityPolicy? quality`;
line 172 becomes `await _quality.qualityFor(item.mediaType)`. The
`media_store_policies.dart` import is dropped.

The tolerant per-item override parse (`_tryParseQuality`) is unchanged: a
corrupt or future-enum override string still falls back to the configured
level, which is now the library level rather than the device level.

### 5.5 Changed: settings UI

`media_storage_page.dart` stops loading quality in `_loadPolicies()`. The two
dropdowns move to `FutureProvider`s the page watches, with `ref.invalidate` on
write -- matching `shareByDefaultProvider` (`settings_providers.dart:799`) and
its consumer (`settings_page.dart:2193`).

New providers in `media_store_providers.dart`:

- `mediaUploadQualityPolicyProvider`
- `photoUploadQualityProvider` (`FutureProvider<MediaUploadQuality>`)
- `videoUploadQualityProvider` (`FutureProvider<MediaUploadQuality>`)

### 5.6 Changed: capability note

`media_storage_page.dart:693` currently gates the transcode-unavailable hint on
`isLinuxPlatformProvider`. That gate was correct while quality was device-local
-- only a Linux user could set a level their own device could not honor. A
library-wide setting breaks the assumption: a Mac can now set `small` for a
Windows box whose plugin is not registered.

Drop the platform gate. Keep the existing
`settings_mediaStorage_quality_linuxFfmpegHint` for Linux; add
`settings_mediaStorage_quality_noTranscoderHint` for other platforms ("This
device cannot compress video and will upload originals," final wording to be
set during implementation). The seam already exists:
`videoTranscodeAvailableProvider` (`media_store_providers.dart:495`) wraps
`PlatformVideoTranscoder.isAvailable()`, whose doc comment already says "used
by the settings hint."

## 6. Behavior

**Defaults.** Key absent means `MediaUploadQuality.original`, unchanged from
Phase A. A fresh library still uploads untouched originals until someone opts
in.

**Read errors are non-throwing and fall back to `original`.** The pipeline
reads on a background upload path, and the database can be absent mid-restore
(see the restore stage-copy/safe-swap work). Falling back to `original` fails
toward *full fidelity*: a transient error can cost storage, but can never
silently upload a degraded rendition as the only copy of a photo. The same
fallback covers an unrecognized enum string, mirroring Phase A's `_readQuality`
catch and the pipeline's `_tryParseQuality` tolerance.

**Write errors rethrow.** The page catches, shows a snackbar, and invalidates
the provider, which re-reads truth and reverts the optimistic value for free.
Today's handlers (`media_storage_page.dart:667-673`) await the write with no
error handling at all, so this is a small improvement in code already being
touched. This asymmetry -- reads degrade, writes surface -- is the documented
policy of `AppSettingsRepository` (line 77).

**Conflict resolution is the existing HLC last-writer-wins**, identical to
every other `settings` row. Two devices set different levels, one wins, all
devices converge. No new machinery.

**First-writer-wins on renditions is unchanged, and becomes harmless.** It is
still one rendition per hash. What changes is that the inputs now agree:
whoever writes first writes the same thing any other device would have.

**Restore semantics deliberately invert.** Phase A's comment insisted these
settings "must not ride a database restore." For quality that was wrong:
restoring a library should restore that library's fidelity policy. Syncing the
setting makes this automatic rather than something to implement.

**Known limitation (deliberate).** An open settings page does not live-update
when a quality change arrives via *incoming* sync; it refreshes on re-entry.
This matches `shareByDefaultProvider`'s existing behavior, and the pipeline
reads fresh at upload time regardless, so library correctness is unaffected. A
`SyncEventBus` listener for a settings dropdown is machinery for a case nobody
hits.

## 7. Schema and sync

**No migration. No `currentSchemaVersion` bump.** Two new keys in the existing
`settings` key-value table need neither. The next free schema version remains
v137.

The `settings` entity is already registered for sync (`sync_repository.dart:76`
with `pk: 'key'`, and handled generically throughout `sync_data_serializer`),
so no serializer changes are required. The existing exact-latest schema
tripwire should pass unmodified, which is itself the check that nothing was
bumped by accident.

## 8. Testing

Tests first, per project convention. The injection seam is what makes that
cheap.

1. **`MediaUploadQualityPolicy` unit tests** (fake `AppSettingsRepository`, no
   database): unset yields `original` for both types; round-trip all four
   levels; photo and video are independent; `qualityFor(MediaType.video)` reads
   the video key and `photo` the photo key; a garbage stored string yields
   `original`; a throwing read yields `original`; a throwing write rethrows.

2. **`AppSettingsRepository` raw accessor tests** (in-memory database):
   round-trip; missing key yields `null`; a write calls `markRecordPending` with
   `entityType: 'settings'` and `recordId: <key>`. That last assertion is what
   actually proves the setting syncs.

3. **Pipeline tests.** Existing Media Store tests swap `policies:` for an
   injected fake `quality:`. Existing behavior coverage (`original` produces no
   rendition; `small` produces one) stays green unchanged -- that is the
   regression signal. Removing now-unnecessary
   `SharedPreferences.setMockInitialValues` calls is opportunistic only where a
   run proves them unneeded; attach state also uses preferences, so no blanket
   sweep.

4. **Settings page widget tests.** Dropdowns render the synced value; a change
   writes and invalidates; the capability note shows on a non-Linux platform
   when the engine reports unavailable and the level is not `original`; the note
   is hidden when the engine is available.

   **Sweep required:** adding provider dependencies to a widget silently breaks
   every *other* test that pumps it without overrides -- those fall through to a
   real database and fail at runtime, not compile time, and `flutter analyze`
   will not catch it. Every test that pumps `MediaStoragePage` must be checked,
   not only the tests written here.

5. **Sync round-trip.** Confirm the two keys export and import as ordinary
   `settings` rows. The serializer handles the entity generically, so this is an
   assertion to add to an existing settings sync test, not a parallel test to
   write.

6. **Localization.** Two new keys -- the non-Linux capability note
   (`settings_mediaStorage_quality_noTranscoderHint`) and the write-failure
   snackbar required by section 6 (`settings_mediaStorage_quality_saveFailed`)
   -- translated across all 11 locales, then `flutter gen-l10n`.
   `app_localizations*.dart` is tracked (unlike `*.g.dart`) and must be
   committed.

## 9. Delivery

Single PR on branch `worktree-synced-media-upload-quality` (worktree
`.claude/worktrees/synced-media-upload-quality`), based on `main`.

Gates before opening the PR: `dart format .`, `flutter analyze` across the
whole project without piping, and a full `flutter test`. Known order-dependent
flakes in the backup suite may need an isolated re-run to confirm they are
pre-existing.
