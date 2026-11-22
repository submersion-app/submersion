# Marine life labels in the viewer: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in one session, in order. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Photos get the same species pills as videos, an All life mode marks
everything detected, a labels menu switches modes and re-analyses, the
species list under the scrub bar stays one line high, and progress moves to
the scrub bar and the labels button (issue #4825, v1.8.5).

**Architecture:** The label rules stay pure functions in
`species_id/domain/services` and gain a mode and a photo variant. The drawing
and tap handling move out of `VideoIdentificationLayer` into one shared
painter that a new photo layer also feeds. Re-analysis is two flags on the
existing request path of `MediaIdentificationService`; a dismissed detection
it brings back is stored as "reopened" (undecided, with `decidedAt` set) so
auto-apply never tags it.

**Tech stack:** Flutter, Riverpod (StateNotifier and FutureProvider families),
Drift (no schema change), `photo_view`, `video_player`, ARB l10n in 11
locales.

**Spec:** `docs/design/specs/2026-11-20-marine-life-viewer-labels-design.md`

## Global constraints

- Everything is behind `marineLifeIdEnabled`. Tests set it true and call
  `resetMarineLifeIdEnabled()` in `addTearDown` (issue #2500: a test puts
  process-wide state back).
- No schema change, no write to a synced table from a detection, a mode
  change or a re-analysis.
- No file over 800 lines. `media_viewer_page.dart` is at 792 and
  `media_identification_service.dart` at 802: new code for them goes in
  their part files, and neither may end longer than it starts.
- Every new string is added to all 11 ARB files under `lib/l10n/arb/`,
  beside a neighbouring key of the same feature group (the files are
  feature-grouped, not sorted), then `flutter gen-l10n`.
- Paths in tests are built with `p.join` and `Directory.systemTemp`.
- Run only the test files a task names, by path. Never a folder, never the
  suite, never `--build-filter`.
- Before each commit: `dart format .` and `flutter analyze` (whole repo).
- Commit messages name no tool. Stage explicit paths, never `git add -A`.
- `video_controls_bar.dart` is also edited by open PR #4821: change it by
  one inserted child and one import.

## Review focus

Conditions the spec implies that are most likely to bite, each pinned by a
test in the task named:

1. **Analyse again pressed while that same video is being scanned, or a
   fresh video job put back in the queue for other work.** Expected: one
   restart from the beginning, never a second one, never a loop (Task 3,
   "a fresh video scan put back resumes instead of restarting").
2. **Right-to-left locales (ar, he) in the one-line species list.**
   Expected: chips run from the right and "+N" sits at the left end (Task 8,
   "lays out from the right in a right-to-left direction").
3. **One chip wider than the whole line (large text, narrow phone).**
   Expected: the line shows only "+N", with no overflow error and no growth
   in height (Task 8, "a first chip wider than the line leaves only the
   count").
4. **A school: a hundred detections on one photo or frame.** Expected: a
   hundred labels, none dropped, no exception (Task 1, "a hundred animals
   get a hundred labels"; Task 7, "a photo with a hundred detections draws
   them all").
5. **Another logbook opened during a fresh run.** Expected: nothing is
   reopened or stored in the new logbook (Task 3, "a fresh request asked for
   in a logbook since closed writes nothing").

---

### Task 1: Label rules gain a mode and a photo variant

**Files:**
- Create: `lib/features/species_id/domain/entities/label_mode.dart`
- Modify: `lib/features/species_id/domain/services/track_labels.dart`
- Test: `test/features/species_id/domain/track_labels_mode_test.dart` (new),
  `test/features/species_id/domain/track_labels_test.dart` (drop the
  six-label expectation)

**Interfaces:**
- Produces:
  - `enum LabelMode { names, allLife, off }` with `String get id => name`
    and `static LabelMode fromId(String? id)` (unknown or null gives
    `names`).
  - `TrackLabelKind? labelKind(MediaIdentification i, {required bool playing, LabelMode mode = LabelMode.names, int minDotMs = 1000, bool unconfirmed = false})`
  - `List<TrackLabel> labelsAt(List<MediaIdentification> shown, int ms, {required bool playing, LabelMode mode = LabelMode.names, Set<String> unconfirmedSpeciesIds = const {}})`
    (no `maxLabels`).
  - `List<TrackLabel> photoLabels(List<MediaIdentification> shown, {LabelMode mode = LabelMode.names, Set<String> unconfirmedSpeciesIds = const {}})`

The rule `labelKind` implements (spec section 1):

| Detection | Result |
| --- | --- |
| `mode == off` | null |
| rejected | null |
| accepted, and (a track, or `suggestable`, or `claimedSpeciesId != null`) | `accepted`, or `confident` when `unconfirmed` |
| accepted photo detection that is neither suggestable nor claimed | the unnamed rule |
| undecided and `confident` | `confident` |
| undecided and `suggestable` | `suggestion` |
| anything else undecided | the unnamed rule |

The unnamed rule: in `allLife`, `dot`. In `names`: a track gets `dot` only
when not `playing`, `specific`, and `durationMs >= minDotMs`; a photo
detection gets `dot` when `specific`; otherwise null.

`photoLabels` takes detections where `!isTrack`, uses `i.box` as the label's
box, passes `playing: false`, and merges and orders exactly as `labelsAt`
does (extract the merge into one private function both call).

- [ ] **Step 1: Write the failing tests** in `track_labels_mode_test.dart`,
  using `track(...)` and `identification(...)` from
  `test/features/species_id/data/identification_fixtures.dart`:

```dart
test('off draws nothing, whatever the animal', () {
  for (final t in [track('a'), track('b', decision: IdentificationDecision.accepted, decidedSpeciesId: 's')]) {
    expect(labelKind(t, playing: false, mode: LabelMode.off), isNull);
  }
});
test('all life gives a dot to an unnamed animal, playing or paused', () {
  final brief = track('a', suggestable: false, confident: false, specific: false, endMs: 1250);
  expect(labelKind(brief, playing: true, mode: LabelMode.allLife), TrackLabelKind.dot);
  expect(labelKind(brief, playing: false, mode: LabelMode.allLife), TrackLabelKind.dot);
});
test('names keeps the guarded paused dot on a video', () {
  final long = track('a', suggestable: false, confident: false, endMs: 2000);
  final brief = track('b', suggestable: false, confident: false, endMs: 1500);
  expect(labelKind(long, playing: false), TrackLabelKind.dot);
  expect(labelKind(long, playing: true), isNull);
  expect(labelKind(brief, playing: false), isNull);
});
test('a photo in names behaves like a paused video, without the one second rule', () {
  final specific = identification('p').copyWith(suggestable: false, confident: false, specific: true);
  final vague = specific.copyWith(specific: false);
  expect(labelKind(specific, playing: false), TrackLabelKind.dot);
  expect(labelKind(vague, playing: false), isNull);
  expect(labelKind(vague, playing: false, mode: LabelMode.allLife), TrackLabelKind.dot);
});
test('a photo tag fills the pill only on a detection the app could suggest or the diver named', () {
  final accepted = identification('p', decision: IdentificationDecision.accepted, decidedSpeciesId: 's');
  final weak = accepted.copyWith(suggestable: false, specific: true);
  final claimed = weak.copyWith(claimedSpeciesId: () => 's');
  expect(labelKind(accepted, playing: false), TrackLabelKind.accepted);
  expect(labelKind(weak, playing: false), TrackLabelKind.dot);
  expect(labelKind(claimed, playing: false), TrackLabelKind.accepted);
});
test('a dismissed animal draws nothing in all life', () {
  expect(labelKind(track('a', decision: IdentificationDecision.rejected), playing: false, mode: LabelMode.allLife), isNull);
});
test('a hundred animals get a hundred labels', () {
  // Disjoint boxes: a 10 by 10 grid of 0.05 squares.
  final many = [for (var k = 0; k < 100; k++) identification('p$k').copyWith(box: IdentificationBox(x: (k % 10) * 0.1, y: (k ~/ 10) * 0.1, width: 0.05, height: 0.05))];
  expect(photoLabels(many), hasLength(100));
});
test('photo labels merge two detections on one animal, the tag first', () { /* same box, one accepted, one suggestion: one label, kind accepted */ });
test('LabelMode.fromId reads an unknown id as names', () {
  expect(LabelMode.fromId('later-version'), LabelMode.names);
  expect(LabelMode.fromId(null), LabelMode.names);
  expect(LabelMode.fromId('allLife'), LabelMode.allLife);
});
```

  In `track_labels_test.dart`, replace the test that expects at most six
  labels with one expecting every label back for eight disjoint tracks.

- [ ] **Step 2: Run them, expect failure**

Run: `flutter test test/features/species_id/domain/track_labels_mode_test.dart`
Expected: compile failure (`LabelMode`, `photoLabels` undefined).

- [ ] **Step 3: Implement** `label_mode.dart` and the three functions.
- [ ] **Step 4: Run** the two test files above plus
  `test/features/species_id/domain/track_labels_unconfirmed_test.dart` and
  `test/features/species_id/domain/track_labels_smoothing_test.dart`.
  Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): label rules for an All life mode and for photos`

---

### Task 2: Reopened detections and what a re-analysis carries

**Files:**
- Modify: `lib/features/species_id/domain/entities/media_identification.dart`
  (`reopened`, `saidByDiver`)
- Modify: `lib/features/species_id/domain/services/identification_rules.dart`
  (`reopenDismissed`, `carryDecisions`)
- Modify: `lib/features/species_id/domain/services/auto_apply_rules.dart`
- Test: `test/features/species_id/domain/identification_rules_test.dart`,
  `test/features/species_id/domain/auto_apply_rules_test.dart`,
  `test/features/species_id/domain/video_identification_rules_test.dart`

**Interfaces:**
- Produces:
  - `bool get reopened` on `MediaIdentification`:
    `decision == undecided && decidedAt != null`. Its doc says: a detection
    the diver dismissed and a re-analysis they asked for brought back; shown
    and offered like any undecided one, never tagged by the app.
  - `saidByDiver` also true when `reopened` (so a video rescan carries it
    through `carryTrackDecisions`, which already copies `decision`,
    `decidedSpeciesId`, `decidedAt` and `claimedSpeciesId`).
  - `List<MediaIdentification> reopenDismissed(List<MediaIdentification> stored, {required DateTime now})`:
    each rejected row as `copyWith(decision: undecided, decidedAt: now)`;
    returns only the changed rows.
  - `carryDecisions` (same signature and return type) with three additions:
    1. A decided match also copies `claimedSpeciesId`.
    2. A previous row that is `reopened` is matched like a decided one (same
       top species, overlap at or above `sameAnimalOverlap`); the fresh
       detection takes `decision: undecided` and its `decidedAt`. An
       unmatched reopened row is deleted, not kept.
    3. A previous undecided row with a `claimedSpeciesId` and no decision is
       matched by overlap alone (the best overlap at or above
       `sameAnimalOverlap`, whatever the names); the fresh detection takes
       the claim. Unmatched, it is kept.
  - `identificationsToApply` skips `reopened` rows.

- [ ] **Step 1: Write the failing tests**

```dart
// identification_rules_test.dart
test('reopenDismissed turns a dismissal into an undecided row that remembers it', () {
  final rejected = identification('a', decision: IdentificationDecision.rejected, decidedAt: fixtureT0);
  final changed = reopenDismissed([rejected, identification('b')], now: fixtureT1);
  expect(changed, hasLength(1));
  expect(changed.single.decision, IdentificationDecision.undecided);
  expect(changed.single.decidedAt, fixtureT1);
  expect(changed.single.reopened, isTrue);
  expect(changed.single.saidByDiver, isTrue);
});
test('a reopened detection is carried to the fresh one of the same animal', () {
  final old = identification('old').copyWith(decidedAt: fixtureT0); // reopened
  final carried = carryDecisions(previous: [old], fresh: [identification('new')]);
  expect(carried.insert.single.reopened, isTrue);
  expect(carried.deleteIds, ['old']);
  expect(carried.keep, isEmpty);
});
test('a reopened detection the fresh run does not find is dropped', () {
  final old = identification('old').copyWith(decidedAt: fixtureT0, box: const IdentificationBox(x: 0.8, y: 0.8, width: 0.1, height: 0.1));
  final carried = carryDecisions(previous: [old], fresh: [identification('new')]);
  expect(carried.deleteIds, ['old']);
  expect(carried.insert.single.reopened, isFalse);
});
test('a name the diver gave a photo detection is carried by overlap alone', () {
  final claimed = identification('old').copyWith(claimedSpeciesId: () => 'sp_x');
  final other = identification('new').copyWith(candidates: const []); // no shared name
  final carried = carryDecisions(previous: [claimed], fresh: [other]);
  expect(carried.insert.single.claimedSpeciesId, 'sp_x');
  expect(carried.deleteIds, ['old']);
});
test('an accepted detection keeps its claim through a re-analysis', () {
  final accepted = identification('old', decision: IdentificationDecision.accepted, decidedSpeciesId: 'sp_x').copyWith(claimedSpeciesId: () => 'sp_x');
  final carried = carryDecisions(previous: [accepted], fresh: [identification('new')]);
  expect(carried.insert.single.claimedSpeciesId, 'sp_x');
});
// auto_apply_rules_test.dart
test('a reopened detection is never applied', () {
  final reopened = identification('a').copyWith(confident: true, decidedAt: fixtureT0);
  expect(identificationsToApply([reopened], const [], isVideo: false, scanComplete: true), isEmpty);
});
// video_identification_rules_test.dart
test('a rescan carries a reopened track to the fresh track of the same fish', () {
  final old = track('old').copyWith(decidedAt: fixtureT0);
  final result = carryTrackDecisions(decided: [old], fresh: [track('new')]);
  expect(result.insert.single.reopened, isTrue);
  expect(result.deleteIds, ['old']);
});
```

- [ ] **Step 2: Run** the three test files, expect the new tests to fail.
- [ ] **Step 3: Implement.** Read every use of `saidByDiver`
  (`video_identification_rules.dart`, `media_identification_video.dart`,
  `video_identification_scan.dart`) and confirm a reopened row belongs with
  the carried rows at each; none needs a change.
- [ ] **Step 4: Run** the three files plus
  `test/features/species_id/data/video_identification_scan_test.dart`.
  Expected: pass.
- [ ] **Step 5: Commit** `feat(species-id): remember a dismissal a re-analysis brings back`

---

### Task 3: Requests by hand and fresh requests in the service

**Files:**
- Create: `lib/features/species_id/data/services/media_identification_fresh.dart`
  (a `part of 'media_identification_service.dart'`)
- Modify: `media_identification_service.dart`, `media_identification_run_lane.dart`,
  `media_identification_video.dart`
- Test: `test/features/species_id/data/media_identification_service_fresh_test.dart`
  (new, on the helpers in `media_identification_service_fixtures.dart`)

**Interfaces:**
- Consumes: `reopenDismissed`, `carryDecisions` (Task 2).
- Produces:
  - `Future<void> request(MediaItem item, {GeoPoint? location, bool byHand = false, bool fresh = false})`.
    `fresh` implies `byHand`.
  - `Future<RunItemOutcome> requestFromRun(MediaItem item, {GeoPoint? location, required ... resolveImage, required ... resolveVideo, bool fresh = false})`
  - `_Job` gains `final bool byHand`, `bool fresh` (consumed once the fresh
    start is stored) and `bool wasFresh`.

Behaviour:

- **By hand.** In `_process`, the switch that reads
  `job.fromRun ? _runEnabled() : _enabled()` uses `_runEnabled()` when
  `job.fromRun || job.byHand`.
- **Fresh, both kinds.** After the logbook check and before the refresh
  decision, a fresh job writes `reopenDismissed(stored, now: _now().toUtc())`
  with `_identifications.updateDecisions`, re-reads `stored`, and only if
  `_databaseGeneration() == generation`.
- **Fresh photo.** Runs `_analyse` whatever `decideRefresh` says.
- **Fresh video.** `_refreshVideo` takes `force: job.fresh`; forced, the
  action is `VideoRefreshAction.rescan`. Its carry list (rows where
  `saidByDiver`) now includes the reopened rows and no rejected ones.
- **Consumed once.** When the fresh photo is stored, or the fresh video's
  starting run row (`scannedMs: 0`) is stored, set `job.fresh = false` and
  `job.wasFresh = true`. A job put back in the queue then resumes.
- **Never joins.** A fresh `request` does not return the running job's
  future for the same item: it queues. A running video scan of that item
  stops between chunks and is not put back (its `keepGoing` is false while a
  fresh job for the same id waits, and `_scanVideo` returns false for that
  case).
- **No auto-apply.** `_settled` returns early when `job.wasFresh`.
- The new part holds the fresh helpers and `_rename` (moved from the main
  file to offset the lines added there).

- [ ] **Step 1: Write the failing tests** (names and what each asserts):

```dart
test('a request by hand runs with identify on open switched off', () async {
  // service built with enabled: () => false; request(photo, byHand: true)
  // -> the fake engine analysed once, a run row is stored.
});
test('an ordinary viewer request is still skipped with identify on open off', () async { /* engine not called */ });
test('a fresh request analyses a photo that needs nothing', () async {
  // analyse once (ordinary), then request(photo, fresh: true): engine called twice.
});
test('a fresh request brings a dismissed suggestion back, reopened', () async {
  // analyse, reject(id), request(fresh: true) -> one row, decision undecided, reopened true.
});
test('a fresh request keeps an accepted detection and the name the diver gave', () async {
  // analyse, claim + tag, reconcile -> accepted; fresh -> still accepted, claimedSpeciesId kept.
});
test('nothing is auto-applied after a fresh request', () async {
  // onItemSettled counter: 1 after the ordinary request, still 1 after the fresh one.
});
test('a fresh video request scans from the start', () async {
  // run stored with scannedMs at the end; request(video, fresh: true) -> first chunk asked from ms 0.
});
test('a fresh video scan put back resumes instead of restarting', () async {
  // fresh video job; another item's request arrives after chunk 1 (put back);
  // when it runs again the next chunk starts where chunk 1 ended, not at 0.
});
test('a fresh request while the same video is being scanned restarts it once', () async {
  // ordinary video scan running; request(video, fresh: true) -> the running job ends,
  // exactly one run row with scannedMs 0 is stored afterwards.
});
test('a fresh request asked for in a logbook since closed writes nothing', () async {
  // reject(id); bump the generation the service reads; request(fresh: true) -> row still rejected.
});
test('a fresh run request from a dive run reopens too and reports done', () async { /* requestFromRun(fresh: true) */ });
```

- [ ] **Step 2: Run** the new file, expect compile failure (`byHand`, `fresh`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the new file and
  `test/features/species_id/data/media_identification_service_test.dart`,
  `media_identification_service_video_test.dart`,
  `media_identification_service_run_lane_test.dart`,
  `media_identification_service_apply_test.dart`,
  `media_identification_service_readiness_test.dart`. Expected: pass.
  Check `wc -l lib/features/species_id/data/services/media_identification_service.dart`
  is at most 802.
- [ ] **Step 5: Commit** `feat(species-id): analyse by hand, and analyse again from the start`

---

### Task 4: Check again on the dive's Marine life card

**Files:**
- Modify: `lib/features/species_id/data/services/dive_species_run.dart`,
  `lib/features/species_id/presentation/providers/dive_species_run_providers.dart`,
  `lib/features/species_id/presentation/widgets/dive_find_species_panel.dart`,
  the 11 ARB files
- Test: `test/features/species_id/data/dive_species_run_test.dart`,
  `test/features/species_id/presentation/dive_find_species_panel_test.dart`

**Interfaces:**
- Consumes: `requestFromRun(..., fresh: true)` (Task 3).
- Produces:
  - `DiveSpeciesRun({..., Future<RunItemOutcome> Function(MediaItem, GeoPoint?)? requestFresh})`
    (defaults to `request`, so existing constructions compile).
  - `Future<void> start(String diveId, {bool fresh = false})`. A fresh run
    asks through `requestFresh` and does not call `applyAll`
    (`speciesTagged` stays 0).
  - Keys: `dive_species_check_again` (the button),
    `dive_species_check_again_confirm` (the dialog's confirm button).
- Strings (English; add after `speciesReview_allChecked`):
  - `speciesReview_checkAgain`: "Check again"
  - `speciesReview_checkAgainTitle`: "Check this dive again?"
  - `speciesReview_checkAgainBody`: "Every photo and video on this dive is
    analysed again. Your species tags stay. Suggestions you dismissed come
    back."

The panel: where the button is disabled as "all checked" today, it is
enabled and reads Check again. Tapping it shows the confirmation; on
confirm it runs the same count-and-ask as Find species with nothing counted
as up to date (`checked: const {}`), then `start(dive.id, fresh: true)`.
`speciesReview_allChecked` is no longer shown; leave the key in the ARBs
only if another caller uses it, else remove it from all 11.

- [ ] **Step 1: Write the failing tests**

```dart
// dive_species_run_test.dart
test('a fresh run asks through requestFresh and tags nothing', () async {
  // run with request and requestFresh recording, applyAll counting;
  // await run.start('d1', fresh: true) -> requestFresh called per item, request never, applyAll 0 calls.
});
test('an ordinary run after a fresh one applies as before', () async { /* fresh flag does not stick to the dive */ });
// dive_find_species_panel_test.dart
testWidgets('an up to date dive offers Check again', (tester) async {
  await pumpCard(tester, installed: pack, checked: true);
  final button = tester.widget<OutlinedButton>(find.byKey(const ValueKey('dive_species_check_again')));
  expect(button.onPressed, isNotNull);
  expect(find.text('Check again'), findsOneWidget);
});
testWidgets('Check again asks first, and a confirmed one starts a fresh run', (tester) async {
  // tap -> dialog text 'Suggestions you dismissed come back.' visible; nothing started.
  // tap confirm -> recording run saw start('d1', fresh: true).
});
testWidgets('cancelling the confirmation starts nothing', (tester) async {});
```

  Extend the test's `_RecordingRun` to record the `fresh` argument.

- [ ] **Step 2: Run** both files, expect failure.
- [ ] **Step 3: Implement**, add the strings to all 11 ARBs, run
  `flutter gen-l10n`.
- [ ] **Step 4: Run** both files plus
  `test/features/species_id/presentation/dive_species_run_lifecycle_test.dart`.
  Expected: pass.
- [ ] **Step 5: Commit** `feat(species-id): check a dive again from its Marine life card`

---

### Task 5: The label mode preference and the viewer's read providers

**Files:**
- Create: `lib/features/species_id/presentation/providers/label_providers.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
  (one key), `lib/core/providers/root_overrides.dart`
- Test: `test/features/species_id/presentation/label_providers_test.dart` (new)

**Interfaces:**
- Consumes: `LabelMode` (Task 1), `MediaIdentificationService.upToDate`.
- Produces:
  - `SettingsKeys.marineLifeLabelMode = 'species_id_label_mode'`
  - `class LabelModeNotifier extends StateNotifier<LabelMode> with SerialPreferenceWrites`:
    `LabelModeNotifier(SharedPreferences prefs)`,
    `LabelModeNotifier.unstored(LabelMode mode)`, `Future<void> setMode(LabelMode mode)`.
    Modelled on `NamingLevelNotifier`.
  - `final labelModeProvider = StateNotifierProvider<LabelModeNotifier, LabelMode>(...)`
    (unstored `names` by default; `rootProviderOverrides` gives it the prefs).
  - `final photoDetectionsProvider = FutureProvider.autoDispose.family<List<MediaIdentification>, String>`:
    as `videoTracksProvider`, keeping rows where `!isTrack`.
  - `typedef ScanStretches = ({ScannedRanges scanned, int durationMs});`
    `final videoScanStretchesProvider = FutureProvider.autoDispose.family<ScanStretches?, String>`:
    null when the feature is off, the item has no run, the run has no
    `videoDurationMs`, or its scan is complete. Invalidated by
    `repository.watchChanges()`.
  - `class AnalysisTarget extends Equatable { const AnalysisTarget(this.item, this.location); }`
    (props: `item.id`, `item.mediaType`, `location`).
  - `enum MediaAnalysisState { noModel, notAnalysed, partial, analysed }`
  - `typedef MediaAnalysisStatus = ({MediaAnalysisState state, int found});`
    `final mediaAnalysisStatusProvider = FutureProvider.autoDispose.family<MediaAnalysisStatus, AnalysisTarget>`:
    `noModel` with no installed pack; `analysed` when the service's
    `upToDate([item], manifest:, locationOf:)` contains the item; `partial`
    when a run exists but it is not up to date; else `notAnalysed`. `found`
    is the number of stored rows that are not rejected. Invalidated by
    `repository.watchChanges()` and by `installedSpeciesPackProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
test('the label mode defaults to names and is stored when changed', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final notifier = LabelModeNotifier(prefs);
  expect(notifier.state, LabelMode.names);
  await notifier.setMode(LabelMode.allLife);
  expect(prefs.getString('species_id_label_mode'), 'allLife');
  expect(LabelModeNotifier(prefs).state, LabelMode.allLife);
});
test('a stored mode this version does not know reads as names', () async { /* prefs value 'x' */ });
test('photoDetectionsProvider leaves out video tracks', () async {});
test('videoScanStretchesProvider is null once the scan is complete, and gives the stretches before', () async {
  // run with scannedRanges [0..8000] of 25000 -> scanned.stretches.single == (startMs: 0, endMs: 8000), durationMs 25000
});
test('mediaAnalysisStatusProvider reads no model, not analysed, partial and analysed', () async {
  // four containers/overrides; found counts rows that are not rejected.
});
```

- [ ] **Step 2: Run** the file, expect compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file. Expected: pass.
- [ ] **Step 5: Commit** `feat(species-id): a labels mode preference and the viewer's status reads`

---

### Task 6: One shared painter, and the video layer through it

**Files:**
- Create: `lib/features/species_id/presentation/widgets/identification_labels.dart`
- Modify: `lib/features/species_id/presentation/widgets/video_identification_layer.dart`
- Test: `test/features/species_id/presentation/video_identification_layer_test.dart`
  (existing tests must pass unchanged, plus the new ones)

**Interfaces:**
- Consumes: `labelsAt(..., mode:)` (Task 1), `labelModeProvider` (Task 5).
- Produces:

```dart
/// What a tap on a label does, found by [identificationLabelTap] when
/// [IdentificationLabels.tapsByMarker] is on.
class LabelTap { const LabelTap(this.onTap); final VoidCallback onTap; }

class IdentificationLabels extends ConsumerWidget {
  const IdentificationLabels({
    super.key,
    required this.labels,
    required this.byId,        // Map<String, MediaIdentification>
    required this.species,     // Map<String, Species>
    required this.item,
    required this.picture,     // the rect the picture is drawn in
    this.floor,
    this.holdIn,               // EditSession<PhotoRecord>? taking edits; null = see-only
    this.keyPrefix = 'video_label',
    this.tapsByMarker = false,
  });
}

/// Runs the label under [globalPosition], if any. True when one was run.
bool identificationLabelTap(BuildContext context, Offset globalPosition);
```

  Keys stay `'${keyPrefix}_dot_<id>'` and `'${keyPrefix}_pill_<id>'`.

The painter holds what `_parts`, `_target`, `_openPill`, `_taggedName` and
`_PillLayout` do today, unchanged in look and behaviour. With
`tapsByMarker`, a tappable part is wrapped in
`MetaData(metaData: LabelTap(onTap), behavior: HitTestBehavior.opaque)`
inside a `Semantics(button: true, onTap: onTap)` instead of a
`GestureDetector`. `identificationLabelTap` hit-tests the view at the
position (`WidgetsBinding.instance.hitTestInView`) and runs the first
`RenderMetaData` in the path whose `metaData` is a `LabelTap`.

`VideoIdentificationLayer` keeps its constructor. It watches
`labelModeProvider`, returns nothing for `off`, passes `mode` to `labelsAt`,
and builds `IdentificationLabels`.

- [ ] **Step 1: Write the failing tests** (added to the existing file; its
  `pump` gains `LabelMode mode = LabelMode.names`, applied with
  `labelModeProvider.overrideWith((ref) => LabelModeNotifier.unstored(mode))`):

```dart
testWidgets('all life dots an unnamed fish while the video plays', (tester) async {
  await pump(tester, playing: true, mode: LabelMode.allLife);
  expect(find.byKey(const ValueKey('video_label_dot_c')), findsOneWidget);
});
testWidgets('off draws no label', (tester) async {
  await pump(tester, mode: LabelMode.off);
  expect(find.byType(TrackPill), findsNothing);
  expect(find.byType(TrackDot), findsNothing);
});
testWidgets('more than six fish are all labelled', (tester) async {
  // eight disjoint confident tracks -> eight TrackPill
});
testWidgets('identificationLabelTap runs a marker label under the point and reports it', (tester) async {
  // pump IdentificationLabels(tapsByMarker: true) with one dot and a sitting;
  // identificationLabelTap(context, centre of the dot) is true and the picker opens;
  // a point away from every label returns false.
});
```

- [ ] **Step 2: Run** the file, expect the new tests to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file and
  `test/features/media/presentation/pages/media_viewer_video_sitting_test.dart`,
  `media_viewer_video_controls_layout_test.dart`. Expected: pass, with no
  edits to tests that existed before this task.
- [ ] **Step 5: Commit** `refactor(species-id): draw video labels through a shared painter, by mode`

---

### Task 7: Labels on photos

**Files:**
- Create: `lib/features/species_id/presentation/widgets/photo_identification_layer.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_gallery.dart`
  (stateful: one `PhotoViewController` per photo page; mount the layer),
  `lib/features/media/presentation/pages/media_viewer_page.dart` and a part
  of it (the tap catcher)
- Test: `test/features/species_id/presentation/photo_identification_layer_test.dart`
  (new), `test/features/media/presentation/pages/media_viewer_photo_labels_test.dart` (new)

**Interfaces:**
- Consumes: `photoLabels`, `photoDetectionsProvider`, `labelModeProvider`,
  `IdentificationLabels`, `identificationLabelTap`.
- Produces:

```dart
class PhotoIdentificationLayer extends ConsumerWidget {
  const PhotoIdentificationLayer({
    super.key,
    required this.item,
    required this.imageSize,   // Size? of the decoded photo; null draws nothing
    required this.zoom,        // ValueListenable<double>, 1 when not zoomed
    this.sitting,
    required this.editable,
  });
}
```

How it draws, so labels keep their size on screen: inside a `LayoutBuilder`
giving the layer's size `s`, and for zoom `z`, it builds
`IdentificationLabels` in a box of size `s * z` with
`picture = containedImageRect(imageSize, s * z)`, then shrinks that box by
`1 / z` from the top left (`OverflowBox` plus `Transform.scale`). `PhotoView`
scales the layer by `z`, so positions match the photo and every part comes
out at its normal size.

Tags as shown, unconfirmed species and the sitting follow
`VideoIdentificationLayer` (`decisionsAsShown`, `shownTaggedSpecies`,
`speciesChipsShown`). `holdIn` is the sitting when `editable` and the
sitting is open. Labels use `keyPrefix: 'photo_label'` and
`tapsByMarker: true`. A dot's tap is `pickOtherSpecies` then
`mediaIdentificationServiceProvider.claim`; a suggestion pill opens
`SuggestionCropView`; a tagged pill pushes `/species/<id>`.

Gallery: `MediaViewerGallery` (or the widget that builds
`PhotoViewGallery.builder`) becomes stateful and keeps a
`PhotoViewController` per photo media id, disposing those whose item left
the list and all on dispose. Each photo page passes its controller to
`PhotoViewGalleryPageOptions.customChild(controller:)`, and `_PhotoItem`
mounts the layer for the current page only, outside people-tag mode and
white-point picking, with `zoom` derived from the controller's
`outputStateStream` (`scale ?? 1`).

Tap catcher: the page-level `GestureDetector` for photos keeps its place.
Its tap handling moves to a function in a part file,
`void _photoTapUp(TapUpDetails details, MediaItem item)`: picking white, it
picks; otherwise if `identificationLabelTap(context, details.globalPosition)`
it stops; otherwise it toggles the controls as today. `onTapUp` is null in
people-tag mode, as `onTap` is today. `media_viewer_page.dart` must end at
or under 792 lines.

- [ ] **Step 1: Write the failing tests**

```dart
// photo_identification_layer_test.dart (pumped in a 400 x 300 box, imageSize 400 x 300)
testWidgets('names shows a pill on a suggestion and on a tag, and a dot on a specific unnamed one', (tester) async {});
testWidgets('all life dots a vague detection too; off draws nothing', (tester) async {});
testWidgets('a pill keeps its height on screen when the photo is zoomed', (tester) async {
  // wrap the layer in Transform.scale(scale: 2) with zoom ValueNotifier(2.0):
  // tester.getRect(find.byType(TrackPill).first).height closeTo 26, as at zoom 1.
});
testWidgets('a label sits on its animal at any zoom', (tester) async {
  // dot centre == centre of the detection's box in the transformed picture, at zoom 1 and 2.
});
testWidgets('locked, labels are see-only', (tester) async {
  // sitting null: identificationLabelTap on a dot returns false.
});
testWidgets('unlocked, a dot names the animal and claims the detection', (tester) async {
  // sitting open; identificationLabelTap on the dot -> picker; pick -> service.claims has (mediaId, id, speciesId).
});
testWidgets('a photo with a hundred detections draws them all', (tester) async {
  // all life, 100 disjoint detections -> 100 TrackDot, tester.takeException() isNull.
});
testWidgets('no image size yet draws nothing', (tester) async {});
// media_viewer_photo_labels_test.dart (the real viewer, media_widget_harness)
testWidgets('a photo in the viewer shows its labels', (tester) async {});
testWidgets('unlocked, a tap on a label acts on it and leaves the controls up', (tester) async {});
testWidgets('a tap off every label still toggles the controls', (tester) async {});
testWidgets('labels hide in people tag mode', (tester) async {});
```

- [ ] **Step 2: Run** both files, expect failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both files plus
  `test/features/media/presentation/pages/media_viewer_page_test.dart`,
  `media_viewer_unlock_test.dart`, `media_viewer_color_panel_test.dart`,
  `photo_viewer_gallery_change_test.dart`. Expected: pass. Check
  `wc -l lib/features/media/presentation/pages/media_viewer_page.dart`.
- [ ] **Step 5: Commit** `feat(species-id): name pills and dots on photos`

---

### Task 8: A species list one line high

**Files:**
- Create: `lib/shared/widgets/one_line_overflow_row.dart`,
  `lib/features/media/presentation/widgets/media_species_list_sheet.dart`
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart`,
  `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart`,
  the 11 ARB files
- Test: `test/shared/widgets/one_line_overflow_row_test.dart` (new),
  `test/features/media/presentation/widgets/media_species_chips_row_test.dart`,
  `media_species_chips_row_suggestions_test.dart`,
  `test/features/media/presentation/widgets/media_species_list_sheet_test.dart` (new),
  `test/features/media/presentation/pages/media_viewer_video_controls_layout_test.dart`

**Interfaces:**
- Produces:

```dart
/// Children on one line, as many as fit, then [overflowBuilder] for the rest.
class OneLineOverflowRow extends StatelessWidget {
  const OneLineOverflowRow({super.key, required this.children, required this.overflowBuilder, this.spacing = 8});
  final List<Widget> children;
  final Widget Function(BuildContext context, int hidden) overflowBuilder;
  final double spacing;
}

Future<void> showMediaSpeciesListSheet(BuildContext context, MediaItem item);
```

  `MediaSpeciesChipsRow` gains `required VoidCallback onMoreTap`. Keys:
  `media_species_more` (the count chip), `media_species_list_sheet`.
- Strings (after `media_species_unnamedFishLocked`):
  - `media_species_moreChips`: "{count} more species" (the count chip's
    semantic label; the chip itself reads "+{count}")
  - `media_species_listTitle` / `media_species_listTitleVideo`: "Species in
    this photo" / "Species in this video"
  - `media_species_listLocked`: "Unlock to add or dismiss"

`OneLineOverflowRow` layout (a custom multi-child render object; this is the
one algorithm the tests do not fix by themselves). Its render children are
the `n` items followed by `n` indicators, where indicator `h` is
`overflowBuilder(context, h)` for `h` in 1 to `n`:

1. Lay each item out loose within the line's width.
2. If all `n` fit with `spacing` between them, show them all and no
   indicator.
3. Otherwise take the largest `m < n` for which the first `m` items, then
   indicator `n - m`, fit with `spacing` between each. `m` may be 0: then
   only the indicator shows.
4. The row is as tall as its tallest shown child and as wide as the line.
   Shown children are centred vertically and run from the start edge of the
   ambient `Directionality`.
5. Children not shown are not painted, not hit and not in the semantics
   tree.

Chips row: the same chips in the same order, as `children` of the row, and
an `ActionChip` reading `+N` as the indicator, calling `onMoreTap`. The scan
progress chip and `_ScanProgressChip` are removed (Task 10 replaces them).
The chip builders move to a function both the row and the sheet call.

Bottom panel: `onMoreTap` opens the species sheet when a sitting is open
(what a suggestion chip does) and `showMediaSpeciesListSheet` when locked.
The list sheet (`useSafeArea: true`) shows the title, the locked line, then
every chip wrapped under "Tagged" and "Suggested" headings reusing existing
strings where they exist; a tag opens its species page, a suggestion is
inert.

- [ ] **Step 1: Write the failing tests**

```dart
// one_line_overflow_row_test.dart (items are SizedBox(width: 100, height: 20), indicator SizedBox(width: 50), spacing 0, line 300 wide)
testWidgets('shows every child when they fit, and no count', (tester) async { /* 3 items */ });
testWidgets('shows what fits, then the count of the rest', (tester) async {
  // 5 items: items 0 and 1 found, 2 to 4 not; indicator built with hidden == 3 is the one shown.
});
testWidgets('never grows past one line', (tester) async { /* 40 items: height 20 */ });
testWidgets('a first chip wider than the line leaves only the count', (tester) async {
  // first item 400 wide: no item shown, indicator hidden == n, no exception.
});
testWidgets('lays out from the right in a right-to-left direction', (tester) async {
  // first item's right edge == line's right edge; indicator at the left of the shown items.
});
testWidgets('hidden children take no taps and are not announced', (tester) async {});
testWidgets('spacing counts towards what fits', (tester) async { /* spacing 30: 5 items -> 1 shown + count 4 */ });
// media_species_chips_row_test.dart
testWidgets('sixteen tags stay on one line with a count chip', (tester) async {
  // phone width: find.byKey('media_species_more') present, its text starts with '+';
  // the row is no taller than one chip.
});
testWidgets('the count chip calls onMoreTap', (tester) async {});
testWidgets('no scan progress chip is drawn', (tester) async {});
// media_viewer_video_controls_layout_test.dart
testWidgets('the scrub bar does not move when a video has many tags', (tester) async {
  // top of VideoControlsBar.trackKey with 16 tags == with 1 tag (phone view).
});
// media_species_list_sheet_test.dart
testWidgets('locked, the count chip opens a read-only list of every species', (tester) async {});
testWidgets('a tag in the list opens its species page; a suggestion does nothing', (tester) async {});
```

- [ ] **Step 2: Run** the listed files, expect failure.
- [ ] **Step 3: Implement**, add the strings, `flutter gen-l10n`. If
  `media_species_scanProgress` is no longer used after Task 10, remove it
  from the 11 ARBs in that task, not here.
- [ ] **Step 4: Run** the listed files plus
  `test/features/media/presentation/widgets/media_species_unconfirmed_test.dart`
  and `test/features/media/presentation/pages/media_viewer_library_overlays_test.dart`.
  Expected: pass.
- [ ] **Step 5: Commit** `feat(media): keep the viewer's species list to one line`

---

### Task 9: The labels button, its menu and its ring

**Files:**
- Create: `lib/features/species_id/presentation/widgets/labels_menu.dart`,
  `lib/features/species_id/domain/services/labels_menu_model.dart`
- Modify: `lib/features/media/presentation/widgets/media_viewer_toolbar.dart`,
  `lib/features/media/presentation/pages/media_viewer_chrome.dart`,
  `lib/features/media/presentation/pages/media_viewer_page.dart` (one
  argument), the 11 ARB files
- Test: `test/features/species_id/domain/labels_menu_model_test.dart` (new),
  `test/features/species_id/presentation/labels_menu_test.dart` (new),
  `test/features/media/presentation/widgets/media_viewer_toolbar_test.dart`

**Interfaces:**
- Consumes: `labelModeProvider`, `mediaAnalysisStatusProvider`,
  `mediaIdentificationBusyProvider`, `mediaIdentificationProgressProvider`,
  `request(..., byHand:, fresh:)`.
- Produces:

```dart
// labels_menu_model.dart (pure)
enum AnalyseAction { analyse, analyseAgain }
enum LabelsStatusLine { noModel, notAnalysed, analysing, analysingPercent, found }
typedef LabelsMenuModel = ({LabelsStatusLine line, int found, double? progress, AnalyseAction action, bool actionEnabled});
LabelsMenuModel labelsMenuModel({required MediaAnalysisState state, required int found, required bool busy, required double? progress});

// media_viewer_toolbar.dart
class ToolbarRing { const ToolbarRing([this.value]); final double? value; } // null spins
// MediaViewerAction gains: final ToolbarRing? ring;
// MediaViewerToolbar gains:
//   final void Function(BuildContext anchor)? onMarineLifeLabels; // null hides the action
//   final bool marineLifeLabelsOn;
//   final ToolbarRing? marineLifeRing;

// labels_menu.dart
Future<void> showMarineLifeLabelsMenu(BuildContext anchor, WidgetRef ref, {required MediaItem item, required GeoPoint? location});
```

- `labelsMenuModel`: busy gives `analysingPercent` when `progress != null`,
  else `analysing`, and `actionEnabled: false`. Not busy: `noModel` (action
  disabled), `notAnalysed` or `partial` (line `notAnalysed` when `found == 0`
  else `found`; action `analyse`, enabled), `analysed` (line `found`; action
  `analyseAgain`, enabled).
- Toolbar action: id `marine_life_labels`, placed in the action list just
  before Info, shown whenever `onMarineLifeLabels != null`, including when
  `readOnly` and when locked.
  Icon: the one the app uses for Marine life in `lib/core/icons`, else
  `Icons.set_meal_outlined`. Tinted primary when `marineLifeLabelsOn`.
- Priorities after this task: unlock -1, go_to_dive 0, share 1,
  marine_life_labels 2, info 3, perdix 4, species 5, adjust_color 6,
  write_metadata 7, people 7, lightroom 8, reupload 9.
- `toolbarActionButtons` draws a visible action with a `ring` as its icon
  centred in a 32 point `CircularProgressIndicator(strokeWidth: 2, value: ring.value)`.
  In the overflow menu the ring is not drawn.
- Menu (anchored at the button, as `showMediaReuploadMenu` anchors): a
  disabled first row with the status line; three rows keyed
  `labels_menu_names`, `labels_menu_all_life`, `labels_menu_off`, the one in
  force checked; a divider; a row keyed `labels_menu_analyse`. Picking a mode
  calls `setMode`. Picking the action calls
  `request(item, location: location, byHand: true, fresh: action == AnalyseAction.analyseAgain)`.
- Chrome: the page passes the location it gives `IdentificationTrigger` to
  `_toolbar`; `onMarineLifeLabels` is non-null when `marineLifeIdEnabled`
  and the item is a photo, or a video where
  `visionVideoRuns(defaultTargetPlatform)`. The ring is `ToolbarRing(progress)`
  while busy (progress null on a photo), else null.
- Strings (after `media_species_listLocked`):
  - `media_labels_action`: "Marine life labels"
  - `media_labels_names`: "Names"; `media_labels_allLife`: "All life";
    `media_labels_off`: "Off"
  - `media_labels_analyse`: "Analyse"; `media_labels_analyseAgain`:
    "Analyse again"
  - `media_labels_statusNoModel`: "No species model installed"
  - `media_labels_statusNotAnalysed`: "Not analysed yet"
  - `media_labels_statusAnalysing`: "Analysing..."
  - `media_labels_statusAnalysingPercent`: "Analysing, {percent}"
  - `media_labels_statusFound`: plural on `{count}`: "Nothing found",
    "1 found", "{count} found" (no hardcoded digit in the `one` branch)

- [ ] **Step 1: Write the failing tests**

```dart
// labels_menu_model_test.dart
test('busy on a video reads the percentage and disables the action', () {
  final m = labelsMenuModel(state: MediaAnalysisState.partial, found: 3, busy: true, progress: 0.42);
  expect(m.line, LabelsStatusLine.analysingPercent);
  expect(m.actionEnabled, isFalse);
});
test('a part scanned video offers Analyse, a finished one Analyse again', () {
  expect(labelsMenuModel(state: MediaAnalysisState.partial, found: 3, busy: false, progress: null).action, AnalyseAction.analyse);
  expect(labelsMenuModel(state: MediaAnalysisState.analysed, found: 3, busy: false, progress: null).action, AnalyseAction.analyseAgain);
});
test('no model disables the action', () {});
test('never analysed reads not analysed yet', () {});
// labels_menu_test.dart
testWidgets('the menu checks the mode in force and stores another when picked', (tester) async {});
testWidgets('Analyse asks by hand, not fresh; Analyse again asks fresh', (tester) async {
  // RecordingIdentificationService extended to record byHand and fresh.
});
testWidgets('the status line gives the percentage while a video is analysed', (tester) async {});
// media_viewer_toolbar_test.dart
test('on a phone the labels action takes the slot Info had', () {
  // actions unlock, share, labels, info, perdix at the width that gives 3 slots:
  // visible ids == ['unlock', 'marine_life_labels', 'share'] in toolbar order; info in overflow.
});
testWidgets('the labels action is offered while locked and in a read-only browser', (tester) async {});
testWidgets('a ring is drawn round the labels icon while analysing', (tester) async {
  // marineLifeRing: ToolbarRing(0.42) -> a CircularProgressIndicator with value 0.42 inside key 'viewer_marine_life_labels'. Use pump(), not pumpAndSettle().
});
testWidgets('no labels action without a handler', (tester) async {});
```

  Update the existing toolbar tests whose expected visible set changes
  because Info moved one rank down.

- [ ] **Step 2: Run** the three files, expect failure.
- [ ] **Step 3: Implement**, add the strings, `flutter gen-l10n`.
- [ ] **Step 4: Run** the three files plus
  `test/features/media/presentation/pages/media_viewer_shell_chrome_test.dart`,
  `media_viewer_browser_lock_test.dart`, `media_viewer_unlock_test.dart`.
  Expected: pass. Check the page file's line count again.
- [ ] **Step 5: Commit** `feat(species-id): a labels menu in the viewer, with Analyse and a progress ring`

---

### Task 10: Analysed stretches on the scrub bar

**Files:**
- Create: `lib/features/species_id/presentation/widgets/video_analysed_stretches.dart`
- Modify: `lib/features/media/presentation/widgets/video_controls_bar.dart`
  (one child, one import), the 11 ARB files if a key is retired
- Test: `test/features/species_id/presentation/video_analysed_stretches_test.dart`
  (new), `test/features/media/presentation/widgets/video_controls_bar_test.dart`

**Interfaces:**
- Consumes: `videoScanStretchesProvider` (Task 5).
- Produces: `class VideoAnalysedStretches extends ConsumerWidget { const VideoAnalysedStretches({super.key, required this.mediaId, required this.duration, required this.width}); }`.
  Each stretch is a 4 point tall box keyed
  `ValueKey('video_analysed_<startMs>')`, from
  `startMs / durationMs * width` to `endMs / durationMs * width`, coloured
  `Theme.of(context).colorScheme.tertiary`, with 2 point rounded ends. It
  draws nothing when the provider gives null. The duration used is the
  run's `durationMs`, falling back to the player's `duration` when 0.

In `VideoControlsBar`'s track `Stack`, it goes between the background track
and the progress track, so the played part and the thumb cover it.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('draws each analysed stretch along the bar', (tester) async {
  // stretches [0..10000] and [15000..20000] of 25000 on width 250:
  // rect of 'video_analysed_0' spans x 0 to 100; 'video_analysed_15000' spans 150 to 200.
});
testWidgets('draws nothing once the scan is complete', (tester) async { /* provider null */ });
testWidgets('draws nothing with the feature off', (tester) async {});
// video_controls_bar_test.dart
testWidgets('the analysed stretches sit under the played part', (tester) async {
  // paint order: VideoAnalysedStretches is before the progress track in the Stack's children.
});
```

- [ ] **Step 2: Run** both files, expect failure.
- [ ] **Step 3: Implement.** Remove `media_species_scanProgress` from the 11
  ARBs if nothing reads it now, and run `flutter gen-l10n`.
- [ ] **Step 4: Run** both files plus
  `test/features/media/presentation/widgets/video_controls_bar_playback_test.dart`.
  Expected: pass.
- [ ] **Step 5: Commit** `feat(species-id): show the analysed stretches on a video's scrub bar`

---

### Task 11: Docs, screenshots and the pull request

**Files:**
- Modify: `docs/developer/species-identification.md` (the viewer: modes,
  reopened detections, by-hand and fresh requests)
- Modify: `docs/design/specs/2026-11-20-marine-life-viewer-labels-design.md`
  only if the build departed from it

- [ ] **Step 1:** Update the developer doc.
- [ ] **Step 2:** `dart format .`, `flutter analyze`, and
  `python3.14 scripts/check_docs_links.py`. Expected: clean.
- [ ] **Step 3:** After screenshots with the same throwaway golden test that
  made the before set (kept outside the repo), extended with the new
  provider overrides: photo and video viewer in Names and All life, the menu
  open, the one-line list, the scrub bar tint, the dive card's Check again,
  at phone and desktop widths. Delete the throwaway test and its goldens
  from the tree afterwards.
- [ ] **Step 4:** Commit the doc change, push, open the PR from the
  template with `Closes #4825`, the spec and plan paths, and the screenshots
  attached through the project's secret gist.

---

### Task 12: Raise the detection ceiling in the species pack

In `~/repos/submersion-app/species-pack` (its own branch and pull request;
`Refs submersion-app/submersion#4825`).

**Files:** `manifest.py`, `manifest_test.py`, and whichever of `boxes.py`,
`megalodon.py`, `score.py` hold a default of 8.

- [ ] **Step 0:** In the app repository, search `lib/features/species_id`
  and its tests for anything that assumes eight boxes (a literal 8 beside
  `maxBoxes`, a fixed-length list, a fixture that pins the count as a rule
  rather than as sample data). Expected: only pack fixtures and sample data.
  Fix anything else in the app's pull request.
- [ ] **Step 1:** Change the pinned expectations in `manifest_test.py` first:
  `maxBoxes` 100 for both detectors and for `BOXES`, and the two detector
  ids to new ones (the existing ids with a `-b100` suffix). Run its tests,
  expect failure.
- [ ] **Step 2:** Change `manifest.py` to match; leave the Python scoring
  defaults at 8 where they describe how the bars were measured, and say so
  in a comment. Run the repo's tests, expect pass.
- [ ] **Step 3:** Measure before any publish: one school clip from the
  maintainer's log at the new ceiling on the Mac, with scan time per minute
  of video and peak memory against the same clip at 8. Report the numbers.
- [ ] **Step 4:** Open the pull request. **Stop and ask the maintainer
  before publishing a pack release.**
