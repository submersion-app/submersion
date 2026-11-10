# Card Info Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in this session. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every card, chart and section that uses diving jargon one
discreet info icon whose sheet explains what the card is showing right now.

**Architecture:** One shared `InfoButton` opens one shared info sheet
(bottom sheet below 800 px, dialog above) rendering an `InfoContent` value.
A shared catalogue of dive terms (`DiveTerm`) holds each term's name and
definition once, so cards list terms instead of repeating copy. The five
shared header widgets take an optional `InfoContentBuilder`; hand-built
headers add an `InfoButton` directly. Each feature owns small pure builders
that turn the card's current state into `InfoContent`.

**Tech Stack:** Flutter, Riverpod, gen-l10n ARB files (11 locales).

**Spec:** `docs/design/specs/2026-11-09-card-info-icons-design.md`

## Global Constraints

- Icon: `Icons.info_outline`, size 18, colour `colorScheme.outline`; hit box
  at least 48 x 48 on touch; header height unchanged.
- Placement: far right of the header; on collapsible headers immediately left
  of the expand arrow; on headerless tile grids the grid's top-right corner.
- Tooltip and semantic label: "About {title}".
- Sheet order: title, summary, terms, Background, How to use. Empty sections
  omitted. No collapsing.
- Caps: summary at most 2 sentences; each term at most 2 sentences;
  background at most 3; how to use at most 4 short sentences.
- Copy never says "you should", "aim for", "stay under", "safe", "it's fine
  to", and gives no second-person diving instructions. References are
  attributed (NOAA, common training).
- Sheets list only the terms the card shows now.
- Numbers with a unit in sheet text go through `UnitFormatter`
  (`formatDepth`, `formatDepthRate`, `formatPressure`, `formatVolume`).
  ppO2 stays in bar and density in g/L, as the app shows them everywhere.
- Every new key goes into all 11 ARB files with a real translation
  (`test/l10n/arb_parity_test.dart` enforces it). Run `flutter gen-l10n`
  after ARB edits; generated files are committed.
- Breakpoint: `ResponsiveBreakpoints.desktop` (800).

## Review Focus

1. RTL locales (ar, he): the icon mirrors to the far left with the arrow, and
   the sheet text aligns right. Test: header hook test pumped with
   `Locale('ar')` finds the icon left of the title (Task 3).
2. Long titles in half-width cards (side-by-side dive detail sections): the
   icon stays visible and the title wraps or ellipsizes, no overflow. Test:
   each hook pumped at 300 px wide with a 60-character title, no
   `FlutterError` (Task 3).
3. Tapping the icon inside a tappable header must not toggle the section or
   fire the card's `onTap`. Test: tap icon, `onToggle` / `onTap` not called
   (Task 3).
4. Imperial units in sheet numbers. Test: term catalogue with imperial
   settings renders "30 ft/min", not "9 m/min" (Task 2).
5. A card showing no explainable terms (profile chart with every overlay off)
   gives a sheet with no Terms section rather than an empty heading. Test:
   builder with an empty visible set has `terms.isEmpty` and the sheet shows
   no term widgets (Tasks 1 and 4).

---

### Task 1: Shared info sheet and button

