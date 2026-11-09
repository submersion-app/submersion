# Estimated profile for dives without samples

Issue: #4112

## Problem

A dive entered by hand, or imported from a logbook that kept only depth and
time, has no profile. The dive list card shows no sparkline, the table view's
profile strip says "No profile data for this dive", and the detail page hides
its Dive Profile card. The request is a generic profile drawn from the depth,
the time and a safety stop where one is due.

## Decisions

- **Drawn, never stored.** The outline is computed at render time from the
  dive's max depth, runtime and bottom time. It is not written to the
  database, not synced, not exported, and nothing that reads profile samples
  (profile analysis, deco and tissue loading, SAC, ascent-rate warnings,
  safety review, statistics, insights) ever sees it. A stored made-up profile
  could not be told apart from recorded data later, and every derived figure
  would quietly inherit the guess.
- **Its own type.** `EstimatedProfile` is not a list of `DiveProfilePoint`,
  so it cannot be handed to code that expects recorded samples.
- **Marked as an estimate.** A dashed, muted line with the caption
  "Estimated from max depth and time, not a recorded profile". No cursor,
  tooltip, markers, overlays, toolbar, sources bar or range statistics.
- **Where it shows** (the user chose all three):
  - the table view's profile strip, under the usual header bar;
  - the detail page, as a plain Dive Profile card in place of no card;
  - the dive list card, as a faded dashed sparkline.
- **Automatic** for every dive without samples that has a max depth and a
  runtime or bottom time. No setting.

## Shape

Builder's calls, from common recreational practice:

- Descent at 18 m/min, ascent at 9 m/min.
- A 3 minute stop at 5 m on a dive deeper than 10 m.
- Bottom time, when known, is where the ascent starts (it runs from leaving
  the surface to the start of the final ascent); runtime is where the dive
  surfaces. One of them is enough.
- With both, a long ascent window slows the first ascent leg; a short one
  shrinks every ascent leg in proportion. A bottom time at or past the
  runtime is ignored.
- A runtime too short for the rates shrinks the descent and ascent in
  proportion, leaving no time at the bottom.
- Average depth is not used; the outline stays flat at max depth.

## The list card's cache

The card draws the estimate only once the batch profile cache knows the dive
has no samples, never while they load, so a recorded dive does not flash an
estimate first. `DiveRepository.getBatchProfileSummaries` therefore maps a
dive with no series to an empty list. A dive whose series is unreadable, and
every dive when the read fails, stays absent, since it may well have samples.

An empty entry is an answer for a card's own request, so profile-less cards
do not refetch. A list page load or reload (and the dashboard's recent dives)
asks again for dives cached as empty, as it did before they were cached at
all, so a dive that later gains a profile replaces its estimate with the
real sparkline. An empty answer only fills a dive with no entry yet, so an
older empty read landing after a newer profile cannot replace it.

## Unreadable stored profiles

A full dive read turns an unreadable series into an empty profile, which
looks the same as a dive logged without samples. The table strip and the
detail page therefore draw the estimate only when
`DiveRepository.hasProfileSeries` (a row count, no blob read) confirms the
dive has no stored series at all. A dive with a damaged recording keeps its
"No profile data" state.

## Not in scope

- Turning the estimate into an editable, saved profile (an "Edit as profile"
  step through the profile editor). Considered and left out.
- Using the estimate in any calculation.
