# Calm Summary Panes, PR 1: Engine, Switcher, Setting and the Dives Water Column

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the scene engine, the scene-or-details switcher with its corner toggle, the Settings > Appearance default, and the first scene (the Dives water column), so every later scene is one painter plus one facts widget.

**Architecture:** A `SceneClock` widget (modelled on `OceanBackground`) publishes elapsed seconds at 24 fps and stops when the window is unfocused, covered, or under reduce motion. A scene is a pure `ScenePainter` of `(seconds, brightness)` under a facts layer of ordinary widgets; `SummaryScenePane` composes them. `SummaryPaneSwitcher` picks scene or details from a per-device `AppSettings.summaryPaneView` plus an in-memory per-section override that the corner toggle flips. `DiveSummaryScene` is the first consumer, reading exactly the providers `DiveSummaryWidget` reads.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` settings, `StateProvider.family` for the override), `CustomPainter`, `clock` package stopwatch, SharedPreferences, ARB l10n via `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-10-17-calm-summary-panes-design.md` (sections 6, 7.1, 8, 9 and 10 govern this PR). Tracking issue #3434; the PR body says `Refs #3434`.

## Global Constraints

- Worktree setup before starting: `git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
- The scene clock runs at **24 frames a second** on a `Timer.periodic`, never a vsync ticker. It stops when the app lifecycle is not resumed (a null state counts as resumed), when `TickerMode` is disabled, or when `MediaQuery.disableAnimations` is true. Under reduce motion it holds the still frame at **7.0 seconds**.
- Randomness is seeded; a frame at a given `(seconds, brightness, seed)` is reproducible.
- No cards, no coloured icon tiles, no buttons, no section headings in a scene. Facts are ordinary widgets excluded from nothing; the painter is wrapped in `ExcludeSemantics`.
- Type follows the preset's text theme family at `FontWeight.w300`; colour comes from the scene (`SceneInk`), never from `colorScheme.onSurfaceVariant` or any secondary role.
- Facts use directional insets (`PositionedDirectional`, `EdgeInsetsDirectional`); the painted picture never mirrors.
- Pane width floor **400 px**; below **560 px** the end column drops under the sentence and marker labels shorten to their value. Widget tests run at **400 x 400, 900 x 700 and 1600 x 1000**.
- Every unit goes through `UnitFormatter` with the active diver's settings. Every string is an ARB key in all eleven locales (`ar de en es fr he hu it nl pt zh`), inserted next to its feature's existing keys; after any ARB edit run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart` with the ARBs.
- A test that replaces process-wide state puts it back in `addTearDown` (CI bundles test files in one isolate). After adding files under `lib/`, run `flutter test test/architecture test/shared/widgets/label_with_control_adoption_test.dart test/shared/widgets/app_bar_text_action_adoption_test.dart`.
- Many small files, none over 800 lines. No emojis anywhere. `dart format .` clean and `flutter analyze` clean before every commit. Run only the test files you touched mid-task.
- No tool or model attribution in commits, PR text, or files.
- This PR is a UI change: it carries before and after screenshots in light and dark at a master-detail width (Task 10).

## Review Focus

1. A log with only prior dives (career totals above zero, `DiveStatistics.totalDives` zero): the headline shows the career count and no depth marker shows "0.0 m". Pinned in Task 8.
2. A diver in feet: the scale ticks and both markers read in feet with the diver's symbol, and the scale maximum rounds in feet. Pinned in Task 8.
3. The deepest dive has no site: the marker label is the date alone, with no "null" and no dangling comma. Pinned in Task 8.
4. A stored preference holding a value that is not a `SummaryPaneView` name: settings load without throwing and the view is `scene`. Pinned in Task 5.
5. Arabic or Hebrew: the toggle, the depth scale and the end column sit at the start of the window (the left), and the facts align to the right edge. Pinned in Tasks 7 and 8.

---

### Task 1: SceneClock

**Files:**
- Create: `lib/shared/widgets/scenes/scene_clock.dart`
- Test: `test/shared/widgets/scenes/scene_clock_test.dart`
- Reference: `lib/core/presentation/widgets/ocean_background.dart` (lines 85 to 165, the lifecycle and timer logic to mirror) and `test/core/presentation/widgets/ocean_background_test.dart` (the `frame budget` group, the test style to mirror)

**Interfaces:**
- Produces: `class SceneClock extends StatefulWidget` with `const SceneClock({super.key, required this.builder, this.framesPerSecond = 24})`, `final Widget Function(BuildContext context, double seconds) builder`, `final int framesPerSecond`, and `static const double stillSeconds = 7.0`. The builder runs once per published value inside a `ValueListenableBuilder<double>`. Under reduce motion the published value is `stillSeconds` and never changes.

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/widgets/scenes/scene_clock_test.dart
// Helper: pumps SceneClock inside MediaQuery(disableAnimations) + TickerMode +
// Directionality, with a builder that appends every seconds value to a list.
// countChangesOverOneSecond pumps 60 frames of 16667 us and counts value changes.

