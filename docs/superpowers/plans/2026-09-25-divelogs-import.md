# divelogs.de Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver import their divelogs.de logbook (dives, sites, gear, certifications, dive-to-gear links, photos) through the existing import wizard, idempotently.

**Architecture:** A `DivelogsImportAdapter` subclasses `UniversalAdapter`, swapping its file steps for Sign In and Fetch and keeping its Divers and Photos steps. The fetch builds an `ImportPayload` and injects it through a new `UniversalImportNotifier.setExternalPayload`, so bundle building, duplicate checks and the importer are all reused. Photos are listed at fetch time and downloaded at import time through a new protected `UniversalAdapter.attachAdditionalPhotos` hook into the folder the user picks, then linked via the existing `ImportPhotoLinker`.

**Tech Stack:** Flutter, Riverpod (StateNotifier/StateProvider), Drift, `package:http` (+ `http/testing.dart` `MockClient`), `flutter_secure_storage` via `FallbackSecureStorage`, gen-l10n ARB files.

**Spec:** `docs/superpowers/specs/2026-09-25-divelogs-import-design.md`

## Global Constraints

- Import only. No code that POSTs to divelogs.de; no `/divelist`; no sync page; no `AccountKind.divelogs`; no schema change (`currentSchemaVersion` stays untouched).
- Dive source ids are `divelogs-<remote id>` (a dash, never a colon): `DiveRepository._looksLikeSourceUuid` drops keys without `-`.
- The password is never persisted. Keychain blob key `divelogs_session` holds only `username` and `token`.
- Never log the password, the token, or an `Authorization` header.
- Dive photos are links only: written into the user-chosen folder via `ImportPhotoLinker.linkBundled`, never into app storage. Do not call `MediaImportService.importLocalFileForDive`.
- Every non-error `ImportWarning` carries an `ImportWarningCode` (the constructor asserts it).
- Any importer file under `lib/features/universal_import/data` that writes a `latitude` key must call `ImportSiteLocation` (guard: `test/architecture/import_site_location_contract_test.dart`).
- ARB plurals: never hardcode a digit in a `one`/`=1` branch; write `one{{count} dive}`. French and Portuguese put 0 in the `one` category.
- No em-dashes or en-dashes as punctuation anywhere (code, comments, ARB strings, commits). No emojis.
- No AI-tool attribution of any kind (trailers, links, footers) in any commit, PR, issue or comment.
- Paths built with `p.join`; temp space via `Directory.systemTemp`.
- Run `dart format .` before every commit.
- Old-branch source for ports: commit `28c9c842fa8006d90ccdc2a0bcfe6fb7c7dd0e4e` (tip of `origin/worktree-divelogs-sync`). Referred to below as `$OLD`.

## Review Focus

1. **A cached token that has expired when the wizard opens.** Expected: the Sign In step shows the form with the username prefilled and no error flash; the stale session is cleared. Pinned in Task 8.
2. **A picture URL with no usable file name (`/pictures/get?id=9`) or two pictures with the same name on one dive.** Expected: both photos saved, neither overwrites the other. Pinned in Task 3 (`attachRemotePhotos`) and Task 6 (`remotePhotoFileName`).
3. **Re-importing the same logbook.** Expected: every dive flagged as an exact source match (Pass 0) through the real repository, and no new photo files or links. Pinned in Task 6 (repository-backed Pass 0 test) and Task 3 (linker dedupe relies on `exportBundledPhoto`, covered by its own tests).
4. **A dive with coordinates but no site name, or with `0/0` coordinates.** Expected: coordinates kept and the site named from them; `0/0` treated as no position. Pinned in Task 5.
5. **Session expiring halfway through photo downloads at import time.** Expected: the import completes; the remaining photos are counted in a "photos not downloaded" notice. Pinned in Task 3 (download failure counted) and Task 7 (adapter wires failures into the notice).

---

### Task 0: Worktree setup and tracking issue

**Files:** none in the repo.

- [ ] **Step 1: Initialize the worktree**

Run from the worktree root:

```bash
git submodule update --init --recursive
```

```bash
flutter pub get
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: all three succeed. `flutter analyze` must then report no errors (mass "undefined" errors mean codegen did not run).

- [ ] **Step 2: Confirm the branch**

Run: `git branch --show-current`
Expected: `feature/divelogs-import`

- [ ] **Step 3: Open the tracking issue (ask the user before running; it publishes to GitHub)**

```bash
gh issue create --repo submersion-app/submersion --title "Import logbook from divelogs.de" --body "Import a divelogs.de logbook through the import wizard: dives with profiles, dive sites, gear, certifications, dive-to-gear links and dive photos. Import only (no push or two-way sync). Re-importing must be safe. Photos are saved into a folder the user chooses and linked, never copied into app storage. Supersedes the two-way sync attempt in PR #603. Design: docs/superpowers/specs/2026-09-25-divelogs-import-design.md"
```

Record the issue number; the PR body in Task 12 needs `Closes #<number>`.

---

### Task 1: Notice kinds and warning codes for remote sources

Adds three warning codes the divelogs fetch emits, four summary notice kinds (the three plus one the adapter emits for failed downloads), and their summary wording.

**Files:**
- Modify: `lib/features/universal_import/data/models/import_warning.dart` (enum `ImportWarningCode`)
- Modify: `lib/features/import_wizard/domain/models/import_notice.dart` (enum `ImportNoticeKind`)
- Modify: `lib/features/import_wizard/data/adapters/import_notice_grouper.dart` (`_kindFor`)
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` (`_fileNoticeWording`)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/import_wizard/data/adapters/import_notice_grouper_test.dart`
- Test: `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`

**Interfaces:**
- Produces: `ImportWarningCode.gearUnavailable`, `ImportWarningCode.certificationsUnavailable`, `ImportWarningCode.photoListingsUnavailable`; `ImportNoticeKind.gearUnavailable`, `.certificationsUnavailable`, `.photoListingsUnavailable`, `.photosNotDownloaded`.

- [ ] **Step 1: Update the grouper mapping test (failing)**

In `import_notice_grouper_test.dart`, test `'every shown code maps to its own notice kind'`, add to the `expected` map after the `sitesUnresolved` entry:

```dart
      ImportWarningCode.gearUnavailable: ImportNoticeKind.gearUnavailable,
      ImportWarningCode.certificationsUnavailable:
          ImportNoticeKind.certificationsUnavailable,
      ImportWarningCode.photoListingsUnavailable:
          ImportNoticeKind.photoListingsUnavailable,
```

- [ ] **Step 2: Add summary card tests (failing)**

In `import_summary_step_test.dart`, inside `group('ImportSummaryStep - notices', ...)` next to the existing `expectCard` tests (after `'says which dives lost the site the file named'`), add:

```dart
    testWidgets('says gear could not be fetched', (tester) async {
      await expectCard(
        tester,
        const ImportNotice(kind: ImportNoticeKind.gearUnavailable, count: 1),
        title: 'Gear not imported',
        bodyFragment: 'gear list could not be fetched',
        countLine: null,
      );
    });

    testWidgets('says certifications could not be fetched', (tester) async {
      await expectCard(
        tester,
        const ImportNotice(
          kind: ImportNoticeKind.certificationsUnavailable,
          count: 1,
        ),
        title: 'Certifications not imported',
        bodyFragment: 'certification list could not be fetched',
        countLine: null,
      );
    });

    testWidgets('counts dives whose photos could not be listed', (
      tester,
    ) async {
      await expectCard(
        tester,
        const ImportNotice(
          kind: ImportNoticeKind.photoListingsUnavailable,
          count: 4,
        ),
        title: 'Some photos not listed',
        bodyFragment: 'Photos for 4 dives could not be listed',
        countLine: null,
      );
    });

    testWidgets('counts photos that could not be downloaded', (tester) async {
      await expectCard(
        tester,
        const ImportNotice(kind: ImportNoticeKind.photosNotDownloaded, count: 1),
        title: 'Some photos not downloaded',
        bodyFragment: '1 photo could not be downloaded',
        countLine: null,
      );
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/import_notice_grouper_test.dart test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`
Expected: compile errors, "There's no constant named 'gearUnavailable'".

- [ ] **Step 4: Add the warning codes**

In `import_warning.dart`, enum `ImportWarningCode`, insert after `sitesUnresolved,` and before the `diagnostic` doc comment:

```dart
  /// A remote source's gear list could not be fetched, so no gear was
  /// imported and dives carry no gear links.
  gearUnavailable,

  /// A remote source's certification list could not be fetched.
  certificationsUnavailable,

  /// A remote source could not list the photos of some dives.
  /// [ImportWarning.count] is the number of dives.
  photoListingsUnavailable,
```

- [ ] **Step 5: Add the notice kinds**

In `import_notice.dart`, enum `ImportNoticeKind`, insert after `sitesUnresolved,` and before the `diveNumberConflict` doc comment:

```dart
  /// A remote source's gear list could not be fetched, so no gear was
  /// imported. [ImportNotice.count] is always 1.
  gearUnavailable,

  /// A remote source's certification list could not be fetched.
  /// [ImportNotice.count] is always 1.
  certificationsUnavailable,

  /// A remote source could not list some dives' photos, so those photos
  /// were not imported. [ImportNotice.count] is the number of dives.
  photoListingsUnavailable,

  /// Photos a remote source listed that could not be downloaded or saved
  /// at import time. [ImportNotice.count] is the number of photos. Appended
  /// by the adapter after the grouped parser notices, like
  /// [diveNumberConflict].
  photosNotDownloaded,
```

In the same file, getter `countsImportedDives`, extend the `=> false` arm:

```dart
    divesSkipped ||
    unreadableDates ||
    columnsNotImported ||
    valuesNotConverted ||
    photosSkipped ||
    macdiveXmlOmitsCertsAndService ||
    macdiveLogbooksNotImported ||
    gearUnavailable ||
    certificationsUnavailable ||
    photoListingsUnavailable ||
    photosNotDownloaded => false,
```

- [ ] **Step 6: Map the codes in the grouper**

In `import_notice_grouper.dart`, `_kindFor`, add before `ImportWarningCode.diagnostic || null => null,`:

```dart
  ImportWarningCode.gearUnavailable => ImportNoticeKind.gearUnavailable,
  ImportWarningCode.certificationsUnavailable =>
    ImportNoticeKind.certificationsUnavailable,
  ImportWarningCode.photoListingsUnavailable =>
    ImportNoticeKind.photoListingsUnavailable,
```

- [ ] **Step 7: Add the English strings**

In `lib/l10n/arb/app_en.arb`, insert directly after the line `"universalImport_summary_noticeSitesUnresolvedBody": ...,`:

```json
  "universalImport_summary_noticeGearUnavailableTitle": "Gear not imported",
  "universalImport_summary_noticeGearUnavailableBody": "The gear list could not be fetched, so no gear was imported and dives were not linked to their gear. Import again later to add it.",
  "universalImport_summary_noticeCertificationsUnavailableTitle": "Certifications not imported",
  "universalImport_summary_noticeCertificationsUnavailableBody": "The certification list could not be fetched, so no certifications were imported. Import again later to add them.",
  "universalImport_summary_noticePhotoListingsUnavailableTitle": "Some photos not listed",
  "universalImport_summary_noticePhotoListingsUnavailableBody": "{count, plural, one{Photos for {count} dive could not be listed, so they were not imported.} other{Photos for {count} dives could not be listed, so they were not imported.}}",
  "@universalImport_summary_noticePhotoListingsUnavailableBody": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "universalImport_summary_noticePhotosNotDownloadedTitle": "Some photos not downloaded",
  "universalImport_summary_noticePhotosNotDownloadedBody": "{count, plural, one{{count} photo could not be downloaded. Import again to retry; photos already saved are not duplicated.} other{{count} photos could not be downloaded. Import again to retry; photos already saved are not duplicated.}}",
  "@universalImport_summary_noticePhotosNotDownloadedBody": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Run: `flutter gen-l10n`
Expected: succeeds; untranslated-message notes for other locales are fine until Task 11.

- [ ] **Step 8: Add the summary wording**

In `import_summary_step.dart`, `_fileNoticeWording`, add before the `ImportNoticeKind.diveNumberConflict =>` arm:

```dart
    ImportNoticeKind.gearUnavailable => (
      title: l10n.universalImport_summary_noticeGearUnavailableTitle,
      body: l10n.universalImport_summary_noticeGearUnavailableBody,
      action: null,
    ),
    ImportNoticeKind.certificationsUnavailable => (
      title: l10n.universalImport_summary_noticeCertificationsUnavailableTitle,
      body: l10n.universalImport_summary_noticeCertificationsUnavailableBody,
      action: null,
    ),
    ImportNoticeKind.photoListingsUnavailable => (
      title: l10n.universalImport_summary_noticePhotoListingsUnavailableTitle,
      body: l10n.universalImport_summary_noticePhotoListingsUnavailableBody(
        notice.count,
      ),
      action: null,
    ),
    ImportNoticeKind.photosNotDownloaded => (
      title: l10n.universalImport_summary_noticePhotosNotDownloadedTitle,
      body: l10n.universalImport_summary_noticePhotosNotDownloadedBody(
        notice.count,
      ),
      action: null,
    ),
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/import_notice_grouper_test.dart test/features/import_wizard/presentation/widgets/import_summary_step_test.dart test/features/import_wizard/presentation/widgets/missing_dives_card_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/universal_import/data/models/import_warning.dart lib/features/import_wizard/domain/models/import_notice.dart lib/features/import_wizard/data/adapters/import_notice_grouper.dart lib/features/import_wizard/presentation/widgets/import_summary_step.dart lib/l10n/arb/ test/features/import_wizard/data/adapters/import_notice_grouper_test.dart test/features/import_wizard/presentation/widgets/import_summary_step_test.dart
git commit -m "feat(import): notices for remote sources that miss gear, certs or photos"
```

---

### Task 2: Notifier `setExternalPayload` and remote photo state

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_state.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (the two photo providers only)
- Modify: `lib/features/import_wizard/presentation/widgets/photo_folder_step.dart`
- Test: `test/features/universal_import/presentation/providers/universal_import_external_payload_test.dart` (create)
- Test: `test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart` (extend)

**Interfaces:**
- Produces: `UniversalImportState.remotePhotoCount` (`int`, default 0; `copyWith(remotePhotoCount:)`).
- Produces: `Future<void> UniversalImportNotifier.setExternalPayload(ImportPayload payload, {int remotePhotoCount = 0})`. Precondition: `payload.isEmpty == false`.
- Produces: `static bool PhotoFolderStep.canPickFolder` (was private `_canPickFolder`).

- [ ] **Step 1: Write the failing notifier test**

Create `test/features/universal_import/presentation/providers/universal_import_external_payload_test.dart`. Reuse the override set from `test/features/import_wizard/data/adapters/universal_adapter_diver_step_test.dart` (copy its `setUp` with `SharedPreferences.setMockInitialValues({})` and its `ProviderContainer` overrides, including its `_FakeDiveNumbers` repository fake and the provider overrides it lists for trips, sites, equipment, buddies, dive centers, certifications, tags and dive types, since `_checkDuplicates` reads all of them). Then:

```dart
const _payload = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'divelogs-1', 'maxDepth': 12.0},
    ],
    ImportEntityType.sites: [
      {'uddfId': 'divelogs-site-reef', 'name': 'Reef'},
    ],
  },
);

