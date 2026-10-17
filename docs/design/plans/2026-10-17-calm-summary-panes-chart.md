# Calm Summary Panes, PR 2: the Chart (Dive Sites) and the Passage (Trips)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Dive sites and Trips summary panes into the paper chart scene, the Trips one as "the passage" with a dashed course from Home through the last trip to the next, behind the corner toggle PR 1 built.

**Architecture:** One `ChartPainter` draws the drifting sheet (paper, coast, contours, soundings, compass, light sweep) edge to edge. The marks (dots, pulsing halos, the course) are a second painter inside the facts layer, laid out below the headline in a `Column` like the Dives depth region, and repainted off the pane's one clock through a new `SceneTime` listenable, so text never rebuilds per frame. Each feature adds a pure facts class (derived exactly as its summary widget derives them), a scene widget, and a pane that feeds `SummaryPaneSwitcher`.

**Tech Stack:** Flutter `CustomPainter` (`repaint:` listenable), Riverpod, go_router `goInPlace`, ARB l10n via `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-10-17-calm-summary-panes-design.md` (sections 6, 7.2, 8, 9, 10; section 2 is settled). Mockup values: `docs/design/specs/assets/2026-10-17-calm-summary-panes-mockup-realms.html` (section I, CSS `.pi`) and `...-mockup-rework.html` (T1, `#p-passage`). Tracking issue #3434.

## Global Constraints

