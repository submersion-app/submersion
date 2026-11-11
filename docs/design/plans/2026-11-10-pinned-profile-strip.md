# Pinned Profile Strip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the dive details profile card scrolls off the top, condense it into a 56 px scrubbable strip pinned at the top that drives the shared profile cursor, sync the buoyancy chart to that cursor both ways, and add a synced setting to turn the strip off.

**Architecture:** Pure value and geometry helpers feed a `PinnedProfileStrip` widget. A `PinnedProfileOverlay` wraps the detail page's existing `SingleChildScrollView`, measures the profile card through the page's existing `_profileSectionKey` on every scroll notification, and draws either the morphing proxy or the strip on top of the scroll view (no layout change to the content). The strip and the buoyancy chart read and write `profileTrackingIndexProvider(diveId)`, so every existing cursor reader follows them for free.

**Tech Stack:** Flutter, Riverpod (`StateProvider.family`), Drift (diver settings column + migration), fl_chart (buoyancy chart), ARB l10n.

**Spec:** `docs/design/specs/2026-11-10-pinned-profile-strip-design.md` (issue #4423)

## Global Constraints

- Strip height: 56 logical px. Curve area 40 px, values row 16 px.
- Setting name `pinProfileOnScroll`, column `pin_profile_on_scroll`, default `true`, schema version **359** (main holds 357; open PR #4417 claims 358).
- Values row is fixed: time (m:ss runtime), depth (diver's unit), ppO2 (bar, 2 decimals), NDL or deco stop. Missing value renders as an en-width dash "-" placeholder, never dropped.
- Deco slot reads `analysis.decoStatuses[index]` exactly as the deco status card does; computer-recorded stops are never mixed in.
- No cursor: dimmed hint "Drag to scrub" (touch) / "Hover to scrub" (pointer); no cursor line.
- Releasing touch or leaving with the mouse writes `null` to the cursor (matches the full chart).
- Strip shown only when: setting on, `layout == DiveDetailLayout.detailed`, chart profile has at least 2 points, and the profile card's bottom edge is above the strip's bottom edge.
- Setting off: no overlay widget in the tree at all.
- Buoyancy sync is not gated by the setting.
- New strings in all 11 ARB files (`ar de en es fr he hu it nl pt zh`), then `flutter gen-l10n`.
- Every new file under `lib/` passes `test/architecture/`.

## Review Focus

1. **Multi-source dive:** cursor index must resolve against `watchChartProfile(ref, dive)`, never `dive.profile` (#543). Test: strip values on a dive whose active source differs from the merged profile (Task 2).
2. **Vertical page scroll starting on the strip (phone):** a vertical drag must scroll the page and must not write the cursor. Test in Task 4.
3. **Dive switch in desktop master-detail while the strip shows:** the strip must rebuild for the new dive id and not keep the old dive's cursor or curve. Test in Task 5.
4. **Analysis still loading / null:** time and depth show, ppO2 and deco slot show the dash, no crash. Test in Task 2.
5. **Imperial units:** depth and stop depth in feet. Test in Task 2.

---

### Task 1: The `pinProfileOnScroll` setting

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `showPressureThresholdMarkers`, ~line 345)
- Create: `lib/core/database/migrations/helpers/pinned_profile_migrations.dart`
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add `part`)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (rung after `from < 357`)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (backstop call)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 359`, append `359` to `migrationVersions` with a comment in the house style)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field, ctor default, `copyWith`, setter `setPinProfileOnScroll`, `pinProfileOnScrollProvider`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three places `showMaxDepthMarker` appears)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (default map entry `'pinProfileOnScroll': true`)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart` (boolean `ConflictField`)
- Modify: `lib/features/agent_access/data/documents/profile_documents.dart` only if the column-name sets require it (follow `show_max_depth_marker`), then regenerate `sql_column_notes.generated.dart` with `dart run tool/generate_sql_column_notes.dart`
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (`SwitchListTile` directly after the max depth marker tile, icon `Icons.vertical_align_top`)
- Modify: all 11 `lib/l10n/arb/app_*.arb`: `settings_appearance_pinProfileOnScroll` "Pin profile when scrolling", `settings_appearance_pinProfileOnScroll_subtitle` "Keep a thin, scrubbable profile at the top of dive details", `settings_conflict_field_pinProfileOnScroll` "Pin profile when scrolling"
- Modify: fake notifiers overriding settings setters: `test/helpers/mock_providers.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `settings_page_shared_data_test.dart`, `test/features/insights/presentation/pages/records_page_test.dart` (each gets `setPinProfileOnScroll`)
- Test: `test/core/database/migration_v359_pin_profile_on_scroll_test.dart`, `test/features/settings/presentation/pages/section_appearance_page_test.dart`

**Interfaces:**
- Produces: `AppSettings.pinProfileOnScroll` (bool), `SettingsNotifier.setPinProfileOnScroll(bool)`, `pinProfileOnScrollProvider` (`Provider<bool>`).

- [ ] **Step 1: Write the failing migration test**, modelled on `migration_v347_dive_card_photo_background_test.dart`: `'v359 is in the ladder'` (`migrationVersions` contains 359, step count from 358 is one more than from 359), `'the column is additive and did not move the sync floor'` (`minimumCompatibleSchemaVersion` is not 359), `'upgrading from v358 turns the strip on for an existing diver'` (reads `pin_profile_on_scroll` as `true`), `'beforeOpen heals a database already at v359 that lacks it'`.
- [ ] **Step 2: Write the failing UI test** in `section_appearance_page_test.dart`: `'the pin profile switch is under Dive Profile, on, and saves'`: find `SwitchListTile` with text 'Pin profile when scrolling', `value` is `true`, tap it, the mock notifier's state has `pinProfileOnScroll == false`.
- [ ] **Step 3: Run both; expect compile failure / FAIL.** `flutter test test/core/database/migration_v359_pin_profile_on_scroll_test.dart test/features/settings/presentation/pages/section_appearance_page_test.dart`
- [ ] **Step 4: Implement** every file above. Column: `BoolColumn get pinProfileOnScroll => boolean().withDefault(const Constant(true))();`. Migration helper `_assertPinProfileOnScrollColumn()` adds `'INTEGER NOT NULL DEFAULT 1 CHECK (pin_profile_on_scroll IN (0, 1))'`. Run `dart run build_runner build --delete-conflicting-outputs` and `flutter gen-l10n`.
- [ ] **Step 5: Run the two tests plus `test/features/settings` and `test/core/database/schema*`; expect PASS.**
- [ ] **Step 6: Commit** `feat(settings): add pin profile when scrolling setting`.

### Task 2: Strip values at the cursor

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values_test.dart`

**Interfaces:**
- Consumes: `resolveSample` (`widgets/instrument_sample.dart`), `ProfileAnalysis` (`data/services/profile_analysis_service.dart`), `DecoStatus`/`DecoStop` (`core/deco/entities/deco_status.dart`).
- Produces:
  ```dart
  sealed class DecoSlot { const DecoSlot(); }
  class NdlSlot extends DecoSlot { final int ndlSeconds; }
  class StopSlot extends DecoSlot { final double depthMeters; final int durationSeconds; }
  class UnknownDecoSlot extends DecoSlot {}
  class PinnedStripValues {
    final int runtimeSeconds; final double? depthMeters; final double? ppO2Bar; final DecoSlot deco;
  }
  PinnedStripValues? pinnedStripValuesAt({
    required List<DiveProfilePoint> chartProfile,
    required ProfileAnalysis? analysis,
    required int? cursorIndex,
  });
  String formatPinnedStripValues(PinnedStripValues v, UnitFormatter units, AppLocalizations l10n) // returns the 4 slot strings
  ```
  `pinnedStripValuesAt` returns null when `cursorIndex` is null or out of range (the widget then shows the hint).

- [ ] **Step 1: Write failing tests:**
  - `'null cursor gives null'`.
  - `'reads time, depth and ppO2 at the index from the chart profile'`: index 3 of a 5-point profile gives that point's timestamp/depth and `analysis.ppO2Curve[3]`.
  - `'NDL slot when the status at the index is not in deco'`: `decoStatuses[i].ndlSeconds == 840` gives `NdlSlot(840)`.
  - `'stop slot from the first deco stop when in deco'`: `ndlSeconds: -1`, `decoStops: [DecoStop(depthMeters: 6, durationSeconds: 180), DecoStop(depthMeters: 3, ...)]` gives `StopSlot(6, 180)`.
  - `'in deco with no stops listed gives unknown'`.
  - `'no analysis: time and depth only, ppO2 null, deco unknown'` (Review Focus 4).
  - `'index past decoStatuses length gives unknown deco'`.
  - `'resolves against the chart profile, not the merged one'` (Review Focus 1): chart profile and a different merged list; result uses the chart profile's point.
  - formatting: `'metric format'` gives `['23:14', '18.2m', '1.12', 'NDL 14 min']`-style strings via l10n; `'imperial depth and stop in feet'` (Review Focus 5); `'missing values are dashes'`.
- [ ] **Step 2: Run; expect FAIL.** `flutter test test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values_test.dart`
- [ ] **Step 3: Implement.** Use `resolveSample` for depth and ppO2 (timestamp of `chartProfile[cursorIndex]`); deco slot from `analysis.decoStatuses[cursorIndex]` (`inDeco` then `decoStops.first`). Strings: add ARB keys `diveLog_pinnedStrip_ndl` ("NDL {minutes} min"), `diveLog_pinnedStrip_stop` ("Stop {depth} · {minutes} min"), `diveLog_pinnedStrip_ppO2` ("ppO2 {value}") in all 11 locales.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): resolve pinned profile strip values at the cursor`.

### Task 3: Condense geometry

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry_test.dart`

**Interfaces:**
- Produces:
  ```dart
  const double kPinnedStripHeight = 56;
  const double kCondenseWindow = 120;
  /// 0 while the card's bottom is at or below stripHeight + window, 1 once it is at or above stripHeight.
  double condenseProgress({required double cardBottom});
  /// The proxy's rect: from the card's visible rect (top clamped to 0) to Rect.fromLTWH(0, 0, width, stripHeight).
  Rect condenseRect({required Rect card, required double width, required double t});
  ```
  Coordinates are relative to the overlay's top-left.

- [ ] **Step 1: Write failing tests:** `'progress is 0 with the card bottom well below the strip'` (`cardBottom: 500` gives 0), `'progress is 1 once the bottom passes the strip'` (`cardBottom: 56` and `-10` give 1), `'progress is linear in the window'` (`cardBottom: 116` gives 0.5), `'rect at t=0 is the visible card'`, `'rect at t=1 is the full-width strip'`, `'rect at t=0.5 is halfway with the top clamped to 0'`.
- [ ] **Step 2: Run; FAIL.** **Step 3: Implement** with `Rect.lerp`. **Step 4: Run; PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): add pinned strip condense geometry`.

### Task 4: `PinnedProfileStrip` widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip_test.dart`