testWidgets('does not request a frame on every vsync', ...)
  // after the first pump: expect(tester.binding.hasScheduledFrame, isFalse)

testWidgets('advances about 24 times a second', ...)
  // expect(await countChangesOverOneSecond(tester), inInclusiveRange(20, 24))

testWidgets('freezes while the app is not focused and resumes from where it stopped', ...)
  // addTearDown restores AppLifecycleState.resumed
  // inactive: zero changes over a second, hasScheduledFrame false
  // resumed: changes > 0, and the value after resume minus the frozen value < 0.15

testWidgets('stops when TickerMode is disabled', ...)
  // tickersEnabled: false -> zero changes over a second

testWidgets('holds the still frame under reduce motion', ...)
  // disableAnimations: true -> last published value == SceneClock.stillSeconds,
  // zero changes over a second, hasScheduledFrame false
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/shared/widgets/scenes/scene_clock_test.dart`
Expected: FAIL, `scene_clock.dart` not found.

- [ ] **Step 3: Implement `SceneClock` in `lib/shared/widgets/scenes/scene_clock.dart`**

State mirrors `_OceanBackgroundState`: a `clock.stopwatch()`, a `ValueNotifier<double>`, a `Timer.periodic` at `Duration(microseconds: 1000000 ~/ framesPerSecond)`, `WidgetsBindingObserver` for lifecycle, `TickerMode.valuesOf(context).enabled` and `MediaQuery.maybeDisableAnimationsOf(context)` read in `didChangeDependencies`. When animations are disabled the notifier is set to `stillSeconds` and the timer is not started. Dispose the timer, the stopwatch and the notifier.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/scenes/scene_clock_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/scenes/scene_clock.dart test/shared/widgets/scenes/scene_clock_test.dart
git commit -m "feat(scenes): add SceneClock, a 24 fps clock that stops when unseen"
```

---

### Task 2: ScenePainter base and the water column painter

**Files:**
- Create: `lib/shared/widgets/scenes/scene_painter.dart`
- Create: `lib/shared/widgets/scenes/water_column_painter.dart`
- Test: `test/shared/widgets/scenes/water_column_painter_test.dart`
- Reference: `docs/design/specs/assets/2026-10-17-calm-summary-panes-mockup-realms.html`, the `.pa`, `.ray`, `.surf` CSS and the `drawSnow` script, for every timing and opacity below

**Interfaces:**
- Produces: `abstract class ScenePainter extends CustomPainter` with `const ScenePainter({required this.seconds, required this.brightness})`, `final double seconds`, `final Brightness brightness`, and `shouldRepaint(covariant ScenePainter old) => old.seconds != seconds || old.brightness != brightness`.
- Produces: `class WaterColumnPalette` (`const`) with `final Color surface, mid, deep` and `final double rayOpacity, snowOpacity, foamOpacity`, plus `static const light` (`0xFFA9E6EF`, `0xFF3EA3C6`, `0xFF0C3F70`, `0.50`, `0.85`, `0.42`) and `static const dark` (`0xFF1B6D8D`, `0xFF0D3A60`, `0xFF030B1B`, `0.26`, `0.75`, `0.16`), and `static WaterColumnPalette of(Brightness b)`.
- Produces: `class WaterColumnPainter extends ScenePainter` with `WaterColumnPainter({required super.seconds, required super.brightness, this.seed = 7})`, `final int seed`, `static const int snowCount = 90`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/widgets/scenes/water_column_painter_test.dart
// Helper: Future<Uint8List> render(WaterColumnPainter p, Size size) paints into a
// PictureRecorder, endRecording().toImage(w, h), toByteData(rawRgba).

test('paints every test size without throwing', ...)
  // for Size(400,400), Size(900,700), Size(1600,1000): render completes

test('is deterministic for the same seconds, brightness and seed', ...)
  // render(seconds: 3.0) twice at 200x140 -> byte lists equal

test('moves with the clock', ...)
  // render(seconds: 3.0) != render(seconds: 9.0)

test('repaints only when the clock or brightness changes', ...)
  // shouldRepaint: same seconds+brightness -> false; different seconds -> true; different brightness -> true

test('the light palette is brighter than the dark one at the surface', ...)
  // pixel (10, 10) of each render: luminance(light) > luminance(dark)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/shared/widgets/scenes/water_column_painter_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement `ScenePainter` in `scene_painter.dart` and `WaterColumnPainter` in `water_column_painter.dart`**

`paint` is a pure function of `seconds`, `brightness` and `seed`; precompute nothing mutable across frames. Draw in this order, with the mockup's values:

