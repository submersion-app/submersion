# Media Provenance PR 2a: The Read-Only Info Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Give every media item an info panel that reports its file facts, where it was linked from, whether it is backed up, and where its bytes are actually being served from right now.

**Architecture:** A cheap synchronous `MediaProvenance` model (row fields plus the transfer-queue row plus the store-attached flag) that a later PR's grid badge can also consume, plus an async store-identity provider the panel alone resolves. Live serving facts come from PR 1's `MediaServingRecorder`, read through a `ListenableBuilder` rather than a provider. Presentation is a modal bottom sheet, matching every other transient panel in this app.

**Tech Stack:** Dart / Flutter, Riverpod 3, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-08-16-media-provenance-design.md`

**Predecessor:** PR 1 (`#1107`, branch `worktree-media-provenance`) must merge first. This plan builds on `ServedFrom`, `ServedTier`, and `MediaServingRecorder`.

**Branch / worktree:** new branch `worktree-media-provenance-pr2a` cut from `origin/main` AFTER #1107 merges, in its own worktree at `.claude/worktrees/media-provenance-pr2a`. Run the init trio there: `git submodule update --init --recursive`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`.

## Global Constraints

- **No em-dashes.** The em-dash character (U+2014) must not appear in any code, comment, doc, ARB string, test name, or commit message. En-dashes (U+2013) used as prose punctuation and spaced hyphens are equally forbidden. Use commas, colons, semicolons, parentheses, or two sentences. This rule is stated by codepoint rather than by quoting the glyph so that this file does not trip the Task 10 check.
- **No emojis** in code, comments, or documentation.
- **No schema change.** No columns, no migration, no version bump, no synced entity touched.
- **No new repair, verify, or upload logic.** PR 2a is READ-ONLY. It renders state and nothing else. Every action button belongs to PR 2b. If a task seems to need a write, stop: it is out of scope.
- **All 11 ARB catalogs stay at exact key parity**, enforced by `test/l10n/arb_parity_test.dart`.
- **Dates must use `UnitFormatter`**, never raw `DateFormat`. The project rule is that anything displaying units respects the diver's settings, and `dateFormat`/`timeFormat` are unit settings.
- `dart format .` produces no changes. `flutter analyze` is clean with zero infos (CI treats infos as fatal).
- Lints in force: `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_final_locals`, `avoid_print`, `require_trailing_commas`, `always_use_package_imports`.

## Verified Facts (do not re-derive)

Confirmed against the branch tip before this plan was written.