- Branch is cut from `ericgriffin/entity-summary-redesign-0bcc42` (draft PR #3451, the integration branch). The PR targets that branch with `--base ericgriffin/entity-summary-redesign-0bcc42`, never main. Before opening it, `git fetch origin && git merge origin/ericgriffin/entity-summary-redesign-0bcc42`. The body says `Refs #3434` and that it targets the integration branch.
- Worktree setup: `git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
- One `SceneClock` per pane, 24 fps, still frame at `SceneClock.stillSeconds` (7.0) under reduce motion. Painters are pure functions of `(seconds, brightness)` plus constructor data; static geometry (paths, dashed paths, sounding `TextPainter`s) is built once and cached, never per frame.
- Mark positions are fixed and not geographic (spec 7.2): the chart is a drawing and must not pretend otherwise.
- The picture never mirrors. Mark dots and their labels are part of the picture, so they use physical `Positioned(left:/right:)`; the headline, sentence and footer use `EdgeInsetsDirectional`.
- Facts come only from what `SiteSummaryWidget` (`sitesWithCountsProvider`) and `TripSummaryWidget` (`tripListNotifierProvider`) read. Trips carry no country: no country count on the passage.
- Type colour is the scene's (`ChartPalette.ink`), never a colour-scheme secondary role. Dates go through `UnitFormatter` (the diver's date format). No unit-bearing numbers appear in these scenes.
- Strings: ARB keys in all eleven locales (`ar de en es fr he hu it nl pt zh`), inserted beside each feature's `*_summary_*` keys. Every `=1{...}` branch interpolates its argument (`=1{{sites} site}`); Arabic plurals give `=1`, `two`, `few`, `many`, `other`. Regenerate with `flutter gen-l10n` and commit `lib/l10n/arb/app_localizations*.dart` with the ARBs.
- Below **560 px** the headline is compact, the sentence spans the pane minus insets, and mark labels shorten to their compact form. Widget tests run at **400 x 400, 900 x 700 and 1600 x 1000**.
- Empty pages (no sites, no trips) default to the details view; the toggle stays.
- Tests that replace process-wide state restore it in `addTearDown`. After adding files under `lib/`, run `flutter test test/architecture test/shared`.
- Cover every new line (Codecov flags patch lines): every branch below has a test that reaches it.
- Files under 800 lines, no emojis, `dart format .` and `flutter analyze` clean before each commit. No tool or model attribution anywhere; no em-dash characters.
- UI change: the PR carries before and after screenshots, light and dark, at a master-detail width.

## Review Focus

1. One site is the most dived, the best rated and the last dived at once: the chart draws one mark, not three on top of each other, and the sentence still names it in each role. Pinned in Task 5.
2. Countries written "Malta" and "Malta " (or whitespace only): the headline's country count matches the details view's Countries card. Pinned in Task 5.
3. A trip that starts today, or is under way: it is the last trip, not the next one; a trip starting tomorrow is next with the countdown "In 1 day". Pinned in Task 6.
4. Only upcoming trips, or only past ones: the course runs Home to the one trip there is, and the sentence has only that clause. Pinned in Task 6.
5. A long site or trip name at 400 px, in Arabic: no overflow, labels stay beside their dots at the same physical positions as in English, and the headline aligns to the right. Pinned in Tasks 3 and 5.

---

### Task 1: SceneTime, facts under the clock, and SceneFooter

The marks layer lives in the facts tree (it is laid out below the headline), but its halos pulse, so it needs the clock. PR 1's pane hands the clock only to the full-pane painter.

**Files:**
- Modify: `lib/shared/widgets/scenes/scene_clock.dart`
- Modify: `lib/shared/widgets/summary/summary_scene_pane.dart`
- Modify: `lib/shared/widgets/summary/scene_text.dart`
- Test: `test/shared/widgets/scenes/scene_clock_test.dart`, `test/shared/widgets/summary/summary_scene_pane_test.dart`, `test/shared/widgets/summary/scene_text_test.dart`

**Interfaces:**
- Produces: `class SceneTime extends InheritedWidget` in `scene_clock.dart`, `const SceneTime({super.key, required this.seconds, required super.child})`, `final ValueListenable<double> seconds`, `static ValueListenable<double> of(BuildContext context)` (falls back to a shared, never-changing listenable holding `SceneClock.stillSeconds` when absent), `updateShouldNotify` true only when the listenable instance changes. `SceneClock.build` wraps its `ValueListenableBuilder` in `SceneTime(seconds: _seconds, ...)`.
- Produces: `SummaryScenePane` builds `SceneInk(...)` around `child` once, outside the clock, and puts the `SceneClock` above a `Stack` of the picture and that prebuilt facts widget, so the facts see `SceneTime` and, being the identical instance every frame, never rebuild. Public API unchanged.
- Produces: `SceneFooter(String text)` in `scene_text.dart`: `bodySmall`, ink at 60 %, weight w400.

- [ ] **Step 1: Write the failing tests**

```dart
// scene_clock_test.dart
testWidgets('publishes its clock to descendants through SceneTime', ...)
  // builder returns a widget that reads SceneTime.of(context); pump 1 s of frames:
  // the listenable's value advances (> 0.5)
testWidgets('SceneTime outside a clock holds the still frame', ...)
  // SceneTime.of(context).value == SceneClock.stillSeconds

// summary_scene_pane_test.dart
testWidgets('the facts do not rebuild while the clock runs', ...)
  // child = a build-counting widget; pump 60 frames of 16667 us: count stays 1
testWidgets('the facts can read the pane clock', ...)
  // a child reading SceneTime.of(context) sees a value that changes over a second

// scene_text_test.dart
testWidgets('SceneFooter is bodySmall in the ink at 60 percent', ...)
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/shared/widgets/scenes/scene_clock_test.dart test/shared/widgets/summary/`
Expected: the new tests FAIL (`SceneTime`, `SceneFooter` undefined); PR 1's tests pass.

- [ ] **Step 3: Implement the three changes**

- [ ] **Step 4: Run to verify all pass, then the Dives scene that rides on the pane**

Run: `flutter test test/shared/widgets/scenes test/shared/widgets/summary test/features/dive_log/presentation/widgets/dive_summary_scene_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/scenes/scene_clock.dart lib/shared/widgets/summary/summary_scene_pane.dart lib/shared/widgets/summary/scene_text.dart test/shared/widgets/scenes/scene_clock_test.dart test/shared/widgets/summary/
git commit -m "feat(scenes): share the pane clock with the facts layer"
```

---

### Task 2: The chart sheet painter

**Files:**
- Create: `lib/shared/widgets/scenes/scene_dash.dart`
- Create: `lib/shared/widgets/scenes/chart_painter.dart`
- Test: `test/shared/widgets/scenes/scene_dash_test.dart`, `test/shared/widgets/scenes/chart_painter_test.dart` (mirror `water_column_painter_test.dart`'s `render` helper)

**Interfaces:**
- Produces: `Path dashedPath(Path source, {required double dash, required double gap, double phase = 0})` in `scene_dash.dart` (shared code cannot import the planner's copy; `phase` shifts the pattern forward along the path, wrapping modulo `dash + gap`).
- Produces: `class ChartPalette` (`const`) with `paper, land, ink, line, landLine, sounding, mark, markLabel, sweep, course` (all `Color`) and `headScrim` (`double`), `static const light`, `static const dark`, `static ChartPalette of(Brightness)`:

| Field | light | dark |
| --- | --- | --- |
| paper | `0xFFEFE7D2` | `0xFF121C26` |
| land | `0xFFE4DABD` | `0xFF1C2A36` |
| ink (type) | `0xFF3B3324` | `0xFFD9E2EA` |
| line | `0x8C463C28` | `0x66BED2E1` |
| landLine | `0x80463C28` | `0x59BED2E1` |
| sounding | `0x8C3C321E` | `0x8CC8D7E4` |
| mark | `0xFF2A8AA6` | `0xFF7FD3EA` |
| markLabel | `0xFF1D5D70` | `0xFFBFE8F3` |
| sweep | `0x59FFFFFF` | `0x1FA0C8E6` |
| course | `0xCCB7352B` | `0xCCF08A7A` |
| headScrim | `0.55` | `0.5` |

- Produces: `class ChartPainter extends ScenePainter` with `ChartPainter({required super.seconds, required super.brightness})`.

- [ ] **Step 1: Write the failing tests**

```dart
// scene_dash_test.dart
test('dashes a straight line into dash-and-gap pieces', ...)
  // 100 px line, dash 6 gap 5 -> computeMetrics count 10, first length 6
test('a phase shifts the pattern along the path', ...)
  // phase 3 -> first metric length 3 (the tail of a dash), still covers to 100

// chart_painter_test.dart
test('paints every test size without throwing', ...)        // 400x400, 900x700, 1600x1000
test('is deterministic for the same seconds and brightness', ...)
test('moves with the clock', ...)                            // seconds 3 vs 30 differ
test('repaints only when the clock or brightness changes', ...)
test('the light sheet is paper and the dark sheet is slate', ...)
  // 200x140, pixel (20, 130) (open sea, below the compass): luminance(light) > 0.7, luminance(dark) < 0.15
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/shared/widgets/scenes/scene_dash_test.dart test/shared/widgets/scenes/chart_painter_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement `scene_dash.dart`, then `ChartPainter`**

Geometry is the mockup's, in its 1000 x 690 viewBox, built once as static `Path`s (dashed ones through `dashedPath` once) and drawn under a canvas transform, with stroke widths divided by the scale:

1. Fill the pane with `paper`.
2. Sheet transform, "slice" fit: scale `max(w / 1000, h / 690)`, centred. Drift with `p = (1 - cos(pi * seconds / 70)) / 2`: translate `lerp(-0.012, 0.012, p) * w`, `lerp(-0.006, 0.008, p) * h`; scale about the centre `1.02 + 0.02 * p` (never below 1.02, so the drift never shows the sheet's edge).
3. Land: `M690 0 C 640 90, 730 180, 660 260 S 720 420, 640 520 S 700 640, 660 690 L1000 690 L1000 0 Z`, fill `land`, stroke `landLine` 1 px.
4. Three contours, dash 3 gap 4, 0.8 px, `line` at 80 %: the coast's sea edge shifted left by 50, 100 and 150 (`M640 0 C 590 90, 680 180, 610 260 S 670 420, 590 520 S 650 640, 610 690` and its two neighbours).
5. Soundings, 11 px serif (`fontFamily: 'Iowan Old Style'`, fallback `Palatino, Georgia, Noto Serif, DejaVu Serif, serif`) in `sounding`: 12 (120,330), 18 (250,420), 27 (380,300), 9 (200,560), 33 (430,500), 21 (320,620), 24 (470,380), 14 (90,470). `TextPainter`s cached per brightness.
6. Compass rose at (130,150): circles r 46 and 30, a cross of half-length 58, and "N" at (-4,-66) at 12 px, all in `line`.
7. Head scrim, pane coordinates: a vertical gradient of `paper` at `headScrim` at 0 %, `headScrim * 0.9` at 26 %, transparent at 46 %, so the compass and contours fade under the headline.
8. Sweep, pane coordinates: a band `0.26 w` wide and `1.4 h` tall from `y = -0.2 h`, rotated 18 degrees about its centre, its left edge moving linearly from `-0.30 w` to `1.20 w` over 42 s (`seconds % 42`); horizontal gradient transparent, `sweep`, transparent; `MaskFilter.blur(normal, 14)`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/shared/widgets/scenes/scene_dash_test.dart test/shared/widgets/scenes/chart_painter_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/scenes/scene_dash.dart lib/shared/widgets/scenes/chart_painter.dart test/shared/widgets/scenes/scene_dash_test.dart test/shared/widgets/scenes/chart_painter_test.dart
git commit -m "feat(scenes): add the paper chart painter"
```

---

### Task 3: Chart marks: painter and layer

**Files:**
- Create: `lib/shared/widgets/scenes/chart_marks_painter.dart`
- Create: `lib/shared/widgets/summary/chart_marks_layer.dart`
- Test: `test/shared/widgets/scenes/chart_marks_painter_test.dart`, `test/shared/widgets/summary/chart_marks_layer_test.dart`

**Interfaces:**
- Consumes: `SceneTime` (Task 1), `ChartPalette`, `dashedPath` (Task 2), `SceneInk`, `SceneLabel`, `SceneLink`.
- Produces: `class ChartSpot extends Equatable` (`const ChartSpot({required this.at, this.halo = true, this.haloDelay = 0})`, `final Offset at` as fractions of the layer, `final bool halo`, `final double haloDelay` in seconds).
- Produces: `class ChartMarksPainter extends CustomPainter`, `ChartMarksPainter({required this.time, required this.brightness, required this.spots, this.course = false}) : super(repaint: time)`, `final ValueListenable<double> time`. Reads `time.value` in `paint`. `shouldRepaint` is true when `brightness`, `course` or `spots` (by `listEquals`) differ.
- Produces: `class ChartMark` (`const ChartMark({required this.spot, required this.label, this.compactLabel, this.onTap, this.semanticsLabel})`, `final String label`, `final String? compactLabel`, `final VoidCallback? onTap`, `final String? semanticsLabel`).
- Produces: `class ChartMarksLayer extends StatelessWidget`, `const ChartMarksLayer({super.key, required this.marks, this.course = false, this.compact = false})`. Fills its constraints: an `ExcludeSemantics(RepaintBoundary(CustomPaint(painter: ChartMarksPainter(time: SceneTime.of(context), ...))))` and, for mark `i`, a label keyed `ValueKey('chart-mark-$i')` set in `SceneInk(color: palette.markLabel)`: a `SceneLink` when `onTap` is set (semantics `semanticsLabel ?? label`), else a `SceneLabel`; text `compact ? (compactLabel ?? label) : label`.

Painting, per spot at `(at.dx * w, at.dy * h)`: when `course` and two or more spots, first a polyline of cubic segments through the spots in order, each segment from `a` to `b` with controls `a + d * 0.35 + n * 0.12` and `a + d * 0.65 - n * 0.12` (`d = b - a`, `n` = `d` turned 90 degrees anticlockwise), dashed 6/5 with `phase = seconds * 5.5 % 11` (220 px per 40 s), 1.4 px, `course`. Then for each spot with `halo`: a circle of radius `14 * (1 + 0.6 * q)` in `mark` at opacity `0.25 - 0.17 * q`, `q = (1 - cos(2 pi (seconds + haloDelay) / 8)) / 2`. Then the 4 px dot in `mark`.

Label placement (physical, never mirrored): vertically centred on the dot (`top: y - 9`). When `at.dx <= 0.6`, `left: x + 12, right: 0.075 * w`; otherwise `right: w - x + 12, left: 0.075 * w` with the text aligned to the dot side (`TextAlign.right`). Labels wrap; they never overflow.

- [ ] **Step 1: Write the failing tests**

```dart
// chart_marks_painter_test.dart (render helper as Task 2, with a ValueNotifier for time)
test('paints spots, halos and a course without throwing at every test size', ...)
test('is deterministic for the same time', ...)
test('the halos pulse with the clock', ...)          // time 0 vs 4 -> different bytes
test('the course creeps with the clock', ...)        // halo: false spots, course: true; time 0 vs 1 differ
test('repaints when the clock ticks, without a new painter', ...)
  // a ValueNotifier listener count > 0 after CustomPaint attaches (via widget test), or
  // painter.addListener fires on time.value change
test('shouldRepaint follows brightness, course and spots', ...)

// chart_marks_layer_test.dart (host: MaterialApp + SizedBox(w, h) + ChartMarksLayer)
testWidgets('a mark with onTap is a link that calls it', ...)
testWidgets('a mark without onTap is a plain label', ...)     // find.byType(SceneLink) findsNothing
testWidgets('compact shows the compact label', ...)
testWidgets('labels sit to the end of a dot on the start half and flip past 60 percent', ...)
  // at (0.3, 0.5): label left > 0.3 w; at (0.8, 0.5): label right < 0.8 w
testWidgets('a right-to-left locale does not move the marks', ...)
  // same rects for ValueKey('chart-mark-0') under ltr and rtl
testWidgets('a long label wraps without overflow at 400 x 400', ...)
  // 80-character label at (0.74, 0.5): takeException() isNull
testWidgets('the painter repaints off SceneTime', ...)
  // wrap in SceneTime(seconds: notifier); the CustomPaint's painter.time is that notifier
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/shared/widgets/scenes/chart_marks_painter_test.dart test/shared/widgets/summary/chart_marks_layer_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement the painter, then the layer**

- [ ] **Step 4: Run to verify they pass, then the guards**

Run: `flutter test test/shared/widgets/scenes test/shared/widgets/summary test/architecture`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/scenes/chart_marks_painter.dart lib/shared/widgets/summary/chart_marks_layer.dart test/shared/widgets/scenes/chart_marks_painter_test.dart test/shared/widgets/summary/chart_marks_layer_test.dart
git commit -m "feat(scenes): add chart marks with pulsing halos and a creeping course"
```

---

### Task 4: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces these keys. Insert `diveSites_scene_*` beside `diveSites_summary_*` and `trips_scene_*` beside `trips_summary_*`. The eyebrows reuse `diveSites_summary_header_title` and `nav_trips`; countdowns reuse `trips_list_countdown`; site dive counts reuse `diveSites_list_tile_diveCount`.

| Key | English | Placeholders |
| --- | --- | --- |
| `diveSites_scene_headline` | `{sites, plural, =1{{sites} site} other{{sites} sites}}, {countries, plural, =1{{countries} country} other{{countries} countries}}` | `sites` int, `countries` int |
| `diveSites_scene_headlineNoCountries` | `{sites, plural, =1{{sites} site} other{{sites} sites}}` | `sites` int |
| `diveSites_scene_sentence` | `Most dived: {mostDived}. Best rated: {bestRated}. Last dived: {lastDived}.` | three String |
| `diveSites_scene_sentenceUnrated` | `Most dived: {mostDived}. Last dived: {lastDived}.` | two String |
| `diveSites_scene_sentenceUndived` | `Best rated: {bestRated}. None dived yet.` | `bestRated` String |
| `diveSites_scene_sentenceNone` | `Saved, and waiting for a first dive.` | |
| `diveSites_scene_mark` | `{site} · {dives}` | `site` String, `dives` String |
| `diveSites_scene_withGps` | `{count, plural, =1{{count} with GPS} other{{count} with GPS}}` | `count` int |
| `diveSites_scene_notDived` | `{count, plural, =1{{count} not yet dived} other{{count} not yet dived}}` | `count` int |
| `trips_scene_headline` | `{trips, plural, =1{{trips} trip} other{{trips} trips}}, {days, plural, =1{{days} day diving} other{{days} days diving}}` | `trips` int, `days` int |
| `trips_scene_sentence` | `Next: {next}. {countdown}. Last: {last}, {date}.` | four String |
| `trips_scene_sentenceNextOnly` | `Next: {next}. {countdown}.` | two String |
| `trips_scene_sentenceLastOnly` | `Last: {last}, {date}.` | two String |
| `trips_scene_mark` | `{trip} · {when}` | two String |
| `trips_scene_home` | `Home` | |
| `trips_scene_liveaboards` | `{count, plural, =1{{count} liveaboard} other{{count} liveaboards}}` | `count` int |
| `trips_scene_divesAway` | `{count, plural, =1{{count} dive away} other{{count} dives away}}` | `count` int |

- [ ] **Step 1: Add the seventeen keys with `@` metadata to `app_en.arb`, then translations to the other ten**

Translate in each locale's own word order and separators; `countdown` is a full clause in every locale, so the sentence keeps it as its own sentence. Where a translation is legitimately the English word (an abbreviation like GPS, the middle-dot template), add it to `test/l10n/kept_english_values.dart` with the matching reason.

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n && git status --short lib/l10n/ && flutter analyze lib/l10n`
Expected: the eleven ARBs and `app_localizations*.dart` modified, analyze clean.

- [ ] **Step 3: Run the localisation guards**

Run: `flutter test test/l10n`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/ test/l10n/kept_english_values.dart
git commit -m "feat(l10n): add the chart and passage scene strings"
```

---

### Task 5: The Dive sites chart scene

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_summary_scene_facts.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_summary_scene.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_summary_scene_facts_test.dart`, `test/features/dive_sites/presentation/widgets/site_summary_scene_test.dart` (host as `site_summary_widget_test.dart`: `getBaseOverrides`, `sitesWithCountsProvider.overrideWith`, a `GoRouter` at `/sites`, view size reset in `addTearDown`)

**Interfaces:**
- Consumes: Tasks 1 to 4; `sitesWithCountsProvider`, `settingsProvider`, `UnitFormatter`, `context.goInPlace`.
- Produces: `class SiteSceneFacts` with `factory SiteSceneFacts.from(List<SiteWithDiveCount> sites)` and fields `int siteCount, countryCount, withGps, notDived`, `SiteWithDiveCount? mostDived, bestRated, lastDived`, and `List<SiteWithDiveCount> get marked` (the distinct sites among most dived, best rated, last dived, in that order, by `site.id`).
- Produces: `class SiteSummaryScene extends ConsumerWidget`, `const SiteSummaryScene({super.key})`, `static const double compactWidth = 560`, and `static const markPositions = [Offset(0.56, 0.24), Offset(0.30, 0.66), Offset(0.74, 0.50)]` with halo delays `0, -3, -5`.

Facts are derived exactly as `SiteSummaryWidget` derives them, reusing its sort expressions so each pick is that widget's first row: countries trimmed and keyed as there; `withGps` by `site.hasCoordinates`; `notDived` by `diveCount == 0`; `mostDived` the first of the descending dive-count sort with `diveCount > 0`; `bestRated` the first of the rating sort over `rating > 0`; `lastDived` the first of the `lastDivedAt` sort over non-null dates.

Layout, a `Column` inside a `LayoutBuilder` (lesson from PR 1: never independent pane fractions):

- Top padding `0.11 h`; headline block with `EdgeInsetsDirectional.only(start: 0.075 w, end: compact ? 0.075 w : 0.30 w)`: `SceneEyebrow(diveSites_summary_header_title)`, `SceneHeadline` (`headline` or `headlineNoCountries` when `countryCount == 0`, `compact` under 560 px), `SceneSentence` (max width `w - 0.15 w` when compact).
- Sentence: `mostDived` and `lastDived` both present: `sentence` when `bestRated` is too, else `sentenceUnrated`; otherwise `sentenceUndived` when `bestRated`, else `sentenceNone`.
- `Expanded(ChartMarksLayer(marks:, compact:))`: mark `i` of `marked` at `markPositions[i]`, label `diveSites_scene_mark(name, diveSites_list_tile_diveCount(count))`, compact label the name, `onTap` `goInPlace('${GoRouterState.of(context).uri.path}?selected=${site.id}')`.
- Footer `SceneFooter`, `EdgeInsetsDirectional.fromSTEB(0.075 w, 8, 0.075 w, 0.09 h)`: the non-zero of `withGps(n)` and `notDived(n)` joined with `' · '`; no footer when both are zero.
- Loading: the sheet paints, eyebrow only. Error: eyebrow only. Ink `ChartPalette.of(brightness).ink`; shadows `[Shadow(color: paper at 0.9, blurRadius: 6)]` built once per brightness as a `static final` so `SceneInk` stays identical.

- [ ] **Step 1: Write the failing tests**

```dart
// site_summary_scene_facts_test.dart (the five-site library of site_summary_widget_test.dart)
test('counts sites, trimmed countries, GPS and never-dived sites as the widget does', ...)
  // add 'Malta ' and '  ' country sites: countryCount still 3
test('picks the most dived, best rated and last dived sites', ...)   // a, a (rating 5), b
test('one site in every role is marked once', ...)                    // marked.length == 1
test('a library with no dives and no ratings has no picks', ...)

// site_summary_scene_test.dart
testWidgets('shows the site and country counts and names the three sites', ...)
  // '5 sites, 3 countries'; 'Most dived: Blue Hole. Best rated: Blue Hole. Last dived: Cathedral.'
testWidgets('marks open their site in place', ...)
  // tap ValueKey('chart-mark-0') -> router uri query selected == 'a'
testWidgets('one site in every role draws one mark', ...)             // chart-mark-1 findsNothing
testWidgets('the footer counts GPS and never-dived sites', ...)       // '0 with GPS' absent, '2 not yet dived' present
testWidgets('sites with no country leave the country out', ...)
testWidgets('an unrated library uses the unrated sentence', ...)
testWidgets('an undived, unrated library says it is waiting', ...)
testWidgets('loading and error show the eyebrow only', ...)
testWidgets('lays out without overflow at the three sizes', ...)      // long site name included
testWidgets('in Arabic the headline aligns right and the marks do not move', ...)
  // ar: eyebrow rect right > w * 0.5; chart-mark-0 rect equals the en rect
testWidgets('renders under every theme preset in both brightnesses', ...)
  // AppThemeRegistry.presets x light/dark: no exception; ChartPainter.brightness matches
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_summary_scene_facts_test.dart test/features/dive_sites/presentation/widgets/site_summary_scene_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement the facts, then the scene**

- [ ] **Step 4: Run to verify they pass**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_summary_scene_facts.dart lib/features/dive_sites/presentation/widgets/site_summary_scene.dart test/features/dive_sites/presentation/widgets/site_summary_scene_facts_test.dart test/features/dive_sites/presentation/widgets/site_summary_scene_test.dart
git commit -m "feat(dive-sites): add the chart scene for the Dive sites summary pane"
```

---

### Task 6: The Trips passage scene

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_summary_scene_facts.dart`
- Create: `lib/features/trips/presentation/widgets/trip_summary_scene.dart`
- Test: `test/features/trips/presentation/widgets/trip_summary_scene_facts_test.dart`, `test/features/trips/presentation/widgets/trip_summary_scene_test.dart` (host with `trip_summary_widget_test.dart`'s `_StubTripListNotifier`, plus a `GoRouter` at `/trips`)

**Interfaces:**
- Consumes: Tasks 1 to 4; `tripListNotifierProvider`, `settingsProvider`, `UnitFormatter.formatMonthYear`, `Trip.daysUntilStart`, `context.goInPlace`, `clock`.
- Produces: `class TripSceneFacts` with `factory TripSceneFacts.from(List<TripWithStats> trips, DateTime now)` and fields `int tripCount, totalDays, liveaboards, totalDives`, `TripWithStats? next, last`. As the widget: `totalDays` sums `trip.durationDays`; `next` is the earliest `startDate.isAfter(now)`; `last` is the latest of the rest (a trip under way, or starting today, is the last one).
- Produces: `class TripSummaryScene extends ConsumerWidget`, `const TripSummaryScene({super.key})`, positions `home Offset(0.19, 0.80)` (no halo), `last Offset(0.52, 0.56)` (delay 0), `next Offset(0.77, 0.26)` (delay -4).

Layout as Task 5, with:

- Eyebrow `nav_trips`; headline `trips_scene_headline(tripCount, totalDays)`.
- Sentence: both trips `trips_scene_sentence(next.name, trips_list_countdown(next.trip.daysUntilStart), last.name, units.formatMonthYear(last.trip.startDate))`; else `sentenceNextOnly` or `sentenceLastOnly`.
- `ChartMarksLayer(course: true, ...)`: Home (`trips_scene_home`), then last, then next, each present one only; trip labels `trips_scene_mark(name, when)` with `when` the month-year or the countdown; compact label the name; `onTap` `goInPlace('$path?selected=${trip.id}')`.
- Footer: the non-zero of `trips_scene_liveaboards(n)` and `trips_scene_divesAway(totalDives)` joined `' · '`.
- `now` is `clock.now()`. Loading: eyebrow only. Error: eyebrow only.

- [ ] **Step 1: Write the failing tests**

Dates are built from today with `DateTime(y, m, d + n)`, never `now.add(Duration(days:))` (DST).

```dart
// trip_summary_scene_facts_test.dart
test('totals trips, days, liveaboards and dives as the widget does', ...)
test('next is the earliest upcoming trip and last the latest started one', ...)
test('a trip starting today is the last trip, not the next', ...)
test('only upcoming trips leave last empty, only past ones leave next empty', ...)

// trip_summary_scene_test.dart
testWidgets('shows the trip count and days, and names the next and last trips', ...)
  // next start today + 23: 'Next: Komodo. In 23 days.'; last: 'Last: Bali, <formatMonthYear>.'
testWidgets('a trip starting tomorrow counts down one day', ...)       // 'In 1 day'
testWidgets('draws home, last and next with the course', ...)
  // chart-mark-0 'Home', chart-mark-1 last, chart-mark-2 next; ChartMarksPainter.course == true
testWidgets('only upcoming trips run the course from home to the next', ...)
  // two marks; sentenceNextOnly text
testWidgets('only past trips run the course from home to the last', ...)
testWidgets('a trip mark opens the trip in place', ...)
testWidgets('the footer counts liveaboards and dives, and leaves out zeros', ...)
testWidgets('loading and error show the eyebrow only', ...)
testWidgets('dates follow the diver date format', ...)                 // DateFormatPreference.dayMonthYear vs ISO
testWidgets('lays out without overflow at the three sizes', ...)
testWidgets('in Arabic the headline aligns right and the marks do not move', ...)
testWidgets('renders under every theme preset in both brightnesses', ...)
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/trip_summary_scene_facts_test.dart test/features/trips/presentation/widgets/trip_summary_scene_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement the facts, then the scene**

- [ ] **Step 4: Run to verify they pass**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_summary_scene_facts.dart lib/features/trips/presentation/widgets/trip_summary_scene.dart test/features/trips/presentation/widgets/trip_summary_scene_facts_test.dart test/features/trips/presentation/widgets/trip_summary_scene_test.dart
git commit -m "feat(trips): add the passage scene for the Trips summary pane"
```

---

### Task 7: Wire the Sites and Trips pages

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_summary_pane.dart`
- Create: `lib/features/trips/presentation/widgets/trip_summary_pane.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart` (both `summaryBuilder` sites, near lines 115 and 278)
- Modify: `lib/features/trips/presentation/pages/trip_list_page.dart` (both `summaryBuilder` sites, near lines 92 and 209)
- Test: `test/features/dive_sites/presentation/widgets/site_summary_pane_test.dart`, `test/features/trips/presentation/widgets/trip_summary_pane_test.dart`, and one desktop test each in `site_list_page_test.dart` and `trip_list_page_test.dart`

**Interfaces:**
- Consumes: `SummaryPaneSwitcher`, `SummaryPaneToggle`, Tasks 5 and 6.
- Produces: `SiteSummaryPane` and `TripSummaryPane` (`ConsumerWidget`, `const`), shaped like `DiveSummaryPane`: `SummaryPaneSwitcher(sectionId: 'sites' | 'trips', isEmpty:, scene:, details:)`, where `isEmpty` is true only once the list has loaded and is empty (a loading list is not empty, so the pane never flashes).

- [ ] **Step 1: Write the failing tests**

```dart
// site_summary_pane_test.dart and trip_summary_pane_test.dart
testWidgets('shows the scene by default', ...)              // find.byType(SiteSummaryScene)
testWidgets('shows the details when the setting says details', ...)
testWidgets('an empty list shows the details and keeps the toggle', ...)
testWidgets('a loading list shows the scene, not the details', ...)

// site_list_page_test.dart / trip_list_page_test.dart, 1200 x 800 as their desktop tests
testWidgets('desktop mode shows the chart scene in the summary pane', ...)
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_summary_pane_test.dart test/features/trips/presentation/widgets/trip_summary_pane_test.dart test/features/dive_sites/presentation/pages/site_list_page_test.dart test/features/trips/presentation/pages/trip_list_page_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 3: Add the two panes and replace the four `summaryBuilder` sites**

- [ ] **Step 4: Run Step 2's command, then both features' presentation folders**

Run: `flutter test test/features/dive_sites/presentation test/features/trips/presentation`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_summary_pane.dart lib/features/trips/presentation/widgets/trip_summary_pane.dart lib/features/dive_sites/presentation/pages/site_list_page.dart lib/features/trips/presentation/pages/trip_list_page.dart test/features/dive_sites/presentation/widgets/site_summary_pane_test.dart test/features/trips/presentation/widgets/trip_summary_pane_test.dart test/features/dive_sites/presentation/pages/site_list_page_test.dart test/features/trips/presentation/pages/trip_list_page_test.dart
git commit -m "feat(summary): show the chart scenes in the Sites and Trips summary panes"
```

---

### Task 8: Records, checks, screenshots, PR

- [ ] **Step 1: Commit this plan** (`docs(design): calm summary panes PR 2 plan`)
- [ ] **Step 2: Format and analyze**: `dart format . && flutter analyze`, clean (commit any format change as `style: format`).
- [ ] **Step 3: Run everything this PR touches**: `flutter test test/shared test/architecture test/l10n test/features/dive_sites/presentation test/features/trips/presentation test/features/dive_log/presentation/widgets`, PASS.
- [ ] **Step 4: Screenshots**: the macOS app at 1400 px wide, Sites and Trips with nothing selected, details (before) and scene (after), light and dark: eight images, handed to the maintainer and listed in the PR.
- [ ] **Step 5: Merge the integration branch**: `git fetch origin && git merge origin/ericgriffin/entity-summary-redesign-0bcc42`, then rerun Step 3's command if the merge brought changes.
- [ ] **Step 6: Open the PR** with `gh pr create --base ericgriffin/entity-summary-redesign-0bcc42`, title `feat(summary): calm summary panes, part 2: the chart for Sites and the passage for Trips`, body: summary, a note that it targets the integration branch of draft #3451, `Refs #3434`, the Screenshots section listing the eight images, the test commands run. Then watch its checks to green.