**Files:**
- Create: `lib/shared/widgets/info_sheet/info_content.dart`
- Create: `lib/shared/widgets/info_sheet/info_button.dart`
- Create: `lib/shared/widgets/info_sheet/info_sheet.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (new `info_` group, appended)
- Test: `test/shared/widgets/info_sheet/info_button_test.dart`,
  `test/shared/widgets/info_sheet/info_sheet_test.dart`

**Interfaces:**
- Produces:
  - `class InfoEntry { const InfoEntry({required String term, required String body}); }`
  - `class InfoContent { const InfoContent({required String title, String? summary, List<InfoEntry> terms = const [], String? background, String? howToUse}); }`
  - `typedef InfoContentBuilder = InfoContent Function(BuildContext context);`
  - `class InfoButton extends StatelessWidget { const InfoButton({required String title, required InfoContentBuilder content}); }`
    (builds content lazily on tap so it reads the card's state at that moment)
  - `Future<void> showInfoSheet(BuildContext context, InfoContent content)`
  - l10n: `info_button_semantics(title)` "About {title}",
    `info_sheet_background` "Background", `info_sheet_howToUse` "How to use",
    `info_sheet_close` "Close"

- [ ] **Step 1: Write failing tests**
  - `info_button_test.dart`:
    - `renders info_outline at 18 in outline colour` (find `Icon` with
      `Icons.info_outline`, `size == 18`, colour equals theme outline).
    - `hit box is at least 48 by 48` (`tester.getSize(find.byType(InfoButton))`
      both sides >= 48).
    - `tooltip and semantics read About {title}` (`find.byTooltip('About Deco Status')`,
      `find.bySemanticsLabel('About Deco Status')`).
    - `opens a bottom sheet below 800 px` (surface 400 x 800, tap, find
      `BottomSheet`).
    - `opens a dialog at 800 px and up` (surface 1200 x 800, tap, find
      `Dialog`, tap "Close", dialog gone).
    - `content builder runs on tap, not on build` (counter in builder is 0
      after pump, 1 after tap).
  - `info_sheet_test.dart`:
    - `shows sections in order` (title, summary, each term then body,
      "Background", "How to use"; compare `tester.getTopLeft(...).dy` order).
    - `omits empty sections` (content with only title and summary: no
      "Background", no "How to use", no term widgets).
    - `scrolls at text scale 2` (40 terms, `MediaQuery(textScaler: 2)`, no
      overflow error, last term reachable with `scrollUntilVisible`).
    - `aligns right in Arabic` (`Locale('ar')`, summary `Text` resolves
      `TextDirection.rtl`).

- [ ] **Step 2: Run, expect failures**
  Run: `flutter test test/shared/widgets/info_sheet/`
  Expected: FAIL, files do not exist.

- [ ] **Step 3: Implement**
  - Add the 4 keys to all 11 ARBs (append script below), `flutter gen-l10n`.
  - `InfoButton`: `IconButton(icon: Icon(Icons.info_outline, size: 18, color: outline), tooltip: l10n.info_button_semantics(title), visualDensity: VisualDensity.compact, constraints: BoxConstraints(minWidth: 48, minHeight: 48), padding: EdgeInsets.zero)`;
    wrap in a `SizedBox` only if needed to keep the header height (check in
    Task 3 tests). `onPressed: () => showInfoSheet(context, content(context))`.
  - `showInfoSheet`: width `< ResponsiveBreakpoints.desktop` uses
    `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, showDragHandle: true)`
    with a `DraggableScrollableSheet`-free `SingleChildScrollView` capped at
    0.85 of the height; otherwise `showDialog` with a `ConstrainedBox(maxWidth: 480)`
    `AlertDialog` (scrollable content, `info_sheet_close` action).
  - `InfoSheetBody` (in `info_sheet.dart`): title `titleLarge`; summary
    `bodyMedium`; each term as a `Text.rich` with the term in `w600` then
    the body (`bodyMedium`, `onSurfaceVariant`); section labels `labelSmall`
    uppercase in `onSurfaceVariant`, as the planner's section headers look.

  ARB append helper (scratch, not committed): a python3.14 script that takes
  a JSON file `{key: {locale: text}, "@key": {...}}` and inserts each entry
  before the closing `}` of every `app_<locale>.arb`, keeping the file's
  two-space indent and trailing-comma style. Removal mode deletes a key and
  its `@key` block. Run it, then `flutter gen-l10n`.

- [ ] **Step 4: Run tests, expect PASS**
  Run: `flutter test test/shared/widgets/info_sheet/ test/l10n/`

- [ ] **Step 5: Commit** `feat(shared): add the info button and info sheet`

### Task 2: Dive term catalogue

**Files:**
- Create: `lib/shared/widgets/info_sheet/dive_terms.dart`
- Modify: all 11 ARBs (`info_term_*` keys)
- Test: `test/shared/widgets/info_sheet/dive_terms_test.dart`

**Interfaces:**
- Consumes: `InfoEntry` (Task 1), `UnitFormatter`.
- Produces:
  - `enum DiveTerm` with at least: `ndl, ceiling, decoStops, tts, gtr, gf99, surfaceGf, gradientFactors, cns, otu, ppO2, ppN2, ppHe, o2Cells, mod, mnd, end, ead, eadd, gasDensity, sac, rmv, ascentRate, descentRate, meanDepth, bottomTime, runtime, safetyStop, surfaceInterval, tissueCompartment, leadingCompartment, tissueLoad, mValue, surfaceLevel, halfTime, ongassing, heatMap, nitrox, trimix, diluent, setpoint, bailout, loop, stage, decoGas, pony, sidemount, twinBackmount, altitudeGroup, surfacePressure, salinity, isobaricCounterdiffusion, hypercapnia, turnPressure, minGas, rockBottom, thirds, airBreaks, rollingAverage, overallTrend, rangeBand, collapseGaps, degreeHeatingWeeks, sstAnomaly, bleachingAlert, sourceDcCalc, scrubber, cellOutput, highO2Hours`
    (add more as content tasks need them; each new member needs both keys).
  - `InfoEntry diveTermEntry(AppLocalizations l10n, UnitFormatter units, DiveTerm term)`
  - `List<InfoEntry> diveTermEntries(AppLocalizations l10n, UnitFormatter units, Iterable<DiveTerm> terms)`
    (keeps the given order, drops duplicates)
  - l10n per term: `info_term_<camelName>_label` (acronym with its expansion,
    e.g. "NDL (no-decompression limit)") and `info_term_<camelName>_body`
    (at most 2 sentences; numbers with units are placeholders filled from
    `UnitFormatter`).

- [ ] **Step 1: Write failing tests**
  - `every term has a non-empty label and body in every locale` (loop over
    `DiveTerm.values` x `AppLocalizations.supportedLocales` via
    `lookupAppLocalizations`).
  - `bodies are at most two sentences in English` (count `. ` plus final
    period; abbreviations like "e.g." are banned in the copy).
  - `no body gives advice` (English bodies match none of
    `RegExp(r"\b(you should|aim for|stay under|safe|it's fine)\b", caseSensitive: false)`).
  - `ascent rate uses the diver's depth unit` (metric settings contain
    "9 m/min"; imperial contain "30 ft/min").
  - `diveTermEntries keeps order and drops duplicates`.