1. **Source-type labels ALREADY EXIST.** `context.l10n.media_source_gallery` / `_localFile` / `_networkUrl` / `_manifest` / `_connector` / `_mediaStore` / `_signature`, switched in `media_sources_section_view.dart:61-71`. **Reuse that switch; do not create new source labels.**
2. **`mediaStoreStatusHintProvider` is NOT cheap.** It awaits `mediaStoreRuntimeProvider`, whose construction does a keychain read, builds the object store, kicks a queue drain, and can trigger an auto verify sweep. `mediaStoreAttachedProvider` exists so per-tile widgets never touch it. This is why the model is split in Task 3 and Task 4.
3. **The status hint is thin for managed providers.** S3 yields `"bucket @ host"`; Dropbox, Google Drive and iCloud yield the bare provider name. Richer identity needs `MediaStoresRepository.getActive()`, which returns `({String id, String providerType, String displayHint, DateTime? lastSweepAt})`.
4. **Queue states are raw strings, not an enum:** `'pending'`, `'transferring'`, `'done'`, `'failed'`. The per-item watch is `MediaTransferQueueRepository.watchLatestForMedia(String mediaId)`, returning `Stream<MediaTransferQueueEntry?>` (newest upload row only, delete rows excluded). The entry exposes `state`, `errorMessage`, `attempts`, `progressBytes`, `totalBytes`, `direction`.
5. **Long-press is unavailable as an entry point.** `MediaThumbnailTile` has no gesture callbacks and `DragSelectGridView` deliberately registers no long-press recognizer (commit `899d7f58baa`). `MediaLibraryTile.onLongPress` is already claimed by selection toggling. PR 2a therefore uses only the viewer button and the Missing-view tap; the library-grid entry point arrives in PR 3 alongside the badge, via `onSecondaryTapDown`.
6. **Every transient panel in this app is `showModalBottomSheet(isScrollControlled: true)`, at all widths.** No panel branches on `ResponsiveBreakpoints`. The tall-content template is `scan_results_dialog.dart:398-410` (a `DraggableScrollableSheet` inside the modal sheet). This overrides the spec's "side panel on wide" wording.
7. **`_TopOverlay` receives its item as a constructor parameter** from `media_viewer_page.dart:288-289`; it reads no provider. Buttons are bare `IconButton`s with hardcoded `Colors.white` and a `context.l10n` tooltip (pattern at `:1213-1217`).
8. **`DiveDetailRow({required String label, required String value, String? sourceName})`** at `lib/features/dive_log/presentation/widgets/dive_detail_row.dart:10-16` is the repo's labelled key-value row. The titled-section-in-a-card convention is `dive_detail_page.dart:3027-3037`.
9. **No shared byte formatter exists.** Six duplicates; the closest is the file-private `_formatBytes` at `network_cache_card.dart:105`. Task 1 extracts one.
10. **`UnitFormatter` is constructed locally**, not provided: `final units = UnitFormatter(ref.watch(settingsProvider));`. `formatDateTime(dt, {l10n})` and `formatDateTimeBullet(dt)` are the date+time methods; both return `'--'` for null.
11. **Riverpod 3 auto-pause trips an assertion on providers that self-invalidate from a raw stream listen.** The repo-wide fix is `Ref.invalidateSelfWhen(Stream<void>)` in `lib/core/providers/ref_invalidate_on_change.dart`. This plan avoids the whole area by reading the recorder through a `ListenableBuilder` in the widget rather than wrapping it in a provider.
12. **ARB catalogs hold 6735 message keys each, at exact parity.** English additionally carries `@`-metadata; the other ten do not. `flutter gen-l10n` runs implicitly (`pubspec.yaml:184` sets `generate: true`), and the 12 generated Dart files under `lib/l10n/arb/` **are committed to git**.

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/shared/utils/byte_format.dart` | Create: shared human-readable byte formatter | 1 |
| `lib/features/media/domain/entities/media_provenance.dart` | Create: `OriginFacts`, `BackupFacts`, `ServingFacts`, `MediaProvenance` | 2 |
| `lib/features/media/presentation/providers/media_provenance_providers.dart` | Create: cheap `mediaProvenanceProvider` plus the per-item queue watch | 3 |
| `lib/features/media/presentation/providers/media_provenance_providers.dart` | Modify: async `mediaStoreIdentityProvider` | 4 |
| `lib/l10n/arb/app_*.arb` (11 files) | Modify: ~41 new `media_info_*` keys | 5 |
| `lib/features/media/presentation/widgets/media_info_panel.dart` | Create: the panel, File and Origin blocks | 6 |
| `lib/features/media/presentation/widgets/media_info_panel.dart` | Modify: Backup and Serving blocks | 7 |
| `lib/features/media/presentation/widgets/media_info_sheet.dart` | Create: `showMediaInfoSheet` launcher | 8 |
| `lib/features/media/presentation/pages/media_viewer_page.dart` | Modify: info button in `_TopOverlay` | 8 |
| `lib/features/media/presentation/pages/media_missing_view.dart` | Modify: wire the no-op `onTileTap` | 9 |

---

### Task 1: Shared byte formatter

**Files:**
- Create: `lib/shared/utils/byte_format.dart`
- Test: `test/shared/utils/byte_format_test.dart`

**Interfaces:**
- Produces: `String formatBytes(int bytes)`. Tasks 6 and 7 call it.

Extracted rather than invented: six near-identical private copies exist. This task creates the shared one and leaves the copies alone. Consolidating them is unrelated refactoring and out of scope.

- [x] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/utils/byte_format.dart';

void main() {
  test('renders bytes below a kilobyte verbatim', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
  });

  test('renders kilobytes and megabytes to one decimal', () {
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(1024 * 1024), '1.0 MB');
    expect(formatBytes(3 * 1024 * 1024 + 512 * 1024), '3.5 MB');
  });

  test('renders gigabytes to two decimals', () {
    expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
  });

  test('treats a negative size as unknown rather than rendering it', () {
    expect(formatBytes(-1), '0 B');
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/utils/byte_format_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist".

- [x] **Step 3: Write the implementation**

```dart
/// Human-readable byte count, matching the thresholds and precision the app
/// already uses elsewhere (B, KB and MB to one decimal, GB to two).
///
/// Unit settings do not apply: the diver's preferences cover seven physical
/// quantities plus date and time formatting, and a byte is none of them.
///
/// The suffixes are intentionally not localized. Every existing size display
/// in this app hardcodes them, and there are no size-unit strings in any ARB
/// catalog; introducing one here would leave the app inconsistent with
/// itself for no reader benefit.
String formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes < 0 ? 0 : bytes} B';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}
```

- [x] **Step 4: Run the test to verify it passes**

Run: `flutter test test/shared/utils/byte_format_test.dart`
Expected: PASS, 4 tests.

- [x] **Step 5: Format and commit**

```bash
dart format .
git add lib/shared/utils/byte_format.dart test/shared/utils/byte_format_test.dart
git commit -m "Add a shared byte formatter

