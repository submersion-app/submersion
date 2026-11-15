# Observations on the Insights Overview

Date: 2026-11-14
Status: approved
Release: v1.8.5

## Intent

On a phone the Insights landing opens with the observations strip (a heading,
"See all", an info button and up to three observation cards) above the category
list. It takes up most of the first screen, so the categories start below the
fold. Meanwhile the Overview category never shows observations: on desktop they
appear only in the Insights home summary pane, and the Overview tab, which is
the same page, hides them behind a `showObservations` flag.

Observations should be reachable from the Overview page on both desktop and
phone, which lets the phone landing drop the strip and lead with its categories.

## Goals

- The Overview page always leads with the observations strip, wherever it is
  shown: the desktop Insights home pane, the desktop Overview tab, the phone
  Overview page and an Overview nav shortcut.
- The phone Insights landing shows no observations strip; its list starts with
  Overview.

## Non-goals

- No change to the desktop Insights home: it looks as it does today.
- No change to the category list contents, the Add shortcut picker, or the
  Observations page itself.

## Anti-goals

- Observations becoming harder to reach on a phone. They stay one tap away
  (Overview) and "See all" still opens the full Observations page.

## Approaches

1. **Observations in the Overview (chosen).** Remove the `showObservations`
   flag so `InsightsOverviewPage` always shows the strip, and remove the strip
   from `InsightsMobileContent`. The smallest change, and it fixes the Overview
   tab gap on desktop at the same time.
2. **Phone-only Observations row.** Drop the strip on phone and add an
   Observations row to the phone category list only. Not needed once the
   Overview carries observations, and it adds a phone-only list entry.
3. **Compact strip.** Keep a one-line "N observations" link at the top of the
   phone landing. Still costs space and is not a navigation entry.

## Design

- `InsightsOverviewPage`: drop the `showObservations` field. `_OverviewBody`
  always puts `ObservationsStrip(padding: EdgeInsets.only(bottom: 16))` above
  the aggregate grid. The strip already takes no space while loading or when
  there is nothing to say, and the empty-logbook state shows no strip.
- `InsightsPage` desktop summary pane: `InsightsOverviewPage(embedded: true)`.
- `InsightsMobileContent`: remove `ObservationsStrip` from the list.

## Tests

- The phone landing renders no `ObservationsStrip`.
- `InsightsOverviewPage(embedded: true)` renders the strip with no flag set.
- Update the existing placement and landing tests to the new placement.
