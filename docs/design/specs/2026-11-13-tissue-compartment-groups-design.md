# Name what the tissue compartments represent

Date: 2026-11-13. Release: v1.8.5. Size: small change.

## Intent

The Tissue Loading card on the dive details page shows 16 numbered
compartments ("Leading: #3", "Compartment: #12"). A diver looking at it does
not know what a compartment number means. The only explanation is one
sentence in the help sheet, and it does not say where fast ends and slow
begins.

## Goals

- Wherever a single compartment is named, say which speed group it belongs to
  and give a rough example of the body tissue that group stands for.
- Give the help sheet the full explanation: the three groups, what each one
  limits, and a caveat that the tissue names are examples.
- Tie the numbers to the charts: number every bar in the bar chart, and give
  the heat map a compartment axis and a time axis.

## Non-goals

- No three-band Fast / Medium / Slow labels under the bars (option C,
  declined).
- No axes on the stacked-area view: only the heat map was asked for, and a
  scale on stacked bands would read as a sum of loads.
- No change to the deco model, the numbers shown, or the Surface Interval tool's
  own fast and slow legend.

## Anti-goals

- The labels must not read as an anatomical mapping. Bühlmann's compartments
  are mathematical; "compartment 3 is the brain" would be false precision.

## Approaches considered

- **A. Help sheet only.** Smallest change, but the number on the card stays
  unexplained unless the diver opens the help sheet.
- **B. Name the group next to the number, plus the help sheet.** Chosen. It
  answers the question where it comes up.
- **C. B plus three labelled bands under the bars.** Declined: more visual
  than explanatory, tight on a phone, and the heat map and area views would
  need matching treatment.

## Design

Groups, by compartment number (the same split as the domain reference and
the Surface Interval tool's fast group):

| Compartments | Label |
| --- | --- |
| 1-5 | Fast, blood-rich tissue |
| 6-10 | Medium, muscle and skin |
| 11-16 | Slow, fat and bone |

1. **Detail row** (`TissueCompartmentDetail`): the group label goes on its
   own line, in the secondary text colour, under "Leading: #3" or
   "Compartment: #3". The ongassing / offgassing badge stays beside the
   number, as today. One row would not fit on a phone (about 335 px of text
   and badge in about 310 px, more in German), and a wrapping row would make
   the card's height jump as the pointer moves between bars. The line is
   always present while a compartment is shown, so the height stays stable.
2. **Tooltip** (`tissueCompartmentTooltip`, shared by the bar chart, heat
   map, area chart and the deco calculator's panel): the group label goes on
   its own line under "Compartment 3".
3. **Help sheet** (`info_term_tissueCompartment_body`): rewritten to name the
   three groups, what fast and slow ones limit, and that the tissue names are
   rough examples, not anatomy.
4. **Bar numbers** (`TissuePressureBarChart`): a row of numbers 1 to 16,
   each centred under its bar, between the bars and the existing "Fast" /
   "Slow" captions. This applies wherever the bar chart appears (the dive
   details card and the deco info panel).
5. **Heat map axes** (the heat map section of `CompactTissueLoadingCard`):
   - Left: compartment numbers 1, 8 and 16 against their rows, fast at the
     top. This replaces the "Rows: fast (top) to slow (bottom)" caption.
   - Bottom: dive time at the start, middle and end of the strip (for
     example "0", "26 min", "52 min").
   - The card has no timestamps today, so it takes a new optional input for
     the time span from the dive details page. Where it is not given (the
     current dive load page), the time axis is left out and the compartment
     axis still shows.
   - The Dive Lab's bare heat map strip is unchanged.

One pure function maps a compartment number to its group, so the detail row
and the tooltip cannot disagree.

## Left to the builder

- Font size and spacing of the bar numbers and axis labels, provided they
  stay readable (11 px or more) at a 360 px phone width.
- The exact ARB keys and wording of the help sheet body, within the meaning
  above.
- How the existing translations of the rewritten help string are handled,
  following the repo's l10n conventions.