Six private near-duplicates already exist. This adds the shared one the
info panel needs and leaves the copies alone; consolidating them is
unrelated refactoring."
```

---

### Task 2: The provenance model

**Files:**
- Create: `lib/features/media/domain/entities/media_provenance.dart`
- Test: `test/features/media/domain/entities/media_provenance_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `MediaSourceType`, `ServedFrom`, `ServedTier`, `UnavailableKind`, `ServingObservation`, `MediaTransferQueueEntry`, `isBackedUp`, `kUploadableSources`.
- Produces, and Tasks 3, 6 and 7 depend on these exact names:

```dart
enum OriginHealth { healthy, missing, neverVerified }
enum BackupTier { none, thumbOnly, renditionOnly, full }

class OriginFacts {
  final MediaSourceType sourceType;
  final String? pointer;          // asset id, path, url, hash, per type
  final String? originDeviceId;
  final OriginHealth health;
  final DateTime? lastVerifiedAt;
}

class BackupFacts {
  final bool storeAttached;
  final bool eligible;            // sourceType in kUploadableSources
  final BackupTier tier;
  final DateTime? originalUploadedAt;
  final DateTime? thumbUploadedAt;
  final DateTime? renditionUploadedAt;
  final String? queueState;       // 'pending' | 'transferring' | 'done' | 'failed'
  final String? queueError;
}

class ServingFacts {
  final ServedFrom? servedFrom;
  final ServedTier servedTier;
  final bool storeFallbackUsed;
  final UnavailableKind? failure;
  final DateTime? observedAt;
  bool get observed;
  factory ServingFacts.from(ServingObservation? observation);
  static const ServingFacts unobserved;
}

class MediaProvenance {
  final OriginFacts origin;
  final BackupFacts backup;
  factory MediaProvenance.from(MediaItem item, {
    required bool storeAttached,
    required MediaTransferQueueEntry? queueEntry,
  });
}
```

**Note the deliberate omission:** `MediaProvenance` holds origin and backup only. `ServingFacts` is NOT a member. Serving state comes from a `ChangeNotifier` the widget listens to directly (Task 7), and folding it in would force this cheap synchronous object to become reactive to something Riverpod cannot see. See Verified Fact 11.

- [x] **Step 1: Write the failing test**

Cover, at minimum:

```dart
test('a gallery row reports its asset id as the pointer', () { ... });
test('a localFile row reports its localPath, falling back to bookmarkRef', () { ... });
test('a networkUrl row reports its url', () { ... });
test('a mediaStore row reports its content hash', () { ... });

test('an orphaned row reads missing', () {
  // isOrphaned true -> OriginHealth.missing
});
test('a never-verified row reads neverVerified', () {
  // isOrphaned false, lastVerifiedAt null
});
test('a verified row reads healthy and keeps its date', () { ... });

test('retainInLibrary does not affect origin health', () {
  // Guards the naming trap: isOrphaned means "file missing"; the orphan
  // sweep's notion of unlinked is a different axis entirely.
});

test('a url row is not eligible for backup', () {
  // sourceType networkUrl -> eligible false, tier none
});
test('thumb stamp alone reads thumbOnly', () { ... });
test('compressed stamp alone reads renditionOnly', () { ... });
test('original stamp reads full', () { ... });
test('a failed queue row carries its error text', () { ... });
test('ServingFacts.from(null) is unobserved', () { ... });
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/features/media/domain/entities/media_provenance_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist".

- [x] **Step 3: Write the implementation**

Key rules to encode:

- **Pointer per source type**, a `switch` on `sourceType`: `platformGallery` yields `platformAssetId`; `localFile` yields `localPath ?? filePath ?? bookmarkRef`; `networkUrl` and `manifestEntry` yield `url`; `serviceConnector` yields `remoteAssetId`; `mediaStore` yields `contentHash`; `signature` yields null.
- **Health** maps from `isOrphaned` ONLY. `isOrphaned` true is `missing`; false with a null `lastVerifiedAt` is `neverVerified`; false with a date is `healthy`. `retainInLibrary` is a different axis (the orphan sweep's "unlinked", not "file missing") and must not be read here.
- **`eligible`** is `kUploadableSources.contains(sourceType)`.
- **`tier`** derives from the three stamps: any `remoteUploadedAt` is `full`; else any `remoteCompressedUploadedAt` is `renditionOnly`; else any `remoteThumbUploadedAt` is `thumbOnly`; else `none`. Do not re-implement `isBackedUp`; this is a finer-grained readout that must stay consistent with it, so assert in a test that `tier != BackupTier.none` agrees with `isBackedUp` for non-thumb-only rows.

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/features/media/domain/entities/media_provenance_test.dart`
Expected: PASS.

- [x] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/domain/entities/media_provenance.dart \
        test/features/media/domain/entities/media_provenance_test.dart
git commit -m "Add the MediaProvenance model

