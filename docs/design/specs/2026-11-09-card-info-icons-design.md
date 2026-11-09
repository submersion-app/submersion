# Info icons on cards, charts and metrics

Date: 2026-11-09. Release: v1.8.5.

## Intent

Many cards, charts and metrics in Submersion use terms a recreational diver
does not know: CNS%, OTU, NDL, TTS, GF99, SurfGF, SAC versus RMV, ppO2, MOD,
END, tissue compartments, heat maps, trend overlays. Today almost nothing
explains them. The one discreet header icon in the app (Buoyancy) is a
hover-only tooltip, and the calculators explain themselves with always-open
"About" cards at the bottom of the screen, far from the numbers.

This feature gives every such card one discreet info icon in its header.
Tapping it opens a sheet that says what the card shows, with some technical
background, or how to use the card when it has inputs. The goal is that a
recreational diver can understand any screen without leaving it, while the
screen looks the same as today to someone who never taps.

## Goals

- One shared info button and one shared info sheet, used everywhere.
- Every card, chart and section that shows a term a recreational diver might
  not know gets the icon, across the whole app (see Coverage).
- The sheet explains only what the card is showing right now.
- Every screen works the same way: existing explanation cards ("About X",
  settings info cards, the tissue "What do these values mean?" footer, the
  Buoyancy tooltip) are replaced by the header icon and its sheet.

## Non-goals

- No glossary page, onboarding tour or coach marks.
- No icon on individual metric rows. One icon per card; its sheet covers
  every term on the card.
- No change to the numbers, charts or layout of any card, beyond adding the
  icon and removing the replaced explanation cards.
- No setting to hide the icons (builder's call: they are discreet enough that
  experts lose nothing).

## Anti-goals (a failure even if it works)