void main() {
  // setUp and containerWith(...) copied from universal_adapter_diver_step_test.dart

  test('installs the payload with every row selected', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);

    await notifier.setExternalPayload(_payload, remotePhotoCount: 3);

    final state = container.read(universalImportNotifierProvider);
    expect(state.payload!.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(state.selectionFor(ImportEntityType.dives), {0});
    expect(state.selectionFor(ImportEntityType.sites), {0});
    expect(state.duplicateResult, isNotNull);
    expect(state.remotePhotoCount, 3);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
  });

  test('clears photo decisions left by an earlier import', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.skipPhotos();

    await notifier.setExternalPayload(_payload, remotePhotoCount: 2);

    final state = container.read(universalImportNotifierProvider);
    expect(state.photosSkipped, isFalse);
    expect(state.bundledPhotoFolderPath, isNull);
    expect(state.photoResolution, isNull);
    expect(state.photoPathsByBaseName, isEmpty);
  });

  test('reset forgets the remote photo count', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);
    await notifier.setExternalPayload(_payload, remotePhotoCount: 2);

    notifier.reset();

    expect(container.read(universalImportNotifierProvider).remotePhotoCount, 0);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_external_payload_test.dart`
Expected: FAIL, "The method 'setExternalPayload' isn't defined".

- [ ] **Step 3: Add `remotePhotoCount` to the state**

In `universal_import_state.dart`:
- constructor: add `this.remotePhotoCount = 0,` after `this.photosSkipped = false,`
- field, after `photosSkipped`:

```dart
  /// Photos a remote source (divelogs.de) listed for the payload's dives.
  /// They are downloaded at import time into [bundledPhotoFolderPath], so a
  /// non-zero count puts the Photos step in front of the user exactly as
  /// ZIP-bundled photos do.
  final int remotePhotoCount;
```

- `copyWith` parameter: `int? remotePhotoCount,` after `bool? photosSkipped,`
- `copyWith` body: `remotePhotoCount: remotePhotoCount ?? this.remotePhotoCount,` after the `photosSkipped:` line.

- [ ] **Step 4: Factor the install step and add `setExternalPayload`**

In `universal_import_providers.dart`, replace the tail of `_parseAndCheckDuplicates` (from `final dupResult = await _checkDuplicatesOrEmpty(payload);` to the closing `state = state.copyWith(...);`) with:

```dart
    await _installPayload(payload);
  }

  /// Duplicate-checks [payload] and makes it the one the review steps act
  /// on, with every row selected except the duplicates. Shared by file
  /// parsing and [setExternalPayload] so both leave the notifier in the
  /// same state.
  Future<void> _installPayload(
    ImportPayload payload, {
    int remotePhotoCount = 0,
  }) async {
    final dupResult = await _checkDuplicatesOrEmpty(payload);
    final selections = _defaultSelections(payload, dupResult);

    state = state.copyWith(
      isLoading: false,
      payload: payload,
      clearDiverMapping: true,
      duplicateResult: dupResult,
      selections: selections,
      currentStep: ImportWizardStep.review,
      remotePhotoCount: remotePhotoCount,
    );
  }

  /// Installs a payload built outside file parsing, by a source that
  /// fetches it itself (divelogs.de).
  ///
  /// Goes through the same surfacing-pressure rule and duplicate check a
  /// parsed file does. Photo decisions from any earlier import are cleared,
  /// and [remotePhotoCount] tells the Photos step how many photos the
  /// source will download at import time. The caller only hands over a
  /// payload with something in it; an empty fetch is its own message.
  Future<void> setExternalPayload(
    ImportPayload payload, {
    int remotePhotoCount = 0,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      photoPathsByBaseName: const {},
      unmatchedPhotoCount: 0,
      photosSkipped: false,
      clearPhotoResolution: true,
      clearPhotoFolderPath: true,
      clearBundledPhotoFolderPath: true,
    );
    await _installPayload(
      _applySurfacingPressureRule(payload),
      remotePhotoCount: remotePhotoCount,
    );
  }
```

Note: `_parseAndCheckDuplicates` passes no `remotePhotoCount`, so a file parse resets it to 0.

- [ ] **Step 5: Run the notifier test**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_external_payload_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing Photos step test**

In `test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart`, add a test using the file's existing harness that seeds notifier state through `setExternalPayload` with a payload of one dive and `remotePhotoCount: 5`, then asserts:
- `universalAdapterNoPhotosProvider` reads `false`;
- `universalAdapterPhotosReadyProvider` reads `false` before a destination is chosen;
- the step shows the bundled-photo destination UI (the widget that uses `l10n.importWizard_photos_...` for bundled photos: find the text the existing bundled-photo test asserts and assert the same text appears);
- after `notifier.chooseBundledPhotoFolder(tempDir.path)` (the file's write-probe override accepting it), `universalAdapterPhotosReadyProvider` reads `true`.

Use the same `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` setup the existing bundled-photo test uses.

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart`
Expected: FAIL on `universalAdapterNoPhotosProvider` being `true`.

- [ ] **Step 8: Count remote photos in the Photos gates and step**

In `universal_adapter.dart`, replace `universalAdapterNoPhotosProvider` and `universalAdapterPhotosReadyProvider` bodies:

```dart
final universalAdapterNoPhotosProvider = Provider<bool>((ref) {
  final payload = ref.watch(
    universalImportNotifierProvider.select((s) => s.payload),
  );
  final bundled = ref.watch(
    universalImportNotifierProvider.select((s) => s.photoPathsByBaseName),
  );
  final remote = ref.watch(
    universalImportNotifierProvider.select((s) => s.remotePhotoCount),
  );
  final referenced = payload?.entitiesOf(ui.ImportEntityType.media) ?? const [];
  return referenced.isEmpty && !_hasBundledPhotos(bundled) && remote == 0;
});
```

```dart
final universalAdapterPhotosReadyProvider = Provider<bool>((ref) {
  if (ref.watch(universalAdapterNoPhotosProvider)) return true;
  final state = ref.watch(universalImportNotifierProvider);
  if (state.photosSkipped) return true;
  final referenced =
      state.payload?.entitiesOf(ui.ImportEntityType.media) ?? const [];
  final referencedReady = referenced.isEmpty || state.photoResolution != null;
  // Remote photos are written into the same chosen folder as bundled ones.
  final needsDestination =
      _hasBundledPhotos(state.photoPathsByBaseName) ||
      state.remotePhotoCount > 0;
  final bundledReady =
      !needsDestination || state.bundledPhotoFolderPath != null;
  return referencedReady && bundledReady;
});
```

Update the doc comment of `universalAdapterNoPhotosProvider` to say "no imported archive bundled any, and no remote source listed any".

In `photo_folder_step.dart`:
- rename `static bool get _canPickFolder` to `static bool get canPickFolder` and update every use in the file;
- change `bundledCount` to include remote photos:

```dart
    final bundledCount =
        state.photoPathsByBaseName.values.fold<int>(
          0,
          (sum, paths) => sum + paths.length,
        ) +
        state.remotePhotoCount;
```

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart test/features/universal_import/ test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/universal_import/presentation/providers/ lib/features/import_wizard/data/adapters/universal_adapter.dart lib/features/import_wizard/presentation/widgets/photo_folder_step.dart test/features/universal_import/presentation/providers/universal_import_external_payload_test.dart test/features/import_wizard/presentation/widgets/photo_folder_step_test.dart
git commit -m "feat(import): install externally fetched payloads and count remote photos"
```

---

### Task 3: Remote photo attacher

A pure function that downloads each listed photo for the dives that survived the import and hands it to an attach callback. No Riverpod, no database.

**Files:**
- Create: `lib/features/import_wizard/data/adapters/remote_photo_attacher.dart`
- Test: `test/features/import_wizard/data/adapters/remote_photo_attacher_test.dart`

**Interfaces:**
- Produces:

```dart
class RemotePhoto {
  const RemotePhoto({required this.url, required this.fileName});
  final Uri url;
  final String fileName;
}

typedef RemotePhotoOutcome = ({int attached, int failed});

Future<RemotePhotoOutcome> attachRemotePhotos({
  required Map<String, List<RemotePhoto>> photosBySourceUuid,
  required Map<int, String> diveIdByIndex,
  required Set<String> removedDiveIds,
  required List<Map<String, dynamic>> dives,
  required Map<String, DateTime> diveStartById,
  required Future<Uint8List> Function(Uri url) download,
  required Future<void> Function(File file, String diveId, DateTime? diveStart)
  attach,
  ImportCancellationToken? cancelToken,
});
```

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

RemotePhoto _photo(String name) => RemotePhoto(
  url: Uri.parse('https://divelogs.de/pics/$name'),
  fileName: name,
);

void main() {
  final start = DateTime.utc(2024, 5, 1, 9);

  test('downloads and attaches photos of surviving dives only', () async {
    final attached = <(String, String, List<int>)>[];
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
        'divelogs-2': [_photo('b.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1', 1: 'dive-2'},
      removedDiveIds: const {'dive-2'},
      dives: [
        {'sourceUuid': 'divelogs-1', 'dateTime': start},
        {'sourceUuid': 'divelogs-2', 'dateTime': start},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([1, 2, 3]),
      attach: (file, diveId, diveStart) async {
        attached.add((diveId, p.basename(file.path), await file.readAsBytes()));
        expect(diveStart, start);
      },
    );

    expect(outcome, (attached: 1, failed: 0));
    expect(attached.single.$1, 'dive-1');
    expect(attached.single.$2, 'a.jpg');
    expect(attached.single.$3, [1, 2, 3]);
  });

  test('prefers the existing dive start for a matched duplicate', () async {
    final existingStart = DateTime.utc(2024, 5, 1, 9, 5);
    DateTime? seen;
    await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
      },
      diveIdByIndex: const {0: 'existing-dive'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1', 'dateTime': start},
      ],
      diveStartById: {'existing-dive': existingStart},
      download: (url) async => Uint8List.fromList([1]),
      attach: (file, diveId, diveStart) async => seen = diveStart,
    );
    expect(seen, existingStart);
  });

  test('two photos with the same name on one dive both attach', () async {
    final names = <String>[];
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('same.jpg'), _photo('same.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([names.length]),
      attach: (file, diveId, diveStart) async {
        names.add(p.basename(file.path));
        expect(file.existsSync(), isTrue);
      },
    );
    expect(outcome.attached, 2);
    expect(names, ['same.jpg', 'same.jpg']);
  });

  test('a failed download is counted and the rest continue', () async {
    var calls = 0;
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('bad.jpg'), _photo('good.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async {
        if (url.path.endsWith('bad.jpg')) throw Exception('401');
        return Uint8List.fromList([1]);
      },
      attach: (file, diveId, diveStart) async => calls++,
    );
    expect(outcome, (attached: 1, failed: 1));
    expect(calls, 1);
  });

  test('a failed attach is counted as failed', () async {
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([1]),
      attach: (file, diveId, diveStart) async => throw const FileSystemException('disk full'),
    );
    expect(outcome, (attached: 0, failed: 1));
  });

  test('stops downloading once cancelled', () async {
    final token = ImportCancellationToken();
    var downloads = 0;
    await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg'), _photo('b.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async {
        downloads++;
        token.cancel();
        return Uint8List.fromList([1]);
      },
      attach: (file, diveId, diveStart) async {},
      cancelToken: token,
    );
    expect(downloads, 1);
  });

  test('leaves no temp files behind', () async {
    final seen = <String>[];
    await attachRemotePhotos(
      photosBySourceUuid: {
        'divelogs-1': [_photo('a.jpg')],
      },
      diveIdByIndex: const {0: 'dive-1'},
      removedDiveIds: const {},
      dives: [
        {'sourceUuid': 'divelogs-1'},
      ],
      diveStartById: const {},
      download: (url) async => Uint8List.fromList([1]),
      attach: (file, diveId, diveStart) async => seen.add(file.parent.parent.path),
    );
    expect(Directory(seen.single).existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/import_wizard/data/adapters/remote_photo_attacher_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Implement**

Create `lib/features/import_wizard/data/adapters/remote_photo_attacher.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

