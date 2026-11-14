# Media Hover Marks the Moment on the Dive Profile: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in one session. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hovering a media thumbnail in dive details moves the dive's shared
profile cursor to that item's moment, so the pinned strip shows its line, dot
and tooltip there (issue #4524).

**Architecture:** The media section reports "this item is hovered" through a
new optional callback and knows nothing about the profile. The dive details
section list turns that report into a write of `profileTrackingIndexProvider`,
using the one placement rule the full chart's camera chips already use. Every
existing follower of that provider (strip, full chart, cards) then follows the
hover with no change of its own.

**Tech Stack:** Flutter, Riverpod 3 (`flutter_riverpod` 3.4.2), flutter_test.

**Spec:** `docs/design/specs/2026-11-13-media-hover-profile-cursor-design.md`

## Global Constraints

- Mouse and trackpad only. Tap and long-press on a thumbnail behave as before.
- No new marker style, no new text, no new localization keys.
- No change to the camera chips on the full chart: `photoMarkersFromMedia`
  must return exactly what it returned before.
- A hover must never leave the cursor stuck after the pointer has left or
  after the hovered thumbnail has gone away.
- Provider writes never happen during build or dispose.
- `lib/features/media/presentation/widgets/dive_media_section.dart` gains no
  import of profile code.
- Imports grouped dart, flutter, packages, local. No em-dashes anywhere.

## Review Focus

- **Hovered thumbnail is unlinked and its neighbour slides under the
  pointer:** the cursor ends on the neighbour's moment, not cleared by the
  removed tile's late "left". Pinned in Task 3.
- **The page goes away while a thumbnail is hovered** (keyboard navigation to
  another dive): the cursor for that dive is cleared, with no "ref used after
  dispose" error. Pinned in Task 2 (deferred leave) and Task 4 (handler works
  with no widget tree).
- **Multi-computer dive:** the cursor index is computed against the active
  source's series, not `dive.profile`. Pinned in Task 4.
- **Capture time before the dive or after its end, inside the tolerance:**
  the mark clamps to the first or last second, as the chips do. Pinned in
  Task 1.
- **A touch on a thumbnail:** reports no hover. Pinned in Task 2.

---

### Task 1: One placement rule for chips and hover

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/photo_marker_layout.dart`
- Test: `test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart`

**Interfaces:**
- Produces: `PhotoChartMarker? photoMarkerFor(MediaItem item, {required int maxProfileSeconds})`.
  Null when the item has no place on the profile; otherwise the marker with
  `elapsedSeconds` clamped to `0..maxProfileSeconds`.

- [ ] **Step 1: Write the failing tests** in a new `group('photoMarkerFor')`,
  reusing the file's `_media` and `_enrichment` helpers:

```dart
test('places a photo with a time and depth', () {
  final marker = photoMarkerFor(
    _media(enrichment: _enrichment(elapsedSeconds: 600, depthMeters: 18)),
    maxProfileSeconds: 3000,
  );
  expect(marker!.elapsedSeconds, 600);
  expect(marker.depthMeters, 18);
});

test('clamps a time just outside the profile to its ends', () {
  expect(
    photoMarkerFor(
      _media(enrichment: _enrichment(elapsedSeconds: -30)),
      maxProfileSeconds: 3000,
    )!.elapsedSeconds,
    0,
  );
  expect(
    photoMarkerFor(
      _media(enrichment: _enrichment(elapsedSeconds: 3030)),
      maxProfileSeconds: 3000,
    )!.elapsedSeconds,
    3000,
  );
});