- **Advice.** Sheet text must never read as training or safety guidance, or
  as permission to dive a certain way. It says what a number means and, where
  useful, what the published reference is ("100% is the NOAA single-exposure
  limit"). It never says "you should", "aim for", "stay under", "safe" or
  "it's fine to". No second-person instructions about diving.
- **Long sheets.** A recreational diver must be able to read a sheet in well
  under a minute. Caps: summary at most 2 sentences; each term at most 2
  sentences; background at most 3 sentences; "How to use" at most 4 short
  sentences. A card whose content does not fit is a sign the card itself
  is doing too much; trim the text, not the caps.

## Decided with the user

1. **Placement:** one icon per card, at the far right of the card's header
   row. Header rows that already hold action icons (Dive Profile's 3D,
   spatial and fullscreen buttons; Tissue Loading's view toggles) keep them;
   the info icon goes last, at the far right.
2. **Look:** very discreet. `Icons.info_outline`, 18 logical px, in
   `colorScheme.outline` (the Buoyancy header's current look). No badge, no
   colour, no animation.
3. **Sheet content:** everything visible at once, in this order:
   - Title (the card's title).
   - Summary: what the card shows, in plain words.
   - Terms: one entry per term currently on the card (term name in bold, then
     its explanation).
   - Background: the technical basis (model, table, formula in words).
   - How to use: only for cards with inputs (calculators, planner setup
     sections, Insights Focus sentence, trend chart controls).
   Any section with nothing to say is omitted. No collapsing or "more" links.
4. **Coverage:** everything (see Coverage below), in one PR for v1.8.5.
5. **Existing explanation cards are replaced** by the header icon so every
   screen works the same way (see Replaced explanations).
6. **Follows the card:** the sheet lists only the terms the card shows now.
   A plain air dive's Dive Profile sheet does not mention ppHe, setpoints or
   gas density unless those overlays are on. Deco Status explains Ceiling
   instead of NDL once the dive is in deco. Rebreather terms appear only on
   rebreather dives.
7. **Both anti-goals above.**
8. **Headerless tile grids** (planner results `PlanResultsPane`, logged-dive
   results `LoggedDiveResults`, Dive Lab `_StatTiles`): one icon in the
   grid's top-right corner, with no new header row. Its one sheet explains
   every tile in the grid (following which tiles are showing, such as NDL
   versus TTS). The tiles themselves get no icon.
9. **Collapsible headers:** the info icon sits immediately left of the
   expand/collapse arrow; the arrow stays at the far right where it is
   today. This applies to `CollapsibleSection`, `CollapsibleCardSection`,
   `SectionFold`, the planner setup accordion and settings `ExpansionTile`s
   (where `trailing` replaces the default arrow, the builder keeps an arrow
   that turns as the default one does, with the icon to its left).

## Builder's calls (for the user to check)

- **Full-screen profile page** (`FullscreenProfilePage`) gets the Dive
  Profile sheet through an info icon in its top bar's actions, in the same
  discreet look. The planner's logged-dive chart, which reads the same
  legend, gets the same sheet from its nearest header.
- **Planner status chips and chart readouts** (TTS, NDL, DECO, CNS chips on
  the plan canvas) get no icon of their own; the terms are explained by the
  results grid's sheet and the plan chart's sheet.
- **No setting to hide the icons.**
- **Kept explanations:** see the end of Replaced explanations.
- **Home gauge chips** get no icon (see Home).

## Behaviour

- **Narrow screens** (below `ResponsiveBreakpoints.desktop`, 800 px): a modal
  bottom sheet (`isScrollControlled: true`, `useSafeArea: true`,
  `showDragHandle: true`, as `cors_help_sheet.dart` does), scrollable when
  long.
- **Wide screens** (800 px and up): a centred dialog, max width about 480 px,
  scrollable body, a Close button.
- **The button:** an `IconButton` with the look above. The visual stays 18 px
  and must not make the header row taller; the hit box is at least 48 x 48 on
  touch platforms (it may overlap header padding). Its tooltip and semantic
  label are "About {card title}" (localized), and it is announced as a button.
- **Collapsible headers** (`CollapsibleSection`, `CollapsibleCardSection`,
  `SectionFold`, `ExpansionTile` sections): the icon sits just left of the
  arrow (decision 9), is visible whether the section is collapsed or
  expanded, and tapping it opens the sheet without toggling the section.
- **Units:** any number in sheet text (an ascent rate, a ppO2, a depth, a
  pressure, a volume) is formatted in the active diver's units with the
  app's existing unit formatter. No hard-coded "9 m/min" or "bar".
- **Languages:** every new string is added to all 11 ARB files (en, ar, de,
  es, fr, he, hu, it, nl, pt, zh) with real translations, as the project does
  for every string.

## Content rules

- Plain words first. The summary assumes an open-water diver.
- Define each acronym on first use in the sheet ("NDL (no-decompression
  limit)").
- State facts, not advice (see Anti-goals). Where a published reference
  helps (NOAA CNS table, 300 OTU daily figure, common 9 m/min ascent rate),
  attribute it to its source or to "common training" rather than to the app.
- Say where a value comes from when the card can show either the dive
  computer's figure or the app's calculation ("DC" versus "Calc" sources).
- Existing reviewed copy may be reused or adapted: `safetyHub_cnsOtu_about_*`,
  `safetyHub_tissueLoading_about_*`, `diveLog_deco_info_body`,
  `buoyancy_tooltip`, the calculators' About bodies, the gradient factor and
  notification "how it works" bodies. Their old keys are removed once nothing
  uses them.
- Content lives with the feature that owns the card, as a small builder that
  takes the card's current state (which terms are visible) and returns the
  sheet content. Builders are pure enough to unit test.

## Replaced explanations

These are removed and their text moves into the matching header icon's
sheet:

- Gas calculators: the About cards in the blender (`blender_about_card.dart`),
  MOD (`_InfoCard` in `mod_calculator.dart`), MND, ICD, Density and Rock
  Bottom calculators.
- Settings: `buildSettingsInfoCard` uses on the decompression settings page
  ("About Gradient Factors") and the notifications section ("How it works").
  The helper is deleted when it has no callers.
- Surface Interval tool: the "About Tissue Loading" card.
- CNS/OTU and tissue safety pages: the two `_AboutCard`s in `cns_otu_page.dart`.
- Tissue Loading card: the `TissueValuesInfo` footer ("What do these values
  mean?").
- Buoyancy card: the hover-only header tooltip becomes the new button.

Kept as they are (builder's call): safety disclaimers and banners (planning
hub, calculators hub, plan details), status notes that explain why data is
missing or withheld (`tissue_load_notes.dart`, `TissueLoadingWithheldCard`,
`SacVolumeHint`, "Based on X of Y dives", excluded-dives and filter
footnotes), and explanatory notes inside settings dialogs (ppO2 and GF limit
dialogs, the CNS method "About these methods" tile). These are not card
headers, and they say something different from what a term means.

## Coverage

Line numbers are from 2026-11-09 and will drift; the widget names are the
anchor.

### Shared hook points (one change reaches many cards)

| Widget | File | Reaches |
|---|---|---|
| `StatSectionHeader` (used by `StatSectionCard`, `SliverStatSectionCard`, `TrendChartSection`, `ConditionsChartCard`) | `lib/features/insights/presentation/widgets/stat_section_card.dart` | almost every Insights card, including the 9 trend charts |
| `PlanSectionHeader` | `lib/features/planner/presentation/widgets/plan_kit.dart` | planner results sheet, logged-dive results, mission, Dive Lab panel sections |
| The tile grids holding `PlanStatTile` (decision 8) | `plan_results_pane.dart`, `logged_dive_results.dart`, `lab_delta_panel.dart` | the headline tiles in planner results, logged-dive results and Dive Lab |
| Planner setup accordion section list | `lib/features/planner/presentation/panes/plan_setup_accordion.dart` | every planner setup section |
| `CollapsibleSection` (`headerActions`), `CollapsibleCardSection` (`trailing`) | `lib/features/dive_log/presentation/widgets/collapsible_section.dart` | Safety review, SAC segments, others |
| `buildSettingsSectionHeader` | `lib/features/settings/presentation/widgets/settings_section_helpers.dart` | settings sections |

Each takes an optional info content (or content builder); when it is null
nothing changes.

### Dive detail (and the safety pages that embed the same cards)

- Dive Profile card header: explains the chart and every overlay currently
  on (from the active legend entries: NDL, ceiling, deco stops, TTS, GTR,
  CNS%, OTU, ppO2, ppN2, ppHe, O2 cells, MOD, gas density, GF%, Surface GF,
  mean depth, ascent rate, consumption, pressure thresholds, late gas
  switches, computed events), the DC/Calc source distinction, and the Range
  Stats panel terms (average vertical speed, SAC, RMV) when that panel is
  shown. The Home "Latest dive profile" card, the full-screen profile page
  and the planner's logged-dive chart reuse the same content.
- Deco Status (`CompactDecoStatusCard`): DECO / NO DECO, NDL or Ceiling, TTS,
  GF99, SurfGF, the GF chip, deco stops.
- Oxygen Toxicity (`CompactO2ToxicityPanel` and the full `O2ToxicityCard`):
  CNS oxygen clock (start, added this dive), OTU with daily and weekly
  figures, ppO2, max ppO2, time above the limit.
- Gas switches (`GasSwitchEfficiencyCard`): ideal versus actual switch depth,
  extra deco.
- Tissue Loading (`CompactTissueLoadingCard`): compartments, leading
  compartment, load, M-value, surface level, GF, half-time, N2 and He,
  ongassing and offgassing, plus the heat map or stacked-area view when that
  view is selected.
- Safety review: what the review is and each finding kind currently listed
  (ascent rate, ceiling breach, sawtooth, surfacing GF, late gas switch).
- Cylinders (`CylindersCard`): MOD, MND, the ppO2 the MOD uses, per-tank SAC
  or RMV, loop use on rebreathers, gas names (EAN32, Tx 18/45).
- Gas consumption by segment: SAC versus RMV and the segment table.
- Details section: Dive Mode values, SAC, RMV, Gradient Factors (these are
  `DiveDetailRow` rows; the section header carries the icon).
- Altitude Dive: surface pressure, altitude groups.
- Buoyancy: buoyancy swing, peak lift, minimum ditchable weight, drysuit gas,
  term breakdown.
- Environment water conditions: Degree Heating Weeks, anomaly, bleaching
  alert levels.
- Compare (Dive Lab on dive detail): NDL on leaving bottom, deco, Surface GF.

### Insights

- Air Consumption: SAC/RMV lane, gas consumption trend, gas mix distribution
  (a dive with several mixes counts under each), gas consumption records,
  tank configuration, consumption by cylinder role, rebreather gas use.
- Profile Analysis: ascent and descent rates, time at depth ranges,
  decompression obligation.
- Progression: max depth, runtime and bottom time trends (runtime versus
  bottom time), cumulative dive count.
- Trend chart controls (`TrendChartSection` / `TrendControlStrip`, all 9
  charts): rolling average, overall trend and per-year rate, weekly and
  monthly grouping with the min/max band, collapse gaps. Listed only when
  that control or overlay is on; "How to use" covers the controls.
- Conditions: visibility distribution (including "logged before measurement"
  and "spans bands"), seasonal water temperature, dives by water temperature
  and its SAC/RMV column, altitude groups, surface pressure, site types.
- Time Patterns: time of day buckets (dawn and dusk definitions), calendar
  days heat map (shading, coverage), surface interval statistics.
- Equipment: exposure units (high-O2 hours, salt-water hours, deep and cold
  dives, thresholds), condition findings and rules, reported issues.
- Dive focus: the sentence controls (How to use), the metrics (CNS at end,
  OTU, SAC, RMV, gas used, average depth), "What stands out", the full
  comparison table and its standout dot.
- Overview: the stat cards (including "Avg Depth", which is the average of
  each dive's maximum depth), Distributions (dive types count a dive once per
  type), Observations.
- Connections: insight strip, colour-by, weighted edges, hops.
- Social, Geographic, Species and Records: no icon (plain language).

### Home

- Latest dive profile card: the Dive Profile content.
- Gauge strip chips (No-fly, Dive window, data issues) have no header and
  already open the no-fly page or data quality page; they get no icon. The
  no-fly page's cards get one where they use jargon (single, repetitive,
  deco categories).
- Other Home cards are plain language: no icon.

### Planner and Dive Lab

- Results: TTS, NDL, CNS tiles and status chips; Decompression Schedule;
  Bailout (open circuit); Contingencies; range table; runtime table columns
  (RT, PO2, END); gas rows (turn pressure, min gas); compare plans page.
- Setup sections (each with "How to use"): cylinders (MOD, Dil MOD,
  diluent, bailout), Decompression (GF Low, GF High, last stop, air breaks),
  gas options (deco and stressed RMV, RMV factor, bottom and deco ppO2, best
  mix END, O2 narcotic, per-O2-band limits, hypercapnia), environment
  (altitude, salinity), CCR and pSCR (setpoints, switch depth, pSCR ratio),
  Contingencies (turn rule, turn fraction, thirds), mission (DPV).
- Logged-dive carry card: surface interval, CNS at end, OTU.
- Dive Lab: stat tiles (TTS, Deco, Surf GF, CNS), Tissues at the surface,
  Buoyancy, Delta table metrics (Surface GF, peak GF99, CNS, OTU, max ppO2,
  min gas margin, ceiling violations and excursion, deepest stop),
  interventions sheet (GF Low/High, last stop, min ditchable lead).

### Calculators and tools

- MOD, MND, ICD, Density, Rock Bottom, Blender: the replaced About text plus
  the terms the old cards left out (ppO2, EADD, diluent MOD, contingency MOD,
  setpoint, minimum ppO2; RMV on Rock Bottom).
- Best Mix and Gas Consumption: new content (they have none today).
- Deco calculator: ppO2, MOD, END metrics and the shared deco info panel.
- Surface Interval tool: tissue recovery chart, compartments, leading
  compartment, minimum surface interval, NDL for the second dive.

### Equipment, sites, trips, settings

- Equipment: condition trend chart (cell output, scrubber use, transmitter
  dropouts), condition findings, exposure.
- Site detail: Altitude card (pressure, altitude group, why altitude matters
  for decompression, stated as fact).
- Trips: scrubber margin sheet header.
- Settings: decompression page sections (Gradient Factors, Oxygen Toxicity,
  Data Source Preferences with NDL/Deco Stop/TTS/GTR/CNS source, Narcosis,
  Isobaric Counterdiffusion, Ascent planning), planner defaults sections,
  safety review rules, equipment condition rules, notifications.

## Testing

- The shared button and sheet: tapping opens a bottom sheet below 800 px and
  a dialog at 800 px and up; sections with no content are omitted; the
  semantic label and tooltip read "About {title}"; the header height does not
  change.
- Each content builder: lists only the terms passed in as visible, formats
  numbers in metric and imperial settings, and produces no empty sections.
- Each hook point: a card with info content shows the icon; one without shows
  nothing new. Collapsible headers open the sheet without toggling.
- Removed explanation cards are gone and their text is reachable from the
  icon.
- `test/architecture/` and `test/shared/` pass (they scan all of `lib/`).

## Left to the builder

- Names and file layout of the shared widget, the content model and the
  per-feature content builders.
- The exact wording of every sheet, within the content rules and caps above,
  using the tech-diving domain references for accuracy.
- ARB key naming, following the file's existing feature grouping.
- The order of work and how it is split into commits within the one PR.