const _log = LoggerService('RemotePhotoAttacher');

/// A photo a remote source listed for one of its dives, not yet downloaded.
class RemotePhoto {
  const RemotePhoto({required this.url, required this.fileName});

  /// Where the bytes are fetched from.
  final Uri url;

  /// The name the photo is saved under in the user's folder.
  final String fileName;
}

/// Photos attached, and photos that could not be downloaded or attached.
typedef RemotePhotoOutcome = ({int attached, int failed});

/// Downloads the photos of every dive that survived the import and hands
/// each to [attach] as a temp file.
///
/// Photos are keyed by the payload dive's `sourceUuid`, so the mapping holds
/// however the payload was re-indexed. [diveIdByIndex] maps payload dive
/// index to the dive the photo belongs on, which for a skipped or
/// consolidated duplicate is the existing dive it matched; a dive in
/// [removedDiveIds] was folded away and gets nothing. Each temp file sits in
/// its own folder, so two photos with the same name never collide, and the
/// whole temp tree is deleted before returning. A failure costs only that
/// photo: it is counted and the loop moves on, so photos can never fail an
/// import.
Future<RemotePhotoOutcome> attachRemotePhotos({
  required Map<String, List<RemotePhoto>> photosBySourceUuid,
  required Map<int, String> diveIdByIndex,
  required Set<String> removedDiveIds,
  required List<Map<String, dynamic>> dives,
  required Map<String, DateTime> diveStartById,
  required Future<Uint8List> Function(Uri url) download,
  required Future<void> Function(File file, String diveId, DateTime? diveStart)
  attach,
  ImportCancellationToken? cancelToken,
}) async {
  if (photosBySourceUuid.isEmpty || diveIdByIndex.isEmpty) {
    return (attached: 0, failed: 0);
  }
  final tempRoot = await Directory.systemTemp.createTemp('remote_photos_');
  var attached = 0;
  var failed = 0;
  var slot = 0;
  try {
    for (final entry in diveIdByIndex.entries) {
      final diveId = entry.value;
      if (removedDiveIds.contains(diveId)) continue;
      if (entry.key < 0 || entry.key >= dives.length) continue;
      final dive = dives[entry.key];
      final photos = photosBySourceUuid[dive['sourceUuid']];
      if (photos == null) continue;
      final diveStart =
          diveStartById[diveId] ?? dive['dateTime'] as DateTime?;
      for (final photo in photos) {
        if (cancelToken?.isCancelled ?? false) {
          return (attached: attached, failed: failed);
        }
        try {
          final bytes = await download(photo.url);
          final dir = Directory(p.join(tempRoot.path, '${slot++}'));
          await dir.create();
          final file = File(p.join(dir.path, photo.fileName));
          await file.writeAsBytes(bytes, flush: true);
          await attach(file, diveId, diveStart);
          attached++;
        } catch (e) {
          failed++;
          _log.warning('Could not attach remote photo ${photo.fileName}: $e');
        }
      }
    }
    return (attached: attached, failed: failed);
  } finally {
    try {
      await tempRoot.delete(recursive: true);
    } catch (e) {
      _log.warning('Could not delete remote photo temp folder: $e');
    }
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/import_wizard/data/adapters/remote_photo_attacher_test.dart`
Expected: PASS. If `LoggerService`'s constructor signature differs, match how `universal_adapter.dart` declares `_log`.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/data/adapters/remote_photo_attacher.dart test/features/import_wizard/data/adapters/remote_photo_attacher_test.dart
git commit -m "feat(import): download listed remote photos for the dives that survive an import"
```

---

### Task 4: UniversalAdapter extension points

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/universal_adapter_extension_points_test.dart` (create)

**Interfaces:**
- Produces (on `UniversalAdapter`):

```dart
@protected
List<WizardStepDef> get payloadSteps; // [Divers, Photos]

@protected
Future<RemotePhotoOutcome> attachAdditionalPhotos({
  required Map<int, String> photoDiveIds,
  required Set<String> removedDiveIds,
  required Map<String, DateTime> diveStartById,
  required List<Map<String, dynamic>> dives,
  required String destinationDir,
  ImportCancellationToken? cancelToken,
}); // default returns (attached: 0, failed: 0)
```

- `buildBundle` reports `sourceType` (the getter) instead of the literal `ImportSourceType.universal`.
- `performImport` adds the hook's `attached` to `attachedPhotoCount`, and appends `ImportNotice(kind: ImportNoticeKind.photosNotDownloaded, count: failed)` when `failed > 0`, before the dive-number conflict notice.

- [ ] **Step 1: Write the failing test**

Create `universal_adapter_extension_points_test.dart`. Obtain a `WidgetRef` the way `universal_adapter_diver_step_test.dart` does (pump a `Consumer` inside `UncontrolledProviderScope` and capture `ref`). Tests:

```dart
  testWidgets('file steps come first, then the payload steps', (tester) async {
    final adapter = await pumpAdapter(tester); // captures UniversalAdapter(ref: ref)
    expect(
      adapter.acquisitionSteps.map((s) => s.label).toList(),
      ['Select File', 'Confirm Source', 'Map Fields', 'Divers', 'Photos'],
    );
    expect(
      adapter.debugPayloadStepLabels,
      ['Divers', 'Photos'],
    );
  });

  testWidgets('the default photo hook attaches nothing', (tester) async {
    final adapter = await pumpAdapter(tester);
    final outcome = await adapter.debugAttachAdditionalPhotos();
    expect(outcome, (attached: 0, failed: 0));
  });
```

Add these two `@visibleForTesting` members to `UniversalAdapter` in Step 3 so the test can reach the protected API without a subclass:

```dart
  @visibleForTesting
  List<String> get debugPayloadStepLabels =>
      payloadSteps.map((s) => s.label).toList();

  @visibleForTesting
  Future<RemotePhotoOutcome> debugAttachAdditionalPhotos() =>
      attachAdditionalPhotos(
        photoDiveIds: const {},
        removedDiveIds: const {},
        diveStartById: const {},
        dives: const [],
        destinationDir: '',
      );
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_extension_points_test.dart`
Expected: FAIL, "The getter 'debugPayloadStepLabels' isn't defined".

- [ ] **Step 3: Split the step list and add the hook**

In `universal_adapter.dart`:
1. Add imports: `import 'package:flutter/foundation.dart';` (if not already imported; it provides `protected` and `visibleForTesting`) and `import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';` plus `import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';` if not present.
2. Move the `Divers` and `Photos` `WizardStepDef`s out of `acquisitionSteps` into:

```dart
  /// The steps that act on a payload once it exists, whatever produced it.
  /// A subclass that fetches its payload rather than parsing a file keeps
  /// these after its own acquisition steps.
  @protected
  List<WizardStepDef> get payloadSteps => [
    // (the existing Divers WizardStepDef, unchanged)
    // (the existing Photos WizardStepDef, unchanged)
  ];
```

and end `acquisitionSteps` with `...payloadSteps,` after the Map Fields step.
3. Add the hook and the two debug members from Step 1:

```dart
  /// Attaches photos this source brings that neither the archive-bundled nor
  /// the path-referenced flow covers. Runs after both, with the same dive
  /// targets, and only when the user chose a destination folder.
  ///
  /// Returns what was attached and what failed; a failure is reported in the
  /// summary and never fails the import. File imports have none.
  @protected
  Future<RemotePhotoOutcome> attachAdditionalPhotos({
    required Map<int, String> photoDiveIds,
    required Set<String> removedDiveIds,
    required Map<String, DateTime> diveStartById,
    required List<Map<String, dynamic>> dives,
    required String destinationDir,
    ImportCancellationToken? cancelToken,
  }) async => (attached: 0, failed: 0);
```

4. In `buildBundle`, change the non-null-payload `ImportSourceInfo(type: ImportSourceType.universal, ...)` to `type: sourceType,`.
5. In `performImport`, after the resolved-photos block (`resolvedPhotos = attached - linker.alreadyLinked; }`), add:

```dart
    // Photos a remote source listed, downloaded now into the same folder
    // the bundled flow uses.
    var additional = (attached: 0, failed: 0);
    if (bundledFolder != null && notifierState.remotePhotoCount > 0) {
      additional = await attachAdditionalPhotos(
        photoDiveIds: photoDiveIds,
        removedDiveIds: removedDiveIds,
        diveStartById: diveStartById,
        dives: payload.entitiesOf(ui.ImportEntityType.dives),
        destinationDir: bundledFolder,
        cancelToken: cancelToken,
      );
    }
```

6. Change the notices list to:

```dart
    final notices = [
      ...groupImportNotices(payload.warnings, netDives),
      if (additional.failed > 0)
        ImportNotice(
          kind: ImportNoticeKind.photosNotDownloaded,
          count: additional.failed,
        ),
      ?numberConflict,
    ];
```

7. Change `attachedPhotoCount:` to `attachedPhotos + resolvedPhotos + additional.attached,`.

- [ ] **Step 4: Run the new test and the whole adapter suite**

Run: `flutter test test/features/import_wizard/`
Expected: PASS (existing UniversalAdapter tests unchanged in behaviour).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/import_wizard/data/adapters/universal_adapter_extension_points_test.dart
git commit -m "refactor(import): expose payload steps and a photo hook on UniversalAdapter"
```

---

### Task 5: divelogs models and dive mapper

**Files:**
- Create: `lib/core/services/divelogs/divelogs_models.dart` (ported)
- Create: `lib/features/universal_import/data/services/divelogs_dive_mapper.dart` (ported, changed)
- Create: `lib/features/universal_import/data/services/divelogs_reference_mappers.dart` (ported, moved)
- Test: `test/core/services/divelogs/divelogs_models_test.dart` (ported)
- Test: `test/features/universal_import/data/services/divelogs_dive_mapper_test.dart` (ported, changed)
- Test: `test/features/universal_import/data/services/divelogs_reference_mappers_test.dart` (ported)

**Interfaces:**
- Produces: `DivelogsDive`, `DivelogsTank`, `DivelogsSample`, `DivelogsDivesResult`, `DivelogsGearItem`, `DivelogsCertification`, `DivelogsPicture` (fields as in `$OLD`).
- Produces: `DivelogsDiveMapper` with `static String siteKey(String name)`, `static String gearKey(String id)`, `static String sourceUuidFor(String id)` (returns `'divelogs-$id'`), `Map<String, dynamic> mapDive(DivelogsDive)`, `Map<String, dynamic>? mapSite(DivelogsDive)`.
- Produces: `DivelogsReferenceMappers.equipmentTypeForGeartypeName`, `.agencyForOrg`, `.levelForName`.

- [ ] **Step 1: Port the files from the old branch**

```bash
OLD=28c9c842fa8006d90ccdc2a0bcfe6fb7c7dd0e4e
mkdir -p lib/core/services/divelogs test/core/services/divelogs test/features/universal_import/data/services
git show "${OLD}:lib/core/services/divelogs/divelogs_models.dart" > lib/core/services/divelogs/divelogs_models.dart
git show "${OLD}:test/core/services/divelogs/divelogs_models_test.dart" > test/core/services/divelogs/divelogs_models_test.dart
git show "${OLD}:lib/features/universal_import/data/services/divelogs_dive_mapper.dart" > lib/features/universal_import/data/services/divelogs_dive_mapper.dart
git show "${OLD}:test/features/universal_import/data/services/divelogs_dive_mapper_test.dart" > test/features/universal_import/data/services/divelogs_dive_mapper_test.dart
git show "${OLD}:lib/features/divelogs_sync/data/mappers/divelogs_reference_mappers.dart" > lib/features/universal_import/data/services/divelogs_reference_mappers.dart
git show "${OLD}:test/features/divelogs_sync/data/mappers/divelogs_reference_mappers_test.dart" > test/features/universal_import/data/services/divelogs_reference_mappers_test.dart
```

(Quote `"${OLD}:..."` exactly: in zsh an unbraced `$OLD:l...` is parsed as a modifier.)

- [ ] **Step 2: Trim the push-only code**

- `divelogs_models.dart`: delete the classes `DivelogsDivelistEntry` and `DivelogsDivelistResult` and the doc comments directly above each.
- `divelogs_models_test.dart`: delete `group('DivelogsDivelistEntry', ...)`.
- `divelogs_reference_mappers.dart`: delete `geartypeIdForEquipmentType` and `geartypeNameForEquipmentType` with their doc comments.
- `divelogs_reference_mappers_test.dart`: fix the import to `package:submersion/features/universal_import/data/services/divelogs_reference_mappers.dart` and delete `group('geartypeIdForEquipmentType', ...)`.

Run: `flutter test test/core/services/divelogs/divelogs_models_test.dart test/features/universal_import/data/services/divelogs_reference_mappers_test.dart`
Expected: PASS.

- [ ] **Step 3: Change the mapper tests to the new contract (failing)**

In `divelogs_dive_mapper_test.dart`:
- change `expect(map['sourceUuid'], 'divelogs:4711');` to `expect(map['sourceUuid'], 'divelogs-4711');`
- replace the test `'no site when name missing'` with:

```dart
  test('a nameless site with coordinates is named from them', () {
    final dive = DivelogsDive.fromJson({
      ...baseJson, // the minimal dive map the file's other tests build on
      'divesite': '',
      'lat': 24.6,
      'lng': 35.1,
    });
    final site = const DivelogsDiveMapper().mapSite(dive)!;
    expect(site['name'], isNotEmpty);
    expect(site['latitude'], 24.6);
    expect(site['longitude'], 35.1);
    final mapped = const DivelogsDiveMapper().mapDive(dive);
    expect((mapped['site'] as Map)['uddfId'], site['uddfId']);
  });

  test('no site when neither name nor usable coordinates', () {
    final dive = DivelogsDive.fromJson({
      ...baseJson,
      'divesite': '',
      'lat': 0,
      'lng': 0,
    });
    expect(const DivelogsDiveMapper().mapSite(dive), isNull);
    final mapped = const DivelogsDiveMapper().mapDive(dive);
    expect(mapped.containsKey('site'), isFalse);
    expect(mapped.containsKey('latitude'), isFalse);
  });
```

If the file has no shared `baseJson`, add one at the top of `main()` with the mandatory fields its first test uses (`id`, `date`, `time`, `duration`, `maxdepth`).

Run: `flutter test test/features/universal_import/data/services/divelogs_dive_mapper_test.dart`
Expected: FAIL on the sourceUuid and the nameless-site tests.

- [ ] **Step 4: Rewrite the mapper's id and site handling**

In `divelogs_dive_mapper.dart`:
1. Add `import 'package:submersion/features/universal_import/data/services/import_site_location.dart';`
2. Add:

```dart
  /// The dive's source id. Namespaced with a dash, never a colon: the
  /// duplicate checker's exact-match pass only reads source ids that
  /// contain one (`DiveRepository._looksLikeSourceUuid`).
  static String sourceUuidFor(String id) => 'divelogs-$id';
```

3. In `mapDive`, replace `if (dive.id != null) map['sourceUuid'] = 'divelogs:${dive.id}';` with `if (dive.id != null) map['sourceUuid'] = sourceUuidFor(dive.id!);`
4. Replace the dive coordinate block and the site block in `mapDive`:

```dart
    final fix = ImportSiteLocation.fix(dive.latitude, dive.longitude);
    if (fix != null) {
      map['latitude'] = fix.latitude;
      map['longitude'] = fix.longitude;
    }
```

```dart
    final site = mapSite(dive);
    if (site != null) {
      map['siteName'] = site['name'];
      map['site'] = <String, dynamic>{
        'uddfId': site['uddfId'],
        'name': site['name'],
      };
    }
```

5. Replace `mapSite`:

```dart
  /// Site entity map for the payload, or null when the dive names no site
  /// and has no usable coordinates. A site with coordinates but no name is
  /// named from them, per the import site contract.
  Map<String, dynamic>? mapSite(DivelogsDive dive) {
    final fix = ImportSiteLocation.fix(dive.latitude, dive.longitude);
    final named = ImportSiteLocation.named(<String, dynamic>{
      'name': dive.siteName,
      if (fix != null) 'latitude': fix.latitude,
      if (fix != null) 'longitude': fix.longitude,
    });
    if (named == null) return null;
    return <String, dynamic>{
      ...named,
      'uddfId': siteKey(named['name'] as String),
    };
  }
```

- [ ] **Step 5: Run mapper tests and the site-contract guard**

Run: `flutter test test/features/universal_import/data/services/divelogs_dive_mapper_test.dart test/architecture/import_site_location_contract_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/services/divelogs/divelogs_models.dart lib/features/universal_import/data/services/divelogs_dive_mapper.dart lib/features/universal_import/data/services/divelogs_reference_mappers.dart test/core/services/divelogs/divelogs_models_test.dart test/features/universal_import/data/services/divelogs_dive_mapper_test.dart test/features/universal_import/data/services/divelogs_reference_mappers_test.dart
git commit -m "feat(divelogs): models and mappers for importing a divelogs.de logbook"
```

---

### Task 6: Session store, auth, API client, import service

**Files:**
- Create: `lib/core/services/divelogs/divelogs_session_store.dart`
- Create: `lib/core/services/divelogs/divelogs_auth.dart`
- Create: `lib/core/services/divelogs/divelogs_api_client.dart` (ported, trimmed)
- Create: `lib/features/universal_import/data/services/divelogs_import_service.dart` (rewritten)
- Test: `test/core/services/divelogs/divelogs_session_store_test.dart`
- Test: `test/core/services/divelogs/divelogs_auth_test.dart`
- Test: `test/core/services/divelogs/divelogs_api_client_test.dart` (ported, trimmed)
- Test: `test/features/universal_import/data/services/divelogs_import_service_test.dart`
- Test: `test/features/universal_import/data/services/divelogs_pass_zero_test.dart`

**Interfaces:**
- Produces:

```dart
class DivelogsSession { const DivelogsSession({required String username, required String token}); final String username; final String token; }
class DivelogsSessionStore {
  DivelogsSessionStore({FlutterSecureStorage? storage});
  static const String storageKey = 'divelogs_session';
  Future<DivelogsSession?> load();
  Future<void> save(DivelogsSession session);
  Future<void> clear();
}

class DivelogsAuthException implements Exception { const DivelogsAuthException(this.reason); final DivelogsAuthFailure reason; }
enum DivelogsAuthFailure { badCredentials, unreachable, unexpectedResponse }
class DivelogsSessionExpiredException implements Exception { const DivelogsSessionExpiredException(); }

class DivelogsAuth {
  DivelogsAuth({required http.Client httpClient, required DivelogsSessionStore store, Uri? loginUri});
  String? get username;
  Future<void> signIn(String username, String password);
  Future<bool> restore();
  Future<String> getToken();
  void invalidateToken();
  Future<void> signOut();
}

class DivelogsApiException implements Exception { final int statusCode; final String message; }
class DivelogsApiClient {
  DivelogsApiClient({required Future<String> Function() getBearerToken, required void Function() onTokenRejected, http.Client? httpClient, Uri? baseUri});
  Future<Map<String, dynamic>> getUser();
  Future<DivelogsDivesResult> getAllDives();
  Future<List<DivelogsGearItem>> getGear();
  Future<List<DivelogsCertification>> getCertifications();
  Future<Map<int, String>> getGeartypes();
  Future<List<DivelogsPicture>> getPictures(String diveId);
  Future<Uint8List> downloadPictureBytes(Uri url);
}

class DivelogsFetchResult {
  final ImportPayload payload;
  final Map<String, List<RemotePhoto>> photosBySourceUuid;
  final int diveCount;
  final int skippedDives;
  final bool gearUnavailable;
  final bool certificationsUnavailable;
  final int photoListingFailures;
  int get photoCount;
}
class DivelogsImportService {
  DivelogsImportService({required DivelogsApiClient api, DivelogsDiveMapper mapper = const DivelogsDiveMapper()});
  Future<DivelogsFetchResult> fetchLogbook({required bool includePhotos, void Function(int current, int total)? onPhotoListingProgress});
}
String remotePhotoFileName(DivelogsPicture picture, {required String remoteDiveId, required int index});
```

- [ ] **Step 1: Session store test (failing)**

Create `test/core/services/divelogs/divelogs_session_store_test.dart` modeled on `test/core/services/suunto_cloud/suunto_session_store_test.dart` (same `InMemoryKeychain` from `test/support/fake_keychain_storage.dart`):

```dart
void main() {
  late InMemoryKeychain storage;
  late DivelogsSessionStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = DivelogsSessionStore(storage: storage);
  });

  test('load returns null when nothing stored', () async {
    expect(await store.load(), isNull);
  });

  test('round-trips username and token and never a password', () async {
    await store.save(const DivelogsSession(username: 'rainer', token: 'jwt'));
    final loaded = await store.load();
    expect(loaded!.username, 'rainer');
    expect(loaded.token, 'jwt');
    final raw = await storage.read(key: DivelogsSessionStore.storageKey);
    expect(jsonDecode(raw!), {'username': 'rainer', 'token': 'jwt'});
  });

  test('a corrupt blob loads as null but is left in place', () async {
    await storage.write(key: DivelogsSessionStore.storageKey, value: 'x');
    expect(await store.load(), isNull);
    expect(await storage.read(key: DivelogsSessionStore.storageKey), 'x');
  });

  test('clear removes the blob', () async {
    await store.save(const DivelogsSession(username: 'a', token: 'b'));
    await store.clear();
    expect(await store.load(), isNull);
  });
}
```

Run: `flutter test test/core/services/divelogs/divelogs_session_store_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 2: Implement the session store**

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// A cached divelogs.de session: the JWT and the username shown in the
/// sign-in step. The password is never persisted.
class DivelogsSession {
  const DivelogsSession({required this.username, required this.token});

  final String username;
  final String token;

  Map<String, Object?> toJson() => {'username': username, 'token': token};
}

/// Persists the divelogs.de session as one JSON blob in the platform
/// keychain, mirroring `SuuntoSessionStore`. A corrupt blob is left in
/// place rather than deleted; [save] overwrites it.
class DivelogsSessionStore {
  DivelogsSessionStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'divelogs_session';

  /// The stored session, or null when unset or the blob is corrupt.
  Future<DivelogsSession?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final username = decoded['username'];
      final token = decoded['token'];
      if (username is! String || token is! String) return null;
      return DivelogsSession(username: username, token: token);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(DivelogsSession session) =>
      _storage.write(key: storageKey, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
```

Run the test. Expected: PASS.

- [ ] **Step 3: Auth tests (failing)**

Create `test/core/services/divelogs/divelogs_auth_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late DivelogsSessionStore store;
  var logins = 0;

  setUp(() {
    store = DivelogsSessionStore(storage: InMemoryKeychain());
    logins = 0;
  });

  http.Client loginClient({int status = 200, String token = 'jwt-1'}) =>
      MockClient((req) async {
        expect(req.url.path, '/api/login');
        logins++;
        return http.Response(jsonEncode({'bearer_token': '$token-$logins'}), status);
      });

  test('signIn stores username and token, never the password', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    await auth.signIn('rainer', 'secret');
    final saved = await store.load();
    expect(saved!.username, 'rainer');
    expect(saved.token, 'jwt-1-1');
    expect(auth.username, 'rainer');
    expect(await auth.getToken(), 'jwt-1-1');
  });

  test('signIn maps 401 to badCredentials', () async {
    final auth = DivelogsAuth(httpClient: loginClient(status: 401), store: store);
    await expectLater(
      auth.signIn('rainer', 'wrong'),
      throwsA(
        isA<DivelogsAuthException>().having(
          (e) => e.reason,
          'reason',
          DivelogsAuthFailure.badCredentials,
        ),
      ),
    );
    expect(await store.load(), isNull);
  });

  test('signIn maps a network error to unreachable', () async {
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => throw http.ClientException('down')),
      store: store,
    );
    await expectLater(
      auth.signIn('rainer', 'secret'),
      throwsA(
        isA<DivelogsAuthException>().having(
          (e) => e.reason,
          'reason',
          DivelogsAuthFailure.unreachable,
        ),
      ),
    );
  });

  test('restore reads the cached session without the network', () async {
    await store.save(const DivelogsSession(username: 'rainer', token: 'cached'));
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => fail('no network expected')),
      store: store,
    );
    expect(await auth.restore(), isTrue);
    expect(auth.username, 'rainer');
    expect(await auth.getToken(), 'cached');
  });

  test('after a 401 a signed-in auth logs in again once', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    await auth.signIn('rainer', 'secret');
    auth.invalidateToken();
    final tokens = await Future.wait([auth.getToken(), auth.getToken()]);
    expect(tokens, ['jwt-1-2', 'jwt-1-2']);
    expect(logins, 2);
  });

  test('a restored session that is rejected expires and is cleared', () async {
    await store.save(const DivelogsSession(username: 'rainer', token: 'cached'));
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => fail('no password to log in with')),
      store: store,
    );
    await auth.restore();
    auth.invalidateToken();
    await expectLater(
      auth.getToken(),
      throwsA(isA<DivelogsSessionExpiredException>()),
    );
    expect(await store.load(), isNull);
  });

  test('signOut clears the stored session and the password', () async {
    final auth = DivelogsAuth(httpClient: loginClient(), store: store);
    await auth.signIn('rainer', 'secret');
    await auth.signOut();
    expect(await store.load(), isNull);
    await expectLater(
      auth.getToken(),
      throwsA(isA<DivelogsSessionExpiredException>()),
    );
  });
}
```

Run: `flutter test test/core/services/divelogs/divelogs_auth_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 4: Implement auth**

Create `lib/core/services/divelogs/divelogs_auth.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';

/// Why a divelogs.de sign-in failed.
enum DivelogsAuthFailure { badCredentials, unreachable, unexpectedResponse }

class DivelogsAuthException implements Exception {
  const DivelogsAuthException(this.reason);

  final DivelogsAuthFailure reason;

  @override
  String toString() => 'DivelogsAuthException(${reason.name})';
}

/// The session is gone and there is no password in memory to renew it:
/// the user has to sign in again.
class DivelogsSessionExpiredException implements Exception {
  const DivelogsSessionExpiredException();

  @override
  String toString() => 'DivelogsSessionExpiredException';
}

/// Owns the divelogs.de JWT for one import wizard run.
///
/// divelogs.de has no OAuth: POST /login with username and password returns
/// a JWT. The token and username are cached in the keychain; the password
/// is kept in memory only, for this object's lifetime, so a token that
/// expires mid-import can be renewed without asking again. A session
/// restored from the keychain has no password, so when its token is
/// rejected the session is cleared and the user signs in again.
class DivelogsAuth {
  DivelogsAuth({
    required http.Client httpClient,
    required DivelogsSessionStore store,
    Uri? loginUri,
  }) : _http = httpClient,
       _store = store,
       _loginUri = loginUri ?? Uri.parse('https://divelogs.de/api/login');

  final http.Client _http;
  final DivelogsSessionStore _store;
  final Uri _loginUri;

  String? _username;
  String? _password;
  String? _token;
  Future<String>? _renewal;

  String? get username => _username;

  /// Logs in and caches the session. Throws [DivelogsAuthException].
  Future<void> signIn(String username, String password) async {
    final token = await _login(username, password);
    _username = username;
    _password = password;
    _token = token;
    await _store.save(DivelogsSession(username: username, token: token));
  }

  /// Loads a cached session. True when one exists; its token may still be
  /// rejected by the server, which the caller finds out on first use.
  Future<bool> restore() async {
    final session = await _store.load();
    if (session == null) return false;
    _username = session.username;
    _token = session.token;
    return true;
  }

  /// The current token, renewing it once (single-flight) when a 401
  /// invalidated it and the password is known.
  Future<String> getToken() async {
    final token = _token;
    if (token != null) return token;
    final username = _username;
    final password = _password;
    if (username == null || password == null) {
      await _store.clear();
      throw const DivelogsSessionExpiredException();
    }
    return _renewal ??= _renew(username, password).whenComplete(() {
      _renewal = null;
    });
  }

  Future<String> _renew(String username, String password) async {
    final token = await _login(username, password);
    _token = token;
    await _store.save(DivelogsSession(username: username, token: token));
    return token;
  }

  /// Called by the API client when a request came back 401.
  void invalidateToken() {
    _token = null;
  }

  Future<void> signOut() async {
    _username = null;
    _password = null;
    _token = null;
    await _store.clear();
  }

  Future<String> _login(String username, String password) async {
    final request = http.MultipartRequest('POST', _loginUri)
      ..fields['user'] = username
      ..fields['pass'] = password;
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on Exception {
      throw const DivelogsAuthException(DivelogsAuthFailure.unreachable);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const DivelogsAuthException(DivelogsAuthFailure.badCredentials);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DivelogsAuthException(DivelogsAuthFailure.unexpectedResponse);
    }
    final token = _extractToken(response.body);
    if (token == null) {
      throw const DivelogsAuthException(DivelogsAuthFailure.unexpectedResponse);
    }
    return token;
  }

  static String? _extractToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final key in const ['bearer_token', 'token', 'access_token']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
```

Run the auth test. Expected: PASS.

- [ ] **Step 5: Port and trim the API client**

```bash
OLD=28c9c842fa8006d90ccdc2a0bcfe6fb7c7dd0e4e
git show "${OLD}:lib/core/services/divelogs/divelogs_api_client.dart" > lib/core/services/divelogs/divelogs_api_client.dart
git show "${OLD}:test/core/services/divelogs/divelogs_api_client_test.dart" > test/core/services/divelogs/divelogs_api_client_test.dart
```

In `divelogs_api_client.dart` delete: `getDivelist`, `postDives`, `postGear`, `postCertification`, `postPicture`; the `method`/`jsonBody` parameters of `_send` and the POST branch (it becomes GET-only: `response = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});`). Change every `'divelogs.de sign-in expired. Sign in again in Settings.'` to `'divelogs.de sign-in expired.'`. Keep `getUser`, `getAllDives`, `getGear`, `getCertifications`, `getGeartypes`, `getPictures`, `downloadPictureBytes`, `_rows`, `_maybe`, `_decode`, `_get`.

In `divelogs_api_client_test.dart` delete the tests: `getDivelist parses array body and counts unusable rows`, `getDivelist tolerates object body with dives/divelist key`, `postDives sends JSON array body with bearer header`, `postDives retries once on 401 then succeeds`, `postDives throws DivelogsApiException on 400`, `postGear sends JSON POST to /api/gear`, `postCertification sends multipart fields with bearer header`, `postCertification retries once on 401`, `postPicture sends a multipart imagefile part with filename`, `postPicture retries once on 401`. Then add:

```dart
  test('a session-expired token failure propagates untouched', () async {
    final client = DivelogsApiClient(
      getBearerToken: () async => throw const DivelogsSessionExpiredException(),
      onTokenRejected: () {},
      httpClient: MockClient((_) async => fail('no request without a token')),
    );
    await expectLater(
      client.getAllDives(),
      throwsA(isA<DivelogsSessionExpiredException>()),
    );
  });