Origin and backup facts only. Serving state deliberately stays out: it
comes from a ChangeNotifier the widget listens to directly, and folding it
in would make this cheap synchronous object reactive to something Riverpod
cannot see.

Origin health maps from isOrphaned alone. In this codebase that means the
FILE is missing, which is a different axis from the orphan sweep's notion
of an unlinked row, and retainInLibrary belongs to neither."
```

---

### Task 3: The cheap provenance provider

**Files:**
- Create: `lib/features/media/presentation/providers/media_provenance_providers.dart`
- Test: `test/features/media/presentation/providers/media_provenance_providers_test.dart`

**Interfaces:**
- Produces:
```dart
final mediaQueueEntryProvider =
    StreamProvider.family<MediaTransferQueueEntry?, String>(...);   // by media id
final mediaProvenanceProvider =
    Provider.family<MediaProvenance, MediaItem>(...);
```

**This provider must stay cheap enough for every visible grid tile**, because PR 3's badge consumes it. It may watch `mediaStoreAttachedProvider` and `mediaQueueEntryProvider`. It must NOT watch `mediaStoreRuntimeProvider` or `mediaStoreStatusHintProvider` (Verified Fact 2).

- [x] **Step 1: Write the failing test**

Use a `ProviderContainer` with `mediaStoreAttachedProvider` and `mediaQueueEntryProvider` overridden. Assert:

```dart
test('composes row facts with the attached flag and queue row', () { ... });
test('reports notBackedUp shape when attached with no stamps', () { ... });
test('a queued row surfaces its state', () { ... });
test('does not build the store runtime', () async {
  // Override mediaStoreRuntimeProvider with a throwing builder and assert
  // reading mediaProvenanceProvider does NOT throw. This is the guard that
  // keeps PR 3's badge affordable; without it the dependency could be added
  // later and nothing would notice until the grid stuttered.
});
```

That last test is the important one. Write it.

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/features/media/presentation/providers/media_provenance_providers_test.dart`
Expected: FAIL to compile.

- [x] **Step 3: Write the implementation**

`mediaQueueEntryProvider` wraps `MediaTransferQueueRepository.watchLatestForMedia(mediaId)`. Follow the guarding pattern in `mediaBadgeStateProvider` (`media_store_providers.dart:242-257`), including its handling of an uninitialized `LocalCacheDatabaseService`, which throws `StateError` rather than an `Exception`.

`mediaProvenanceProvider` reads `.value` off both async dependencies with safe defaults (`storeAttached: ref.watch(mediaStoreAttachedProvider).value ?? false`) so it never surfaces a loading state to a tile.

Add the `// no-tick:` comment convention if this repo's provider-tick contract test requires it; read the failure message from that test rather than guessing.

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/features/media/presentation/providers/media_provenance_providers_test.dart`
Expected: PASS.

- [x] **Step 5: Register with the provider tick contract test if it complains**

Run: `flutter test test/core/providers/` and the media provider contract tests. If a test enumerates media providers and fails naming the new ones, add them where it says. Read the failure text; it names the missing site precisely.

- [x] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/providers/media_provenance_providers.dart \
        test/features/media/presentation/providers/media_provenance_providers_test.dart
git commit -m "Add the cheap media provenance provider

Watches only the store-attached flag and the per-item queue row, never the
store runtime: building that runtime does a keychain read, constructs the
object store, kicks a queue drain and can trigger a verify sweep, which is
why mediaStoreAttachedProvider exists at all.

A test overrides the runtime provider with a throwing builder and asserts
this provider still resolves, so the expensive dependency cannot be added
later without a test failing."
```

---

### Task 4: The async store identity provider

**Files:**
- Modify: `lib/features/media/presentation/providers/media_provenance_providers.dart`
- Test: extend `test/features/media/presentation/providers/media_provenance_providers_test.dart`

**Interfaces:**
- Produces:
```dart
class MediaStoreIdentity {
  final String providerType;   // 's3' | 'dropbox' | 'googledrive' | 'icloud'
  final String displayHint;    // "bucket @ host" for S3, else the provider name
}
final mediaStoreIdentityProvider = FutureProvider<MediaStoreIdentity?>(...);
```

Panel-only. Null when no store is attached.

- [x] **Step 1: Write the failing test**

```dart
test('is null when no store is attached', () { ... });
test('reports the active descriptor provider type and hint', () { ... });
```

Override `mediaStoresRepositoryProvider` (or whatever the repo names it; read `media_store_providers.dart` for the exact symbol) with a fake returning a `MediaStoreDescriptor`.

- [x] **Step 2: Run to verify it fails**

Expected: FAIL, `MediaStoreIdentity` undefined.

- [x] **Step 3: Write the implementation**

Read `MediaStoresRepository.getActive()`, which returns
`({String id, String providerType, String displayHint, DateTime? lastSweepAt})`.
Return null when it yields null. Do NOT reuse `mediaStoreStatusHintProvider`: it collapses the provider type into the hint and loses the distinction the panel wants to show.

