# CNS Calculation Method Setting - Design

Role: this document is the SPECIFICATION (what and why; decisions locked in
the PR #599 review). The execution steps live in
2026-07-16-cns-calculation-method-setting-implementation-plan.md.

Status: implemented on this branch (PR #599)
Related: issue #578, analysis comment
https://github.com/submersion-app/submersion/issues/578#issuecomment-4966328653

## Summary

Make the CNS toxicity calculation method user-configurable in settings with
three options, each with a documented historical origin:

1. NOAA table, stepped (classic) - the app's current behavior
2. Linear interpolation, Shearwater-style - the default
3. Exponential fit, as Subsurface

The setting affects only the *calculated* CNS path (profile analysis and both
planners). The existing computer-vs-calculated CNS source toggle is unrelated
and stays unchanged: when a dive computer reported CNS and the user prefers
it, that value is displayed regardless of this setting.

## Background: why this exists

Investigating issue #578 (app 51.8% vs "Subsurface 43%" on fixture
`test/dives/003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml`):

| Method | Full samples | At end of dive (77:20) |
| --- | --- | --- |
| App step table (current) | 52.0% | 49.2% |
| NOAA linear interpolation | 46.0% | 43.4% |
| Subsurface exp-fit (exact replica) | 45.9% | 44.0% |
| Shearwater DC-reported | 46% | 43% |

(The fixture cross-validation test's acceptance target is the "Full samples"
column: profile analysis integrates the entire recorded sample set, including
the surface tail. Its computed pipeline values sit within about half a CNS
point of these replica figures.)

Findings:

- The 43% originally attributed to Subsurface is the Shearwater Petrel's own
  end-of-dive CNS. Subsurface displays DC-reported CNS when available and
  only computes its own as a fallback (`calculate_cns` returns early when
  `dive.maxcns != 0`).
- Subsurface's computed value, linear interpolation, and the Shearwater agree
  within about 1 point. The app's step table is the only outlier, roughly 6
  points high on this dive, because it charges the whole 1.21-1.30 bar band
  at the 1.3-bar rate for 77 minutes.
- The app's flat rule above 1.6 bar (10-minute equivalent limit) is *more*
  lenient than extrapolating NOAA's trend once ppO2 exceeds about 1.76 bar,
  while being about 3x too harsh just above 1.6.

## Historical provenance (also the basis for in-app explanations)

- **NOAA table**: NOAA Diving Manual (4th edition) publishes maximum single
  exposure times at 0.1-bar steps (300 min at ppO2 1.0, 180 min at 1.3,
  45 min at 1.6). CNS% is the consumed fraction of the allowed time. The
  table is a US government publication (public domain). It defines nothing
  between its entries or above 1.6 bar; treating each band at its upper
  bound (what the app does today) is the coarsest conservative reading.
- **Shearwater**: documents its method in "Shearwater and the CNS Oxygen
  Clock" (shearwater.com blog): linear interpolation of the time limits
  between NOAA entries, a fixed rate of 1% per 4 seconds (15%/min) above
  1.65 ata, CNS never decreases underwater, and a 90-minute elimination
  half-life at the surface. The fixture's Petrel matches a linear
  interpolation replica within rounding (43% vs 43.4%).
- **Subsurface**: commit `a0912b38bd` (Robert C. Helling, 2019-08-17,
  "Replace table interpolation by two line fit for CNS") replaced table
  lookup with a two-line least-squares fit to the log of the NOAA table,
  published two days after Helling's blog post "Calculating Oxygen CNS
  toxicity" (thetheoreticaldiver.org, 2019-08-15). Motivation per commit
  message: better fit than a 4th-order polynomial with fewer parameters,
  log-space fitting can never produce negative rates, and the steep upper
  line extrapolates naturally above the table instead of needing a cutoff.
  The fit is direction-blind (least squares), so it sits on the lenient
  side of the table at some points (315 vs 300 min at 1.0 bar, 47 vs 45 min
  at 1.6; worst case 8.1%: 259 vs 240 min at 1.1 bar) and on the harsh side
  at others (176 vs 180 at 1.3). Implementation note: measured against the
  table, the fit's per-entry deviation stays below 8.1%, and the two lines
  meet discontinuously at 1.5 bar (the rate dips ~4.5% stepping onto the
  upper line) - both properties are asserted in
  test/core/deco/cns_calculation_method_test.dart.

## The three methods, precisely

All methods share: no accumulation at or below ppO2 0.5 bar, no decrease
underwater, 90-minute half-life recovery at the surface (already implemented
in `CnsTable.cnsAfterSurfaceInterval`; all three sources agree on it).

### 1. NOAA table, stepped (classic)

Current `CnsTable.cnsPerMinute`: each 0.1-bar band charged at its upper
bound's rate; above 1.6 bar a flat 100/10 %/min. Kept unchanged as the
legacy/most-conservative-in-band option so existing users can reproduce old
numbers. Known wart, to be stated in its description: above ~1.76 bar the
flat rule is more lenient than both other methods.

### 2. Linear interpolation, Shearwater-style (default)

- 0.5 < ppO2 <= 0.6: rate of the 0.6 entry (100/720 %/min), matching the
  step table at the low end rather than interpolating toward zero.
- 0.6 < ppO2 <= 1.6: linearly interpolate the *time limits* between adjacent
  NOAA entries (as Shearwater documents), rate = 100 / limit. Example:
  1.25 bar -> 195 min -> 0.513 %/min.
- 1.6 < ppO2 <= 1.65: rate of the 1.6 entry (100/45 %/min).
- ppO2 > 1.65: flat 15 %/min (1% per 4 seconds), per the Shearwater blog.

Exact at every NOAA entry; never charges less than the table's own values.

### 3. Exponential fit, as Subsurface

rate(ppO2) with ppO2 in mbar, result in %/min:

- ppO2 <= 500: 0
- 500 < ppO2 <= 1500: `exp(-11.7853 + 0.00193873 * ppO2) * 6000`
- ppO2 > 1500: `exp(-23.6349 + 0.00980829 * ppO2) * 6000`

Constants are re-derived by us via least squares on the log of the NOAA
table (see Licensing) and cross-checked against Subsurface's published
values; a derivation script lives next to the tests so the numbers are
reproducible rather than magic.

## Licensing and naming

- No code is copied from Subsurface. Subsurface is GPL-2.0-only, Submersion
  is GPL-3.0; the two are incompatible for literal code reuse. What we use
  is the mathematical method (uncopyrightable) with constants we re-derive
  from public-domain NOAA data. Doc comments cite NOAA, the Shearwater blog
  post, Subsurface `core/divelist.cpp`, and Helling's blog as references.
- Option labels use nominative fair use: descriptive name first, origin as
  reference. No logos, no claim of endorsement or firmware equivalence.
- Settings page footnote: "Names refer to the published methods of the
  respective projects and manufacturers; no affiliation or endorsement is
  implied. Computed values may differ from actual dive computer readings."

## Settings UI

- Location: Decompression section of settings, next to gradient factors
  (global `AppSettings` via `settingsProvider`, same persistence and
  recompute path as GF changes; profile analysis already watches settings).
- Control: a "CNS calculation" ListTile opening a dialog (same pattern as
  the GF picker) with three radio options, each with a one-line subtitle:
  - "NOAA table, stepped (classic)" - "Whole 0.1-bar bands at the harsher
    edge; Submersion's original method"
  - "Linear interpolation (Shearwater-style)" - "Smooth between NOAA limits,
    as documented by Shearwater; matches most dive computers"
  - "Exponential fit (as Subsurface)" - "Smooth curve fit to the NOAA table,
    identical to Subsurface's calculated CNS"
- An "About these methods" expandable in the dialog carries a condensed
  version of the provenance section above (the historical explanation the
  user asked for), plus the trademark/accuracy footnote.
- All strings localized (l10n arb files, all languages).

## Behavior changes and migration

- Default changes from stepped to Shearwater-style interpolation: calculated
  CNS on existing dives drops (CCR dives near a band edge by up to ~6
  points; typical OC dives by a few points at most). No stored data changes;
  CNS is computed on display. Release notes should mention it and point to
  the setting for restoring old numbers via "classic".
- Planner and profile analysis use the same selected method, so plan CNS and
  logged CNS stay comparable.

## Testing

- Unit tests per method: exact values at NOAA entries, midpoints (1.25),
  band edges (1.2 vs 1.2+epsilon), the >1.6 regions including the classic
  method's 1.76-bar crossover, and 0.5/0.6 boundaries.
- Fixture cross-validation: dive 003 end-of-dive calculated CNS per method
  against the reference table above (tolerances, since the app's resolved
  ppO2 curve is not identical to the replica script's).
- Constants derivation test: refit the two log-space lines from the NOAA
  table and assert the shipped constants match within tolerance.
- Settings roundtrip and recompute-on-change test following the existing GF
  setting tests.

## Decisions (resolved in PR #599 review, Eric Griffin, 2026-07-16)

1. Default method: Shearwater-style linear interpolation. Calculated values
   drop relative to today; "classic" remains selectable for old numbers.
2. Classic method above 1.6 bar: keep the legacy flat 10-minute rule
   verbatim for reproducibility; document the leniency above ~1.76 bar in
   the option description ("keep verbatim, document the wart").
3. Shearwater-style between entries: interpolate the *limits*, matching the
   documented Shearwater behavior.
4. Planner: respects the user's selected method, keeping plan CNS and
   logged CNS comparable.
5. Setting scope: global app setting (like gradient factors), for
   consistency.

## Implementation sketch (for the later implementation plan)

1. `CnsCalculationMethod` enum + three rate functions in
   `lib/core/deco/entities/o2_exposure.dart` (or a new
   `cns_calculation_method.dart` beside it), `CnsTable.cnsPerMinute` gains a
   method parameter with the enum defaulted, keeping call sites compiling.
2. Thread the method through `O2ToxicityCalculator` (constructor parameter)
   and its construction sites in profile analysis and the two planners.
3. `AppSettings` field + persistence + `settingsProvider` setter.
4. Settings UI (dialog + about text) + l10n strings.
5. Tests as above; `dart format` and analyzer clean; validation against the
   fixture.

References:
- NOAA Diving Manual oxygen exposure limits (4th ed.)
- https://shearwater.com/blogs/community/shearwater-and-the-cns-oxygen-clock
- https://thetheoreticaldiver.org/wordpress/index.php/2019/08/15/calculating-oxygen-cns-toxicity/
- https://github.com/subsurface/subsurface/commit/a0912b38bd
- https://github.com/submersion-app/submersion/issues/578
