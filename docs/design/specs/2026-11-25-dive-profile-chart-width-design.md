# A wider dive profile chart: slimmer chart chrome

Status: design approved in conversation, 2026-11-25. Release v1.8.7.

## Intent

On dive details the dive profile chart reads as narrow, most of all on a phone.
The diver wants more horizontal room for the curve, with phones first and any
desktop gain a bonus.

The profile card already spans the full width of the details pane; it never
pairs with another card. The width goes to the chrome around the plot. Per side
there is the page padding (16 px), the card margin (4 px), the card's inner
padding (12 px), a 16 px strip holding the rotated axis title ("Depth (m)" on
the left, the right-axis metric on the right), and the tick-label gutter. On a
390 px phone the plot is about 232 px wide, 59% of the screen.

## Goals

- A wider plot on phones (about 232 px to 276 px on a 390 px phone, +19%).
- The same gain carried to desktop and every other profile chart (about 44 px).
- No loss of information: each axis still says what unit it is in.

## Non-goals

- Changing the page padding or the card margins: the profile card keeps the
  same left and right edges as every other card (the pinned strip keeps
  matching them, issue #4488).
- Changing the master-detail list pane, which is already resizable.
- Changing the tick-label gutter widths or their 350 px breakpoint.

## Anti-goals

- An axis whose unit can no longer be read.
- A right-axis caption that no longer follows the right axis's metric or colour.
- A plot whose inset helpers (`plotLeftInset`, `plotRightInset`) disagree with
  where fl_chart actually draws, which would misalign the gas-switch sheet and
  the in-chart overlays.

## Approaches considered

1. **Edge to edge on phones.** Below about 600 px the profile card drops page
   padding, margin and side padding. Plot +24% on a phone; no desktop gain; the
   card no longer lines up with the cards below it.
2. **Slimmer chart chrome everywhere (chosen).** The card stays where it is;
   its side padding shrinks and the axis titles leave their side strips. Plot
   +19% on a phone, about 44 px more on desktop, and the card keeps its edges.
3. **Both.** +38% on a phone, but carries option 1's break in alignment.

The diver picked option 2.

For the axis titles, two placements were considered: unit captions above each
tick column (chosen), or the axis names moved into the legend row. The legend
already wraps to a second row on a phone with a few metrics on, so adding to it
would cost more height there.

## Design

1. **Axis titles become unit captions.** `DiveProfileChart` drops the 16 px
   rotated axis-name strips on the left and right axes. In their place a short
   caption row sits directly above the plot: the depth unit (for example `m` or
   `ft`) left-aligned over the left tick column, and the right axis's unit (for
   example `bar`, `psi`, `°C`) right-aligned over the right tick column, drawn
   in the right axis's colour, as the rotated title is today. The right caption
   follows the right axis: it changes when the metric changes (menu or hover
   auto-switch) and is absent when the right axis shows nothing. Height cost is
   one `labelSmall` line, about 12 px; no width.
2. **Applies to every profile chart.** The change lives in `DiveProfileChart`,
   so dive details, the pinned strip, fullscreen, Dive Lab and the gas-switch
   sheet all gain the width. `plotLeftInset` and `plotRightInset` drop the
   axis-name size so the gas-switch sheet and in-chart overlays stay aligned
   with the plot.
3. **The dive details profile card's side padding drops from 12 px to 6 px.**
   Top and bottom padding are unchanged. The pinned strip squashes the same
   section, so it keeps matching the card.
4. Units follow the active diver's unit settings, as the current titles do.

## Left to the builder

- How the caption row is laid out (fl_chart's top axis name, or a row above the
  chart) as long as each caption lines up with its tick column.
- The legend's left padding, which today adds the axis-name size so the legend
  lines up with the plot, follows the new inset.
- Widget tests: captions present with the right unit, the right caption
  following the right-axis metric and absent without one, the inset helpers
  matching the drawn plot, and the card's horizontal padding.
- Checks at both ends of the range: a 360 px phone and a wide desktop pane;
  a shallow dive and a deep one with 3-digit depths in feet; a right axis with
  4-digit psi values.