Document in the doc comment that this provider constructs nothing itself but that its dependency chain may, and that it is therefore panel-only and must never be watched from a tile.

- [x] **Step 4: Run to verify it passes**

Expected: PASS.

- [x] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/providers/media_provenance_providers.dart \
        test/features/media/presentation/providers/media_provenance_providers_test.dart
git commit -m "Add the panel-only store identity provider

Reads MediaStoresRepository.getActive directly rather than reusing
mediaStoreStatusHintProvider, which collapses the provider type into the
display hint and loses the distinction the panel shows. Panel-only by
contract: never watch it from a grid tile."
```

---

### Task 5: The localized strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Modify (generated, committed): `lib/l10n/arb/app_localizations*.dart`
- Test: `test/l10n/media_info_strings_test.dart` (create)

**REUSE, do not recreate:** source-type labels already exist as `media_source_gallery` / `_localFile` / `_networkUrl` / `_manifest` / `_connector` / `_mediaStore` / `_signature`. Copy the `switch` from `media_sources_section_view.dart:61-71`.

**41 new keys.** Add message + `@` metadata to `app_en.arb`; add message only to the other ten. Keys are appended, not sorted. Placeholders are formatted in Dart and passed as `String`, per repo convention (no ARB uses `format:`).

- [x] **Step 1: Write the failing test**

Model it on `test/l10n/site_media_strings_test.dart`. It must assert (a) every new key resolves in every locale, and (b) no non-English locale shipped the English source text verbatim.

- [x] **Step 2: Run to verify it fails**

Expected: FAIL, the getters do not exist.

- [x] **Step 3: Add the keys to `app_en.arb`**

Panel chrome and File block:
```
media_info_title                 "Media info"
media_info_fileSection           "File"
media_info_filename              "Filename"
media_info_type                  "Type"
media_info_dimensions            "Dimensions"
media_info_size                  "Size"
media_info_taken                 "Taken"
media_info_coordinates           "Coordinates"
media_info_unknown               "Unknown"
```
Origin block:
```
media_info_originSection         "Origin"
media_info_source                "Source"
media_info_reference             "Reference"
media_info_linkedOn              "Linked on"
media_info_thisDevice            "This device"
media_info_otherDevice           "Another device"
media_info_status                "Status"
media_info_statusFound           "Found on this device"
media_info_statusMissing         "Missing from this device"
media_info_statusUnchecked       "Not checked yet"
media_info_lastChecked           "Last checked {date}"      // placeholder date: String
```
Backup block:
```
media_info_backupSection         "Backup"
media_info_store                 "Cloud store"
media_info_storeNotConnected     "No cloud store connected"
media_info_notEligible           "This source is not eligible for backup"
media_info_backupFull            "Original uploaded"
media_info_backupThumbOnly       "Thumbnail only, original not sent"
media_info_backupRenditionOnly   "Compressed version uploaded"
media_info_backupNone            "Not backed up"
media_info_uploadedOn            "Uploaded {date}"          // placeholder date: String
media_info_queuePending          "Waiting to upload"
media_info_queueTransferring     "Uploading now"
media_info_queueFailed           "Upload failed: {error}"   // placeholder error: Object
```
Serving block:
```
media_info_servingSection        "Serving now"
media_info_servingUnobserved     "Not loaded yet"
media_info_servingFailed         "Could not be loaded"
media_info_servedLocalDisk       "Local file on this device"
media_info_servedGallery         "Photo library"
media_info_servedStoreCache      "Local cache, from the cloud store"
media_info_servedStoreNetwork    "Downloaded from the cloud store"
media_info_servedNetworkUrl      "Streaming from a URL"
media_info_servedConnectorCache  "Local cache, from the connected service"
media_info_servedConnectorNetwork "Downloaded from the connected service"
media_info_servedEmbedded        "Stored inside this logbook"
media_info_servingFallbackNote   "The original source could not be reached, so the cloud store served this."
media_info_servingTierThumbnail  "Thumbnail"
media_info_servingTierRendition  "Compressed version"
```

Metadata shape to copy exactly:
```json
"media_info_lastChecked": "Last checked {date}",
"@media_info_lastChecked": {
  "description": "Origin block, when the media source was last verified",
  "placeholders": { "date": { "type": "String" } }
}
```

- [x] **Step 4: Translate into the other ten catalogs**

Add the message key only, no `@` metadata, to `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`. Every locale must be genuinely translated, not copied English. Preserve `{date}` and `{error}` placeholder names exactly; `arb_parity_test.dart:60` compares ICU argument names per key.

- [x] **Step 5: Regenerate and verify parity**

```bash
flutter pub get     # runs gen-l10n implicitly (pubspec.yaml:184 generate: true)
flutter test test/l10n/
```
Expected: `arb_parity_test.dart` and the new strings test both PASS. The 12 generated `app_localizations*.dart` files change and must be committed.

- [x] **Step 6: Format and commit**

```bash
dart format .
git add lib/l10n/arb/ test/l10n/media_info_strings_test.dart
git commit -m "Add media info panel strings in 11 locales