**Interfaces:**
- Consumes: Task 2 (`pinnedStripValuesAt`, `formatPinnedStripValues`), Task 3 (`kPinnedStripHeight`), `MiniProfilePainter` (`widgets/mini_profile_picker.dart`), `profileTrackingIndexProvider`, `watchChartProfile`, `sourceProfileAnalysisProvider` keyed by `(diveId, activeDiveSourceProvider(diveId))`, `indexForTimestamp` (`domain/services/profile_position.dart`).
- Produces: `class PinnedProfileStrip extends ConsumerStatefulWidget { const PinnedProfileStrip({required Dive dive}); }` sized `kPinnedStripHeight` x parent width.

- [ ] **Step 1: Write failing widget tests:**
  - `'shows the hover hint with no cursor on a pointer platform'` and `'shows the drag hint after a touch'` (hint chosen from the last `PointerDeviceKind` seen, defaulting from `defaultTargetPlatform`: iOS/Android touch, else pointer).
  - `'shows four values when the cursor is set'`.
  - `'a horizontal drag writes the cursor index'`: drag from x=10% to x=50%; provider holds the index nearest 50% of the dive.
  - `'lifting the finger clears the cursor'`.
  - `'hover writes and mouse exit clears'`.
  - `'a vertical drag does not write the cursor'` (Review Focus 2): wrap in a `SingleChildScrollView`, vertical drag over the strip, provider stays null and the scroll offset changed.
  - `'semantics label names the strip'`.
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement.** `Material` with surface colour and elevation 2; `CustomPaint(MiniProfilePainter(...))` for the curve with `selectedSeconds` from the cursor; values `Row` of four `Expanded` centred texts (`labelSmall`, tabular figures), or the hint in `onSurfaceVariant` at 60% opacity. Input: `GestureDetector` with `onHorizontalDragStart/Update/End/Cancel` and `onTapDown/onTapUp`, plus `MouseRegion(onHover, onExit)`; x maps to seconds then `indexForTimestamp`. ARB keys `diveLog_pinnedStrip_hintDrag` "Drag to scrub", `diveLog_pinnedStrip_hintHover` "Hover to scrub", `diveLog_pinnedStrip_semantics` "Dive profile, scrub to move the cursor", all 11 locales.
- [ ] **Step 4: Run; PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): add scrubbable pinned profile strip`.

### Task 5: Overlay and page wiring

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildContent`: wrap `body`; the three `Scrollable.ensureVisible` calls use the offset helper)
- Test: `test/features/dive_log/presentation/pages/dive_detail_pinned_profile_test.dart`

