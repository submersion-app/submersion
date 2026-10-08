# Media capture-time offset and unmatched diagnostics

Date: 2026-08-26
Branch: `worktree-media-capture-time-offset`
Closes: [#312](https://github.com/submersion-app/submersion/issues/312)

## Problem

Issue #312 reports that linking photos to dives is "too strict on timestamp
constraints", and names two independent causes:

1. Photos downloaded from a camera, edited on the phone, and re-saved
   elsewhere. The reporter cannot link them and is unsure which timestamp the
   app even reads.
2. A camera clock that is out of sync with the dive computer, typically after
   travelling to another timezone.

These have different mechanisms and need different remedies.

### What already exists

`ExifExtractor` resolves a capture time through a three-tier cascade and
already falls back to the file's modification time:

1. `native_exif` `DateTimeOriginal` (iOS and Android only).
2. A pure-Dart container parse: JPEG EXIF, or the `mvhd` box of MP4/MOV/M4V
   (`capture_time_reader.dart`, every platform).
3. `file.lastModifiedSync()`, reinterpreted as wall-clock UTC
   (`exif_extractor.dart:105`, `takenAt: takenAt ?? mtime`).

So "no EXIF, use the file timestamp" is already the shipped behavior. What is
missing is not another timestamp source.

### Why a further mtime fallback is not the answer

An additional "EXIF produced a time but it matched no dive, so retry with
mtime" tier was considered and rejected:

- When a camera clock is wrong, the camera stamps the file's mtime on the card
  from that same wrong clock, so mtime carries an identical error.
- When mtime does differ from EXIF, it differs because the transfer rewrote it,
  making it the copy or edit time. That is months after the dive and matches
  nothing.
- mtime is a real epoch instant read back in host-local time, whereas the whole
  matching pipeline compares wall-clock-UTC digits. Logging a Palau trip from a
  US-Eastern host skews an mtime-derived time by roughly 13 hours, so the
  fallback fails hardest exactly where dive photography lives.
- Offloading a card between dives can land mtime inside the previous dive's
  60-minute post-buffer, silently linking topside photos to the wrong dive.

### The actual gap

Cause 2 is a constant offset across every file on the card, so one correction
fixes all of them. Nothing in the app can change the matching inputs and re-run
the matcher.

Cause 1 leaves no recoverable capture time at all, and here the app has a hard
dead end: `FilesTabNotifier.commit()` walks `state.match.matched.entries` only,
so the unmatched bucket is never persisted. The two manual assignment
affordances (`assignToDive` on the card, `assignAllUnmatched` on the group
header) are both gated on `assignableDiveId != null`, which is non-null only
for a `DiveAttachTarget`. When the picker is opened from the library rather
than from a dive, an unmatched file cannot reach the database by any route, and
no message explains why.

Underlying both: the review pane never says which of the three time sources it
used, which is precisely the reporter's "I'm not sure what timestamp
Submersion looks at".

## Goals

- Tell the user which timestamp a file was dated from and, when it matched no
  dive, how far it was from the nearest one.
- Let the user apply a single capture-time offset to a picking session and see
  the match result update live.
- Give every unmatched file a route into the database regardless of how the
  picker was opened.

## Non-goals

- The gallery scan path (`TripMediaScanner` and `ScanResultsDialog`). It shares
  only the domain layer with the Files tab, converts back to `AssetInfo`
  immediately, and renders unmatched assets as a non-assignable warning row.
  The domain changes here are additive so that path can adopt them later.
- `MediaImportReviewPage` and the Lightroom auto-linker, which use the separate
  `DivePhotoMatcher.matchTimestamp` API.
- Writing any correction back to the file's own EXIF.
- Automatic detection of the offset. The user dials it and sees the result.
- Any database schema change. See "Persistence" below.

## Design

### 1. Timestamp provenance

New value object `lib/features/media/domain/value_objects/taken_at_source.dart`:

```dart
enum TakenAtSource { nativeExif, containerMetadata, fileModifiedTime, none }
```

`MediaSourceMetadata` gains `final TakenAtSource takenAtSource`, defaulted to
`TakenAtSource.none` so existing constructors keep compiling, and added to
`props`.

`ExifExtractor._extract` already has three distinct branches that can produce
`takenAt`; each tags the source it used. `readLocalCaptureTime` keeps returning
a bare `DateTime?`, and the extractor infers `containerMetadata` from a non-null
result, so `capture_time_reader.dart` needs no signature change.

### 2. Matcher offset and diagnostics

`DivePhotoMatcher.match` gains `Duration offset = Duration.zero`, applied to
each file's `takenAt` at comparison time only. It never mutates
`ExtractedFile`.

The matcher currently discards why a file failed: a null `takenAt`
(`dive_photo_matcher.dart:55-58`) and a no-window-hit
(`dive_photo_matcher.dart:75-76`) both collapse to the same
`unmatched.add(file)`. New value object
`lib/features/media/domain/value_objects/unmatched_diagnostic.dart`:

```dart
enum UnmatchedReason { noTimestamp, outsideAllWindows }

class UnmatchedDiagnostic extends Equatable {
  final UnmatchedReason reason;
  final String? nearestDiveId;   // null when reason == noTimestamp
  final Duration? gapToNearest;  // signed: negative = file is before the dive
}
```

`MatchedSelection` gains
`final Map<String, UnmatchedDiagnostic> diagnostics`, keyed by `sourcePath`
(already the identity key used by `removeFile` and `assignToDive`), defaulted
to an empty map. `MatchedSelection.empty()` and
`TripMediaScanner._mergeSelections` are unaffected by an additive optional
field.

"Nearest dive" is the dive minimising the absolute distance from the offset
file time to the dive's match window, not to its entry time, so the reported
gap is the amount of shift that would actually bring the file into range.

### 3. Persistence: the offset is applied when writing, not only when matching

This is a correctness constraint, not a preference.

`EnrichmentService.calculateEnrichment` derives
`elapsedSeconds = toWallClockUtc(photoTime) - toWallClockUtc(diveStartTime)`
(`enrichment_service.dart:77-81`) and uses it to place a photo on the profile
chart and derive its depth badge. A negative elapsed falls into the "photo is
before first profile point" branch (`enrichment_service.dart:146-155`), which
returns the first profile sample's depth for every such photo.

If a file were matched on a shifted time but persisted with the unshifted one,
every shift-rescued photo would carry an elapsed value wrong by the offset,
and a positive offset of a few hours reproduces exactly the "every photo shows
the same near-surface depth badge" failure this codebase has shipped and fixed
once already.

Therefore:

- `ExtractedFile.metadata.takenAt` stays the pristine extracted value, so the
  card can show the original alongside the corrected time.
- The offset lives in `FilesTabState`, and `FilesTabNotifier._persistOne`
  applies it at the single write site,
  `files_tab_providers.dart:363`, today `takenAt: file.metadata.takenAt ?? now`.

Accepted tradeoff: the stored `taken_at` is a corrected time rather than the
literal EXIF value, and the correction is not written back to the file. The
existing Undo action on the commit SnackBar covers an immediate mistake.

No schema change is required: provenance and diagnostics are review-session
state and are never persisted, so this work claims no schema version.

### 4. State

`FilesTabState` gains `Duration captureTimeOffset`, default `Duration.zero`,
in `props` and `copyWith`.

`filesTabNotifierProvider` is **not** autoDispose, and `clearStagedFiles()`
deliberately preserves `autoMatchByDate` across picker sessions
(`files_tab_providers.dart:140-157`). The offset must go in the reset half of
that method; otherwise a correction applied to one trip's import silently
leaks into the next one. `clear()` resets it via `FilesTabState.initial()`.

New notifier method:

```dart
void setCaptureTimeOffset(Duration offset, {required MatchedSelection match});
```

It sets both fields in one state update so the summary count and the rendered
groups can never disagree.

Re-matching without an OS picker round-trip needs `DiveBounds` outside
`_pickFiles` and `_pickFolder`. The derivation currently inlined at
`files_tab.dart:187-205` moves to a `diveBoundsProvider`
(`FutureProvider<List<DiveBounds>>`) in `files_tab_providers.dart`, mapping
`divesProvider` through the existing rule: `entryTime = d.effectiveEntryTime`,
`exitTime = d.exitTime ?? d.effectiveEntryTime + (d.effectiveRuntime ?? 1h)`.
This also makes that rule directly testable for the first time.

### 5. UI

**Offset bar**, new widget
`lib/features/media/presentation/widgets/capture_time_offset_bar.dart`,
inserted in `FileReviewPane` between the summary header
(`file_review_pane.dart:59-62`) and the `Expanded > ListView`
(`file_review_pane.dart:63`).

Rendered when `files.isNotEmpty && autoMatchByDate && !flat`. It is shown
whenever those hold, **not** only while something is unmatched: gating on
`unmatched.isNotEmpty` would make the control disappear the moment a shift
succeeded, leaving the user no way to undo or adjust it.

Layout: coarse steppers (-1h / +1h), fine steppers (-15m / +15m), the current
signed offset formatted as `+5h 00m`, and a reset that returns to zero. Each
interaction reads `diveBoundsProvider`, re-runs `DivePhotoMatcher.match` with
the new offset, and calls `setCaptureTimeOffset`. The summary header above it
already reports matched and unmatched counts, so the live preview needs no
separate count widget.

**Card subtitle**, `file_review_card.dart:47-49`. Today a single
`Text(file.metadata.takenAt?.toIso8601String() ?? 'No EXIF date')`. It becomes
a two-line block:

- Line 1: the capture time, shown as the corrected time with the original in
  parentheses when the offset is non-zero, plus a provenance label derived from
  `TakenAtSource` ("from EXIF", "from file metadata", "from file date",
  "no date found").
- Line 2, unmatched files only: the reason. For `noTimestamp`, a statement that
  no capture time could be read. For `outsideAllWindows`, the nearest dive and
  the signed gap.

`MediaImportReviewPage._subtitle` (`media_import_review_page.dart:106-134`) is
the pattern to follow.

**Escape hatch**, `file_review_card.dart`. The `Icons.add_link` button is
currently rendered only when `assignTo != null && assignTo != targetDiveId`.
When `assignableDiveId == null` it instead opens the existing
`showDivePickerSheet(context)` (`dive_picker_sheet.dart:13`, searchable,
already used by `media_selection_bar.dart:95`) and routes the returned dive id
into the existing `assignToDive(sourcePath, diveId)`. No new state and no new
persistence path: once a file is in a matched group, `commit()` already
handles it.

### 6. Localization

`files_tab.dart`, `file_review_pane.dart`, and `file_review_card.dart` are
currently 100% hardcoded English behind `TODO(media): l10n` markers.
`test/l10n/arb_parity_test.dart` requires every English key to exist in all 10
non-English locales, so any new key must be translated regardless.

Since most strings in these three files are being rewritten anyway, the
`TODO(media): l10n` debt is cleared across all three rather than leaving new
localized strings adjacent to old hardcoded ones. Roughly 15 keys times 11
locales.

- Source ARB directory is `lib/l10n/arb/`, template `app_en.arb`.
- Generated `app_localizations_*.dart` files live in that same directory and
  are checked into git, so regeneration produces a real diff that must be
  committed.
- New keys use the existing `media_photoPicker_*` prefix.
- The data-quality repair sheet already has `dataQuality_repairLabel_shiftTime`
  and `dataQuality_repairLabel_shiftImport` translated in all 11 locales; reuse
  their phrasing for consistency, but define picker-scoped keys rather than
  borrowing keys across features.

## Files

New:

- `lib/features/media/domain/value_objects/taken_at_source.dart`
- `lib/features/media/domain/value_objects/unmatched_diagnostic.dart`
- `lib/features/media/presentation/widgets/capture_time_offset_bar.dart`

Modified:

- `lib/features/media/domain/value_objects/media_source_metadata.dart`
- `lib/features/media/domain/value_objects/matched_selection.dart`
- `lib/features/media/domain/services/dive_photo_matcher.dart`
- `lib/features/media/data/services/exif_extractor.dart`
- `lib/features/media/presentation/providers/files_tab_providers.dart`
- `lib/features/media/presentation/widgets/files_tab.dart`
- `lib/features/media/presentation/widgets/file_review_pane.dart`
- `lib/features/media/presentation/widgets/file_review_card.dart`
- `lib/l10n/arb/app_en.arb` and the 10 translation ARBs, plus regenerated
  `app_localizations*.dart`

## Testing

TDD: each behavior gets a failing test first.

- `dive_photo_matcher_test.dart`: offset shifts window membership in both
  directions; zero offset is identical to today's behavior; diagnostics
  distinguish `noTimestamp` from `outsideAllWindows`; nearest dive and signed
  gap are correct with several dives, including a file before the first dive
  and after the last.
- `exif_extractor_test.dart`: each cascade tier reports its own
  `TakenAtSource`; a file with no readable date reports `fileModifiedTime`.
- `files_tab_providers_test.dart`: offset defaults to zero; `setCaptureTimeOffset`
  updates offset and match together; `clearStagedFiles()` resets the offset
  while preserving `autoMatchByDate`; `_persistOne` writes a `taken_at` that
  includes the offset; `diveBoundsProvider` derives the documented entry and
  exit rule including the missing-exit-time fallback.
- `file_review_card_test.dart`: subtitle per `TakenAtSource`; corrected time
  shown with the original when the offset is non-zero; unmatched reason lines;
  the dive-picker escape hatch appears when `assignableDiveId == null`.
- `file_review_pane_test.dart` and `files_tab_test.dart`: bar visibility rules
  (hidden for site sessions, hidden when auto-match is off, still visible when
  everything matched); a stepper re-runs the match and updates the header.
- `test/l10n/arb_parity_test.dart` passes with the new keys in all locales.

Also required before the PR: `dart format .`, a whole-project `flutter
analyze`, and one full test suite run.

## Rollout

Single PR from `worktree-media-capture-time-offset`, closing #312 with a reply
to the reporter explaining which remedy addresses which of their two cases.
