# Isobaric counterdiffusion on the dive profile

Issue: #4530

## Goal

Mark the phases of a dive in which the tissue model shows isobaric
counterdiffusion (ICD) as time bands on the dive profile, the way O2 cell
divergence is marked today. Gas switches that break the rule of fifths get a
point marker, and a new safety rule reports ICD in the findings lane.

## Current state

### Tissue loading

- `DecoStatus.gasExchanges(compartment)` (`lib/core/deco/entities/deco_status.dart`)
  returns, per compartment, the direction of N2, the direction of He and the
  net direction (`GasExchange.ongassing / offgassing / equilibrium`).
  - Per gas: compartment tension against the inspired partial pressure, with
    a tolerance of `gasEquilibriumToleranceBar` (0.01 bar).
  - Net, when the gases move in opposite directions: the sign of the combined
    Haldane rate (`isOffgassing`).
- `TissueCompartmentDetail` shows this as an N2 arrow, an He arrow and a net
  badge (#4228). Without a known inspired gas everything is `null`; nothing is
  guessed (#2593).
- The values exist for every profile sample: `ProfileAnalysis.decoStatuses`
  is aligned with the sample timestamps.
- The profile analysis carries residual tissue loading over from previous
  dives (48 h lookback, `_computeResidualTissueState`), helium included.
- Nothing evaluates the exchanges over time today; the view only shows the
  selected instant.

### Prior art on the chart

- `cellDivergenceHighlightRanges()` (`cell_divergence_highlight.dart`) turns
  the sensor summary into `ProfileHighlightRange`s.
- `DiveProfileChart` receives them as `secondaryRanges` and draws them as
  `VerticalRangeAnnotation`s (alpha 0.10), only while the O2 cell overlay is
  on (`_showO2Cells`).
- Late gas switches use the same mechanism with their own toggle
  (`gasSwitchEfficiency.windows`, `showLateGasSwitches`).
- Chart option entries appear only when the dive has something for them
  (`config.hasO2CellData`, `config.hasPpHeData`, `config.hasLateGasSwitches`).

### Rule of fifths

- `computeIcd()` (`lib/features/gas_calculators/domain/icd_calculator.dart`)
  checks one gas switch against the rule of fifths; so far only the ICD
  calculator uses it. The `icdWarningsEnabled` setting already exists.

## Design

### Levels

N2 rising while He falls is normal and intended on every trimix dive after
the switch to a deco nitrox. Marking every such phase would colour nearly the
whole deco. Two levels, evaluated per profile sample:

| Level | Condition (at least one compartment) | Display |
| --- | --- | --- |
| ICD-relevant | N2 and He move in opposite directions, the net on-gassing rate exceeds a minimum, and the compartment's total inert tension is at least the total inspired inert pressure | prominent band (warning colour), default |
| Opposing | N2 and He move in opposite directions, net off-gassing | subtle band, optional sub-setting |

- The total-tension condition separates counterdiffusion from ordinary
  uptake. When the inspired inert total exceeds the tissue's, the tissue
  takes gas up anyway (a nitrox bottom phase with residual helium, slow
  compartments on a deco nitrox); that is not counterdiffusion. Only when the
  tissue holds more inert gas than is breathed, and would off-gas if both
  gases moved at the same speed, does net on-gassing come from the gases'
  different half-times.
- In the Buhlmann model helium moves 2.65 times faster than nitrogen, so a
  trimix to nitrox switch nearly always off-gasses net; model ICD appears
  mainly after switching from a nitrogen-rich to a helium-rich gas at depth.
  The trimix to nitrox case the rule of fifths targets is covered by the
  gas switch markers, not the bands. The info text says so, so a missing
  band after an EAN50 switch is not read as a bug.
- One compartment is enough; the minimum rate filters insignificant cases.
  Starting value 0.005 bar/min, tuned against real dives during
  implementation.
- Directions come from `gasExchanges()`, so profile and tissue view share the
  same physics. The tissue view's net badge keeps its current (sign-only)
  behaviour; the info text explains that the profile marks noticeable
  on-gassing only.
- Short gaps are merged and ranges below a minimum duration (about 30 s) are
  dropped to avoid flicker.
- No ranges when neither the gases nor the starting tissue state contain
  helium, when the inspired gas is unknown, or when tissue data is withheld
  (`tissue_loading_withheld_card`).
- OC and CCR are treated alike; detection depends only on the inspired gas.

### Rule-of-fifths markers

- Every gas switch is checked with `computeIcd()`. Violations and cautions
  (`IcdSeverity.caution`, above 80 % of the allowed rise) become point
  markers at the switch time, coloured like the ICD calculator (violation
  red, caution amber). Only violations raise a safety finding. Examples:
  Tx 18/45 to EAN50 is a violation (N2 +13, allowed 9); Tx 21/35 to EAN50 a
  caution (N2 +6, allowed 7).
- The markers share the profile toggle with the bands. `icdWarningsEnabled`
  additionally acts as a master switch: off means no markers.
- On CCR dives only switches to open circuit (bailout) are checked.

### Visibility

- New entry "Isobaric counterdiffusion" under Settings > Default visible
  metrics, always present, off by default. Stored and synced like the other
  default visible metrics (`diver_tables.dart` + migration,
  `diver_settings_repository.dart`, `diver_settings_fields.dart`).
- When enabled, every profile shows the bands wherever the tissue model
  yields counterdiffusion, residual loading from previous dives included
  (e.g. a nitrox dive after a trimix dive).
- The chart options ("Overlays") get an entry to toggle it for the current
  view. It is offered when helium is in the gases or still in the tissues,
  like ppHe and O2 cells.
- The entry carries a two-segment choice, `ICD | All`, built with
  `buildToggleWithSource` like the O2 cells' `mV | ppO2`. `ICD` (default)
  shows the ICD-relevant bands only, `All` adds the opposing phases. The
  choice is persisted to the diver settings the way the O2 cell unit is,
  so it holds for every dive.

### Display

- Bands as `VerticalRangeAnnotation`s on the detail view
  (`dive_profile_chart_host.dart`) and the fullscreen profile
  (`fullscreen_profile_page.dart`). Draw order, bottom to top: late gas
  switches, counterdiffusion, O2 cells, selected finding.
- Colours: ICD-relevant bands use a warning orange, distinct from the error
  red of the O2 cell bands, since a CCR dive on a trimix diluent can show
  both. Opposing bands use a neutral tone at low alpha.
- The tissue heat map marking is left out of this change; it can follow
  once the bands have been seen on real dives.
- `secondaryRanges` is tied to the O2 cell overlay, so counterdiffusion gets
  its own chart parameter, analogous to `gasSwitchEfficiency`.
- Inside a band the cursor tooltip names the affected compartments, the
  directions and the net direction, e.g. "C3-C7 · N2 up, He down · net up".
- The info sheet links the existing `DiveTerm.isobaricCounterdiffusion`.

### Safety finding

- New rule `SafetyRuleId.isobaricCounterdiffusion`, raised by an
  ICD-relevant band or by a rule-of-fifths violation at a gas switch.
- Shown as a chip in the findings lane whether or not the overlay is on;
  tapping highlights the span, it can be dismissed like other findings.
- Governed only by its own rule toggle, like every other rule: always
  computed, filtered at display time through `safetyReviewDisabledRules`
  (a new rule is enabled by default, no migration). It does not follow
  `icdWarningsEnabled`: that setting is not part of the analysis
  fingerprint, and adding it would need a fingerprint format bump that
  older peers treat as "from a newer build". `icdWarningsEnabled` keeps
  gating the calculator and the profile markers, which are display only.
- Bump `SafetyReviewService.engineVersion` (11 to 12) so stored reviews are
  recomputed with the new rule.
- The opposing level never raises a finding.

### Computation

New pure function, e.g. `lib/core/deco/counterdiffusion_ranges.dart`:

```dart
class CounterdiffusionRange {
  final int startSeconds;
  final int endSeconds;
  final CounterdiffusionKind kind; // opposing | netOngassing
  final List<int> compartmentNumbers;
}

List<CounterdiffusionRange> counterdiffusionRanges(
  List<DecoStatus> statuses,
  List<int> timestamps, {
  double minNetOngassingRateBarPerMin = 0.005,
  int minDurationSeconds = 30,
  int mergeGapSeconds = 10,
});
```

Computed once as a field of `ProfileAnalysis` (like `gasSwitchEfficiency`),
not in a widget, so the chart and `SafetyReviewService.review()` share it.
The minimum rate is a real Haldane rate in bar/min
(`ln 2 * (inspired - tension) / halfTime`, summed over N2 and He);
`DecoStatus.isOffgassing` omits ln 2 and is only good for the sign.

## Out of scope

- Changes to the tissue loading view itself (badge, arrows, thresholds).
- ICD checks in the planner (#3716).

## Affected files (estimate)

- new: `lib/core/deco/counterdiffusion_ranges.dart` + test
- `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`,
  `dive_profile_chart_host.dart`, `chart_options_dialog*.dart`,
  `active_legend_entries.dart`, `profile_legend_config.dart`
- `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`
- settings: `default_visible_metrics_page.dart`, `settings_providers.dart`,
  `diver_tables.dart` + migration, `diver_settings_repository.dart`,
  `diver_settings_fields.dart`
- safety: `safety_finding.dart`, `safety_review_service.dart`, rule toggle
- `lib/l10n/arb/app_*.arb`