```

(with `import 'package:submersion/core/services/divelogs/divelogs_auth.dart';`).

Run: `flutter test test/core/services/divelogs/`
Expected: PASS. `grep -n "post\|POST" lib/core/services/divelogs/divelogs_api_client.dart` returns nothing.

- [ ] **Step 6: Import service tests (failing)**

Create `test/features/universal_import/data/services/divelogs_import_service_test.dart`. Start from `$OLD`'s version for its `diveJson` and `service(...)` harness (shown in the plan header research), extended with `pictures` and `picturesStatus` handling:

```dart
  DivelogsImportService service(
    Object dives, {
    Object gear = const [],
    Object geartypes = const [],
    Object certifications = const [],
    int gearStatus = 200,
    int certStatus = 200,
    Map<String, Object> picturesByDive = const {},
    Set<String> failingPictureDives = const {},
  }) => DivelogsImportService(
    api: DivelogsApiClient(
      getBearerToken: () async => 't',
      onTokenRejected: () {},
      httpClient: MockClient((req) async {
        final path = req.url.path;
        if (path.startsWith('/api/pictures/')) {
          final id = path.split('/').last;
          if (failingPictureDives.contains(id)) {
            return http.Response('boom', 500);
          }
          return http.Response(jsonEncode(picturesByDive[id] ?? []), 200);
        }
        switch (path) {
          case '/api/dives':
            return http.Response(jsonEncode(dives), 200);
          case '/api/gear':
            return http.Response(jsonEncode(gear), gearStatus);
          case '/api/geartypes':
            return http.Response(jsonEncode(geartypes), 200);
          case '/api/certifications':
            return http.Response(jsonEncode(certifications), certStatus);
        }
        fail('unexpected request ${req.url}');
      }),
    ),
  );
