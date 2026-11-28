# Data Sources: one entry per source

## Intent

On a dive with two or more data sources, the Data Sources section on the dive
detail page names every source twice: once as a column of the comparison table
and again as a card beneath it. After #3247 and #3281 moved every number and
every provenance detail into the table, the cards carry only the source's
name, its Primary and Viewing chips, its menu (Set primary, Split, Remove) and
tap-to-view. Each source should appear once.

## Approaches

| Approach | Trade-off |
| --- | --- |
| **A. Column headers carry the card's job (chosen)** | Keeps the side-by-side comparison; the header gets busier and has to fit a menu button at phone width. |
| B. Cards only, each with its own numbers | Simplest, but loses side-by-side comparison, which is what #3247 set out to fix. |
| C. One row per source, details behind an expand arrow | Scales to many sources vertically, but only two or three numbers fit across a phone; the rest hide. |

Picked A (decided in conversation): the table is already one column per
source, so the header is the natural home for what the card still does.

## Design

Multi-source dives (2 or more sources):

- The source cards and the divider above them are removed. The comparison
  table is the whole section body.
- Each source's header cell holds:
  - the source name, bold when primary (as today), up to two lines with an
    ellipsis;
  - the model as a subtitle when the computer was renamed away from it (the
    card's existing rule);
  - the Primary chip on the primary source and the Viewing chip on the viewed
    one, wrapping beneath the name;
  - the per-source menu with the same entries, the same enablement rules and
    the same unavailable-operation caption as the card's menu. The menu
    button shows only when it would have an entry (#2974).
- Tapping a source's column (header or any value cell) views that source,
  calling the same `onTapSource` the card called.
- The viewed source's column is tinted top to bottom with
  `surfaceContainerHighest`, gated on the dive still having 2 or more
  sources, as the card tint was.
- Two sources still flex to the card width; three or more still scroll
  sideways with each column capped at
  `DataSourcesSection.maxScrollingCellWidth`.

Single-source and manual-entry dives are unchanged.

## Builder's calls

- `DataSourcesSection.cardKey(sourceId)` moves to the header cell so existing
  finders keep pointing at "the entry for this source".
- The header cell is exposed to screen readers as a button, marked selected
  when its source is the one being viewed.
- The menu button in the header uses the compact density the section header
  menu uses, so a two-source table still fits a phone.

## Non-goals

- No change to which rows the table shows, how values are formatted, or what
  the menu actions do.
- No change to the section header menu (Compare in 3D, Separate).
