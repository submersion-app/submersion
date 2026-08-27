# Media Provenance PR 2b: The Actions Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make the media info panel actionable, so a problem it surfaces can be fixed from the same place, without adding any new repair or upload machinery.

**Architecture:** Four actions, three of which are entry points into flows that already exist and one of which is genuinely new. Two existing flows are private methods on `_DiveMediaSectionState` and get extracted to shared helpers; the dive section then calls the extracted versions, so behaviour there is unchanged by construction.

**Tech Stack:** Dart / Flutter, Riverpod 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-16-media-provenance-design.md`

**Predecessor:** PR 2a (`#1120`, branch `worktree-media-provenance-pr2a`). This branch is stacked on it and must be retargeted to `main` once 2a merges.

**Branch / worktree:** `worktree-media-provenance-pr2b` at `.claude/worktrees/media-provenance-pr2b`.

## Global Constraints

- **No em-dashes.** The em-dash character (U+2014) must not appear in any code, comment, doc, ARB string, test name, or commit message. Stated by codepoint so this file does not trip its own check.
- **No emojis** in code, comments, or documentation.
- **No schema change**, no migration, no synced entity touched.
- **No new repair or upload logic.** Locate, Back up and Reveal are entry points into existing engines. The ONLY new capability is single-item verify, and only because no such entry point exists.
- All 11 ARB catalogs stay at exact key parity.
- `dart format --set-exit-if-changed .` exits 0; `flutter analyze` reports no issues (CI treats infos as fatal).

## Verified Facts (do not re-derive)

1. **`_replaceLink(MediaItem)`** at `dive_media_section.dart:265` IS the single-item repair flow: pick a file, hash it, confirm when the bytes differ from `contentHash`, then `MediaRepairService.apply([one proposal])`. Its l10n keys (`media_diveMediaSection_replaceEditedTitle` / `_replaceEditedContent` / `_replaceButton` / `_cancelButton`) already exist and are reused.
2. **`_showInFinder(String path)`** at `dive_media_section.dart:244` is the reveal helper: `open -R` on macOS, `explorer /select,` on Windows, `xdg-open` on the parent directory on Linux. Failures are deliberately swallowed.
3. **`enqueueRepairUpload({required String mediaId})`** (`media_transfer_queue_repository.dart:93`) is idempotent AND re-arms a terminally failed row via `retry()`. **"Back up now" and "Retry upload" are therefore the same call**, differing only in label, and neither needs the queue row id. Do not use `enqueueUpload`, which will not resurrect a failed row, and do not use `mediaStoreEnqueueImplProvider`, which short-circuits unless the auto-upload policy is on.
4. **No single-item verify exists.** `LocalFilesDiagnosticsService.reverifyAll()` is a bulk sweep hardcoded to `LocalFileResolver` rather than dispatching through the registry. Its persistence contract (`local_files_diagnostics_service.dart:97-112`) is the one to mirror: `volumeOffline` and `transientError` update `lastVerifiedAt` only; every other result also writes `isOrphaned = result != available`.
5. **`MediaSourceResolverRegistry.resolverFor` throws `UnsupportedError`** for an unregistered source type. Guard it; the blast radius must stay one item.
6. **`VerifyResult`** values: `available`, `notFound`, `unauthenticated`, `transientError`, `fromOtherDevice`, `volumeOffline`.
7. **`MediaRepository.markAsVerified(id)` sets both `isOrphaned = false` and `lastVerifiedAt`,** and is currently called from nowhere. `markOrphaned(id, bool)` sets the flag without a date, so it is NOT a substitute.
8. **`core/providers/provider.dart` re-exports flutter_riverpod** alongside `invalidateSelfWhen`. Importing both trips `unnecessary_import`, which CI treats as fatal.

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/shared/utils/file_reveal.dart` | Create: extracted reveal helper | 1 |
| `lib/features/media/data/services/media_item_verifier.dart` | Create: single-item verify plus persistence | 2 |
| `lib/features/media/presentation/helpers/media_link_replacer.dart` | Create: extracted replace-link flow | 3 |
| `lib/features/media/presentation/widgets/dive_media_section.dart` | Modify: call the extracted helpers | 1, 3 |
| `lib/l10n/arb/app_*.arb` (11 files) | Modify: 11 new `media_info_action*` keys | 4 |
| `lib/features/media/presentation/widgets/media_info_panel.dart` | Modify: render the actions | 5 |

---

### Task 1: Extract the reveal helper

**Files:**
- Create: `lib/shared/utils/file_reveal.dart`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
- Test: `test/shared/utils/file_reveal_test.dart`

**Interfaces:**
- Produces: `Future<void> revealInFileManager(String path)` and `bool get canRevealInFileManager`.

The reveal itself shells out to `Process.run` and cannot be unit-tested, so the test covers only the platform predicate. Do not fake `Process.run` to manufacture coverage; mark the shell-out `coverage:ignore` with the same reasoning the original carries.

- [x] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/utils/file_reveal.dart';

void main() {
  test('reveal is offered on desktop only', () {
    final expected =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    expect(canRevealInFileManager, expected);
  });
}
```