test('gives no place to a signature, a bare item, noProfile, a missing '
    'depth, or a time far outside the dive', () {
  MediaItem m(MediaEnrichment? e, {MediaSourceType? source}) => _media(
    enrichment: e,
    sourceType: source ?? MediaSourceType.platformGallery,
  );
  expect(photoMarkerFor(m(null), maxProfileSeconds: 3000), isNull);
  expect(
    photoMarkerFor(
      m(_enrichment(), source: MediaSourceType.signature),
      maxProfileSeconds: 3000,
    ),
    isNull,
  );
  expect(
    photoMarkerFor(
      m(_enrichment(confidence: MatchConfidence.noProfile)),
      maxProfileSeconds: 3000,
    ),
    isNull,
  );
  expect(
    photoMarkerFor(m(_enrichment(depthMeters: null)), maxProfileSeconds: 3000),
    isNull,
  );
  expect(
    photoMarkerFor(
      m(_enrichment(elapsedSeconds: 3000 + 86400)),
      maxProfileSeconds: 3000,
    ),
    isNull,
  );
});

test('a manual position passes even far outside the dive window', () {
  expect(
    photoMarkerFor(
      _media(
        enrichment: _enrichment(
          elapsedSeconds: 3000 + 86400,
          confidence: MatchConfidence.manual,
        ),
      ),
      maxProfileSeconds: 3000,
    )!.elapsedSeconds,
    3000,
  );
});
```

  If the existing helpers build a signature differently (check how the
  file's own signature test does it), follow that test.

- [ ] **Step 2: Run** `flutter test test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart`.
  Expected: FAIL, `photoMarkerFor` is not defined.

- [ ] **Step 3: Implement `photoMarkerFor`** above `photoMarkersFromMedia`,
  moving that function's per-item checks into it unchanged, and make
  `photoMarkersFromMedia` build its list from `photoMarkerFor` then sort. The
  doc comment that explains the rule (window tolerance, issue #1090, photos
  and videos, signatures excluded) moves with the checks.

- [ ] **Step 4: Run the same test file.** Expected: PASS, including every
  pre-existing `photoMarkersFromMedia` test untouched.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/photo_marker_layout.dart test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart && git commit -m "refactor(dive-log): one rule for whether a media item has a place on the profile"
```

### Task 2: A hover reporter that also reports its own removal

**Files:**
- Create: `lib/features/media/presentation/widgets/media_hover_region.dart`
- Test: `test/features/media/presentation/widgets/media_hover_region_test.dart`

**Interfaces:**
- Produces:

```dart
class MediaHoverRegion extends StatefulWidget {
  const MediaHoverRegion({
    super.key,
    required this.onHoverChanged,
    required this.child,
  });

  /// true when a mouse pointer enters, false when it leaves, and false once
  /// more, after the current frame, if the region is removed while hovered.
  final ValueChanged<bool> onHoverChanged;
  final Widget child;
}
```

- [ ] **Step 1: Write the failing tests.** Each pumps a `MaterialApp` with a
  100 x 100 `MediaHoverRegion` at the top-left that appends to a
  `List<bool> events`, and drives a
  `tester.createGesture(kind: PointerDeviceKind.mouse)` added at
  `Offset(500, 500)` (remove it in `addTearDown`):

  - `reports enter then leave`: move to `(50, 50)`, pump, expect `[true]`;
    move to `(500, 500)`, pump, expect `[true, false]`.
  - `reports a leave after the frame when removed while hovered`: move to
    `(50, 50)`, pump; `pumpWidget` a tree without the region; expect
    `[true, false]`.
  - `reports nothing when removed while not hovered`: `pumpWidget` a tree
    without the region; expect `events` empty.
  - `a touch reports no hover`: `await tester.tapAt(const Offset(50, 50))`,
    pump, expect `events` empty.
  - `the removal report is not made during the build or dispose phase`: the
    callback records `SchedulerBinding.instance.schedulerPhase`; after the
    removal case, the phase recorded for the final `false` is
    `SchedulerPhase.postFrameCallbacks`.

