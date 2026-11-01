# Richer Gas Switch Time Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in this session. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer recorded breathing starts as one-tap times on a gas switch row,
and let the diver pick a switch time on a profile chart in a sheet.

**Architecture:** A pure detector turns one cylinder's recorded series into start
times, cached per dive in a provider derived from `tankPressuresProvider`. A
second pure function chooses what a row offers. The editor shows chips and a
picker icon, and both write through the page's existing time-change path.

**Tech Stack:** Flutter, Riverpod, fl_chart, flutter_test.

**Spec:** `docs/design/specs/2026-11-01-gas-switch-time-entry-design.md`

## Global Constraints

- Time stays the stored truth; no change to storage, save, re-parse, resync or
  analysis.
- Series come from `tankPressuresProvider`, never an estimated series.
- Detector constants: lag 90 s, falling 2 bar, hold 120 s, net loss 5 bar,
  kept falling 240 s, start offset 0.5 bar, gap 60 s.
- A row shows at most 3 suggestions; a start within 60 s of another row on the
  same cylinder is claimed.
- No chips for `TankRole.diluent` or `TankRole.oxygenSupply`.
- Strings in all 11 ARB files; depth through `UnitFormatter`; no em-dashes in
  docs or comments; no file over 800 lines; imports dart, flutter, packages, local.
- Before committing: `dart format .`, `flutter analyze`, affected tests, and
  `test/architecture/` when `lib/` gains a file.

## Review Focus

- A start later than the row's upper time limit (series outlasting the profile):
  it is not offered. Pinned in Task 2.
- A cylinder added in this editing session has no series: its rows show no chips
  and nothing throws. Pinned in Task 2 and Task 3.
- A row whose time lies past the profile (typed, or left by an edit): the sheet
  opens with the cursor clamped to the end. Pinned in Task 5.
- A profile with fewer than two samples or a zero span: no picker icon, no
  divide by zero. Pinned in Task 4.
- Pressure data still loading or failed to load: the editor works, without
  chips. Pinned in Task 3.

---

### Task 1: The start detector

**Files:**
- Create: `lib/features/dive_log/domain/services/cylinder_breath_starts.dart`
- Test: `test/features/dive_log/domain/services/cylinder_breath_starts_test.dart`

**Interfaces:**
- Consumes: `PressureReading`, `readingsInTimeOrder`, `withoutPressureGlitches`
  from `lib/core/profile/tank_pressure_glitches.dart`.
- Produces: `List<int> cylinderBreathStarts(List<PressureReading> readings)`,
  seconds in time order, and the constants below.

- [ ] **Step 1: Write the failing tests.** A helper builds a 2 s series from a
  function of time, rounded to whole bar. Each test states the expected result:
  - held 1200 s then 3.4 bar/min to the end: one start, within 2 to 30 s after 1200
  - falling from the first reading: `[]`
  - 8 min turns and 8 min holds at 3.4 bar/min, three turns after a lead hold: three starts
  - a whole dive at 0.5 bar/min drift: `[]`
  - held, then 3 turns separated by 5 min holds with 0.5 bar/min drift in the holds:
    three starts
  - recovered dip of 4.5 bar over 20 s, and of 8 bar over 40 s: `[]`
  - two-reading dropout to 3 bar: `[]`
  - 3 bar hose fill then steady, and then with 0.5 bar/min drift: `[]`
  - held then cooled by 10 degrees (`200 * 10 / 300` bar, time constant 240 s): `[]`
  - 3 minute turn: `[]`; 5 minute turn: one start
  - 5 bar loss over a 2 minute dip that does not recover but never keeps falling: `[]`
  - a 300 s gap in readings with the fall on the far side: `[]`
  - a series ending mid-turn after 6 min of falling: one start
  - readings given out of order: same result as in order
  - empty and single-reading series: `[]`

- [ ] **Step 2: Run them.**
  `flutter test test/features/dive_log/domain/services/cylinder_breath_starts_test.dart`
  Expected: compile failure, the function does not exist.

- [ ] **Step 3: Implement.** Name the constants `kBreathLagSeconds = 90`,
  `kBreathFallingBar = 2.0`, `kBreathHoldSeconds = 120`, `kBreathNetLossBar = 5.0`,
  `kBreathMinFallingSeconds = 240`, `kBreathStartOffsetBar = 0.5`,
  `kBreathMaxGapSeconds = 60`. Clean with
  `withoutPressureGlitches(readingsInTimeOrder(readings))`, then one pass with a
  lag cursor. The state the pass carries is the algorithm:

  ```dart
  // anchor: the latest reading at or before t - lag.
  // falling: anchor.bar - p >= kBreathFallingBar.
  // falling and not in a turn: open a turn. onset is the first reading after
  //   the anchor below anchor.bar - kBreathStartOffsetBar; level is anchor.bar;
  //   eligible is onset - restSince >= hold, and the gap into onset <= maxGap.
  // falling: lastFalling = t.
  // in a turn, not falling, t - lastFalling >= hold: close the turn with the
  //   current reading, then restSince = lastFalling.
  // after the loop: close an open turn with the last reading.
  // close(endBar): add onset if eligible, level - endBar >= netLoss and
  //   lastFalling - onset >= minFalling.
  ```