- [ ] **Step 2: Run, expect FAIL** `flutter test test/shared/widgets/info_sheet/dive_terms_test.dart`

- [ ] **Step 3: Implement** the enum, the two functions (a `switch` from term
  to its two l10n getters) and the ARB entries in 11 locales. Use the
  tech-diving references for accuracy; reuse wording from
  `safetyHub_cnsOtu_about_body`, `diveLog_deco_info_body` and the calculator
  About bodies where it fits the caps.

- [ ] **Step 4: Run, expect PASS** (same command plus `test/l10n/`)

- [ ] **Step 5: Commit** `feat(shared): add the dive term catalogue for info sheets`

### Task 3: Hook points in shared headers

**Files:**
- Modify: `lib/features/insights/presentation/widgets/stat_section_card.dart`
  (`StatSectionCard`, `StatSectionHeader`, `SliverStatSectionCard`: add
  `final InfoContentBuilder? info;`)
- Modify: `lib/features/insights/presentation/widgets/trend_chart_section.dart`,
  `lib/features/insights/presentation/widgets/conditions/conditions_card_parts.dart`
  (pass `info` through)
- Modify: `lib/features/dive_log/presentation/widgets/collapsible_section.dart`
  (`CollapsibleSection`, `CollapsibleCardSection`: `info`)
- Modify: `lib/shared/widgets/section_fold.dart` (`info`)
- Modify: `lib/features/planner/presentation/widgets/plan_kit.dart`
  (`PlanSectionHeader(label, {InfoContentBuilder? info})`; new
  `PlanTileGrid({required List<Widget> tiles, InfoContentBuilder? info, required String title})`
  replacing the three hand-built `GridView.count` blocks)
- Modify: `lib/features/settings/presentation/widgets/settings_section_helpers.dart`
  (`buildSettingsSectionHeader(context, title, {InfoContentBuilder? info})`)
- Modify: `lib/features/planner/presentation/panes/plan_setup_accordion.dart`
  (section list entries gain an optional `InfoContentBuilder`; `ExpansionTile.trailing`
  becomes `Row(InfoButton, rotating expand_more)`)
- Modify: `plan_results_pane.dart`, `logged_dive_results.dart`,
  `lab_delta_panel.dart` (use `PlanTileGrid`, no info yet)
- Test: one `*_info_hook_test.dart` beside each widget's existing test.

**Interfaces:**
- Consumes: `InfoButton`, `InfoContentBuilder` (Task 1).
- Produces: the `info` parameters above. Null means no visible change.