- [x] **Step 2: Run it and confirm it fails** with "Target of URI doesn't exist".

- [x] **Step 3: Write the implementation**

Move the body of `_showInFinder` verbatim into a top-level function, keeping its swallow-failures comment, and add the predicate. Then replace the private method in `dive_media_section.dart` with a call to it and delete the private version. Leave the `coverage:ignore` block covering the shell-out.

- [x] **Step 4: Run the test and the dive media section suite.**

Run: `flutter test test/shared/utils/file_reveal_test.dart test/features/media/presentation/widgets/`
Expected: PASS, unchanged counts. Extraction must not change behaviour.

- [x] **Step 5: Format, analyze, commit.**

---

### Task 2: Single-item verify

**Files:**
- Create: `lib/features/media/data/services/media_item_verifier.dart`
- Test: `test/features/media/data/services/media_item_verifier_test.dart`

**Interfaces:**
- Produces:
```dart
class MediaItemVerifier {
  MediaItemVerifier({
    required MediaSourceResolverRegistry registry,
    required MediaRepository repository,
    DateTime Function()? now,
  });
  Future<VerifyResult> verify(MediaItem item);
}
final mediaItemVerifierProvider = Provider<MediaItemVerifier>(...);
```

This is the ONE piece of new capability in this PR. It exists because the only caller that persists a verify result today is a bulk sweep wired to a single concrete resolver.

- [x] **Step 1: Write the failing test**

Use a fake registry whose resolver returns a configurable `VerifyResult`, and a fake repository capturing writes. Cover:

```dart
test('an available result clears the orphan flag and stamps the date', ...);
test('notFound sets the orphan flag and stamps the date', ...);
test('unauthenticated sets the orphan flag', ...);
// volumeOffline and transientError are recoverable conditions, not dead
// pointers: flagging them would let a re-verify mark a row missing while
// the share is simply unmounted, and the flag is sticky.
test('volumeOffline stamps the date but leaves the orphan flag alone', ...);
test('transientError stamps the date but leaves the orphan flag alone', ...);
test('an unregistered source type reports transientError and writes nothing', ...);
```

- [x] **Step 2: Run it and confirm it fails.**

- [x] **Step 3: Write the implementation**

```dart
Future<VerifyResult> verify(MediaItem item) async {
  final MediaSourceResolver resolver;
  try {
    resolver = _registry.resolverFor(item.sourceType);
  } on UnsupportedError {
    // A row whose source type has no resolver is a programmer error, but
    // its blast radius here must stay one item. Reporting a transient
    // failure leaves the orphan flag untouched, which is the honest
    // outcome: nothing was actually checked.
    return VerifyResult.transientError;
  }
  final result = await resolver.verify(item);
  final stamp = _now();
  if (result == VerifyResult.volumeOffline ||
      result == VerifyResult.transientError) {
    await _repository.updateMedia(item.copyWith(lastVerifiedAt: stamp));
    return result;
  }
  await _repository.updateMedia(
    item.copyWith(
      isOrphaned: result != VerifyResult.available,
      lastVerifiedAt: stamp,
    ),
  );
  return result;
}
```

Mirror `LocalFilesDiagnosticsService`'s contract exactly; a divergence here would make one-off checks and the bulk sweep disagree about the same row.

- [x] **Step 4: Run the test.** Expected: PASS.

- [x] **Step 5: Format, analyze, commit.**

---

### Task 3: Extract the replace-link flow

**Files:**
- Create: `lib/features/media/presentation/helpers/media_link_replacer.dart`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
- Test: `test/features/media/presentation/helpers/media_link_replacer_test.dart`

**Interfaces:**
- Produces: `Future<bool> replaceMediaLink(BuildContext context, WidgetRef ref, MediaItem item)`, returning whether a repair was applied.

The extracted helper must NOT refresh any list: that is the caller's concern, and the dive section's refresh is dive-scoped. Keep the file picker injectable so a test can drive it without a native dialog.

- [x] **Step 1: Write the failing test**

Inject a picker returning a temp file, plus a fake `MediaRepairService`, and assert:

```dart
test('applies an exact proposal when the bytes match the row hash', ...);
test('returns false and applies nothing when the picker is cancelled', ...);
// Accepting different bytes re-uploads them to the media store, which is
// why the original flow demands an explicit confirm.
test('different bytes require confirmation before applying', ...);
```

- [x] **Step 2: Run it and confirm it fails.**

- [x] **Step 3: Write the implementation.** Move the body verbatim, minus the `mediaListNotifierProvider` refresh, and add the injectable picker. Then rewrite `_replaceLink` as a call to the helper followed by its existing refresh.

- [x] **Step 4: Run the helper test and the dive media section suite.** Expected: PASS, unchanged counts.

- [x] **Step 5: Format, analyze, commit.**

---