- [ ] **Step 4: Run the tests.** Same command. Expected: all pass.

- [ ] **Step 5: Commit.** `feat(dive-log): find when a cylinder started being breathed`

### Task 2: What a row offers, and the cached provider

**Files:**
- Create: `lib/features/dive_log/domain/services/gas_switch_time_suggestions.dart`
- Create: `lib/features/dive_log/presentation/providers/cylinder_breath_starts_provider.dart`
- Test: `test/features/dive_log/domain/services/gas_switch_time_suggestions_test.dart`
- Test: `test/features/dive_log/presentation/providers/cylinder_breath_starts_provider_test.dart`

**Interfaces:**
- Consumes: `cylinderBreathStarts`; `tankPressuresProvider`.
- Produces:
  - `const int kGasSwitchClaimSeconds = 60`, `const int kGasSwitchMaxSuggestions = 3`
  - `List<int> gasSwitchTimeSuggestions({required GasSwitch row, required DiveTank? tank, required List<int> starts, required List<GasSwitch> switches, required int? maxTimestamp})`
  - `final cylinderBreathStartsProvider = FutureProvider.family<Map<String, List<int>>, String>`, keyed by dive id, values keyed by tank id, tanks with no start left out.

- [ ] **Step 1: Write the failing tests.** For `gasSwitchTimeSuggestions`:
  - starts `[890, 1800]`, row at 900 on that tank: `[890, 1800]`
  - the row's own second is left out: starts `[900, 1800]`, row at 900: `[1800]`
  - another row on the same tank within 60 s claims it; at exactly 61 s it does not
  - another row on a different tank does not claim it
  - five remaining starts: the three nearest the row's time, in time order
  - a start past `maxTimestamp` is left out; a null `maxTimestamp` keeps all
  - `TankRole.diluent` and `TankRole.oxygenSupply`: `[]`
  - a null tank or empty `starts`: `[]`

  For the provider, with `tankPressuresProvider` overridden: a held-then-falling
  series gives its start under its tank id; a tank with a steady series is absent;
  it maps `TankPressurePoint` to `PressureReading`.

- [ ] **Step 2: Run them.** Expected: compile failure.

- [ ] **Step 3: Implement both.** The provider awaits
  `ref.watch(tankPressuresProvider(diveId).future)`.

- [ ] **Step 4: Run the tests.** Expected: all pass.

- [ ] **Step 5: Commit.** `feat(dive-log): choose the times a gas switch row suggests`

### Task 3: Chips under the row

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_chips.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page_gas_switches.dart`
- Modify: every `lib/l10n/arb/app_*.arb`, then regenerate
- Test: `test/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor_test.dart`
- Test: `test/features/dive_log/presentation/pages/dive_edit_gas_switches_test.dart`

**Interfaces:**
- Consumes: `gasSwitchTimeSuggestions`, `cylinderBreathStartsProvider`.
- Produces: `GasSwitchesEditor.breathStarts` (`Map<String, List<int>>`, default
  empty). A chip calls `onChanged(sw.copyWith(timestamp: t), GasSwitchField.time)`
  then `onTimeSettled(sw.id)`.

- [ ] **Step 1: Add strings to all 11 ARB files,** beside
  `diveLog_edit_gasSwitches_duplicateError`, each translated:
  `diveLog_edit_gasSwitches_startedDropping` "Started dropping at",
  `diveLog_edit_gasSwitches_useTime` "Use {time}" (String placeholder, the chip's
  tooltip), `diveLog_edit_gasSwitches_pickOnProfile` "Pick on profile",
  `diveLog_edit_gasSwitches_pickTitle` "Set switch time",
  `diveLog_edit_gasSwitches_pickReadout` "{time} at {depth}" (String placeholders),
  `diveLog_edit_gasSwitches_pickConfirm` "Set time". Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget tests.** Editor: a row with
  `breathStarts: {'deco': [890]}` shows "14:50" under a "Started dropping at"
  label; tapping it records one change `(timestamp: 890, field: time)` and one
  settle; picking the other cylinder in the row hides it; `breathStarts` absent
  shows no label. Page (with `tankPressuresProvider` overridden): a saved dive with
  a recorded start shows the chip, tapping it updates the time field and refills
  the depth from the profile; a depth typed first stands; a cylinder added in this
  session shows no chip; a provider that never completes and one that errors both
  leave the section working with no chip.

- [ ] **Step 3: Run them.** Expected: fail.

- [ ] **Step 4: Implement.** `GasSwitchTimeChips` takes `times`, `onSelected`: a
  `Wrap` of the label and one `ActionChip` per time with
  `formatMinutesSeconds`. `_GasSwitchRow` calls `gasSwitchTimeSuggestions` and
  renders the chips under its layout. In `_buildGasSwitchesChild`, read
  `widget.diveId` and `ref.watch(cylinderBreathStartsProvider(id)).value`, with
  `const {}` when null.

- [ ] **Step 5: Run the tests,** then `test/l10n` if present. Expected: pass.

- [ ] **Step 6: Commit.** `feat(dive-log): suggest gas switch times from tank pressure`

### Task 4: The picker sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_sheet.dart`
- Test: `test/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_sheet_test.dart`