```

Port these tests from `$OLD` (`git show "${OLD}:test/features/universal_import/data/services/divelogs_import_service_test.dart"`), switching `fetchAllDives()` to `fetchLogbook(includePhotos: false)` and reading `result.payload`: `'assembles payload with dives and deduped sites'` (expect `'divelogs-1'`, not `'divelogs:1'`), `'maps gear rows into equipment entities'`, `'maps certification rows into certification entities'`, `'dive gearitems become equipmentRefs'`, `'fuzzy date/time match flags the pulled dive as duplicate'`. Drop the old `'second pull is a Pass-0 exact source match'` (it bypassed the repository; Step 8 replaces it). Rewrite the degradation tests to assert codes:

```dart
  test('skipped dives become one coded warning with a count', () async {
    final result = await service([
      diveJson(1),
      {'id': 2}, // missing date/time/duration/maxdepth
      'not a map',
    ]).fetchLogbook(includePhotos: false);
    expect(result.skippedDives, 2);
    final warning = result.payload.warnings.single;
    expect(warning.code, ImportWarningCode.divesSkipped);
    expect(warning.count, 2);
  });

  test('gear failure degrades to a coded warning, dives survive', () async {
    final result = await service(
      [diveJson(1)],
      gearStatus: 500,
    ).fetchLogbook(includePhotos: false);
    expect(result.gearUnavailable, isTrue);
    expect(result.payload.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(
      result.payload.warnings.map((w) => w.code),
      contains(ImportWarningCode.gearUnavailable),
    );
  });

  test('certification failure degrades to a coded warning', () async {
    final result = await service(
      [diveJson(1)],
      certStatus: 500,
    ).fetchLogbook(includePhotos: false);
    expect(result.certificationsUnavailable, isTrue);
    expect(
      result.payload.warnings.map((w) => w.code),
      contains(ImportWarningCode.certificationsUnavailable),
    );
  });

  test('lists photos per dive keyed by source id when asked', () async {
    final progress = <(int, int)>[];
    final result = await service(
      [diveJson(1), diveJson(2, time: '16:00:00')],
      picturesByDive: {
        '1': [
          {'id': 10, 'url': 'https://divelogs.de/pics/u/1/reef.jpg'},
          {'id': 11, 'url': 'https://divelogs.de/pics/get?id=11'},
        ],
      },
    ).fetchLogbook(
      includePhotos: true,
      onPhotoListingProgress: (c, t) => progress.add((c, t)),
    );
    final photos = result.photosBySourceUuid['divelogs-1']!;
    expect(photos.map((p) => p.fileName), ['reef.jpg', 'divelogs-1-2.jpg']);
    expect(result.photosBySourceUuid.containsKey('divelogs-2'), isFalse);
    expect(result.photoCount, 2);
    expect(progress.last, (2, 2));
  });

  test('a picture row without a downloadable url is not listed', () async {
    final result = await service(
      [diveJson(1)],
      picturesByDive: {
        '1': [
          {'id': 10, 'url': 'reef.jpg'},
        ],
      },
    ).fetchLogbook(includePhotos: true);
    expect(result.photoCount, 0);
  });

  test('photo listing failures are counted into one coded warning', () async {
    final result = await service(
      [diveJson(1), diveJson(2, time: '16:00:00')],
      failingPictureDives: {'1', '2'},
    ).fetchLogbook(includePhotos: true);
    expect(result.photoListingFailures, 2);
    final warning = result.payload.warnings.singleWhere(
      (w) => w.code == ImportWarningCode.photoListingsUnavailable,
    );
    expect(warning.count, 2);
  });

  test('photos are not requested when not asked', () async {
    final result = await service([diveJson(1)]).fetchLogbook(
      includePhotos: false,
    );
    // The mock fails any /api/pictures request it is not configured for
    // only via fail(); an empty picturesByDive would answer []. Assert on
    // the result instead:
    expect(result.photoCount, 0);
    expect(result.photoListingFailures, 0);
  });

  test('a /dives failure is fatal', () async {
    final failing = DivelogsImportService(
      api: DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((_) async => http.Response('down', 503)),
      ),
    );
    await expectLater(
      failing.fetchLogbook(includePhotos: false),
      throwsA(isA<DivelogsApiException>()),
    );
  });

  test('remotePhotoFileName falls back when the url has no file name', () {
    expect(
      remotePhotoFileName(
        DivelogsPicture(id: '9', url: Uri.parse('https://x.de/a/b/pic.JPG')),
        remoteDiveId: '1',
        index: 0,
      ),
      'pic.JPG',
    );
    expect(
      remotePhotoFileName(
        DivelogsPicture(id: '9', url: Uri.parse('https://x.de/get?id=9')),
        remoteDiveId: '1',
        index: 3,
      ),
      'divelogs-1-4.jpg',
    );
  });
```

For `'photos are not requested when not asked'`, make the harness strict by passing a `picturesByDive` sentinel is not needed: instead change the harness so `/api/pictures/` requests call `fail('pictures requested')` when a `forbidPictures: true` flag is set, and pass `forbidPictures: true` in that test.

Run: `flutter test test/features/universal_import/data/services/divelogs_import_service_test.dart`
Expected: FAIL (service missing).

- [ ] **Step 7: Implement the import service**

Create `lib/features/universal_import/data/services/divelogs_import_service.dart`:

```dart
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_reference_mappers.dart';

/// What one fetch of a divelogs.de logbook produced.
class DivelogsFetchResult {
  const DivelogsFetchResult({
    required this.payload,
    required this.photosBySourceUuid,
    required this.diveCount,
    required this.skippedDives,
    required this.gearUnavailable,
    required this.certificationsUnavailable,
    required this.photoListingFailures,
  });

  final ImportPayload payload;

  /// Listed photos per payload dive, keyed by the dive's `sourceUuid`.
  final Map<String, List<RemotePhoto>> photosBySourceUuid;
  final int diveCount;
  final int skippedDives;
  final bool gearUnavailable;
  final bool certificationsUnavailable;
  final int photoListingFailures;

  int get photoCount =>
      photosBySourceUuid.values.fold(0, (sum, list) => sum + list.length);
}