41 new media_info_* keys. Source-type labels are reused from the existing
media_source_* set rather than duplicated. Placeholders are formatted in
Dart and passed as strings, matching every other entry in these catalogs;
no ARB in this repo uses an ICU format specifier."
```

---

### Task 6: The panel, File and Origin blocks

**Files:**
- Create: `lib/features/media/presentation/widgets/media_info_panel.dart`
- Test: `test/features/media/presentation/widgets/media_info_panel_test.dart`

**Interfaces:**
- Produces: `class MediaInfoPanel extends ConsumerWidget { const MediaInfoPanel({super.key, required this.item}); final MediaItem item; }`

Structure: a `ListView` of titled sections, each section a `Card` containing a title `Text` in `titleMedium`, a `Divider`, then `DiveDetailRow`s. That is the `dive_detail_page.dart:3027-3037` convention. Reuse `DiveDetailRow({label, value})`; do not write a new key-value row.

- [x] **Step 1: Write the failing test**

Use `localizedMaterialApp` from `test/helpers/l10n_test_helpers.dart` and pin `Intl.defaultLocale = 'en_US'` in `setUp` with restore in `tearDown` (the established widget-test pattern). Assert:

```dart
testWidgets('renders filename, dimensions, size and taken date', ...);
testWidgets('renders Unknown for absent file facts', ...);
testWidgets('renders the source label and the pointer for a gallery row', ...);
testWidgets('a missing row renders the missing status', ...);
testWidgets('an unverified row renders the unchecked status', ...);
testWidgets('a row linked on another device says so', ...);
```

Dates in expectations must match `UnitFormatter` output, not raw `DateFormat`. `UnitFormatter` uses an explicit `'h:mm a'` pattern and emits an ASCII space, so these assertions do NOT need the U+202F narrow no-break space that `media_repair_history_test.dart:100` requires. If an assertion needs ` `, something is using raw intl and should be fixed to use `UnitFormatter`.

- [x] **Step 2: Run to verify it fails**

Expected: FAIL to compile.

- [x] **Step 3: Write the implementation**

```dart
final units = UnitFormatter(ref.watch(settingsProvider));
```
Format `takenAt` with `units.formatDateTime(item.takenAt, l10n: context.l10n)`. Format size with `formatBytes` from Task 1. Render dimensions as `'${item.width} × ${item.height}'` when both are present. Absent values render `context.l10n.media_info_unknown`, never an empty row.

For the source label, copy the `switch` from `media_sources_section_view.dart:61-71`.

`originDeviceId` handling. **CORRECTED 2026-08-16 after reading the writer.**
The original instruction here said to treat null as "this device". That is
wrong. `MediaRepository._effectiveOriginDeviceId` (`media_repository.dart:187-201`)
stamps a device id for `localFile` and `serviceConnector` ONLY, and returns
null for `platformGallery`, `networkUrl`, `manifestEntry`, `signature` and
`mediaStore`. So null means "this source type does not track an origin
device", not "this device". Rendering it as "This device" would state a fact
the app never recorded, and it would say it on every gallery photo.

The rule is therefore three-way:

- `originDeviceId == null`: omit the row entirely. Nothing is known.
- equal to `SyncRepository.getDeviceId()`: `media_info_thisDevice`.
- anything else: `media_info_otherDevice`.

Never render the raw id; it is a UUID and means nothing to a reader.

- [x] **Step 4: Run to verify it passes**

Expected: PASS.

- [x] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/media_info_panel.dart \
        test/features/media/presentation/widgets/media_info_panel_test.dart
git commit -m "Add the media info panel with its File and Origin blocks

Reuses DiveDetailRow and the card-with-title section convention rather than
inventing layout. Dates go through UnitFormatter so they respect the
diver's date and time settings, which also avoids the U+202F narrow
no-break space that raw intl jm formatting forces tests to match."
```

---