**Interfaces:**
- Consumes: `profileDepthAt`, `shouldDrawSurfaceLeadIn`, `formatMinutesSeconds`,
  `UnitFormatter`.
- Produces:
  - `bool canPickOnProfile(List<DiveProfilePoint> profile)`: two or more samples
    and `profile.last.timestamp > 0`.
  - `Future<int?> showGasSwitchTimeSheet(BuildContext context, {required List<DiveProfilePoint> profile, required int initialSeconds, required UnitFormatter units, List<int> otherSwitchTimes = const [], List<int> breathStarts = const []})`,
    null on cancel.

- [ ] **Step 1: Write the failing tests.** `canPickOnProfile` false for empty, one
  sample, and a zero span. With a 3000 s profile: the readout starts at the initial
  time; tapping the chart at 50% of its width reads 25:00 and the profile's depth;
  a horizontal drag follows; the slider moves the same value; Confirm returns the
  seconds, Cancel returns null; `initialSeconds` past the end opens at the end;
  feet settings show feet; a vertical drag over the chart leaves the time alone.

- [ ] **Step 2: Run them.** Expected: compile failure.

- [ ] **Step 3: Implement.** `showModalBottomSheet<int>`. The state holds `_seconds`.
  A `LayoutBuilder` maps `dx / width` to seconds, clamped to the span. The fl_chart
  `LineChart` (no touch, no titles, no grid, `Duration.zero`, theme colours, depth
  negated, lead-in spot from `shouldDrawSurfaceLeadIn`, vertical lines for
  `otherSwitchTimes` and `breathStarts`) sits in a `RepaintBoundary` and is built
  once; the cursor is a `Positioned` above it, so a drag does not rebuild the chart.
  `GestureDetector` with `onTapDown` and `onHorizontalDrag*` only. A `Slider` over
  `0..span` carries a `Semantics` label. Keep the file under 300 lines.

- [ ] **Step 4: Run the tests.** Expected: pass.

- [ ] **Step 5: Commit.** `feat(dive-log): pick a gas switch time on the profile`

### Task 5: Wire the picker into the row

**Files:**
- Modify: `lib/shared/widgets/forms/minutes_seconds_field.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page_gas_switches.dart`
- Test: `test/shared/widgets/forms/minutes_seconds_field_test.dart`
- Test: the editor and page tests from Task 3

**Interfaces:**
- Consumes: `showGasSwitchTimeSheet`, `canPickOnProfile`.
- Produces: `MinutesSecondsField.suffixIcon` (`Widget?`);
  `GasSwitchesEditor.onPickTime` (`void Function(GasSwitch)?`, null hides the icon).

- [ ] **Step 1: Write the failing tests.** Field: `suffixIcon` renders. Editor: the
  icon shows with `onPickTime`, hides without it, and calls it with the row's
  switch. Page: a dive with a profile shows the icon and a confirmed sheet updates
  the time and the depth and re-sorts the rows; a dive with no profile shows none; a
  row whose time is past the profile opens at the end; Cancel changes nothing and
  does not mark the page dirty.

- [ ] **Step 2: Run them.** Expected: fail.

- [ ] **Step 3: Implement.** In the part file add `_pickGasSwitchTime(GasSwitch sw)`:
  await the sheet with the other rows' times and the row cylinder's starts; on a
  result that differs, call `_onGasSwitchChanged(sw.copyWith(timestamp: t), GasSwitchField.time)`
  then `_onGasSwitchTimeSettled(sw.id)`, guarded by `mounted`. Pass
  `onPickTime` only when `canPickOnProfile` holds.

- [ ] **Step 4: Run the tests.** Expected: pass.

- [ ] **Step 5: Commit.** `feat(dive-log): open the profile picker from a switch row`

### Task 6: Whole-branch checks

**Files:** none new.

- [ ] **Step 1:** `dart format .` and `flutter analyze`. Expected: no issues.

- [ ] **Step 2:** `flutter test test/features/dive_log test/shared test/architecture`,
  logged to the scratchpad. Expected: all pass.

- [ ] **Step 3:** Capture the after screenshots with the throwaway golden harness:
  the section at phone and desktop width, the sheet at both widths, light and dark.
  Delete the harness before staging.
