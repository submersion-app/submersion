# Cylinders card: a tank figure for each cylinder

Mockup: [assets/2026-10-28-cylinders-tank-figure-mockup.html](assets/2026-10-28-cylinders-tank-figure-mockup.html).
Builds on the table design in
[2026-10-25-cylinders-card-table-design.md](2026-10-25-cylinders-card-table-design.md)
(issue #3675).

## Why

The Cylinders card on the dive detail page shows each tank's start, end and
used pressure as three numbers in columns. The diver wants a quick visual
reference of roughly how much of each tank's gas was used and how much was
left at the end of the dive. Numbers make the diver do the arithmetic; a tank
drawn part full answers the question at a glance.

## Goals

- Each cylinder is drawn as an upright tank, filled to show what was left at
  the end and, in a lighter tint, what was used.
- The start, end and used pressures sit on and beside the figure, at their
  levels, so the figure and the numbers are read together.
- A tank that was not filled to its rated pressure looks like it was never
  quite full.

## Non-goals

- No new data. Every number already exists on the card; only how it is shown
  changes.
- The detail lines under each tank (gas volume used, SAC/RMV, MOD/MND, trip
  cylinder, transmitter, the role-from-transmitter-name warning, check-in)
  keep their content and their quiet style.
- No pressure-over-time drawing inside the figure; it shows start and end
  only.

## Anti-goals

- Labels that overlap or become unreadable on a barely used tank.
- A figure that implies a full tank when the tank was short filled.
- A figure that claims a used amount when the data is missing or wrong.

## Design

### Layout of one cylinder

The Start / End / Used columns and the table header above them go away. Each
cylinder becomes a block:

- **Left:** the tank figure, with its pressure labels to its right.
- **Right of that:** the tank's title (name, else preset name, else formatted
  volume, else "Tank N", as today), the gas pill beside or under the title,
  and the muted subtitle (size when the name took the title, and the role,
  joined by " · "; the role stays hidden on a dive whose only tank is back
  gas, as today).
- **Under the title,** in the same right-hand column: the existing detail
  lines, unchanged in content and style, with the gear check-in button at the
  end of the detail block as today.

Blocks are separated by the same thin dividers as the current rows. The "MOD
at ppO2 x.x" note and the Reassign pressure series action stay below the
blocks, unchanged.

### The figure

- **Shape:** an upright cylinder with rounded shoulders and base and a small
  valve on top, drawn in an outline colour from the theme.
- **Full height = the tank's rated working pressure** (the diver's decision).
  The rated pressure is the tank's own working pressure, else its preset's.
  When the tank has neither, full height is the start pressure, so the tank
  looks full at the start. With no rated pressure and no start pressure there
  is nothing to measure against, and the figure is an empty outline (see the
  table below).
- **Three zones, bottom to top:**
  - from the base up to the end pressure: solid, in the gas's colour
    (`GasColors.forGasMix`, the colour the gas pill and the profile chart
    use);
  - from the end pressure up to the start pressure: the used gas, a lighter
    tint of the same colour;
  - from the start pressure up to the rated pressure: empty (outline only).
    This is the short fill.
- A start pressure above the rated pressure (an overfill) draws the tank
  full to the top; the labels still show the real numbers.

### The labels

- **Start**, at the level of the start pressure, with a short tick from the
  figure.
- **End**, at the level of the end pressure, with a short tick.
- **Used**, emphasised (bold), between them, with a bracket spanning the used
  zone.
- Each label shows its word and its value in the active diver's pressure unit
  (bar or psi), for example "Start 200 bar", "Used 140 bar", "End 60 bar".
  The words are localized.
- **Crowding:** when the start and end levels are too close for three labels
  to fit (a barely used tank), the labels keep a minimum spacing and are
  pushed apart vertically, each joined to its level by a short leader line,
  rather than overlapping. The figure's block grows taller if the labels need
  the room.

### Missing or odd data

| Case | Figure | Labels |
| --- | --- | --- |
| Start and end known, end <= start | Three zones as above | All three |
| End equals start (carried, not breathed) | Solid up to start, no used zone | Start, End, "Used 0 bar" |
| End above start (sensor or entry error) | Empty outline (the fill would be a guess) | Start and End shown, no Used |
| Start known, end missing | Solid up to start | Start shown, End "--", no Used |
| End known, start missing, rated known | Solid up to end | Start "--", End shown, no Used |
| End known, start and rated missing | Empty outline (no reference for full) | Start "--", End shown, no Used |
| Neither known | Empty outline | Start "--", End "--", no Used |

Start and end are resolved exactly as the card does today: the stored tank
value wins, and the pressure time series fills a missing one. A label whose
value is missing ("--") has no level of its own; it sits at the top (Start)
or bottom (End) of the figure.

### Below the blocks

The MOD note and the Reassign action keep whatever form main has when this
is built (open PR #3760 rewrites the MOD note to name several limits; this
feature does not touch that text, nor the spacing above it, so any closing
rule #3760 adds lands without a conflict here).

### Size

Tanks on one card are drawn at heights scaled to their volume, so a 40 cu ft
stage looks smaller than an 80 beside it. The height has a sensible minimum
so a pony bottle still has room for its labels, and a maximum so doubles do
not dominate the card. A tank with no volume on record is drawn at the size
of a typical single tank (about an AL80 / 11 L).

### Accessibility

The figure and its labels are one semantics node that reads the three values
in order, for example "Start 200 bar, end 60 bar, used 140 bar", with a
missing value read as missing, as the cells do today. The title, gas and
detail lines keep their current semantics.

## Decided by the diver

- The figure carries the start / end / used numbers on and beside it (layout
  E in the brainstorming mockups), replacing the three number columns.
- Full height is the rated working pressure, so a short fill shows as a tank
  never quite full.

## Builder's calls (made during design, open to change)

- The gas colour for the solid zone and a lighter tint for the used zone.
- Falling back to the start pressure as "full" when the rated pressure is
  unknown.
- Spreading crowded labels with leader lines.
- Scaling figure height by volume, with a minimum and a maximum.
- The role icon (#3314), which led the old Tank cell, moves to sit before
  the title, since the figure now takes the leading spot.
- With no rated and no start pressure, the figure is an empty outline rather
  than guessing a typical rated pressure.
- Built on main; if #3760 merges first, this branch merges main and keeps
  its MOD note as is.
- The PR links a new issue opened from this design.

## Left to the builder

- Exact figure dimensions, the height range for volume scaling, tint
  strength, tick and bracket styling, and label minimum spacing.
- Drawing technique (a `CustomPainter` is the obvious fit).
- Whether the gas pill sits beside the title or on the subtitle line, as long
  as it reads clearly at phone width.
- Removing the column-label strings and header widget that no longer have a
  use, following the repo's l10n guards.
- Updating the existing Cylinders card widget tests that look for the start /
  end / used cells.