### Task 7: Backup and Serving blocks

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart`
- Test: extend `test/features/media/presentation/widgets/media_info_panel_test.dart`

- [x] **Step 1: Write the failing test**

```dart
testWidgets('an ineligible source says so instead of not backed up', ...);
testWidgets('no store connected renders the not-connected line', ...);
testWidgets('a thumb-only row says the original was not sent', ...);
testWidgets('a failed queue row shows its error', ...);
testWidgets('an unobserved item says not loaded yet', ...);
testWidgets('a store-cache serving reads as local cache', ...);
testWidgets('a store fallback adds the fallback note', ...);
testWidgets('the panel refreshes when the recorder records', (tester) async {
  // Pump with an empty recorder, assert "Not loaded yet"; then call
  // recorder.record(...) and pump; assert the served line appears. This is
  // the test that proves the ListenableBuilder is actually wired.
});
```

That last test is the important one.

- [x] **Step 2: Run to verify it fails**

Expected: FAIL.

- [x] **Step 3: Write the implementation**

Backup block reads `ref.watch(mediaProvenanceProvider(item)).backup` plus `ref.watch(mediaStoreIdentityProvider)` for the store name. Precedence for the summary line: not `eligible` yields `notEligible`; not `storeAttached` yields `storeNotConnected`; otherwise the `BackupTier` maps to `backupFull` / `backupThumbOnly` / `backupRenditionOnly` / `backupNone`. Queue state, when present and not `'done'`, renders as its own row below.

Serving block wraps in:
```dart
ListenableBuilder(
  listenable: ref.watch(mediaServingRecorderProvider),
  builder: (context, _) {
    final facts = ServingFacts.from(
      ref.read(mediaServingRecorderProvider).lastFor(item.id, thumbnail: false),
    );
    ...
  },
)
```
Reading the recorder through a `ListenableBuilder` rather than a provider is deliberate: Riverpod 3 auto-pause trips an assertion on providers that self-invalidate from a listener the framework cannot see, and the repo's fix for that (`Ref.invalidateSelfWhen`) takes a `Stream<void>`, which a `ChangeNotifier` is not. Add that reasoning as a code comment.

Map `ServedFrom` to its string with an exhaustive `switch` (no `default:` arm, so a future enum value is a compile error rather than a silently wrong label). Append the tier when it is not `original`. When `storeFallbackUsed` is true and bytes were served, append `media_info_servingFallbackNote`.

- [x] **Step 4: Run to verify it passes**

Expected: PASS.

- [x] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/media_info_panel.dart \
        test/features/media/presentation/widgets/media_info_panel_test.dart
git commit -m "Add the Backup and Serving blocks to the media info panel

Serving state is read through a ListenableBuilder rather than a provider.
Riverpod 3 auto-pause trips an assertion on providers that self-invalidate
from a listener it cannot see, and the repo's fix for that takes a stream,
which a ChangeNotifier is not.

ServedFrom maps through an exhaustive switch with no default arm, so a new
enum value becomes a compile error instead of a silently wrong label."
```

---

### Task 8: The sheet launcher and the viewer entry point

**Files:**
- Create: `lib/features/media/presentation/widgets/media_info_sheet.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart`
- Test: `test/features/media/presentation/media_info_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showMediaInfoSheet(BuildContext context, MediaItem item)`

- [x] **Step 1: Write the failing test**

```dart
testWidgets('the viewer info button opens the sheet', ...);
testWidgets('the sheet renders the panel for the given item', ...);
```

- [x] **Step 2: Run to verify it fails**

- [x] **Step 3: Write the implementation**

Launcher, following `scan_results_dialog.dart:398-410`:

```dart
Future<void> showMediaInfoSheet(BuildContext context, MediaItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) =>
            MediaInfoPanel(item: item, scrollController: controller),
      ),
    );
```

A modal bottom sheet at every width is the repo convention: no transient panel in this app branches on `ResponsiveBreakpoints`. This overrides the spec's "side panel on wide" wording, and the deviation is deliberate.

Viewer button: add an `onShowInfo` callback parameter to `_TopOverlay` and render it beside the share button, copying the `IconButton` pattern at `media_viewer_page.dart:1213-1217` exactly (`Icons.info_outline`, `color: Colors.white`, `tooltip: context.l10n.media_info_title`). Wire it at the construction site (`:288-289`) as `onShowInfo: () => showMediaInfoSheet(context, currentItem)`, matching how `onShare` is passed.

`_topChromeHeight = 64` (`:1098`) does not need changing: it is sized for a 48 px `IconButton` plus padding, and another button does not alter the height.

- [x] **Step 4: Run to verify it passes**

- [x] **Step 5: Run the viewer's existing suites**

Run: `flutter test test/features/media/presentation/`
Expected: PASS, unchanged counts. Adding a button to the overlay must not break existing viewer tests; if one asserts an exact icon count in the overlay, update it and note that in the commit.

- [x] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/media_info_sheet.dart \
        lib/features/media/presentation/pages/media_viewer_page.dart \
        test/features/media/presentation/media_info_sheet_test.dart
git commit -m "Add the info sheet launcher and the viewer info button