/// The name a listed picture is saved under: the URL's own file name when
/// it has an extension, else a stable name built from the dive and the
/// picture's position.
String remotePhotoFileName(
  DivelogsPicture picture, {
  required String remoteDiveId,
  required int index,
}) {
  final segments = picture.url?.pathSegments ?? const <String>[];
  final last = segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
  final name = p.basename(last);
  if (name.isNotEmpty && p.extension(name).isNotEmpty) return name;
  return 'divelogs-$remoteDiveId-${index + 1}.jpg';
}

/// Fetches a full divelogs.de logbook and assembles an [ImportPayload] for
/// the universal import pipeline.
///
/// `/dives` failing is fatal. Gear, gear types, certifications and each
/// dive's picture listing degrade independently to coded warnings, so a
/// problem with any of them never costs the dives.
class DivelogsImportService {
  DivelogsImportService({
    required DivelogsApiClient api,
    DivelogsDiveMapper mapper = const DivelogsDiveMapper(),
  }) : _api = api,
       _mapper = mapper;

  final DivelogsApiClient _api;
  final DivelogsDiveMapper _mapper;

  Future<DivelogsFetchResult> fetchLogbook({
    required bool includePhotos,
    void Function(int current, int total)? onPhotoListingProgress,
  }) async {
    final result = await _api.getAllDives();

    Map<int, String> geartypes = const {};
    var gear = const <DivelogsGearItem>[];
    var certs = const <DivelogsCertification>[];
    var gearUnavailable = false;
    var certificationsUnavailable = false;
    try {
      geartypes = await _api.getGeartypes();
    } on DivelogsApiException {
      // Types degrade to EquipmentType.other; not worth a notice.
    }
    try {
      gear = await _api.getGear();
    } on DivelogsApiException {
      gearUnavailable = true;
    }
    try {
      certs = await _api.getCertifications();
    } on DivelogsApiException {
      certificationsUnavailable = true;
    }

    final diveEntities = <Map<String, dynamic>>[];
    final sitesByKey = <String, Map<String, dynamic>>{};
    for (final dive in result.dives) {
      diveEntities.add(_mapper.mapDive(dive));
      final site = _mapper.mapSite(dive);
      if (site == null) continue;
      final existing = sitesByKey[site['uddfId'] as String];
      if (existing == null) {
        sitesByKey[site['uddfId'] as String] = site;
      } else {
        // Same site on an earlier dive: backfill a position it lacked.
        if (existing['latitude'] == null && site['latitude'] != null) {
          existing['latitude'] = site['latitude'];
          existing['longitude'] = site['longitude'];
        }
      }
    }

    final photosBySourceUuid = <String, List<RemotePhoto>>{};
    var photoListingFailures = 0;
    if (includePhotos) {
      final withIds = [
        for (final dive in result.dives)
          if (dive.id != null) dive.id!,
      ];
      for (var i = 0; i < withIds.length; i++) {
        final remoteId = withIds[i];
        try {
          final pictures = await _api.getPictures(remoteId);
          final photos = <RemotePhoto>[
            for (final (n, picture) in pictures.indexed)
              if (picture.url != null)
                RemotePhoto(
                  url: picture.url!,
                  fileName: remotePhotoFileName(
                    picture,
                    remoteDiveId: remoteId,
                    index: n,
                  ),
                ),
          ];
          if (photos.isNotEmpty) {
            photosBySourceUuid[DivelogsDiveMapper.sourceUuidFor(remoteId)] =
                photos;
          }
        } on DivelogsApiException {
          photoListingFailures++;
        }
        onPhotoListingProgress?.call(i + 1, withIds.length);
      }
    }

    final equipmentEntities = [
      for (final item in gear)
        <String, dynamic>{
          'uddfId': DivelogsDiveMapper.gearKey(item.id),
          'name': item.name,
          'type': DivelogsReferenceMappers.equipmentTypeForGeartypeName(
            geartypes[item.geartypeId],
          ),
          if (item.purchaseDate != null) 'purchaseDate': item.purchaseDate,
          if (item.lastServiceDate != null)
            'lastServiceDate': item.lastServiceDate,
          'status': item.discardDate != null
              ? EquipmentStatus.retired
              : EquipmentStatus.active,
          'isActive': item.discardDate == null,
        },
    ];

    final certEntities = [
      for (final cert in certs)
        <String, dynamic>{
          'uddfId': 'divelogs-cert-${cert.id ?? cert.name}',
          'name': cert.name,
          'agency': DivelogsReferenceMappers.agencyForOrg(cert.org),
          if (cert.date != null) 'issueDate': cert.date,
          if (DivelogsReferenceMappers.levelForName(cert.name) != null)
            'level': DivelogsReferenceMappers.levelForName(cert.name),
        },
    ];

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{
      if (diveEntities.isNotEmpty) ImportEntityType.dives: diveEntities,
      if (sitesByKey.isNotEmpty)
        ImportEntityType.sites: sitesByKey.values.toList(),
      if (equipmentEntities.isNotEmpty)
        ImportEntityType.equipment: equipmentEntities,
      if (certEntities.isNotEmpty)
        ImportEntityType.certifications: certEntities,
    };

    final warnings = <ImportWarning>[
      if (result.skippedCount > 0)
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.divesSkipped,
          message: '${result.skippedCount} divelogs.de dives could not be read',
          count: result.skippedCount,
        ),
      if (gearUnavailable)
        const ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.gearUnavailable,
          message: 'divelogs.de gear list could not be fetched',
        ),
      if (certificationsUnavailable)
        const ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.certificationsUnavailable,
          message: 'divelogs.de certification list could not be fetched',
        ),
      if (photoListingFailures > 0)
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.photoListingsUnavailable,
          message: '$photoListingFailures divelogs.de photo listings failed',
          count: photoListingFailures,
        ),
    ];

    return DivelogsFetchResult(
      payload: ImportPayload(
        entities: entities,
        warnings: warnings,
        metadata: {'source': 'divelogs.de', 'diveCount': result.dives.length},
      ),
      photosBySourceUuid: photosBySourceUuid,
      diveCount: result.dives.length,
      skippedDives: result.skippedCount,
      gearUnavailable: gearUnavailable,
      certificationsUnavailable: certificationsUnavailable,
      photoListingFailures: photoListingFailures,
    );
  }
}
```

Note: `divesSkipped` warnings are grouped per warning; check `import_notice_grouper.dart`: it sums `warning.count`, so one warning with `count: N` is correct.

Run the service test. Expected: PASS.

- [ ] **Step 8: Repository-backed Pass 0 test**

Create `test/features/universal_import/data/services/divelogs_pass_zero_test.dart`. It stores a dive whose data source carries the mapper's source id through the real repository, then runs the checker with the map the repository returns, which is exactly what the wizard does:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(tearDownTestDatabase);

  test('a divelogs source id survives the repository source-id filter', () async {
    const epoch = 1700000000000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: epoch,
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: 'dive-1',
            isPrimary: const Value(true),
            sourceUuid: Value(DivelogsDiveMapper.sourceUuidFor('4711')),
            importedAt: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ),
        );

    final byDive = await DiveRepository().getSourceUuidByDiveId();

    expect(byDive, {'dive-1': 'divelogs-4711'});
  });
}
```

Run: `flutter test test/features/universal_import/data/services/divelogs_pass_zero_test.dart`
Expected: PASS. Sanity check that it guards the regression: temporarily change `sourceUuidFor` to return `'divelogs:$id'`, confirm the test FAILS, then restore it (copy the file to the scratchpad first rather than using `git checkout`, so the working change is not lost).

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/services/divelogs/ lib/features/universal_import/data/services/divelogs_import_service.dart test/core/services/divelogs/ test/features/universal_import/data/services/divelogs_import_service_test.dart test/features/universal_import/data/services/divelogs_pass_zero_test.dart
git commit -m "feat(divelogs): sign in and fetch a divelogs.de logbook for import"
```

---

### Task 7: DivelogsImportAdapter

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (enum `ImportSourceType`)
- Create: `lib/features/import_wizard/data/adapters/divelogs_import_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/divelogs_import_adapter_test.dart`

**Interfaces:**
- Consumes: `UniversalAdapter.payloadSteps`, `attachAdditionalPhotos` (Task 4); `attachRemotePhotos`, `RemotePhoto` (Task 3); `DivelogsApiClient` (Task 6).
- Produces:

```dart
final divelogsSignedInProvider = StateProvider<bool>((ref) => false);
final divelogsFetchedProvider = StateProvider<bool>((ref) => false);
final divelogsIncludePhotosProvider = StateProvider<bool>((ref) => true);
final divelogsSessionStoreProvider = Provider<DivelogsSessionStore>(...);
final divelogsHttpClientProvider = Provider<http.Client>(...); // closed on dispose

class DivelogsImportAdapter extends UniversalAdapter {
  DivelogsImportAdapter({required WidgetRef ref});
  DivelogsApiClient? get client;
  void setClient(DivelogsApiClient? client);
  void setRemotePhotos(Map<String, List<RemotePhoto>> photos);
}
```

- `ImportSourceType.divelogs`.

- [ ] **Step 1: Write the failing tests**

Create `divelogs_import_adapter_test.dart`, capturing a `WidgetRef` as in Task 4's test:

```dart
  testWidgets('sign in and fetch replace the file steps', (tester) async {
    final adapter = await pumpDivelogsAdapter(tester);
    expect(adapter.acquisitionSteps.map((s) => s.label).toList(), [
      'Sign In',
      'Fetch',
      'Divers',
      'Photos',
    ]);
    expect(adapter.sourceType, ImportSourceType.divelogs);
    expect(adapter.displayName, 'divelogs.de');
  });

  testWidgets('resetState forgets the client, photos and step flags', (
    tester,
  ) async {
    final adapter = await pumpDivelogsAdapter(tester);
    adapter.setClient(fakeClient());
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(url: Uri.parse('https://x.de/a.jpg'), fileName: 'a.jpg'),
      ],
    });
    container.read(divelogsSignedInProvider.notifier).state = true;
    container.read(divelogsFetchedProvider.notifier).state = true;

    adapter.resetState();

    expect(adapter.client, isNull);
    expect(await adapter.debugAttachAdditionalPhotos(), (attached: 0, failed: 0));
    expect(container.read(divelogsSignedInProvider), isFalse);
    expect(container.read(divelogsFetchedProvider), isFalse);
  });

  testWidgets('downloads photos into the chosen folder and links them', (
    tester,
  ) async {
    // Override localFileLinkServiceProvider with a fake whose
    // linkedPathsForDive returns {} and whose linkFileForDive records
    // (path, diveId) and returns a non-null item; see
    // test/features/import_wizard/data/adapters/import_photo_linker_test.dart
    // for how that test fakes LocalFileLinkService.
    final adapter = await pumpDivelogsAdapter(tester, linker: fakeLinker);
    final dest = await Directory.systemTemp.createTemp('divelogs_dest_');
    addTearDown(() => dest.delete(recursive: true));
    adapter.setClient(
      DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('bad.jpg')) return http.Response('', 500);
          return http.Response.bytes([7, 7, 7], 200);
        }),
      ),
    );
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(url: Uri.parse('https://divelogs.de/p/reef.jpg'), fileName: 'reef.jpg'),
        RemotePhoto(url: Uri.parse('https://divelogs.de/p/bad.jpg'), fileName: 'bad.jpg'),
      ],
    });

    final outcome = await tester.runAsync(
      () => adapter.debugAttachAdditionalPhotosFor(
        photoDiveIds: const {0: 'dive-1'},
        dives: const [
          {'sourceUuid': 'divelogs-1'},
        ],
        destinationDir: dest.path,
      ),
    );

    expect(outcome, (attached: 1, failed: 1));
    expect(File(p.join(dest.path, 'reef.jpg')).readAsBytesSync(), [7, 7, 7]);
    expect(fakeLinker.linked.single, (p.join(dest.path, 'reef.jpg'), 'dive-1'));
  });
```

Add to `DivelogsImportAdapter` (Step 3) a `@visibleForTesting` wrapper `debugAttachAdditionalPhotosFor({required Map<int, String> photoDiveIds, required List<Map<String, dynamic>> dives, required String destinationDir})` that calls `attachAdditionalPhotos` with empty `removedDiveIds` and `diveStartById`. Real file IO in a widget test must run inside `tester.runAsync`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/import_wizard/data/adapters/divelogs_import_adapter_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Add the source type and the adapter**

In `import_bundle.dart`, enum `ImportSourceType`, after `garminCloud,`:

```dart
  /// A divelogs.de logbook import.
  divelogs,
```

Then fix any exhaustive `switch` over `ImportSourceType` that `flutter analyze` reports (add a `divelogs` arm mirroring `universal`).

Create `lib/features/import_wizard/data/adapters/divelogs_import_adapter.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/import_photo_linker.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_import_steps.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Signals that the sign-in step can advance.
final divelogsSignedInProvider = StateProvider<bool>((ref) => false);

/// Signals that the fetch step installed a payload.
final divelogsFetchedProvider = StateProvider<bool>((ref) => false);

/// Whether the fetch lists photos. Only honoured where the Photos step can
/// pick a destination folder (desktop).
final divelogsIncludePhotosProvider = StateProvider<bool>((ref) => true);

/// Injected so widget tests can use an in-memory keychain.
final divelogsSessionStoreProvider = Provider<DivelogsSessionStore>(
  (ref) => DivelogsSessionStore(),
);

