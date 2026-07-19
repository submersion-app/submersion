# Planner UI Redesign and Subsurface Parity - Design

Date: 2026-07-17
Status: Approved (brainstorm validated section-by-section)
Predecessor: docs/superpowers/specs/2026-07-05-dive-planner-redesign-design.md (engine,
canvas, CCR, contingencies, log integration - all merged via PRs #484-#491)

## 1. Motivation

The current planner UI is functional but visually rudimentary and wastes desktop
space. Root causes identified from the code:

- Nested master-detail layouts: the app nav rail, then PlanningShell's fixed
  440px sidebar (planning_shell.dart), then PlanCanvasPage's fixed 360px editor
  column. On a ~1500pt window the profile chart gets roughly a third of the
  screen.
- The profile chart (plan_canvas_chart.dart) is a plain fl_chart line chart:
  thin line, faint grid, dashed ceiling line, no stop annotations, no visual
  language of a dedicated deco planner.
- Each layer checks isDesktop against the window, not the space it was given,
  so the layouts compose badly.

In addition, the planner must reach feature parity with Subsurface's dive
planner (user requirement: "all of the features of Subsurface's dive planner").
A verified gap analysis is in section 4.

## 2. Decisions (validated in brainstorm)

| Topic | Decision |
| --- | --- |
| Scope | Whole Planning section: planner, hub/shell, all calculator tools |
| Platforms | Full redesign of desktop AND phone layouts |
| Desktop layout | Mission Control: editor pane, chart hero, results pane; tools render full-bleed (REVISED in phase 2 live review: no icon rail, no shell - back buttons navigate to the hub) |
| Chart style | Precision Instrument: crisp technical chart, stop tags, ceiling as shaded no-go band, gas-switch flags, mean-depth line |
| Chart technology | CustomPainter (not fl_chart) |
| Phone layout | Chart + Tab Deck (chart approx 40%, stat strip, tabs: Plan, Tanks, Setup, Results); DraggableScrollableSheet removed |
| Feature scope | Full literal Subsurface parity, including VPM-B, recreational mode, pSCR |
| Sequencing | Experience-first: visual phases 1-3, then parity phases 4-7, section restyle phase 8 |
| Process | Eight phases, one PR each, stacked and merged bottom-up (same discipline as #484-#491) |

## 3. Current state (verified inventory)

Engine (lib/core/deco, lib/features/planner/domain):

- DecoModel is an abstract seam; BuhlmannGf (ZHL-16C + GF) is the only
  implementation. No VPM-B.
- BreathingConfig: OpenCircuit, ClosedCircuit (constant ppO2), and Scr (CMF
  semi-closed) exist; Scr is NOT exposed in UI (PlanMode is only {oc, ccr}).
  Passive SCR (pSCR) is not modeled.
- SchedulePolicy: stopIncrement 3m, lastStopDepth (3 or 6m), single scalar
  ascentRate, gasSwitchStopSeconds, AirBreakPolicy. No per-band ascent rates,
  no descent rate (lives on DivePlan), no safety-stop policy, no
  drop-to-first-depth, no only-switch-at-required-stops, no surface segment.
- PlanEngine/PlanOutcome: CNS, OTU, gas density, per-segment ppO2/NDL/ceiling/
  TTS, min gas (rock bottom), turn pressure, severity-sorted PlanIssues,
  tissue timeline for scrubbing. Rich - at or beyond Subsurface in places.
- CCR setpoints are plan-level (low/high + switch depth); no per-segment
  setpoint, no per-segment dive-mode override.
- Repetitive planning: FollowDiveSheet seeds tissues from ONE hand-picked
  logged dive via tissue_seed.dart. No plan start date/time, no automatic
  init from all prior dives, no overlap detection.
- Best-mix calculator is O2-only (no helium/END-driven suggestion).

Presentation:

- Only PlanningShell (440px master/detail) and PlanCanvasPage (wide/phone)
  have responsive branching; the four calculator tools are single-column
  scroll views.
- CustomPainter precedent exists: tissue_area_chart.dart (layered path fills,
  M-value line), dive_3d_interactive_viewport.dart (gesture-to-transform).
- Theming: Material 3 ColorScheme.fromSeed, 5 presets x light/dark, no
  ThemeExtension anywhere. l10n: 11 locales, context.l10n pattern.

## 4. Subsurface parity gap analysis

Verified against the Subsurface user manual planner chapter AND current source
(diveplannermodel.cpp, planner.cpp, plannernotes.cpp, plannerSettings.ui,
pref.cpp). Where the manual and code disagree, code wins (e.g. problem-solving
time default is 4 min, not the manual's 2; pSCR ratio default is 1:10, not 1:8).

Already at parity (no work): Buhlmann GF, altitude/surface pressure, water
type/salinity, last stop 3/6m, gas-switch minimum stop, O2 air breaks,
separate bottom/deco SAC, per-segment gas, save-plan-as-dive, CNS/OTU,
ppO2 warnings, hypoxic gas warning, gas density warnings (Submersion extra),
turn pressure and lost-gas contingencies and range tables and PDF slate and
plan compare and bailout TTS sampling (all Submersion extras Subsurface lacks).

Gaps to close (parity backlog; phase in parentheses):

| # | Feature | Subsurface behavior (verified) | Phase |
| --- | --- | --- | --- |
| G1 | VPM-B deco model | Conservatism +0..+4 (default +3), CVA iteration, Boyle compensation, prints effective GF | 6 |
| G2 | Recreational mode | Third deco-mode radio; extends bottom time in 1-min steps while direct no-ceiling ascent possible, gas minus reserve suffices, total < 6h; 3min at 5m safety stop when max depth >= 10m; blank start pressure = pure NDL | 5 |
| G3 | pSCR mode | Passive SCR: gas use = SAC x ratio (default 1:10), loop pO2 = inspired minus metabolic drop (O2 consumption default 0.72 L/min), low-pO2 warning; per-segment dive mode always available | 5 |
| G4 | Per-segment setpoint (CCR) | Setpoint column, 0-2.00 bar, floor 0.16; empty segments auto-fill default setpoint (pref default 1.10) | 4 |
| G5 | Per-segment dive-mode override | Model mid-plan bailout (CCR/pSCR to OC) per segment | 4 |
| G6 | Setpoint changes in computed ascent | Subsurface uses fake "SP x.y" cylinders; we use an explicit setpointSchedule (depth -> setpoint) list | 4 |
| G7 | Ascent rate bands | 4 bands: below 75% mean depth, 75-50%, 50% to 6m, 6m to surface; defaults 9/9/9/9 m/min; mean depth drawn on profile | 4 |
| G8 | Descent rate + drop-to-first-depth | Default 18 m/min; drop-stone mode | 4 |
| G9 | Only switch at required stops | Postpone gas switch to next required stop; overridden when current gas hypoxic (O2 < 16%) | 4 |
| G10 | Surface segment | N minutes breathing air after surfacing (consumption planning) | 4 |
| G11 | O2 narcotic toggle | Exists in engine config; expose in UI; flips MND/EAD basis | 4 |
| G12 | Plan start date/time | Default now + 1h; drives repetitive tissue init and overlap detection | 4 |
| G13 | Tissue init from all prior dives | Simulate every earlier logged/planned dive profile sample-by-sample at plan start | 4 |
| G14 | Overlap detection | Planned dive overlapping a logged dive raises a warning | 4 |
| G15 | Reverse profile | Append mirrored waypoints (cave out-and-back) | 4 |
| G16 | On-chart editing | Drag handles, double-click add waypoint (snap to whole min/m), right-click gas switch menu, keyboard: arrows = 1m/1min nudge, Delete = remove | 3 |
| G17 | Best-mix suggestion | Best O2% from bottom pO2 at max depth; best He% from END limit (bestmixend default 30m), honoring O2-narcotic | 7 (+ calculator in 8) |
| G18 | Per-tank deco-switch depth | Default MOD at deco pO2 rounded to 3m; user-editable per cylinder | 4 |
| G19 | Tank use types | OC-gas / diluent / oxygen / not-used, filtered by dive mode; invalid use blocks plan with error | 4 |
| G20 | Runtime table + verbatim text output | Localized plan text: model line, runtime table (depth/duration/runtime/gas rows, switches emphasized), verbatim sentences, CNS/OTU, consumption, min gas, warnings | 7 |
| G21 | Plan text embedded in dive notes | Written on convert; stripped from disclaimer marker and regenerated on replan, preserving user notes | 7 |
| G22 | Replan logged dive | "Edit in planner" on a dive; Save rewrites, Save-new duplicates | 7 |
| G23 | Plan variations | Recompute with final segment +/-1 m and +/-1 min; print "Stop times + m:ss/m + m:ss/min"; async | 7 |
| G24 | ICD rule of fifths | Warning when N2 increase > 1/5 He decrease at a gas switch; detail row with deltas | 7 |
| G25 | Min gas inputs | SAC factor (2.0-10.0, default 4.0) and problem-solving time (0-10 min, default 4) exposed; rec mode forces 2.0/0 | 4 |
| G26 | Reserve gas (rec) | 10-99 bar spinbox, rec mode only, default 40 bar | 5 |
| G27 | Safety stop toggle | Honored in rec mode only | 5 |

Per-mode control matrix (drives the Setup accordion enable/disable; from
diveplanner.cpp disableDecoElements):

| Control | Buhlmann | VPM-B | Recreational |
| --- | --- | --- | --- |
| GF low/high | on | off | on |
| Conservatism | off | on | off |
| Safety stop | off | off | on |
| Reserve gas | off | off | on |
| Last stop 6m | on | on | off |
| Air breaks | on | on | off (forced unchecked) |
| Deco pO2 | on | on | off |
| Switch at required stop | on | on | off |
| Min switch duration | on | on | off |
| Surface segment | on | on | off |
| SAC factor / problem time | on (off for rebreather) | on (off for rebreather) | forced 2.0 / 0 |
| Plan variations | on | on | off |

## 5. Program structure

Eight phases, one PR each, stacked bottom-up. Phases 1-3 are pure presentation
(no schema change). Phase 4 carries the schema migration for all new plan
fields so 5-7 are engine/UI only. Each phase leaves the app shippable.

1. Chart + design system. PlanProfileChart (CustomPainter) replaces
   PlanCanvasChart inside the existing layout. Shared planner widget
   vocabulary (stat tile, section header, warning row, table style) and
   PlanChartPalette.
2. Mission Control layout. Icon rail shell, three-pane desktop planner,
   phone Chart + Tab Deck, header summary chips. PlanSettingsPanel decomposed
   into the Setup accordion, laid out for the FULL parity control set (later
   phases only add controls into existing sections).
3. On-chart editing (G16): drag, double-click add, context gas menu,
   keyboard nudges, selection shared with the segment list.
4. Engine parity I (G4-G15, G18, G19, G25): schedule policy expansion,
   per-segment fields, tissue init service, schema migration + sync.
5. Modes (G2, G3, G26, G27): recreational and pSCR, per-mode control matrix.
6. VPM-B (G1): model implementation + golden vectors + model picker UI.
7. Outputs (G17, G20-G24): plan text service, notes embed, replan,
   variations, ICD.
8. Hub + calculators restyle; Surface Interval tool rewired to
   TissueInitService; deco calculator gains model picker; best-mix calculator
   gains He suggestion; weight planner and compare visual pass.

## 6. Architecture

### 6.1 Chart (phase 1)

New family under lib/features/planner/presentation/chart/:

- PlanChartGeometry: pure (time, depth) <-> pixel mapping, tick intervals,
  hit-testing. No widget dependencies; reused by drag editing in phase 3.
- Three painter layers, each behind a RepaintBoundary, split by repaint
  frequency:
  1. Backdrop: grid, axes, labels, ceiling no-go band (shaded region above
     the ceiling curve plus dashed boundary).
  2. Series: profile line + gradient fill, deviation ghost, mean-depth line,
     gas-switch flags.
  3. Overlay: scrub cursor, hover readout; phase 3 adds drag handles and
     selection highlight. Repaints per pointer event without re-rendering
     the series.
- StopTagLayouter: pure greedy collision avoidance for stop tags ("21m 1'"
  pills) so dense schedules (15+ stops) never overlap.
- PlanChartPalette: derived from Theme.of(context).colorScheme + brightness
  at build time. No hard-coded hex, no ThemeExtension (repo has none); all
  5 presets x light/dark get coherent charts automatically.

Data flow unchanged: the chart consumes planCanvasSeriesProvider,
deviationGhostSeriesProvider, planBailoutProvider, scrubTimeProvider.

### 6.2 Layout (phase 2)

REVISION (phase 2 live review): no icon rail and no PlanningShell - tools render full-bleed on all widths and back buttons return to the hub. The paragraphs below predate that revision where they mention the rail or a centered hub.

- PlanningShell: two wide states. On /planning index, the hub renders
  full-width (no master list; the 440px _PlanningSidebar is deleted). On any
  tool route, a 52px icon rail (back-to-hub + 5 tools, tooltips) renders
  beside the tool. Narrow screens keep push navigation.
- PlanCanvasPage becomes a thin router over three panes: PlanEditorPane
  (Segments, Tanks and Gases, Plan Setup accordion), PlanChartPane (chart +
  status chips), PlanResultsPane (stat tiles: Runtime/TTS/CNS/OTU/density/
  issues; deco schedule; gas plan; contingency; warnings).
- Breakpoints computed from LayoutBuilder constraints (the space actually
  given), not window width:
  - >= 1160px: three panes (editor 300, chart flex, results 320), side panes
    collapsible with remembered state.
  - 760-1160px: chart + results; editor slides in as a drawer.
  - < 760px: phone Chart + Tab Deck; chart expand button opens a full-screen
    chart route for editing.
- Header: editable plan name, mode toggle, live summary chips (deco model +
  GF/conservatism, environment) deep-linking to their Setup section, save,
  overflow menu (existing actions).
- DivePlanNotifier and planOutcomeProvider are untouched. SegmentList,
  PlanTankList, results sections are restyled onto the phase-1 vocabulary,
  not rewritten.

### 6.3 On-chart editing (phase 3)

- PlanChartController mediates gestures -> plan mutations: hit-test via
  PlanChartGeometry, drag updates segment depth/duration (snapped to whole
  minutes and whole m/ft), double-click adds a waypoint, context menu
  switches gas (from the plan's tanks), keyboard nudges (arrows 1 m / 1 min,
  Delete removes), all through existing DivePlanNotifier mutations so undo
  and dirty-state semantics stay uniform.
- During a drag only the overlay layer invalidates per pointer-move; the
  engine recompute lands on the series layer a frame later.

### 6.4 Engine and domain (phases 4-6)

- DivePlan.decoMode: buhlmannGf | vpmB | recreational. VpmB is a second
  DecoModel implementation (CVA iteration, Boyle compensation, conservatism
  +0..+4, effective-GF output). Recreational is a PlanEngine strategy, not a
  new model (ZHL-16-based NDL maximization per G2).
- PlanMode: {oc, ccr, pscr}. New Pscr BreathingConfig (G3). Existing CMF Scr
  class remains but is not the parity target.
- PlanSegment: nullable setpointBar, nullable diveModeOverride. Plan-level
  setpointSchedule (list of depth -> setpoint) replaces the two-level
  setpoint fields for computed-ascent setpoint changes; the state mapper
  migrates old plans (low/high/switch-depth becomes a two-entry schedule).
- SchedulePolicy grows: ascentRateBands (4), descentRate (moves from
  DivePlan), dropToFirstDepth, onlySwitchAtRequiredStops (with hypoxic
  override), surfaceSegmentMinutes, safetyStopPolicy. Defaults match
  Subsurface (9/9/9/9 up, 18 down).
- TissueInitService (G13): given plan startDateTime and the selected deco
  model, simulate all earlier dives' real profiles through
  DecoModel.simulateDive (new seam entry point; VPM state differs from
  Buhlmann state) and off-gas the surface intervals. FollowDiveSheet remains
  as an explicit override. Overlap raises a PlanIssue (G14).
- Best-mix helpers (G17): best O2 from bottom pO2 at max depth; best He from
  END limit with O2-narcotic toggle. (Helper lands with phase 7's tank-table
  exposure; the standalone calculator adopts it in phase 8.)

### 6.5 Persistence and sync (phase 4)

- One schema migration adds the new plan/segment columns (claim the next
  free schema version at implementation time - the ladder moves; memory says
  v118 is next free as of 2026-07-17 but VERIFY).
- All new fields are plan inputs; schedules stay recomputed, so no output
  data migrates. Standard sync registration (serializer sites, sync_service,
  _hlcTargets) with the existing structural tests extended.

### 6.6 Outputs (phase 7)

- PlanTextService renders runtime table and verbatim plan from PlanOutcome,
  localized. Shown in a copyable results section, embedded in converted-dive
  notes between explicit markers, stripped and regenerated on replan
  (user notes preserved), and included in the PDF slate.
- Replan: "Edit in planner" action on logged dives via the existing state
  mapper reverse path; Save rewrites the linked dive, Save-as-new duplicates.
- Variations (G23) computed asynchronously alongside contingencies.
- ICD (G24): rule-of-fifths check at each gas switch; warning issue plus a
  detail row with the He/N2 deltas.

### 6.7 Hub and calculators (phase 8)

- Hub: New Plan hero, recent plans as cards with mini profile sparklines,
  tool cards, disclaimer footer.
- Deco calculator: restyle + deco-model picker (reuses the seam).
- Gas calculators: restyled 5 tabs; best-mix gains the He suggestion.
- Surface interval tool: can start from a logged dive via TissueInitService;
  manual entry stays; restyle.
- Weight planner, plan compare: visual pass only.

## 7. Error handling

- The engine keeps a no-throw contract. Hard failures (deco stop exceeding
  48h below 6m, no breathable gas for bailout at final depth, tank use
  invalid for dive mode) become a PlanComputationError variant of the
  outcome, rendered as a blocking banner in the results pane - never a
  silent empty chart, never an exception surfacing to widgets.
- Everything recoverable stays in severity-sorted PlanIssues (extended with
  ICD and overlap warnings). The Issues stat tile glows when nonzero; tap
  scrolls to warnings.
- Editing guardrails: invalid segment values clamp (depth cap, duration cap,
  10-second minimum spacing on runtime edits) exactly as Subsurface does,
  rather than erroring.

## 8. Testing

- Phase 1: golden-image tests (light + dark x empty/NDL/multi-stop-deco/
  CCR-bailout fixtures); unit tests for PlanChartGeometry and
  StopTagLayouter.
- Phase 2: pane-breakpoint widget tests driving LayoutBuilder constraints;
  tab-deck navigation tests; existing planner widget tests updated.
- Phase 3: controller unit tests (hit-test -> mutation, snapping, clamping);
  golden for handles/selection.
- Phases 4-6: independent Python implementations generate golden vectors for
  VPM-B and recreational mode (scripts/deco_golden pattern - regenerate,
  never hand-edit); property tests (conservatism and GF monotonicity, band
  rate ordering, pSCR consumption = OC x ratio, VPM-B first stop never
  shallower than Buhlmann's for the same dive); per-mode control matrix as a
  table-driven widget test; migration tests; sync structural tests.
- Phase 7: exact-string goldens for runtime/verbatim text (en); notes
  embed/strip round-trip; variations against hand-computed cases.
- Phase 8: widget/golden per tool.
- Cross-cutting: every new string in all 11 locales; dart format .; flutter
  analyze; TDD throughout.
- Release gate: manual comparison checklist against MultiDeco (carried over
  from the previous program) plus a side-by-side Subsurface session - the
  same plans entered in both, schedules and warnings compared. That is the
  parity acceptance test.

## 9. Out of scope

- No changes to logged-dive profile charts outside the planner (dive detail,
  statistics) beyond what phase 8 touches in the Planning section.
- No VPM-B in the logged-dive analysis pipeline (planner + deco calculator
  only, this program).
- No Subsurface mobile-specific behaviors (QML shims).
- Subsurface's CMF-SCR is not re-modeled; pSCR is the parity target and the
  existing Scr class stays as-is.
- No print pipeline beyond the existing PDF slate (Subsurface's print dialog
  maps to the slate).

## 10. Risks

- VPM-B correctness: mitigated by the independent-Python golden-vector
  discipline and property tests; phase 6 is isolated so it can soak.
- Drag editing on desktop trackpads vs touch: controller is pure and
  unit-tested; gesture wiring is thin. Full-screen chart route keeps phone
  editing viable.
- Schema-version collisions with parallel branches: claim the version number
  at implementation time and rely on the beforeOpen re-assert self-heal
  pattern already in the codebase.
- Scope creep in phase 8: strictly visual; any behavior change found there
  gets its own issue.