**Interfaces:**
- Consumes: Tasks 3 and 4, `pinProfileOnScrollProvider` (Task 1).
- Produces:
  ```dart
  class PinnedProfileOverlay extends StatefulWidget {
    const PinnedProfileOverlay({required Dive dive, required GlobalKey profileKey, required Widget child});
  }
  /// Scrollable.ensureVisible that leaves room for the strip when it is showing.
  Future<void> ensureVisibleBelowPinnedStrip(BuildContext target, {Duration duration, Curve curve, double alignment});
  ```

- [ ] **Step 1: Write failing page tests** (pump like `dive_detail_chart_series_consistency_test.dart`, with a 46-minute, 277-point profile so the page scrolls):
  - `'no strip while the profile card is on screen'`.
  - `'the strip appears after scrolling past the profile'` (jump the scrollable past the card's bottom; `find.byType(PinnedProfileStrip)` finds one).
  - `'the proxy shows mid-condense'` (card bottom inside the window: a `PinnedProfileOverlay` proxy keyed `pinnedProfileProxy` is present, the strip is not).
  - `'no strip with the setting off'` (no `PinnedProfileOverlay` in the tree).
  - `'no strip in the list layout'`.
  - `'no strip when the profile section is hidden'`.
  - `'switching dives in the embedded pane rebuilds the strip'` (Review Focus 3): pump with dive A scrolled, swap to dive B, strip curve is B's profile and cursor for B is null.
  - `'scrolling to notes leaves the strip clear of the notes card'`.
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement.** Overlay: `NotificationListener<ScrollNotification>` + `Stack(children: [child, Positioned.fill(IgnorePointer(proxy)) or Positioned(top: 0, left: 0, right: 0, child: strip)])`; measure on each notification and once post-frame: `profileKey.currentContext?.findRenderObject()` as `RenderBox`, convert its bottom-left to the overlay's coordinates. The proxy is a `Material` with `MiniProfilePainter` inside `condenseRect`, corner radius lerped from the card's 12 to 0. Page: wrap `body` only when `pinProfileOnScroll && layout == DiveDetailLayout.detailed && watchChartProfile(...).length >= 2`; key the overlay by `dive.id`.
- [ ] **Step 4: Run the new test file and `test/features/dive_log/presentation/pages/dive_detail_*`; PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): pin the condensed profile strip on dive details`.

### Task 6: Buoyancy two-way cursor sync

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_chart.dart`
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_gas_cards.dart` (`DiveDetailBuoyancySection` passes the dive)
- Test: `test/features/dive_log/presentation/widgets/buoyancy_chart_test.dart`, `buoyancy_section_test.dart`

**Interfaces:**
- Produces: `BuoyancyChart({..., int? cursorSeconds, ValueChanged<int?>? onCursorSeconds})`. `cursorSeconds` draws a vertical `ExtraLinesData` line at `cursorSeconds / 60` in the profile cursor colour; `onCursorSeconds` fires with the touched sample's `timestamp`, and `null` on exit or touch end.
- `BuoyancySection` maps between seconds and `profileTrackingIndexProvider(diveId)` through `watchChartProfile` and `indexForTimestamp`.

- [ ] **Step 1: Write failing tests:** chart: `'draws a cursor line at cursorSeconds'`, `'no cursor line when null'`, `'touch reports the touched sample timestamp'`, `'touch end reports null'`. Section: `'profile cursor moves the buoyancy marker'`, `'buoyancy hover writes the profile cursor index'`.
- [ ] **Step 2: Run; FAIL.** **Step 3: Implement** using `LineTouchData.touchCallback` (`FlTouchEvent.isInterestedForInteractions`). **Step 4: Run; PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): sync the buoyancy chart with the profile cursor`.

### Task 7: Final checks

- [ ] `dart format .`, `flutter analyze` (no issues), `flutter test test/architecture/`, and the test files from Tasks 1 to 6.
- [ ] After screenshots via the capture harness: dive details top, mid-condense, strip with cursor and buoyancy marker (desktop and phone, light and dark), Appearance with the new switch.