1. Vertical `LinearGradient` `surface` at 0 %, `mid` at 48 %, `deep` at 100 %.
2. Three rays: left edges at 22 %, 46 %, 68 % of width; widths 16 %, 10 %, 20 %; base rotations -16, -11, -19 degrees around their top centre; sway plus or minus 2.5 degrees and plus or minus 6 px over periods 18, 22, 26 s (ease-in-out, alternating); white-to-transparent gradient over 72 % of their 130 % height, `MaskFilter.blur(normal, 7)`, opacity `rayOpacity` scaled by 0.55 to 1.0 across the sway; `BlendMode.screen`.
3. Marine snow: `snowCount` particles from `Random(seed)`: x in [0, 1], y0 in [0, 1], radius 0.5 to 1.8 px, fall speed 0.0028 to 0.0091 of height per second, wobble `sin(seconds * 0.4 + phase) * 0.004` of width, alpha 0.18 to 0.58 times `snowOpacity`; y = `(y0 + speed * seconds) % 1.1 - 0.05`. Colour white in light, `0xFFD2EBF5` in dark.
4. Surface foam: two sine bands along the top 34 px, wavelength half the width, sliding at periods 26 s and 46 s in opposite directions, filled white at `foamOpacity` (second band at half that).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/scenes/water_column_painter_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/scenes/scene_painter.dart lib/shared/widgets/scenes/water_column_painter.dart test/shared/widgets/scenes/water_column_painter_test.dart
git commit -m "feat(scenes): add the water column painter"
```

---

### Task 3: Scene text widgets and SummaryScenePane

**Files:**
- Create: `lib/shared/widgets/summary/scene_text.dart`
- Create: `lib/shared/widgets/summary/summary_scene_pane.dart`
- Test: `test/shared/widgets/summary/scene_text_test.dart`
- Test: `test/shared/widgets/summary/summary_scene_pane_test.dart`

**Interfaces:**
- Consumes: `SceneClock` (Task 1), `ScenePainter` (Task 2).
- Produces: `class SceneInk extends InheritedWidget` with `const SceneInk({required this.color, required super.child})` and `static Color of(BuildContext)` (falls back to `Theme.of(context).colorScheme.onSurface` when absent).
- Produces: `SceneEyebrow(String text)` (upper-cased, `labelSmall`, letter spacing 1.8, ink at 68 %), `SceneHeadline(String text)` (`headlineSmall`, `w300`, ink), `SceneSentence(String text)` (`bodyMedium`, ink at 74 %, max width 520), `SceneLabel(String text)` (`bodySmall`, ink at 70 %), and `SceneLink({required String text, required VoidCallback onTap, required String semanticsLabel, TextStyle? style})` (dotted underline at ink 50 %, `SystemMouseCursors.click`, `Semantics(button: true, label:)`).
- Produces: `class SummaryScenePane extends StatelessWidget` with `const SummaryScenePane({super.key, required this.painterBuilder, required this.ink, required this.child})`, `final CustomPainter Function(double seconds, Brightness brightness) painterBuilder`, `final Color ink`, `final Widget child`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/widgets/summary/scene_text_test.dart
testWidgets('SceneLink is a button with the given label that calls onTap', ...)
  // find.bySemanticsLabel('open deepest dive') exists with SemanticsFlag.isButton; tap -> tapped == true
testWidgets('SceneLink underlines dotted in the ink colour at half opacity', ...)
  // Text style: decoration underline, decorationStyle dotted, decorationColor == ink.withValues(alpha: 0.5)
testWidgets('scene text takes the preset text family at weight 300', ...)
  // Theme with fontFamily 'Nunito': SceneHeadline's RichText style fontFamily == 'Nunito', fontWeight == w300

// test/shared/widgets/summary/summary_scene_pane_test.dart
testWidgets('the painter is excluded from semantics and the facts are not', ...)
  // CustomPaint has an ExcludeSemantics ancestor; a Text child does not
testWidgets('the painter receives the clock and the ambient brightness', ...)
  // dark theme -> painterBuilder called with Brightness.dark; under disableAnimations the seconds == SceneClock.stillSeconds
testWidgets('SceneInk.of inside the pane returns the ink colour', ...)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/shared/widgets/summary/`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement `scene_text.dart` and `summary_scene_pane.dart`**

`SummaryScenePane` builds `SizedBox.expand(child: Stack(children: [Positioned.fill(child: ExcludeSemantics(child: RepaintBoundary(child: SceneClock(builder: (context, s) => CustomPaint(painter: painterBuilder(s, Theme.of(context).brightness)))))), SceneInk(color: ink, child: child)]))`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/summary/`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/summary/scene_text.dart lib/shared/widgets/summary/summary_scene_pane.dart test/shared/widgets/summary/scene_text_test.dart test/shared/widgets/summary/summary_scene_pane_test.dart
git commit -m "feat(scenes): add scene text widgets and SummaryScenePane"
```