- [ ] **Step 2: Run** `flutter test test/features/media/presentation/widgets/media_hover_region_test.dart`.
  Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `MediaHoverRegion`.** A `MouseRegion` with
  `onEnter` and `onExit`, tracking a private hovered flag. `dispose`, when
  hovered, captures `widget.onHoverChanged` and schedules
  `WidgetsBinding.instance.addPostFrameCallback((_) => callback(false))`.
  The doc comment says why: Flutter does not call `onExit` for a region
  removed while hovered, and the listener may write a provider, which is not
  legal during dispose.

- [ ] **Step 4: Run the same test file.** Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/presentation/widgets/media_hover_region.dart test/features/media/presentation/widgets/media_hover_region_test.dart && git commit -m "feat(media): a hover region that reports its own removal"
```

### Task 3: The media section reports the hovered item

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
  (constructor, state, and the grid's `itemBuilder` near line 540)
- Test: `test/features/media/presentation/widgets/dive_media_section_hover_test.dart`

**Interfaces:**
- Consumes: `MediaHoverRegion` (Task 2).
- Produces: `DiveMediaSection.onHoverMedia`, type
  `void Function(MediaItem? item)?`. Called with the item when a mouse
  pointer enters its thumbnail and with null when the pointer leaves the item
  last reported. A leave for any other item is not reported.

- [ ] **Step 1: Write the failing tests.** Copy the `host` harness of
  `dive_media_section_selection_test.dart` (its `_item`, `_mediaProvider`,
  `settingsProvider` and `mediaForDiveProvider('dive-1')` overrides), add an
  `onHoverMedia` that appends to `List<MediaItem?> reported`, and find
  thumbnails with
  `find.descendant(of: find.byType(DragSelectGridView<MediaItem>), matching: find.byType(MediaHoverRegion))`.
  Mouse gesture as in Task 2.

  - `reports the item under the pointer, then null when it leaves`: move to
    the centre of the first thumbnail, pump, expect `reported.single.id` is
    `'a'`; move to `Offset(790, 590)` (clear of the grid), pump, expect
    `reported.last` is null.
  - `moving from one thumbnail to the next ends on the next item`: over the
    first then the second; expect `reported.last!.id` is `'b'`.
  - `removing the hovered item ends on the item that slides under the pointer`:
    hover the first of `[a, b]`; set `_mediaProvider` to `[b]`;
    `pumpAndSettle`; expect `reported.last!.id` is `'b'`.
  - `still reports in selection mode`: tap
    `find.byKey(const ValueKey('enter_selection'))`, pump, hover the first
    thumbnail, expect `reported.last!.id` is `'a'`.
  - `without the callback, hovering does nothing and does not throw`: host
    with no `onHoverMedia`, hover, pump, `expect(tester.takeException(), isNull)`.

- [ ] **Step 2: Run** `flutter test test/features/media/presentation/widgets/dive_media_section_hover_test.dart`.
  Expected: FAIL, `onHoverMedia` is not a parameter.

- [ ] **Step 3: Implement.** Add the `onHoverMedia` field with a doc comment
  stating the contract above. In the state, keep `String? _hoveredMediaId`
  (not build state: never `setState` for it) and a method
  `void _onTileHover(MediaItem item, bool hovered)`: on enter, record the id
  and report the item; on leave, report null only when the id is the recorded
  one, then forget it. In `itemBuilder`, wrap the existing
  `GestureDetector` in
  `MediaHoverRegion(onHoverChanged: (h) => _onTileHover(item, h), child: ...)`.

- [ ] **Step 4: Run** the new file and the three existing section tests:
  `flutter test test/features/media/presentation/widgets/dive_media_section_hover_test.dart test/features/media/presentation/widgets/dive_media_section_selection_test.dart test/features/media/presentation/widgets/dive_media_section_test.dart test/features/media/presentation/widgets/dive_media_section_unlink_test.dart`.
  Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/presentation/widgets/dive_media_section.dart test/features/media/presentation/widgets/dive_media_section_hover_test.dart && git commit -m "feat(media): the dive media section reports the hovered thumbnail"
```

