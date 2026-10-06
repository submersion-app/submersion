# Merge non-overlapping dives as another computer

Issue: #552

## Problem

A diver who logs one dive on two computers gets two records. When the
computers' clocks agree, the records overlap in time and the Combine action
folds them into one dive with two computers (multi-computer consolidation).
When one clock is wrong (timezone, daylight saving, never set), the records
can be far enough apart that they do not overlap. Combine then classifies the
selection as sequential and can only join the records end to end, which is
the wrong result: the diver wants one dive with a second computer.

Two things block this today:

1. There is no way to tell Combine "these records are the same dive". The
   overlap test decides, and a non-overlapping selection only ever gets the
   sequential join. `DiveConsolidationBuilder.classify` rejects it as
   `notOverlapping`.
2. `DiveConsolidationBuilder.build` offsets each secondary by
   `secondary.entryTime - primary.entryTime`. For a clock-skewed pair that
   offset is the skew itself, so folding with it would put the secondary's
   samples minutes or hours away from the primary's timeline.

A related dead end: a selection where some dives overlap and one does not
(three computers, one with a skewed clock) is classified as overlapping,
reaches the consolidation panel, and stops on the `notOverlapping` error.

## Goals

- Let the user choose, for a non-overlapping selection, between joining the
  records into one continuous dive (today's behaviour) and merging them as
  additional computers on one dive.
- Align a merged secondary onto the primary's timeline by its depth profile,
  not by its (wrong) clock, with a fallback and a user override.
- Show the alignment in a preview before anything is written.
- Use the profile match to suggest Merge when two different computers'
  records look like the same dive.
- Cover selections of any size, including the mixed case above, and the data
  quality inbox's Consolidate repair.

## Non-goals

- A manual offset control (nudging the secondary by seconds or minutes).
- Extending the data quality duplicate detector to flag clock-skewed records.
- Correcting the secondary computer's clock for future imports.
- Any change for selections that already overlap entirely.

## Approach

The alignment rule is a builder concern. `DiveConsolidationService` already
shifts every child row (profile samples, events, tank pressure series) by
`plan.offsetsSeconds[id]` and records the shift in the copied source row's
`timeOffsetSeconds` so a re-parse can reapply it. So the builder gains an
optional alignment mode, the service passes it through, and the preview and
the persisted result keep coming from the same `build()` call.

Rejected alternatives:

- Passing explicit offsets from the UI into the builder and service. The
  persisted offset would be whatever the widget sent, and the inbox caller
  would need its own copy of the logic.
- Shifting the secondary's entry time first, then consolidating unchanged.
  Two writes and two undos, and it overwrites the computer's raw entry time on
  the source row.

## Dialog behaviour

- A non-overlapping selection from the multi-select Combine action opens
  with a segmented choice at the top: **Join into one dive** or **Merge as
  another computer**.
  - Join shows today's sequential preview, unchanged.
  - Merge shows the consolidation panel (primary picker and chart, as today)
    plus a **Best fit** / **Align starts** toggle above the chart. The chart
    redraws when the toggle or the primary changes.
- Default: Join, unless every selected dive is from a different computer and
  every non-overlapping secondary's best fit is a strong match against the
  primary. Then Merge is preselected and a hint reads "These profiles look
  like the same dive recorded by two computers."
- Merge unavailable: when two selected dives share a computer serial the
  segmented choice is not shown and the dialog is today's Join preview. A
  non-overlapping pair from one computer is a split dive, never a second
  computer.
- Mixed selection (some dives overlap, some do not): the consolidation panel
  opens with the alignment toggle instead of the `notOverlapping` error.
  Overlapping secondaries keep the entry-time offset; the toggle governs only
  the non-overlapping ones. There is no Join choice, since
  `DiveMergeBuilder` cannot join overlapping dives.
- Data quality inbox (`consolidateOnly`): a non-overlapping selection opens
  the Merge panel with the toggle instead of the error. No Join choice.
- A Merge panel with any non-overlapping secondary also shows a note: "These
  records don't overlap in time, so one computer's clock is probably off. The
  dive keeps the primary computer's time." When best fit fell back for a
  record with no profile, it adds: "A record has no depth profile to match,
  so its start is lined up with the primary's."
- Fully overlapping selections behave exactly as today, with no toggle.

## Best-fit alignment

New pure file `lib/features/dive_log/domain/services/profile_alignment.dart`:

- `enum ConsolidationAlignment { bestFit, starts }`
- `ProfileAlignmentResult`: `offsetSeconds`, `rmsDepthError` (nullable),
  `overlapFraction`, `usedFallback`, and `isStrongMatch`.
- `ProfileAligner.align(primaryProfile, secondaryProfile)`.

Profile timestamps are seconds from each record's own start, so aligning the
starts is offset 0 and best fit is a small shift around 0. The wall-clock skew
never enters the calculation.

Algorithm:

1. If either profile has fewer than 3 samples below the surface, return
   offset 0 with `usedFallback: true` and no score. A fallback is never a
   strong match.
2. Search shifts within plus or minus W, where W is the smaller of half the
   shorter trace's extent and 15 minutes. That covers a computer switched on
   late or a surface segment logged before the descent, without letting one
   record's descent slide onto the other's ascent.
3. Score a shift as the root mean square of the depth difference over the
   part where the two traces overlap, compared on a 5 second grid with linear
   interpolation (computers sample at different rates).
4. Search in 10 second steps, then refine in 1 second steps within 10 seconds
   of the best coarse shift. Ties go to the smallest absolute offset, which
   keeps a flat, square profile at start alignment.
5. `isStrongMatch`: not a fallback, the overlap covers at least 80% of the
   shorter trace, and the RMS depth error is at most the larger of 1.0 m and
   5% of the primary's maximum depth. The percentage allows for one computer
   set to fresh water and the other to salt, which differ by about 3% at every
   depth.

## Builder changes

`lib/features/dive_log/domain/services/dive_consolidation_builder.dart`:

- `classify` and `build` take an optional `ConsolidationAlignment? alignment`.
  - `null`: behaviour is unchanged, including the `notOverlapping` rejection.
  - A mode: `notOverlapping` is no longer returned. Every other rejection
    (too few dives, mixed divers, same computer) still applies.
- `ConsolidationReady` gains `realignedIds`: the secondaries that do not
  overlap the chosen primary. The dialog shows the alignment toggle only when
  it is non-empty.
- `build` offsets:
  - overlapping secondaries: entry-time difference, as today;
  - realigned secondaries: 0 for `starts`, `ProfileAligner.align` for
    `bestFit`.
- `DiveConsolidationPlan` gains `alignments`, a map from each realigned
  secondary's id to its `ProfileAlignmentResult` (empty when none). For
  `starts` the results carry offset 0 and the best-fit score is still
  computed, so the hint does not flicker when the user switches the toggle.
- Overlap is judged against the chosen primary, so switching the primary
  recomputes which secondaries are realigned.

## Service and shared runner

- `DiveConsolidationService.apply` gains `ConsolidationAlignment? alignment`
  and passes it to `build`. Shifting, `timeOffsetSeconds`, the same-computer
  FK guard and undo are unchanged.
- Each copied source row keeps the computer's own recorded entry time, so the
  data sources view still shows what each clock said. The consolidated dive
  keeps the primary's entry time.
- `runDiveConsolidation` forwards the alignment, so the dialog and the inbox
  repair share it.
- If a sync changes the selection between the preview and the confirm,
  `apply` re-runs `build` on freshly loaded dives and rejects with the same
  `ArgumentError` mapping as today. Nothing is written.

## UI structure and strings

- `combine_dives_dialog.dart` adds `_mode` (join or merge) and `_alignment`
  (default `bestFit`) next to `_selectedPrimaryId`. On load, for a
  non-overlapping selection it also runs `classify(..., alignment: bestFit)`;
  `ConsolidationReady` means Merge is available, and one `build` decides the
  default mode.
- The segmented choice, the alignment toggle, the hint and the notes live in
  a new widget file, `consolidation_alignment_controls.dart`, so the dialog
  (already about 700 lines) does not grow further.
- Confirm passes `_alignment`, or null for a fully overlapping selection.

New keys in `app_en.arb`, translated into every locale like the existing
combine and consolidate keys:

| Key | English |
| --- | --- |
| `diveLog_combine_modeJoin` | Join into one dive |
| `diveLog_combine_modeMerge` | Merge as another computer |
| `diveLog_consolidate_alignmentLabel` | Line up the records by |
| `diveLog_consolidate_alignBestFit` | Best fit |
| `diveLog_consolidate_alignStarts` | Align starts |
| `diveLog_consolidate_sameDiveHint` | These profiles look like the same dive recorded by two computers. |
| `diveLog_consolidate_clockNote` | These records don't overlap in time, so one computer's clock is probably off. The dive keeps the primary computer's time. |
| `diveLog_consolidate_noProfileFallback` | A record has no depth profile to match, so its start is lined up with the primary's. |

`diveLog_consolidate_error_notOverlapping` stays: the strict path can still
produce it.

## Testing

Written first, per the repo's TDD rule.

- `test/features/dive_log/domain/services/profile_alignment_test.dart`: finds
  a known shift; a computer switched on late; fallback for an empty or
  surface-only profile; a flat profile ties to offset 0; the search stays
  inside the window; a strong match under a 3% depth scale; no strong match
  for two different dives.
- `dive_consolidation_builder_test.dart`: null alignment is unchanged (still
  `notOverlapping`); `bestFit` and `starts` offsets for a clock-skewed pair;
  the mixed selection keeps entry-time offsets for overlapping secondaries;
  `sameComputer` still rejected under a mode; `realignedIds` follows the
  chosen primary.
- `dive_consolidation_test.dart` (service, real database): a skewed pair
  applied with `bestFit` lands samples and events on the primary's timeline
  and records `timeOffsetSeconds`; undo restores both dives.
- Combine dialog widget tests: the choice shows for different computers and
  hides for one serial; Merge is preselected with the hint on a strong match;
  the toggle redraws the preview; the mixed selection shows the toggle, not
  the error; `consolidateOnly` opens the Merge panel; confirm passes the
  alignment to `apply`.

## Screenshots for the PR

The Combine dialog on a non-overlapping pair from two computers: before
(today's Join-only preview) and after (Join selected; Merge selected with the
toggle, hint and note), at phone and desktop widths.