---

### Task 4: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

**Interfaces:**
- Produces these keys (English values given; translate each into the other ten locales, in that locale's own order and separators). Insert the `diveLog_scene_*` keys beside `diveLog_summary_selectDive` and the rest beside `settings_appearance_trendGaps_subtitle`; every ARB is feature-grouped.

| Key | English | Placeholders |
| --- | --- | --- |
| `diveLog_scene_headline` | `{dives, plural, =1{1 dive} other{{dives} dives}} · {time} below` | `dives` int, `time` String |
| `diveLog_scene_sites` | `{sites, plural, =1{1 site} other{{sites} sites}}. You return most to {site}.` | `sites` int, `site` String |
| `diveLog_scene_sitesNoTop` | `{sites, plural, =1{1 site} other{{sites} sites}}.` | `sites` int |
| `diveLog_scene_usualDepth` | `your usual depth` | |
| `diveLog_scene_deepest` | `deepest, {site}, {date}` | `site` String, `date` String |
| `diveLog_scene_deepestNoSite` | `deepest, {date}` | `date` String |
| `settings_appearance_summaryPanes` | `Summary panes` | |
| `settings_appearance_summaryPanes_subtitle` | `What a section shows when nothing is selected` | |
| `settings_appearance_summaryPanes_scene` | `Scene` | |
| `settings_appearance_summaryPanes_details` | `Details` | |
| `summaryPane_toggle_showDetails` | `Show details` | |
| `summaryPane_toggle_showScene` | `Show scene` | |

The eyebrow reuses the Dives section's existing app-bar title key; the filtered line reuses `diveLog_summary_filteredBanner`. No key for either.

- [ ] **Step 1: Add the twelve keys with `@` metadata to `app_en.arb`, then the translations to the other ten ARBs**

The `=1{...}` branch is the CLDR `one` category: keep the digit inside the branch as `1`, never `{dives}`, so French and Portuguese do not print "1" for zero. Keep each placeholder map in the same order across locales.

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n && git status --short lib/l10n/`
Expected: the eleven ARBs and `app_localizations*.dart` listed as modified, nothing else; `flutter analyze` clean.

- [ ] **Step 3: Run the localisation guard**

Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): add the dive scene, summary pane setting and toggle strings"
```

---

### Task 5: The `summaryPaneView` setting

**Files:**
- Create: `lib/core/constants/summary_pane_view.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys` near line 117, `AppSettings` fields near line 582, constructor defaults near line 769, `copyWith` near lines 964 and 1167, `_loadSettings` device-local block near line 1464, the two `AppSettings(...)` constructions near lines 1506 and 1576, `_saveSettings` near line 1653, setters near line 1875)
- Modify: `test/helpers/mock_providers.dart` (`MockSettingsNotifier`, add the setter beside `setAccentNavIcons` near line 154)
- Test: `test/features/settings/presentation/providers/home_card_settings_test.dart` (new group, reusing that file's container helper and fakes)

**Interfaces:**
- Produces: `enum SummaryPaneView { scene, details; static SummaryPaneView fromName(String? name) }` in `lib/core/constants/summary_pane_view.dart`, defaulting to `scene` for null or unknown names.
- Produces: `SettingsKeys.summaryPaneView = 'summary_pane_view'`; `AppSettings.summaryPaneView` (`SummaryPaneView`, default `scene`, in `copyWith`); `Future<void> SettingsNotifier.setSummaryPaneView(SummaryPaneView view)`; the same setter on `MockSettingsNotifier`. Stored as `view.name` with `prefs.setString`, read with `fromName(prefs.getString(...))` inside the existing try that guards corrupt device-local prefs.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/settings/presentation/providers/home_card_settings_test.dart
group('Summary pane view persistence', () {
  test('defaults to scene', ...)                // empty prefs -> settings.summaryPaneView == SummaryPaneView.scene
  test('setSummaryPaneView persists the name to SharedPreferences', ...)
    // after setSummaryPaneView(details): state details; prefs.getString(SettingsKeys.summaryPaneView) == 'details'
  test('a stored value that is not a view name loads as scene', ...)
    // setMockInitialValues({SettingsKeys.summaryPaneView: 'bogus'}) -> scene, no throw
  test('a stored details value is loaded on start', ...)
    // setMockInitialValues({SettingsKeys.summaryPaneView: 'details'}) -> details
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/home_card_settings_test.dart`
Expected: FAIL, `summaryPaneView` undefined.

- [ ] **Step 3: Implement the enum, the field, the key, load, save and the setter; add the setter to `MockSettingsNotifier`**

- [ ] **Step 4: Run the tests and the settings suite that already exercises `AppSettings`**

Run: `flutter test test/features/settings/presentation/providers/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/summary_pane_view.dart lib/features/settings/presentation/providers/settings_providers.dart test/helpers/mock_providers.dart test/features/settings/presentation/providers/home_card_settings_test.dart
git commit -m "feat(settings): add the per-device summary pane view setting"
```

---

### Task 6: The Appearance tile, in both appearance UIs

**Files:**
- Modify: `lib/features/settings/presentation/widgets/appearance_settings_tiles.dart` (`AppearanceGeneralTiles`, insert after the trend-gaps `ListTile` and before `NavCustomizationTile`, near line 170)
- Test: `test/features/settings/presentation/widgets/appearance_settings_tiles_test.dart` (use its `_pumpGeneralTiles` helper)

**Interfaces:**
- Consumes: `AppSettings.summaryPaneView`, `setSummaryPaneView` (Task 5), the four `settings_appearance_summaryPanes*` keys (Task 4).
- Produces: a `ListTile` keyed `ValueKey('settings-summary-pane-view')`, leading `FeatureAccentIcon(Icons.water, featureId: 'settings-appearance', surface: AccentSurface.list)`, title `LabelWithControl(label: Text(l10n.settings_appearance_summaryPanes), control: DropdownButton<SummaryPaneView>(...))` with `underline: const SizedBox.shrink()`, subtitle `Text(l10n.settings_appearance_summaryPanes_subtitle)`. Both the phone `AppearancePage` and the desktop `_AppearanceSectionContent` render `AppearanceGeneralTiles`, so one tile covers both; do not put a `DropdownButton` in `trailing` (the `label_with_control_adoption_test` guard rejects it).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('summary panes tile shows Scene by default', ...)
  // find.byKey(ValueKey('settings-summary-pane-view')) found; the dropdown's value == SummaryPaneView.scene; find.text('Scene') found
testWidgets('choosing Details calls setSummaryPaneView', ...)
  // open the dropdown, tap 'Details' -> notifier state summaryPaneView == details
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/presentation/widgets/appearance_settings_tiles_test.dart`
Expected: FAIL, key not found.

- [ ] **Step 3: Add the tile**

- [ ] **Step 4: Run the tile tests, both settings page tests and the adoption guard**

Run: `flutter test test/features/settings/presentation/widgets/appearance_settings_tiles_test.dart test/features/settings/presentation/pages/settings_page_test.dart test/shared/widgets/label_with_control_adoption_test.dart`
Expected: PASS. If `settings_page_test.dart` now pushes a section below the 800 x 600 fold, use `scrollUntilVisible` as its other sections do.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/widgets/appearance_settings_tiles.dart test/features/settings/presentation/widgets/appearance_settings_tiles_test.dart
git commit -m "feat(settings): add the Summary panes choice to Appearance"
```

---

### Task 7: SummaryPaneSwitcher and the corner toggle

**Files:**
- Create: `lib/shared/widgets/summary/summary_pane_switcher.dart`
- Test: `test/shared/widgets/summary/summary_pane_switcher_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` (`summaryPaneView`), `MockSettingsNotifier` in tests, the two `summaryPane_toggle_*` keys (Task 4).
- Produces: `final summaryPaneOverrideProvider = StateProvider.family<SummaryPaneView?, String>((ref, sectionId) => null)` (not autoDispose: the override lives for the session).
- Produces: `class SummaryPaneSwitcher extends ConsumerWidget` with `const SummaryPaneSwitcher({super.key, required this.sectionId, required this.scene, required this.details, this.isEmpty = false})`, `final String sectionId`, `final WidgetBuilder scene`, `final WidgetBuilder details`, `final bool isEmpty`. Resolution: `isEmpty ? details : (override ?? settings.summaryPaneView)`. Renders a `Stack` of the chosen view and, unless `isEmpty`, a `PositionedDirectional(top: 12, end: 12, child: SummaryPaneToggle(...))`.
- Produces: `class SummaryPaneToggle extends StatelessWidget` with `const SummaryPaneToggle({super.key, required this.showingScene, required this.onPressed})`: an `IconButton` whose icon is `Icons.grid_view` when `showingScene` and `Icons.water` otherwise, tooltip `summaryPane_toggle_showDetails` or `summaryPane_toggle_showScene`, a 30 px translucent disc (`Colors.white.withValues(alpha: 0.10)` fill, `0.22` border) with the icon at 16 px, and a hit box of at least 48 x 48 (`IconButton` default constraints; do not set `visualDensity`). The toggle sets `summaryPaneOverrideProvider(sectionId)` to the other view.

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/widgets/summary/summary_pane_switcher_test.dart
// Helper: pumps ProviderScope(overrides: [settingsProvider.overrideWith((_) => MockSettingsNotifier(settings))],
// child: MaterialApp(localizationsDelegates..., home: SummaryPaneSwitcher(sectionId: 'dives',
// scene: (_) => const Text('scene'), details: (_) => const Text('details'), isEmpty: ...)))

testWidgets('shows the scene by default', ...)                       // find.text('scene')
testWidgets('shows the details when the setting says details', ...)  // AppSettings(summaryPaneView: details)
testWidgets('an empty page shows the details and no toggle', ...)    // isEmpty: true -> 'details', find.byType(SummaryPaneToggle) findsNothing
testWidgets('the toggle flips the pane for the session only', ...)
  // tap -> 'details'; pumpWidget again with the SAME ProviderScope key/container -> still 'details';
  // a fresh ProviderScope -> 'scene'
testWidgets('the override is per section', ...)
  // two switchers 'dives' and 'sites' in one scope; flip 'dives' -> 'sites' still shows 'scene'
testWidgets('the toggle names the other view and keeps a 48 px target', ...)
  // tooltip 'Show details' while scene shows, 'Show scene' after; tester.getSize(find.byType(IconButton)) >= 48 x 48
testWidgets('the toggle sits at the end edge in a right-to-left locale', ...)
  // Directionality rtl: toggle rect left < pane width / 2
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/shared/widgets/summary/summary_pane_switcher_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 3: Implement `summary_pane_switcher.dart`**

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/summary/summary_pane_switcher_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/summary/summary_pane_switcher.dart test/shared/widgets/summary/summary_pane_switcher_test.dart
git commit -m "feat(scenes): add SummaryPaneSwitcher with the corner toggle"
```

---

### Task 8: DiveSummaryScene

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_summary_scene.dart` (the facts and layout)
- Create: `lib/features/dive_log/presentation/widgets/dive_summary_scene_markers.dart` (the depth scale and marker widgets)
- Test: `test/features/dive_log/presentation/widgets/dive_summary_scene_test.dart` (mirror the database setup and overrides of `dive_summary_widget_test.dart`)
- Reference: `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart` for every provider read and the `goInPlace` navigation; spec section 7.1 for the facts

**Interfaces:**
- Consumes: `SummaryScenePane`, `SceneEyebrow`, `SceneHeadline`, `SceneSentence`, `SceneLabel`, `SceneLink`, `SceneInk` (Task 3); `WaterColumnPainter`, `WaterColumnPalette` (Task 2); `careerTotalsProvider`, `diveStatisticsProvider`, `diveRecordsProvider`, `diveListScopedStatisticsProvider`, `diveListScopedRecordsProvider`, `diveFilterProvider`, `settingsProvider`, `UnitFormatter`, `context.goInPlace`.
- Produces: `class DiveSummaryScene extends ConsumerWidget` with `const DiveSummaryScene({super.key})`.
- Produces, in `dive_summary_scene_markers.dart`: `class DepthScale extends StatelessWidget` (`const DepthScale({super.key, required this.maxMeters, required this.units})`, keyed `ValueKey('scene-depth-scale')`, a 1 px hairline from 18 % to 92 % of the pane height at the end edge with tick labels at 0, half and `maxMeters`), `class DepthMarker extends StatelessWidget` (`const DepthMarker({super.key, required this.meters, required this.maxMeters, required this.value, required this.label, this.onTap, this.semanticsLabel, this.compact = false})`: a glowing 6 px dot, a hairline across the pane, the value at `headlineSmall` `w300`, the label as a `SceneLabel` or a `SceneLink` when `onTap` is set; `compact` hides the label), and `double depthToFraction(double meters, double maxMeters) => 0.18 + meters / maxMeters * 0.72`.

Facts (spec 7.1), read exactly as `DiveSummaryWidget` reads them, with `skipLoadingOnReload` on the scoped providers:

- Eyebrow: the Dives section title key.
- Headline: `diveLog_scene_headline(career?.combinedDives ?? stats.totalDives, career?.combinedTimeFormatted ?? CareerTotals-style h/m of stats.totalTimeSeconds)`.
- Sentence: `diveLog_scene_sites(stats.totalSites, stats.topSites.first.siteName)`, or `diveLog_scene_sitesNoTop` when `topSites` is empty.
- Filtered: when `diveFilterProvider.effective.hasActiveFilters`, a `SceneLabel` under the sentence with `diveLog_summary_filteredBanner(shown.totalDives, total.totalDives)`, and `career` is null.
- Scale maximum in metres: `max(45.0, ((stats.maxDepth / 10).ceil() * 10 + 5).toDouble())`; tick labels through `units.formatDepth(v, decimals: 0)`.
- Marker one: `stats.avgMaxDepth` with `diveLog_scene_usualDepth`, hidden when `avgMaxDepth <= 0`.
- Marker two: `records.deepestDive` with `units.formatDepth(maxDepth)` and `diveLog_scene_deepest(siteName, units.formatDate(dateTime))` or `diveLog_scene_deepestNoSite(units.formatDate(dateTime))`; hidden when the record or its `maxDepth` is null; `onTap` runs `context.goInPlace('${GoRouterState.of(context).uri.path}?selected=${record.diveId}')`.
- Collapse: when the two markers are within 9 % of the pane height, marker one is `compact`. Below 560 px the headline drops to `titleLarge` `w300` and the sentence's max width is the pane width minus the insets.
- Loading: the scene paints and the facts are absent; no spinner. Error: eyebrow only.
- Ink: `Colors.white` in both brightnesses (spec 7.1). Painter: `WaterColumnPainter(seconds: s, brightness: b)`.
- Markers do not move. The spec's bobbing was a mockup flourish; facts are still widgets so text never re-lays out per frame.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_log/presentation/widgets/dive_summary_scene_test.dart
// Setup as dive_summary_widget_test.dart: setUpTestDatabase, DiveRepository, getBaseOverrides,
// diveRepositoryProvider/diveStatisticsProvider/diveRecordsProvider overrides.
// Router helper: MaterialApp.router with GoRouter(initialLocation: '/dives',
// routes: [GoRoute(path: '/dives', builder: (_, __) => const Scaffold(body: DiveSummaryScene()))]).
// Size helper: tester.view.physicalSize + devicePixelRatio 1.0, reset in addTearDown.

testWidgets('shows the dive count, time, site count and top site', ...)
  // two dives at 'Blue Hole': find.textContaining('2 dives'), find.textContaining('Blue Hole')
testWidgets('places the deepest dive as a marker that opens it in place', ...)
  // dive maxDepth 41.2: find.text('41.2 m'); tap the SceneLink; router location query 'selected' == dive id
testWidgets('a log with only prior dives shows the career count and no markers', ...)
  // careerTotalsProvider overridden with priorDives 50, stats with totalDives 0, records empty:
  // find.textContaining('50 dives'); find.byType(DepthMarker) findsNothing; find.textContaining('0.0') findsNothing
testWidgets('reads depths in the diver unit', ...)
  // settings depthUnit feet: find.textContaining('ft') findsWidgets; no ' m' depth text
testWidgets('the deepest marker without a site shows the date alone', ...)
  // dive with no site: label == 'deepest, <formatted date>'; no 'null'
testWidgets('describes the filtered list while a filter is active', ...)
  // set diveFilterProvider to a filter: find.textContaining('Filtered:') found; scoped providers watched
testWidgets('lays out without overflow at 400 x 400 and 1600 x 1000', ...)
  // for each size: pump, expect(tester.takeException(), isNull)
testWidgets('puts the scale at the start edge in a right-to-left locale', ...)
  // locale 'ar': rect of ValueKey('scene-depth-scale') left < width / 2
testWidgets('renders under every theme preset in both brightnesses', ...)
  // for each preset in AppThemeRegistry.presets and each of lightTheme/darkTheme: pump, takeException() isNull,
  // and the WaterColumnPainter's brightness matches the theme's
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_summary_scene_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement the markers file, then the scene**

Layout with a `LayoutBuilder` over a `Stack`; positions in fractions of the constraints; `PositionedDirectional` for every fact; the depth scale and tick labels at `end: 7.5 %`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_summary_scene_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Run the architecture and adoption guards**

Run: `flutter test test/architecture test/shared/widgets/label_with_control_adoption_test.dart test/shared/widgets/app_bar_text_action_adoption_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_summary_scene.dart lib/features/dive_log/presentation/widgets/dive_summary_scene_markers.dart test/features/dive_log/presentation/widgets/dive_summary_scene_test.dart
git commit -m "feat(dive-log): add the water column scene for the Dives summary pane"
```

---

### Task 9: Wire the Dives page

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (both `summaryBuilder` sites, lines 223 and 408)
- Test: `test/features/dive_log/presentation/pages/dive_list_page_test.dart` (beside `desktop mode renders MasterDetailScaffold`, line 299)

**Interfaces:**
- Consumes: `SummaryPaneSwitcher` (Task 7), `DiveSummaryScene` (Task 8), `DiveSummaryWidget`, `diveStatisticsProvider`, `careerTotalsProvider`.
- Produces: both sites become `SummaryPaneSwitcher(sectionId: 'dives', scene: (_) => const DiveSummaryScene(), details: (_) => const DiveSummaryWidget(), isEmpty: isEmpty)` where `isEmpty` is true only when both `diveStatisticsProvider` and `careerTotalsProvider` have resolved and `stats.totalDives == 0 && career.combinedDives == 0` (a loading log is not empty, so the pane never flashes from scene to details on start).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('desktop mode shows the dive scene by default', ...)
  // 1200 x 800 as the neighbouring test; find.byType(DiveSummaryScene) findsOneWidget; find.byType(DiveSummaryWidget) findsNothing
testWidgets('desktop mode shows the summary widget when the setting says details', ...)
  // overrides with AppSettings(summaryPaneView: details) through getBaseOverrides(settingsNotifier: MockSettingsNotifier(...)) or the file's own override path
testWidgets('an empty log shows the summary widget and its quick actions', ...)
  // no dives, career zero: find.byType(DiveSummaryWidget) findsOneWidget; find.byType(SummaryPaneToggle) findsNothing
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_page_test.dart`
Expected: the three new tests FAIL.

- [ ] **Step 3: Replace both `summaryBuilder` sites**

- [ ] **Step 4: Run the page tests and the whole dive_log widget folder**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_page_test.dart test/features/dive_log/presentation/widgets/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_list_page.dart test/features/dive_log/presentation/pages/dive_list_page_test.dart
git commit -m "feat(dive-log): show the water column scene in the Dives summary pane"
```

---

### Task 10: Design records, format, analyze, screenshots, PR

**Files:**
- Add: `docs/design/specs/2026-10-17-calm-summary-panes-design.md`, `docs/design/specs/assets/2026-10-17-calm-summary-panes-mockup-*.html`, `docs/design/plans/2026-10-17-calm-summary-panes.md` (already in the working tree, untracked)

- [ ] **Step 1: Commit the design records**

```bash
git add docs/design/specs/2026-10-17-calm-summary-panes-design.md docs/design/specs/assets/2026-10-17-calm-summary-panes-mockup-pages.html docs/design/specs/assets/2026-10-17-calm-summary-panes-mockup-realms.html docs/design/specs/assets/2026-10-17-calm-summary-panes-mockup-rework.html docs/design/plans/2026-10-17-calm-summary-panes.md
git commit -m "docs(design): calm summary panes design and PR 1 plan"
```

- [ ] **Step 2: Format and analyze the whole tree**

Run: `dart format . && flutter analyze`
Expected: no changes from format (or commit them as `style: format`), analyze clean.

- [ ] **Step 3: Run the full set of files this PR touched or could affect**

Run: `flutter test test/shared/widgets/scenes test/shared/widgets/summary test/features/settings test/features/dive_log/presentation test/architecture test/l10n/localization_test.dart`
Expected: PASS.

- [ ] **Step 4: Capture screenshots**

Run the macOS app at a window 1400 px wide, open Dives with nothing selected, and capture: the old summary widget (toggle to Details) and the new scene, in light and dark (Settings > Appearance > theme mode). Four images, handed to the maintainer; the PR description lists what each shows.

- [ ] **Step 5: Open the PR**

Title: `feat(summary): calm summary panes, part 1: scene engine, toggle, setting and the Dives water column`. Body: summary, `Refs #3434`, the Screenshots section listing the four images, the test commands run. Push with the hooks; if the pre-push hook hangs on the affected-test run, kill only that process tree, rerun the flagged files alone, and push with `--no-verify`.

---

## Plans 2 to 11: one scene each

Each later scene is its own plan and PR, written once this PR has merged, from the same template:

1. **Painter task**: `lib/shared/widgets/scenes/<scene>_painter.dart` extending `ScenePainter`, palette constants from the spec section and the mockup CSS, tests for the three sizes, determinism, `shouldRepaint`, and the light/dark luminance check (Task 2's shape). Data-driven painters (chart marks, kelp blades, shoal, constellation, tracing) take their data as constructor fields.
2. **Strings task**: the page's `<feature>_scene_*` keys in all eleven ARBs, `flutter gen-l10n` (Task 4's shape).
3. **Facts task**: `lib/features/<feature>/presentation/widgets/<feature>_summary_scene.dart` reading the page's current summary widget's providers plus any new query the spec's section 9 allows, tests at the three sizes, in RTL, with units, and with the page's empty and error states (Task 8's shape).
4. **Wiring task**: the page's `summaryBuilder` becomes `SummaryPaneSwitcher(sectionId: '<section>', scene:, details:, isEmpty:)` (Task 9's shape).
5. **Records task**: screenshots, format, analyze, guards, PR with `Refs #3434` (`Closes #3434` on the last one).

Order after this PR: Chart (Sites, then Trips as the passage variant), Strata (Certifications and Courses), Constellation (Insights, with the lean per-dive query), Current (Transfer), Kelp (Buddies), Shoal (Equipment), Snell's window (Dive centres), Tracing (Planning), Horizon (Settings), Water column with MOD markers (Gas calculators, with the most-used-mixes query).