/// HTTP client for divelogs.de. Overridable with a `MockClient` in tests;
/// closed on dispose so sockets do not outlive the container.
final divelogsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Import source that pulls the user's logbook from divelogs.de.
///
/// Only acquisition differs from a file import: Sign In and Fetch replace
/// Select File, Confirm Source and Map Fields. The fetch installs its payload
/// through `UniversalImportNotifier.setExternalPayload`, so review, duplicate
/// handling and the importer are the universal ones. Listed photos are
/// downloaded at import time into the folder the Photos step chose.
class DivelogsImportAdapter extends UniversalAdapter {
  DivelogsImportAdapter({required WidgetRef ref})
    : _widgetRef = ref,
      super(ref: ref, displayName: 'divelogs.de');

  final WidgetRef _widgetRef;

  DivelogsApiClient? _client;
  Map<String, List<RemotePhoto>> _photos = const {};

  /// The signed-in client, set by the sign-in step.
  DivelogsApiClient? get client => _client;

  void setClient(DivelogsApiClient? client) => _client = client;

  /// Listed photos per payload dive `sourceUuid`, set by the fetch step.
  void setRemotePhotos(Map<String, List<RemotePhoto>> photos) =>
      _photos = Map.unmodifiable(photos);

  @override
  ImportSourceType get sourceType => ImportSourceType.divelogs;

  @override
  void resetState() {
    super.resetState();
    _client = null;
    _photos = const {};
    _widgetRef.invalidate(divelogsSignedInProvider);
    _widgetRef.invalidate(divelogsFetchedProvider);
  }

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Sign In',
      icon: Icons.login,
      builder: (context) => DivelogsSignInStep(onSignedIn: setClient),
      canAdvance: divelogsSignedInProvider,
      autoAdvance: true,
    ),
    WizardStepDef(
      label: 'Fetch',
      icon: Icons.cloud_download,
      builder: (context) =>
          DivelogsFetchStep(client: _client, onPhotosListed: setRemotePhotos),
      canAdvance: divelogsFetchedProvider,
      // Not auto-advance: the step shows what was found, and any gear,
      // certification or photo listing that failed, before moving on.
      autoAdvance: false,
    ),
    ...payloadSteps,
  ];

  @override
  Future<RemotePhotoOutcome> attachAdditionalPhotos({
    required Map<int, String> photoDiveIds,
    required Set<String> removedDiveIds,
    required Map<String, DateTime> diveStartById,
    required List<Map<String, dynamic>> dives,
    required String destinationDir,
    ImportCancellationToken? cancelToken,
  }) async {
    final client = _client;
    if (client == null || _photos.isEmpty) return (attached: 0, failed: 0);
    final linker = ImportPhotoLinker(
      _widgetRef.read(localFileLinkServiceProvider),
    );
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: _photos,
      diveIdByIndex: photoDiveIds,
      removedDiveIds: removedDiveIds,
      dives: dives,
      diveStartById: diveStartById,
      download: client.downloadPictureBytes,
      attach: (file, diveId, diveStart) => linker.linkBundled(
        file: file,
        diveId: diveId,
        diveStart: diveStart,
        destinationDir: destinationDir,
      ),
      cancelToken: cancelToken,
    );
    return (
      attached: outcome.attached - linker.alreadyLinked,
      failed: outcome.failed,
    );
  }

  @visibleForTesting
  Future<RemotePhotoOutcome> debugAttachAdditionalPhotosFor({
    required Map<int, String> photoDiveIds,
    required List<Map<String, dynamic>> dives,
    required String destinationDir,
  }) => attachAdditionalPhotos(
    photoDiveIds: photoDiveIds,
    removedDiveIds: const {},
    diveStartById: const {},
    dives: dives,
    destinationDir: destinationDir,
  );
}
```

The steps file `divelogs_import_steps.dart` is created in Tasks 8 and 9. To make this task compile first, create it now with minimal placeholders that Tasks 8 and 9 replace wholesale:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';

class DivelogsSignInStep extends StatelessWidget {
  const DivelogsSignInStep({super.key, required this.onSignedIn});
  final ValueChanged<DivelogsApiClient?> onSignedIn;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class DivelogsFetchStep extends StatelessWidget {
  const DivelogsFetchStep({
    super.key,
    required this.client,
    required this.onPhotosListed,
  });
  final DivelogsApiClient? client;
  final ValueChanged<Map<String, List<RemotePhoto>>> onPhotosListed;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

(Do not commit these stubs past Task 9: Tasks 8 and 9 replace both classes.)

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/import_wizard/data/adapters/divelogs_import_adapter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/domain/models/import_bundle.dart lib/features/import_wizard/data/adapters/divelogs_import_adapter.dart lib/features/import_wizard/presentation/widgets/divelogs_import_steps.dart test/features/import_wizard/data/adapters/divelogs_import_adapter_test.dart
git commit -m "feat(divelogs): import adapter that reuses the universal pipeline"
```

---

### Task 8: Sign In step

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/divelogs_import_steps.dart` (replace `DivelogsSignInStep`)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/import_wizard/presentation/widgets/divelogs_sign_in_step_test.dart`

**Interfaces:**
- Consumes: `DivelogsAuth`, `DivelogsApiClient`, `DivelogsSessionStore` (Task 6); providers from Task 7.
- Produces: `DivelogsSignInStep({required ValueChanged<DivelogsApiClient?> onSignedIn})`. Calls `onSignedIn(client)` on success and `onSignedIn(null)` on sign-out.

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, directly before the first `"divers_` key (keep alphabetical order; `divelogsImport_` sorts before `divers_`):

```json
  "divelogsImport_signIn_badCredentials": "divelogs.de rejected the username or password.",
  "divelogsImport_signIn_button": "Sign In",
  "divelogsImport_signIn_description": "Sign in with your divelogs.de account to import your logbook. Your password is never stored; only the resulting session is cached.",
  "divelogsImport_signIn_passwordLabel": "Password",
  "divelogsImport_signIn_passwordRequired": "Password is required",
  "divelogsImport_signIn_signedInAs": "Signed in as {username}",
  "@divelogsImport_signIn_signedInAs": {
    "placeholders": {
      "username": {
        "type": "String"
      }
    }
  },
  "divelogsImport_signIn_signingIn": "Signing in…",
  "divelogsImport_signIn_signOut": "Sign out",
  "divelogsImport_signIn_title": "Sign in to divelogs.de",
  "divelogsImport_signIn_unexpected": "divelogs.de sent an unexpected response. Try again later.",
  "divelogsImport_signIn_unreachable": "Could not reach divelogs.de. Check your connection and try again.",
  "divelogsImport_signIn_usernameLabel": "Username",
  "divelogsImport_signIn_usernameRequired": "Username is required",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing widget tests**

Create `divelogs_sign_in_step_test.dart` with a `_host` like `suunto_cloud_adapter_steps_test.dart`'s, overriding `divelogsSessionStoreProvider` with `DivelogsSessionStore(storage: InMemoryKeychain())` and `divelogsHttpClientProvider` with a `MockClient`. Cases:

1. **No cached session:** form shows `Sign in to divelogs.de`; entering `rainer`/`secret` and tapping `Sign In` sends a multipart POST to `/api/login`; `onSignedIn` receives a non-null client; `divelogsSignedInProvider` becomes `true`; the store holds `{username: rainer, token: ...}`.
2. **Bad credentials:** `/api/login` returns 401; the text `divelogs.de rejected the username or password.` appears; `divelogsSignedInProvider` stays `false`.
3. **Cached session still valid:** store pre-seeded; the mock answers `GET /api/user` with 200 `{}`; the step shows `Signed in as rainer` without any `/api/login` call; `onSignedIn` got a client.
4. **Cached session expired (Review Focus 1):** store pre-seeded; `GET /api/user` returns 401; the form shows with the username field prefilled `rainer`, no error text, and the store is now empty.
5. **Sign out:** from state 3, tap `Sign out`; the form shows; store empty; `onSignedIn` received `null`; `divelogsSignedInProvider` is `false`.

Run: `flutter test test/features/import_wizard/presentation/widgets/divelogs_sign_in_step_test.dart`
Expected: FAIL (stub renders nothing).

- [ ] **Step 3: Implement the step**

Replace the stub `DivelogsSignInStep` in `divelogs_import_steps.dart` with a `ConsumerStatefulWidget` built on `SuuntoCloudSignInStep` (`lib/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps.dart`), same layout and form fields, with these differences:

```dart
  DivelogsAuth _newAuth() => DivelogsAuth(
    httpClient: ref.read(divelogsHttpClientProvider),
    store: ref.read(divelogsSessionStoreProvider),
  );

  DivelogsApiClient _clientFor(DivelogsAuth auth) => DivelogsApiClient(
    getBearerToken: auth.getToken,
    onTokenRejected: auth.invalidateToken,
    httpClient: ref.read(divelogsHttpClientProvider),
  );

  Future<void> _tryCachedSession() async {
    final auth = _newAuth();
    final restored = await auth.restore();
    if (!mounted) return;
    if (!restored) {
      setState(() => _checkingCachedSession = false);
      return;
    }
    final client = _clientFor(auth);
    try {
      await client.getUser();
      if (!mounted) return;
      _auth = auth;
      _markSignedIn(client, auth.username!);
    } on DivelogsSessionExpiredException {
      // The cached token was rejected and auth cleared it: sign in afresh.
      if (!mounted) return;
      setState(() {
        _checkingCachedSession = false;
        _usernameController.text = auth.username ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingCachedSession = false;
        _usernameController.text = auth.username ?? '';
        _errorText = context.l10n.divelogsImport_signIn_unreachable;
      });
    }
  }

  Future<void> _submit() async {
    if (_signingIn) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _signingIn = true;
      _errorText = null;
    });
    final auth = _newAuth();
    final username = _usernameController.text.trim();
    try {
      await auth.signIn(username, _passwordController.text);
      if (!mounted) return;
      _auth = auth;
      _passwordController.clear();
      _markSignedIn(_clientFor(auth), username);
    } on DivelogsAuthException catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _signingIn = false;
        _errorText = switch (e.reason) {
          DivelogsAuthFailure.badCredentials =>
            l10n.divelogsImport_signIn_badCredentials,
          DivelogsAuthFailure.unreachable =>
            l10n.divelogsImport_signIn_unreachable,
          DivelogsAuthFailure.unexpectedResponse =>
            l10n.divelogsImport_signIn_unexpected,
        };
      });
    }
  }

  Future<void> _signOut() async {
    await _auth?.signOut();
    _auth = null;
    widget.onSignedIn(null);
    ref.read(divelogsSignedInProvider.notifier).state = false;
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _signedInUsername = null;
    });
  }
```

`_markSignedIn(client, username)` calls `widget.onSignedIn(client)`, sets `_signedIn`/`_signedInUsername`, and sets `divelogsSignedInProvider` to `true`. The signed-in view shows `l10n.divelogsImport_signIn_signedInAs(username)` and a `TextButton` labelled `l10n.divelogsImport_signIn_signOut` calling `_signOut`. The username field uses `autofillHints: const [AutofillHints.username]` and `divelogsImport_signIn_usernameLabel` / `_usernameRequired`; the password field uses `divelogsImport_signIn_passwordLabel` / `_passwordRequired`. Keep the password only in the controller and in `DivelogsAuth`; never log it.

Imports needed: `flutter_riverpod`, `divelogs_auth.dart`, `divelogs_api_client.dart`, `divelogs_import_adapter.dart` (for the providers), `l10n_extension.dart`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/import_wizard/presentation/widgets/divelogs_sign_in_step_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/presentation/widgets/divelogs_import_steps.dart lib/l10n/arb/ test/features/import_wizard/presentation/widgets/divelogs_sign_in_step_test.dart
git commit -m "feat(divelogs): sign-in step with a cached session and sign out"
```

---

### Task 9: Fetch step

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/divelogs_import_steps.dart` (replace `DivelogsFetchStep`)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/import_wizard/presentation/widgets/divelogs_fetch_step_test.dart`

**Interfaces:**
- Consumes: `DivelogsImportService`, `DivelogsFetchResult` (Task 6); `UniversalImportNotifier.setExternalPayload` (Task 2); `PhotoFolderStep.canPickFolder` (Task 2); providers (Task 7).
- Produces: `DivelogsFetchStep({required DivelogsApiClient? client, required ValueChanged<Map<String, List<RemotePhoto>>> onPhotosListed})`.

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, directly before `"divelogsImport_signIn_badCredentials"`:

```json
  "divelogsImport_fetch_button": "Fetch Logbook",
  "divelogsImport_fetch_certificationsUnavailable": "Certifications could not be fetched and will not be imported.",
  "divelogsImport_fetch_empty": "Your divelogs.de logbook has nothing to import.",
  "divelogsImport_fetch_failedTitle": "Could not fetch your logbook",
  "divelogsImport_fetch_fetching": "Fetching your logbook…",
  "divelogsImport_fetch_foundDives": "{count, plural, one{Found {count} dive} other{Found {count} dives}}",
  "@divelogsImport_fetch_foundDives": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "divelogsImport_fetch_foundPhotos": "{count, plural, =0{No photos to import} one{{count} photo to import} other{{count} photos to import}}",
  "@divelogsImport_fetch_foundPhotos": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "divelogsImport_fetch_gearUnavailable": "Gear could not be fetched; dives will import without gear links.",
  "divelogsImport_fetch_includePhotos": "Include photos",
  "divelogsImport_fetch_includePhotosHint": "Photos are downloaded during the import into a folder you choose.",
  "divelogsImport_fetch_listingPhotos": "Listing photos for dive {current} of {total}…",
  "@divelogsImport_fetch_listingPhotos": {
    "placeholders": {
      "current": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "divelogsImport_fetch_photoListingsFailed": "{count, plural, one{Photos for {count} dive could not be listed.} other{Photos for {count} dives could not be listed.}}",
  "@divelogsImport_fetch_photoListingsFailed": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "divelogsImport_fetch_retry": "Try Again",
  "divelogsImport_fetch_sessionExpired": "Your divelogs.de session expired. Go back and sign in again.",
  "divelogsImport_fetch_skippedDives": "{count, plural, one{{count} dive could not be read and will be skipped.} other{{count} dives could not be read and will be skipped.}}",
  "@divelogsImport_fetch_skippedDives": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing widget tests**

Create `divelogs_fetch_step_test.dart`. Harness: `ProviderScope` overriding the providers `universal_import_external_payload_test.dart` (Task 2) needs for the duplicate check, plus a `DivelogsApiClient` built on a `MockClient` serving `/api/dives`, `/api/gear`, `/api/geartypes`, `/api/certifications`, `/api/pictures/<id>`. Set `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` unless the case says otherwise, and reset it with `addTearDown(() => debugDefaultTargetPlatformOverride = null)`. Cases:

1. **Happy path with photos:** two dives, dive 1 has one picture. Tap `Fetch Logbook`. Expect `Found 2 dives`, `1 photo to import`; `divelogsFetchedProvider` is `true`; the notifier's `payload` has 2 dives and `remotePhotoCount == 1`; `onPhotosListed` got `{'divelogs-1': [one photo]}`.
2. **Photos switched off:** turn the `Include photos` switch off, fetch; expect no `/api/pictures/` request (the mock `fail()`s on one) and `remotePhotoCount == 0`.
3. **Mobile hides the switch (Review Focus context):** `debugDefaultTargetPlatformOverride = TargetPlatform.iOS`; expect no `Include photos` text; fetch makes no `/api/pictures/` request.
4. **Degraded:** `/api/gear` returns 500; expect the text `Gear could not be fetched; dives will import without gear links.` and `divelogsFetchedProvider` `true`.
5. **Fatal:** `/api/dives` returns 503; expect `Could not fetch your logbook` and a `Try Again` button; `divelogsFetchedProvider` stays `false`. Tapping `Try Again` after switching the mock to succeed fetches again.
6. **Session expired:** client built with `getBearerToken: () async => throw const DivelogsSessionExpiredException()`; expect `Your divelogs.de session expired. Go back and sign in again.`; `divelogsSignedInProvider` set to `false`.
7. **Empty:** `/api/dives` returns `[]` and gear/certs `[]`; expect `Your divelogs.de logbook has nothing to import.`; `divelogsFetchedProvider` stays `false`; `setExternalPayload` not called (notifier `payload` stays null).

Run: `flutter test test/features/import_wizard/presentation/widgets/divelogs_fetch_step_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the step**

Replace the stub `DivelogsFetchStep` with a `ConsumerStatefulWidget`:

```dart
class DivelogsFetchStep extends ConsumerStatefulWidget {
  const DivelogsFetchStep({
    super.key,
    required this.client,
    required this.onPhotosListed,
  });

  final DivelogsApiClient? client;
  final ValueChanged<Map<String, List<RemotePhoto>>> onPhotosListed;

  @override
  ConsumerState<DivelogsFetchStep> createState() => _DivelogsFetchStepState();
}

enum _FetchPhase { idle, fetching, done, empty, failed, expired }

class _DivelogsFetchStepState extends ConsumerState<DivelogsFetchStep> {
  _FetchPhase _phase = _FetchPhase.idle;
  DivelogsFetchResult? _result;
  (int, int)? _photoProgress;

  Future<void> _fetch() async {
    final client = widget.client;
    if (client == null) return;
    final includePhotos =
        PhotoFolderStep.canPickFolder &&
        ref.read(divelogsIncludePhotosProvider);
    setState(() {
      _phase = _FetchPhase.fetching;
      _photoProgress = null;
    });
    try {
      final result = await DivelogsImportService(api: client).fetchLogbook(
        includePhotos: includePhotos,
        onPhotoListingProgress: (current, total) {
          if (mounted) setState(() => _photoProgress = (current, total));
        },
      );
      if (!mounted) return;
      if (result.payload.isEmpty) {
        setState(() => _phase = _FetchPhase.empty);
        return;
      }
      widget.onPhotosListed(result.photosBySourceUuid);
      await ref
          .read(universalImportNotifierProvider.notifier)
          .setExternalPayload(
            result.payload,
            remotePhotoCount: result.photoCount,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _FetchPhase.done;
      });
      ref.read(divelogsFetchedProvider.notifier).state = true;
    } on DivelogsSessionExpiredException {
      if (!mounted) return;
      ref.read(divelogsSignedInProvider.notifier).state = false;
      setState(() => _phase = _FetchPhase.expired);
    } on DivelogsApiException {
      if (!mounted) return;
      setState(() => _phase = _FetchPhase.failed);
    } on DivelogsAuthException {
      // A token renewal mid-fetch could not reach divelogs.de.
      if (!mounted) return;
      setState(() => _phase = _FetchPhase.failed);
    }
  }
```

`build` renders, in a `SingleChildScrollView` with 24 padding:
- `idle`: when `PhotoFolderStep.canPickFolder`, a `SwitchListTile` titled `divelogsImport_fetch_includePhotos` with subtitle `_includePhotosHint`, bound to `divelogsIncludePhotosProvider`; then a `FilledButton.icon` (`Icons.cloud_download`) labelled `divelogsImport_fetch_button` calling `_fetch`.
- `fetching`: a `CircularProgressIndicator` row with `divelogsImport_fetch_listingPhotos(current, total)` when `_photoProgress` is set, else `divelogsImport_fetch_fetching`.
- `done`: `divelogsImport_fetch_foundDives(result.diveCount)`; if photos were listed, `divelogsImport_fetch_foundPhotos(result.photoCount)`; then, each in `theme.colorScheme.error` body text, only when applicable: `_skippedDives(result.skippedDives)`, `_gearUnavailable`, `_certificationsUnavailable`, `_photoListingsFailed(result.photoListingFailures)`.
- `empty`: `divelogsImport_fetch_empty` and the fetch button again.
- `failed`: title `divelogsImport_fetch_failedTitle` and a `FilledButton` `divelogsImport_fetch_retry` calling `_fetch`.
- `expired`: `divelogsImport_fetch_sessionExpired`.

Imports: `photo_folder_step.dart`, `universal_import_providers.dart`, `divelogs_import_service.dart`, `divelogs_auth.dart`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/import_wizard/presentation/widgets/divelogs_fetch_step_test.dart test/features/import_wizard/presentation/widgets/divelogs_sign_in_step_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/presentation/widgets/divelogs_import_steps.dart lib/l10n/arb/ test/features/import_wizard/presentation/widgets/divelogs_fetch_step_test.dart
git commit -m "feat(divelogs): fetch step that lists photos and reports partial failures"
```

---

### Task 10: Route and Transfer card

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart` (`_CloudSectionContent`)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/transfer/presentation/pages/transfer_page_divelogs_test.dart` (create; model on the existing transfer page tests' harness: `ls test/features/transfer/presentation/pages/`)

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, directly after `"transfer_importCloud_garminSubtitle": ...,`:

```json
  "transfer_importCloud_divelogsTitle": "divelogs.de",
  "transfer_importCloud_divelogsSubtitle": "Import your logbook, sites, gear, certifications and photos from divelogs.de",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Pump the Transfer page's Cloud section (as the existing transfer page test does) with a `GoRouter` that records pushes; expect a card titled `divelogs.de`; tapping it pushes `/transfer/import-cloud/divelogs`.

Run the test. Expected: FAIL (no card).

- [ ] **Step 3: Add the card and route**

In `_CloudSectionContent.build`, after the Garmin card:

```dart
          const SizedBox(height: 8),
          _CloudProviderCard(
            title: context.l10n.transfer_importCloud_divelogsTitle,
            subtitle: context.l10n.transfer_importCloud_divelogsSubtitle,
            icon: Icons.menu_book,
            onTap: () => context.push('/transfer/import-cloud/divelogs'),
          ),
```

Update the class doc comment's example list ("Additional providers (Shearwater Cloud, etc.)") to mention that logbook services such as divelogs.de also live here.

In `app_router.dart`, after the `import-cloud/garmin` `GoRoute`:

```dart
              GoRoute(
                path: 'import-cloud/divelogs',
                name: 'importFromCloudDivelogs',
                builder: (context, state) =>
                    const _DivelogsImportWizardRoute(),
              ),
```

and after `_GarminCloudImportWizardRoute`:

```dart
/// Wrapper that creates a [DivelogsImportAdapter], for importing a logbook
/// from a divelogs.de account.
class _DivelogsImportWizardRoute extends ConsumerWidget {
  const _DivelogsImportWizardRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedImportWizard(adapter: DivelogsImportAdapter(ref: ref));
  }
}
```

with `import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/transfer/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/router/app_router.dart lib/features/transfer/presentation/pages/transfer_page.dart lib/l10n/arb/ test/features/transfer/presentation/pages/transfer_page_divelogs_test.dart
git commit -m "feat(divelogs): add divelogs.de to the Transfer page's cloud imports"
```

---

### Task 11: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Modify: generated `lib/l10n/arb/app_localizations*.dart` (via `flutter gen-l10n`)

The keys to translate are exactly the ones added in Tasks 1, 8, 9 and 10 (8 + 15 + 20 + 2 = 45 messages including metadata-bearing ones; copy each `@key` metadata block unchanged).

- [ ] **Step 1: Translate**

For each of the 10 locales, add every new key. Rules:
- Non-English ARB files are grouped by feature, not alphabetical: anchor each insertion on the same neighbouring key used in `app_en.arb` (`universalImport_summary_noticeSitesUnresolvedBody`, `transfer_importCloud_garminSubtitle`, and for the `divelogsImport_` block, directly before the locale's first `divers_` key).
- Keep "divelogs.de" untranslated. Keep `{count}`, `{current}`, `{total}`, `{username}` placeholders intact.
- Plural branches: use `one{...{count}...}`, never a hardcoded digit. Use the locale's CLDR categories (`ar`: zero/one/two/few/many/other; `he`: one/two/other; `zh`: other only is fine but `one` is tolerated; `fr`/`pt`: `one` covers 0 and 1).
- Use proper diacritics (ç, ã, é, ü, ő, ß and so on), and each locale's own quotation and ellipsis conventions matching its existing `suuntoCloud_*` strings.

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: no "untranslated message" output for the new keys.

Run: `flutter test test/l10n/`
Expected: PASS (the repo's l10n guards, including the plural `=1` guard).

- [ ] **Step 3: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n(divelogs): translate the divelogs.de import strings"
```

---

### Task 12: Full verification and PR

- [ ] **Step 1: Format and analyze**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!` (infos are fatal in CI).

- [ ] **Step 2: Guards and the touched suites**

```bash
flutter test test/architecture/
```

```bash
flutter test test/features/import_wizard/ test/features/universal_import/ test/core/services/divelogs/ test/features/transfer/
```

Expected: PASS.

- [ ] **Step 3: Full suite, once**

```bash
flutter test
```

Expected: PASS. A failure in a file this branch never touched: check `main` first before debugging it here.

- [ ] **Step 4: Scan for forbidden text**

```bash
git diff origin/main...HEAD | perl -CSD -ne 'print if /^\+.*(\x{2014}|\x{2013}|divelogs:)/' | grep . || echo clean
```

Expected: `clean` (the `divelogs:` pattern catches a regressed source id).

- [ ] **Step 5: Push and open the PR (ask the user first)**

```bash
git push -u origin feature/divelogs-import
```

```bash
gh pr create --repo submersion-app/submersion --base main --title "feat(divelogs): import a divelogs.de logbook" --body "Closes #<issue>

Imports a divelogs.de logbook through the import wizard: dives with profiles, dive sites, gear, certifications, dive-to-gear links and dive photos. Import only; this replaces the two-way sync attempt in #603.

- Sign in works like the Suunto and Garmin cloud imports: the JWT is cached in the keychain, the password never is. Card in Transfer > Cloud.
- DivelogsImportAdapter subclasses UniversalAdapter, so review, duplicate handling (Pass 0 on divelogs-<id> source ids), multi-diver handling and the importer are the universal ones.
- Photos are listed at fetch time and downloaded at import time into the folder chosen in the Photos step, then linked. Nothing is stored in app storage. Desktop only, like the existing folder picker.
- Gear, certification and photo-listing failures degrade to summary notices; only a /dives failure stops the fetch.
- No schema change.

Test plan
- [x] flutter analyze
- [x] flutter test (full suite)
- [ ] Manual: macOS import against a real divelogs.de account (sign in, fetch with photos, import, re-import shows every dive as an exact match and adds no photo files)"
```

Then bind the PR with the ccd_pr tools and, with the user's go-ahead, close #603 with a comment linking the new PR.