### Task 4: Dive details turns the hover into the profile cursor

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart`
  (the `DiveDetailSectionId.media` case near line 296)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover_test.dart`

**Interfaces:**
- Consumes: `photoMarkerFor` (Task 1), `DiveMediaSection.onHoverMedia`
  (Task 3), `profileTrackingIndexProvider`, `activeSourceProfileProvider`,
  `indexForTimestamp`.
- Produces:

```dart
/// What dive details does when a media thumbnail is hovered ([item]) or the
/// pointer leaves it (null): moves or clears [dive]'s shared profile cursor.
void Function(MediaItem? item) mediaHoverCursorHandler(
  ProviderContainer container,
  Dive dive,
);
```

- [ ] **Step 1: Write the failing tests** against a bare `ProviderContainer`
  (disposed in `addTearDown`), with
  `activeSourceProfileProvider('dive-1').overrideWith((ref) => null)` unless
  the test says otherwise, a `Dive` whose `profile` has samples at
  0, 10, 20 ... 600 s, and media built like Task 1's helpers:

  - `moves the cursor to the sample at the item's moment`: item at 125 s;
    after `handler(item)`, `profileTrackingIndexProvider('dive-1')` is
    `indexForTimestamp(dive.profile, 125)` (12).
  - `clears the cursor when the pointer leaves`: `handler(item)` then
    `handler(null)`; the provider is null.
  - `an item with no place on the profile leaves the cursor as it is`: set
    the provider to 7, `handler(itemWithNoEnrichment)`, the provider is
    still 7.
  - `a dive with no profile does nothing`: `Dive` with an empty profile,
    `handler(item)`, the provider is null.
  - `indexes the active source's series on a multi-computer dive`: override
    `activeSourceProfileProvider('dive-1')` with a `SourceProfile` whose
    `points` are at 0, 60, 120 ... 600 s; item at 125 s gives index 2.
  - `clamps a capture time past the end to the last sample`: item at 620 s
    (inside the window tolerance) gives `dive.profile.length - 1`.

- [ ] **Step 2: Run** `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover_test.dart`.
  Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `mediaHoverCursorHandler`.** The returned closure
  reads the series at call time
  (`container.read(activeSourceProfileProvider(dive.id))?.points ?? dive.profile`,
  the same rule as `watchChartProfile`), and writes
  `profileTrackingIndexProvider(dive.id)` only when the value changes. It
  takes a `ProviderContainer`, not a `WidgetRef`, because the deferred leave
  of Task 2 can arrive after the page's widgets are gone; say so in the doc
  comment. For a non-null item with no marker, or an empty series, it writes
  nothing.

- [ ] **Step 4: Wire it.** In `DiveDetailSectionList`, pass
  `onHoverMedia: mediaHoverCursorHandler(ref.container, dive)` to
  `DiveMediaSection`.

- [ ] **Step 5: Run** the new test file. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover.dart lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart test/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover_test.dart && git commit -m "feat(dive-log): hovering a media thumbnail marks its moment on the profile"
```

### Task 5: Whole-change checks and the after screenshot

- [ ] **Step 1:** `dart format .` then `flutter analyze` (whole repo).
  Expected: no changes left unformatted, no issues.
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/` (new files
  under `lib/`). Expected: PASS.
- [ ] **Step 3:** `flutter test test/features/dive_log/presentation/widgets/pinned_profile/ test/features/dive_log/presentation/widgets/dive_detail/ test/features/media/presentation/widgets/`.
  Expected: PASS.
- [ ] **Step 4:** Build the macOS debug app, open dive 36 on the seeded
  private database, scroll to Photos & Video, put the pointer on the second
  thumbnail, and capture the same frame as
  `01-dive-details-media-hover-before.png`: the strip now shows its cursor
  and tooltip at that photo's moment. Move the pointer off and confirm the
  cursor clears.
- [ ] **Step 5:** Commit anything the formatter changed.