- [ ] **Step 1: Write failing tests**, for each hook:
  - `no icon without info` (`find.byType(InfoButton)` is nothing).
  - `icon at far right` (non-collapsible) or `icon left of the arrow`
    (collapsible: icon's right edge < `Icons.expand_more` left edge).
  - `tapping the icon does not toggle or fire onTap` (Review Focus 3).
  - `header height unchanged` (height with info == height without).
  - `RTL mirrors` (Review Focus 1) and `long title at 300 px` (Review Focus 2).
  - `PlanTileGrid` puts the icon in the top-right corner over the grid with
    the grid's top unchanged.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement.** In `StatSectionHeader` the icon goes after the
  title column in the `Row` branch, and on the `LabelWithControl` label row
  in the `trailing` branch. `SectionFold` and the two collapsible widgets
  put it immediately before `AnimatedRotation`, keeping the padding so the
  height holds (they already shrink padding for `headerActions`).
  `PlanTileGrid` stacks a `Positioned(top: 0, right: 0)` icon over the grid.

- [ ] **Step 4: Run, expect PASS.** Also run the widgets' existing tests:
  `flutter test test/features/insights/presentation/widgets test/features/dive_log/presentation/widgets/collapsible_section_test.dart test/shared/widgets/section_fold_test.dart test/features/planner test/features/settings/presentation/widgets`

- [ ] **Step 5: Commit** `feat(shared): let shared card headers carry an info icon`

### Task 4: Dive detail, profile and safety pages

**Files:**
- Create: `lib/features/dive_log/presentation/info/` with one builder file per
  card: `dive_profile_info.dart`, `deco_status_info.dart`,
  `o2_toxicity_info.dart`, `gas_switches_info.dart`,
  `tissue_loading_info.dart`, `safety_review_info.dart`,
  `cylinders_info.dart`, `sac_segments_info.dart`, `dive_details_info.dart`,
  `altitude_info.dart`, `buoyancy_info.dart`, `water_conditions_info.dart`
- Create: `lib/features/dive_lab/presentation/info/compare_info.dart`
- Modify: the card widgets named in the spec's Dive detail list, plus
  `FullscreenProfilePage` (AppBar action), the Home
  `recent_dive_profile_preview.dart`, `no_fly_page.dart`, and
  `cns_otu_page.dart` (delete both `_AboutCard`s)
- Delete: `tissue_values_info.dart` and its test; the Buoyancy `Tooltip`
- Modify: all 11 ARBs (`info_diveLog_*`, `info_diveLab_compare_*`)
- Test: `test/features/dive_log/presentation/info/*_test.dart` and an
  icon-present case in each card's existing widget test

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces, each returning `InfoContent`:
  - `diveProfileInfo(AppLocalizations l10n, UnitFormatter units, {required Set<DiveTerm> visibleOverlays, required bool showsRangeStats, required bool hasDcAndCalcSources})`
    (`visibleOverlays` derived from the active legend entries in
    `active_legend_entries.dart`)
  - `decoStatusInfo(l10n, units, {required bool inDeco, required bool hasGf99, required bool hasSurfaceGf, required bool hasStops})`
  - `o2ToxicityInfo(l10n, units, {required bool hasOtuWindows, required bool hasTimeAbove})`
  - `tissueLoadingInfo(l10n, units, {required TissueView view, required bool hasHelium})`
    (`TissueView` is the card's existing view enum)
  - `cylindersInfo(l10n, units, {required bool hasMnd, required bool isRebreather, required bool showsSac, required bool showsRmv})`
  - `safetyReviewInfo(l10n, units, {required Set<SafetyFindingKind> kinds})`
  - the rest take the flags their card already computes.

- [ ] **Step 1: Write failing builder tests**, per builder:
  `lists only visible terms` (e.g. `decoStatusInfo(inDeco: true)` has the
  ceiling entry and no NDL entry; `false` the reverse);
  `air dive profile sheet has no ppHe or setpoint`;
  `empty overlays give no terms` (Review Focus 5);
  `summary at most two sentences`.
- [ ] **Step 2: Write failing widget tests**: each card shows an
  `InfoButton`; tapping on `CompactDecoStatusCard` opens a sheet containing
  "NDL"; `CompactTissueLoadingCard` no longer shows "What do these values
  mean?"; the CNS/OTU page has no "About CNS and OTU" card; the Buoyancy
  header has an `InfoButton` and no `Tooltip` with the old message.
- [ ] **Step 3: Run, expect FAIL** `flutter test test/features/dive_log test/features/safety test/features/dashboard test/features/dive_lab`
- [ ] **Step 4: Implement** builders, ARB entries (11 locales), wiring. Cards
  with hand-built header rows add `InfoButton` as the last child of the
  header `Row`.
- [ ] **Step 5: Run, expect PASS** (same command plus `test/l10n/`)
- [ ] **Step 6: Commit** `feat(dive-log): explain dive detail cards with info icons`

### Task 5: Insights

**Files:**
- Create: `lib/features/insights/presentation/info/` builders:
  `gas_info.dart` (consumption trend, gas mix distribution, records, tank
  configuration, role consumption, rebreather gas use),
  `profile_info.dart` (rates, time at depth, deco obligation),
  `progression_info.dart`, `trend_controls_info.dart`,
  `conditions_info.dart`, `time_patterns_info.dart`,
  `equipment_info.dart`, `focus_info.dart`, `overview_info.dart`,
  `connections_info.dart`
- Modify: the pages and widgets in the spec's Insights list (hand-built
  headers on the Overview page, `ObservationsStrip` and the Connections
  insight strip add `InfoButton` directly)
- Modify: all 11 ARBs (`info_insights_*`)
- Test: `test/features/insights/presentation/info/*_test.dart`

**Interfaces:**
- Produces:
  - `InfoContent trendChartInfo(l10n, units, {required String title, required String summary, required List<DiveTerm> metricTerms, required TrendControlsState controls})`
    where `TrendControlsState` is the strip's existing state (rolling
    average on, trend on, aggregation, collapse gaps). `TrendChartSection`
    calls it, so all 9 charts get the controls in "How to use" and only the
    overlays that are on in Terms.
  - One builder per card, taking the flags the card already has.