A modal bottom sheet at every width, matching every other transient panel
in this app: none of them branch on ResponsiveBreakpoints. This overrides
the spec's side-panel-on-wide wording deliberately."
```

---

### Task 9: The Missing-view entry point

**Files:**
- Modify: `lib/features/media/presentation/pages/media_missing_view.dart`
- Test: `test/features/media/presentation/media_missing_view_info_test.dart`

The tile tap is a literal no-op today (`:107`), so a missing item cannot be inspected in the one view built for troubleshooting it. This wires it.

- [x] **Step 1: Write the failing test**

```dart
testWidgets('tapping a missing tile opens the info panel', ...);
```

- [x] **Step 2: Run to verify it fails**

Expected: FAIL, no sheet appears.

- [x] **Step 3: Write the implementation**

Replace `onTileTap: (entry, index) {}` with `onTileTap: (entry, index) => showMediaInfoSheet(context, entry.item)`. Confirm the entry type's field name for the `MediaItem` by reading `MediaLibraryGrid`'s entry type; do not assume `.item`.

- [x] **Step 4: Run to verify it passes**

- [x] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/pages/media_missing_view.dart \
        test/features/media/presentation/media_missing_view_info_test.dart
git commit -m "Open the info panel from a missing media tile

The tap was a literal no-op, so the one view built for troubleshooting a
missing item could not tell you anything about it."
```

---

### Task 10: Full verification

- [x] **Step 1:** `dart format --set-exit-if-changed .` exits 0.
- [x] **Step 2:** `flutter analyze` reports no issues. Analyze the whole project; do not pipe through `tail` or `grep`, which masks the exit code.
- [x] **Step 3:** `flutter test` has zero failures. Expect a rise equal to the tests added, and expect some shared-widget consumer tests to need localization hosts added (see below).
- [x] **Step 4:** `git diff --stat origin/main...HEAD -- lib/core/database lib/features/sync` is empty.
- [x] **Step 5:** no em-dash was added to source. Build the pattern rather than
  typing it, so this file does not contain what it searches for, and scope the
  diff to source because docs legitimately discuss the character by name:
  ```bash
  EMDASH=$(printf '\xe2\x80\x94')
  git diff origin/main...HEAD -- lib test | grep -n "^+.*$EMDASH" || echo "clean"
  ```
- [x] **Step 6:** `flutter test test/l10n/` passes, confirming all 11 catalogs are still at parity.
- [x] **Step 7:** Push and open the PR against `main`, with no attribution line and no session URL.

**Expected failure class, not a surprise:** adding localized strings to widgets that other tests render will break every consumer test that does not host localization delegates. Fix by wrapping those tests in `localizedMaterialApp` from `test/helpers/l10n_test_helpers.dart`. Budget for this fanout rather than debugging it.

## Self-Review

**Spec coverage.** Spec section 6 (the model) is Tasks 2 to 4, with the section 6.4 "synchronous and cheap" claim corrected: store identity genuinely requires the runtime, so the model is split along the cost boundary. Section 7.1's four blocks are Tasks 6 and 7. Section 7.3's entry points are Tasks 8 and 9, minus the tile long-press, which the gesture system does not allow (Verified Fact 5) and which moves to PR 3 as a right-click. Section 7.4 (l10n) is Task 5. Section 7.2 (actions) is deliberately absent: it is PR 2b.

**Deviations from the spec, all deliberate and stated at their point of use.** Modal bottom sheet at all widths rather than a wide-layout side panel (Task 8). Tile entry point deferred to PR 3 as right-click rather than long-press (Verified Fact 5). `MediaProvenance` excludes `ServingFacts` (Task 2). The provider is split into cheap and async halves (Tasks 3 and 4).

**Type consistency.** `ServingFacts.from(ServingObservation?)` is defined in Task 2 and called in Task 7. `formatBytes(int)` is defined in Task 1 and called in Task 6. `mediaProvenanceProvider` is `Provider.family<MediaProvenance, MediaItem>` in Task 3 and consumed with that exact family type in Task 7. `showMediaInfoSheet(BuildContext, MediaItem)` is defined in Task 8 and called in Task 9.

**Places the plan says look rather than telling.** The `MediaStoresRepository` provider symbol (Task 4), the provider-tick contract test's registration site (Task 3), the current-device-id accessor (Task 6), and `MediaLibraryGrid`'s entry field name (Task 9). Each was not verifiable from the files read while planning, and guessing would produce code that does not compile.

**Three of those four were resolved before implementation began, and one of
them changed the design:**

- `mediaStoresRepositoryProvider` exists at `media_store_providers.dart:298`.
- The device id comes from `SyncRepository.getDeviceId()`. Reading its caller
  revealed that `originDeviceId` is null for five of the seven source types by
  design, which corrected Task 6's rule from two-way to three-way. Had the
  plan asserted a guess instead, every gallery photo would have claimed
  "Linked on: This device".
- `MediaLibraryEntry` (`media_library_filter.dart:167-179`) exposes `.item`,
  so Task 9's assumption holds.

The provider-tick registration site stays a "read the failure text" item,
because only the failing test names it precisely.