### Task 4: The action strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: extend `test/l10n/media_info_strings_test.dart`

11 new keys. Add message plus `@` metadata to `app_en.arb`, message only to the other ten. Reuse the script pattern from PR 2a: textual insertion before the closing brace, then re-parse to prove valid JSON and no duplicates.

```
media_info_actionCheckNow      "Check now"
media_info_actionLocate        "Locate file..."
media_info_actionBackUpNow     "Back up now"
media_info_actionRetryUpload   "Retry upload"
media_info_actionReveal        "Show in file manager"
media_info_actionCopyPath      "Copy reference"
media_info_referenceCopied     "Reference copied"
media_info_checkFound          "Source found"
media_info_checkMissing        "Source is missing"
media_info_checkUnavailable    "Could not check right now"
media_info_backupQueued        "Queued for upload"
```

- [x] **Step 1** Extend the strings test with the 11 new getters, expecting failure.
- [x] **Step 2** Add the keys to all 11 catalogs and run `flutter pub get` to regenerate.
- [x] **Step 3** Run `flutter test test/l10n/`. Expected: parity and strings tests PASS.
- [x] **Step 4** Format and commit, including the regenerated `app_localizations*.dart`.

---

### Task 5: Render the actions in the panel

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart`
- Test: extend `test/features/media/presentation/widgets/media_info_panel_test.dart`

Placement, one action row per block:

- **Origin block:** Check now (always). Locate (only when health is `missing` AND the source type is `localFile`, because the repair engine's file candidate only makes sense there). Show in file manager and Copy reference (only when the pointer is a path and the platform can reveal).
- **Backup block:** Back up now / Retry upload, shown only when `eligible` AND `storeAttached` AND the tier is not `full`. The label is Retry when the queue state is `failed`, otherwise Back up now. Hidden entirely while `pending` or `transferring`, because the answer to "is it uploading" is already on screen.

- [x] **Step 1: Write the failing tests**

```dart
testWidgets('Check now is always offered', ...);
testWidgets('Locate appears only for a missing local file', ...);
testWidgets('Locate is absent for a missing gallery row', ...);
testWidgets('Back up now is hidden when already fully backed up', ...);
testWidgets('Back up now is hidden when no store is attached', ...);
testWidgets('the label reads Retry upload when the queue row failed', ...);
testWidgets('no upload action while a transfer is in flight', ...);
testWidgets('Check now writes the result and reports it', ...);
testWidgets('Copy reference puts the pointer on the clipboard', ...);
```

For the clipboard assertion, intercept `SystemChannels.platform` with
`tester.binding.defaultBinaryMessenger.setMockMethodCallHandler` and capture
`Clipboard.setData`.

- [x] **Step 2: Run and confirm failure.**

- [x] **Step 3: Implement.** Actions render as `TextButton`s in a trailing `Wrap` inside each section. Every handler captures `context.l10n` and the messenger BEFORE its first await, then guards on `context.mounted` after, matching the repo's async-gap convention.

- [x] **Step 4: Run the panel suite.** Expected: PASS.

- [x] **Step 5: Format, analyze, commit.**

---

### Task 6: Full verification

- [x] **Step 1** `dart format --set-exit-if-changed .` exits 0.
- [x] **Step 2** `flutter analyze` reports no issues. Do not pipe through `tail`: a pipeline's exit status comes from the last command, which masks the real one.
- [x] **Step 3** `flutter test`, redirected to a file rather than piped, with the exit code captured explicitly. Expect zero failures.
- [x] **Step 4** `git diff --stat origin/main...HEAD -- lib/core/database lib/features/sync` is empty.
- [x] **Step 5** No em-dash entered source:
  ```bash
  EMDASH=$(printf '\xe2\x80\x94')
  git diff origin/main...HEAD -- lib test | grep -n "^+.*$EMDASH" || echo "clean"
  ```
- [x] **Step 6** Push and open the PR against `worktree-media-provenance-pr2a`, retargeting to `main` once 2a merges. No attribution line, no session URL.

## Self-Review

**Spec coverage.** Spec section 7.2's action table is Tasks 1 to 3 and 5. Check now maps to Task 2, Locate to Task 3, Reveal and Copy to Task 1 and 5, Back up and Retry to Task 5 on top of the existing queue API. Re-upload is deliberately absent: `MediaReuploadButton` already ships in the viewer and duplicating it in the panel would give two controls for one operation.

**Scope discipline.** Exactly one new capability (single-item verify), justified in Verified Fact 4. Two extractions that must not change behaviour, guarded by running the dive-section suite unchanged. Everything else is a call into an existing API.

**Type consistency.** `revealInFileManager(String)` and `canRevealInFileManager` from Task 1 are used in Task 5. `MediaItemVerifier.verify(MediaItem) -> Future<VerifyResult>` from Task 2 is used in Task 5. `replaceMediaLink(BuildContext, WidgetRef, MediaItem) -> Future<bool>` from Task 3 is used in Task 5 and by the rewritten `_replaceLink`.