- [ ] **Step 1: Failing tests:** `trendChartInfo` with rolling average off
  has no rolling-average term; weekly aggregation adds the range-band term;
  `focusInfo` lists CNS and OTU only when the selected metric is one of
  them; the Overview "Avg Depth" card's sheet says it is the average of each
  dive's maximum depth; each Insights page test finds `InfoButton`s.
- [ ] **Step 2: Run, expect FAIL** `flutter test test/features/insights test/features/connections`
- [ ] **Step 3: Implement** builders, ARB entries, wiring.
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(insights): explain Insights cards with info icons`

### Task 6: Planner and Dive Lab

**Files:**
- Create: `lib/features/planner/presentation/info/` builders:
  `plan_results_info.dart` (tile grid, decompression schedule, bailout,
  contingencies, range table, runtime table, gas rows, compare page),
  `plan_setup_info.dart` (one per setup section, each with How to use),
  `logged_dive_info.dart`
- Create: `lib/features/dive_lab/presentation/info/lab_info.dart` (tile grid,
  tissues at the surface, buoyancy, delta table, interventions)
- Modify: `plan_results_pane.dart`, `plan_results_sheet.dart`,
  `logged_dive_results.dart`, `plan_setup_accordion.dart`,
  `plan_compare_page.dart`, `lab_delta_panel.dart`,
  `lab_add_intervention_sheet.dart`, the logged-dive chart host
- Modify: all 11 ARBs (`info_planner_*`, `info_diveLab_*`)
- Test: `test/features/planner/presentation/info/*_test.dart`,
  `test/features/dive_lab/presentation/info/*_test.dart`

**Interfaces:**
- Produces: `planResultsTilesInfo(l10n, units, {required bool inDeco})`
  (NDL or TTS, CNS, warnings), `planSetupSectionInfo(l10n, units, PlanSetupSection section, {required DiveMode mode})`
  (rebreather terms only for CCR or pSCR), `labTilesInfo(l10n, units)`,
  and the per-section builders.

- [ ] **Step 1: Failing tests:** results tile sheet explains TTS when in deco
  and NDL otherwise; the gas options section on open circuit has no
  setpoint term; every setup section has a How to use; the Dive Lab tile
  grid shows one `InfoButton` and no tile has its own.
- [ ] **Step 2: Run, expect FAIL** `flutter test test/features/planner test/features/dive_planner test/features/dive_lab`
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(planner): explain planner and Dive Lab sections with info icons`

### Task 7: Calculators and tools

**Files:**
- Create: `lib/features/gas_calculators/presentation/info/calculator_info.dart`
  (MOD, MND, ICD, Density, Rock Bottom, Blender, Best Mix, Gas Consumption)
- Create: `lib/features/deco_calculator/presentation/info/deco_calculator_info.dart`,
  `lib/features/surface_interval_tool/presentation/info/surface_interval_info.dart`
- Modify: each calculator's widgets; delete `blender_about_card.dart`, the
  `_InfoCard` in `mod_calculator.dart` and the About cards in MND, ICD,
  Density and Rock Bottom; delete the Surface Interval "About Tissue
  Loading" card
- Modify: all 11 ARBs (`info_calculators_*`, `info_decoCalculator_*`,
  `info_surfaceInterval_*`)
- Test: `test/features/gas_calculators/presentation/info/calculator_info_test.dart`
  and updates to the calculators' existing tests

**Interfaces:**
- Produces: `calculatorInfo(l10n, units, GasCalculator calculator, {DiveMode mode = DiveMode.oc})`
  (`GasCalculator` is the hub's existing calculator enum; check its name in
  `gas_calculators_list_content.dart`), `decoCalculatorInfo(...)`,
  `surfaceIntervalInfo(...)`.

- [ ] **Step 1: Failing tests:** each calculator page shows an `InfoButton`
  in its first card's header and no "About" card; the MOD sheet keeps the
  old About text's facts (MOD, EAD, END); Best Mix and Gas Consumption
  sheets explain END, density and RMV; How to use present for every
  calculator.
- [ ] **Step 2: Run, expect FAIL** `flutter test test/features/gas_calculators test/features/deco_calculator test/features/surface_interval_tool`
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(gas-calculators): explain calculators with info icons in place of About cards`

### Task 8: Equipment, sites, trips and settings

**Files:**
- Create: `lib/features/equipment/presentation/info/equipment_info.dart`,
  `lib/features/dive_sites/presentation/info/site_altitude_info.dart`,
  `lib/features/trips/presentation/info/scrubber_margin_info.dart`,
  `lib/features/settings/presentation/info/settings_info.dart`
- Modify: `condition_trend_card.dart`, `condition_findings_card.dart`,
  `exposure_card.dart`, `site_detail_page.dart` (Altitude card),
  `trip_gear_alert_sheet.dart`, `decompression_settings_page.dart`,
  `planner_defaults_settings_page.dart` and its section widgets,
  `safety_review_settings_page.dart`, `equipment_condition_settings_page.dart`,
  `settings_page.dart` (notifications)
- Delete: `buildSettingsInfoCard` and its two uses
- Modify: all 11 ARBs
- Test: builder tests per file and icon-present cases in each page's test

**Interfaces:**
- Produces: `equipmentConditionInfo(l10n, units, ConditionMetric metric)`,
  `exposureInfo(l10n, units)`, `siteAltitudeInfo(l10n, units)`,
  `scrubberMarginInfo(l10n)`, `settingsSectionInfo(l10n, units, SettingsInfoSection section)`
  with `enum SettingsInfoSection { gradientFactors, oxygenToxicity, dataSources, narcosis, isobaricCounterdiffusion, ascentPlanning, plannerGas, plannerRates, plannerContingency, safetyReviewRules, equipmentConditionRules, notifications }`.

- [ ] **Step 1: Failing tests:** decompression settings page has no "About
  Gradient Factors" card and its Gradient Factors header opens a sheet with
  GF Low and GF High; the notifications section has no "How it works" card;
  the cell output chart sheet explains mV per bar; the site Altitude card
  sheet explains altitude groups without advice words.
- [ ] **Step 2: Run, expect FAIL** `flutter test test/features/equipment test/features/dive_sites test/features/trips test/features/settings`
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(settings): explain equipment, site, trip and settings sections with info icons`

### Task 9: Orphaned keys and full verification

**Files:**
- Modify: all 11 ARBs (remove keys whose only users were deleted: the About
  card titles and bodies, `diveLog_deco_info_*`, `buoyancy_tooltip`,
  `settings_notifications_howItWorks_*`, the gradient factor about keys,
  `safetyHub_*_about_*`)

- [ ] **Step 1:** List candidate keys with
  `grep -rn "<key>" lib test` for each; remove only keys with no remaining
  reference. `flutter gen-l10n`.
- [ ] **Step 2:** `dart format .` then `flutter analyze` (whole repo):
  expected "No issues found!"
- [ ] **Step 3:** `flutter test test/architecture test/shared test/l10n`,
  then the feature folders touched in Tasks 4 to 8: all pass.
- [ ] **Step 4: Commit** `chore(l10n): remove explanation keys the info sheets replaced`
