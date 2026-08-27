# Decompression Obligation Statistic: Root Cause and Design

**Issue:** [#623](https://github.com/submersion-app/submersion/issues/623) ("Statistics bug")
**Reported:** 2026-07-18, via r/submersion, by kirdam74
**Date:** 2026-08-18

## The report

The reporter has 167 dives and observed two problems on the Statistics tab:

1. "Average ascent and descent speeds" rendered its empty state, "No profile
   data available", despite his dives carrying dense profiles.
2. "Decompression obligation" reported 0 deco dives, 167 no-deco dives, and a
   0.0% deco rate, despite his doing many deco dives. His dive detail page for
   the same library shows a DECO badge, a 9.3 m ceiling, TTS 23 min, GF 85/85,
   and a stop schedule of 1 min @ 9 m, 5 min @ 6 m, 12 min @ 3 m.

A third card on the same page, "Time by depth range", rendered real data. That
contrast is the key diagnostic: all three cards read the same
`dive_profiles` table, so whatever broke the other two is in their predicates,
not in the presence of profile data.

## Symptom 1: already fixed and released

`getAscentDescentRates` averaged `dive_profiles.ascent_rate` under
`WHERE p.ascent_rate IS NOT NULL`. No write path populates that column:
libdivecomputer reports no ascent-rate sample type, `parsed_dive_mapper`
builds every sample without it, no file importer sets it, and all three DB
write sites pass a value that is always null. The card was therefore
unconditionally empty for every user on every build up to and including
v1.7.2.

Commit `4a881e397dc` (2026-08-09) rewrote the query to derive rates from
stored depth samples, and also corrected a latent sign inversion that would
have displayed ascent and descent swapped. It ships in `v1.7.3.6027` and
`v1.7.4.6062`. The report predates both.

**No further work is required for symptom 1.**

## Symptom 2: the live bug

`StatisticsRepository.getDecoObligationStats` classifies a deco dive as any
dive having a profile sample with `p.ceiling > 0`. That is wrong in two
opposite directions.

### It under-counts

`dive_profiles.ceiling` is only ever written from computer-reported sample
data. Both mappers gate it identically:

- `parsed_dive_mapper.dart:70`:
  `ceiling: s.decoType != null && s.decoType != 0 ? s.decoDepth : null`
- `parsed_dive_profile_mapper.dart:88`:
  `if (s.decoDepth != null && s.decoType != null && s.decoType != 0)`

Several import sources never populate it at all, among them the MacDive XML
and SQLite parsers, the Shearwater Cloud parser, the generic UDDF import
parser, the CSV parser, and the OCR importer. Any dive from those sources is
silently counted as no-deco.

Meanwhile the rest of the app answers the same question from a different
layer. `profile_analysis_provider.dart:472-488` treats the app's computed
analysis as the base and overlays computer-reported columns only when present:
`profile[i].ceiling ?? analysis.ceilingCurve[i]`. The ceiling, stops, and DECO
badge on the dive detail page come from the app's own Buhlmann engine
(`profile_analysis_service.dart:668-684`) at the dive's stored gradient
factors, or the diver's GF settings when the dive has none. Nothing writes
that computed curve back to `dive_profiles.ceiling`.

So the statistic and the dive detail page disagree by construction, and the
statistic asserts a confident `0` where the honest answer is "not recorded".

### It over-counts

Per `libdc_wrapper.h:157`, `deco_type` is `0=NDL, 1=safetystop, 2=decostop,
3=deepstop`, and the mappers write `ceiling = decoDepth` for any non-zero
type. A routine 5 m safety stop therefore stores `ceiling = 5`, and
`ceiling > 0` counts that dive as a decompression obligation. A purely
recreational diver on a computer that reports safety stops could see a deco
rate approaching 100%.

### The codebase already knows better

`DiveRepositoryImpl.getNoFlyDiveInputs` (`dive_repository_impl.dart:4218`)
uses `p.deco_type = 2 OR p.ceiling > 0`, and `safety_review_service.dart:180`
uses the computed `analysis.ndlCurve[i] < 0` as its in-deco test. A third
signal, `decoStopStart` rows in `dive_profile_events`, is populated by the
Subsurface XML parser, the UDDF importer, and the dive computer download path,
and is ignored by all of the above.

## Design

Classify each dive from the best available evidence, in priority order, and
never assert "no deco" from an absence of data.

### Resolution order

1. **Recorded, authoritative.** Any sample with `deco_type = 2`, or any
   `decoStopStart` profile event, means deco. Any dive whose profile carries
   `deco_type` values that are all `0` means no deco. This deliberately stops
   treating `deco_type` 1 and 3 as obligations.
2. **Recorded, ceiling only.** For sources that write `ceiling` without
   `deco_type` (Subsurface XML, DAN DL7, FIT), `ceiling > 0` means deco. Only
   consulted when the dive carries no `deco_type` at all, so it can no longer
   promote a safety stop.
3. **Computed.** For a dive with a profile but no recorded deco signal, run the
   same analysis the dive detail page runs and test `ndlCurve.any((n) => n < 0)`.
   This is what makes the statistic agree with the DECO badge the diver can
   see on the dive.
4. **Unknown.** A dive with no profile at all cannot be classified. It is
   reported separately and excluded from the rate denominator, rather than
   counted as no-deco.

### Caching

Step 3 is the expensive one. The Buhlmann arithmetic is cheap (a 167 dive
library is roughly 2M float operations), but hydrating the profiles is not:
the existing ascent-rate query takes about 590 ms at 1.62M profile rows.

Computed classifications are re-derivable from data every device already
holds, so per `docs` precedent they belong in `local_cache_database.dart`, not
the synced main DB. That avoids a `currentSchemaVersion` bump, HLC timestamps,
tombstones, merge rules, and backup inclusion, and a restored database simply
recomputes instead of carrying another device's stale answer.

The cache is keyed by dive and invalidated by an inputs fingerprint covering
the values that can change the answer: the engine version, the gradient
factors actually used, and the dive's profile revision.

### Reuse, not reimplementation

The computed step reads `profileAnalysisProvider`, the same provider the dive
detail page uses. That is a deliberate choice over reimplementing the deco
determination in SQL or in a parallel service: it guarantees the card and the
dive page can never drift apart, which is the entire substance of this bug. It
costs a per-dive provider read, so the batch pass invalidates each dive's
analysis after classifying it to bound memory.

## Out of scope

Two adjacent defects were found during the investigation and are **not**
addressed here. Both are filed separately so this change stays reviewable:

- **#1148**: `getTimeAtDepthRanges` counts sample rows and divides by 60,
  assuming 1 Hz sampling. At the reporter's roughly 4-5 s sample interval the
  card overstates time at depth by that factor. It also omits the `is_primary`
  filter, so a dive logged by two computers is double-counted.
- **#1149**: `setPrimaryDataSource` (`dive_repository_impl.dart:5877-5891`)
  demotes every `dive_profiles` row for a dive, then re-promotes only rows
  matching `newPrimary.computerId`, and only when that id is non-null.
  File-imported dives have a null `computerId` on both the data source row
  (`uddf_entity_importer.dart` sets `computerModel` and `computerSerial` but
  never `computerId`) and the profile rows, and the "Set Primary" menu item in
  `data_sources_section.dart` carries no `computerId` guard. So the dive is
  left with no primary profile at all. That silently empties the
  ascent/descent card, among others. Confirmed reachable, not latent.
