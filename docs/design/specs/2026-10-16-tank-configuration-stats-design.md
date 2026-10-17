# Tank configuration statistics

Issue: #3421 (Statistics using tank types)

## Intent

A sidemount diver from the Sidemount-Forum asked for statistics that show
what kind of kit their dives were done in: sidemount, single backmount, twin
backmount, dives with stages, multi-gas dives. Everything must be read from
the tank data each dive already carries. No new fields, nothing extra for the
diver to fill in.

The question the statistic answers: "How much of my diving is sidemount
versus backmount, and how often do I carry stages or more than one gas?" It is
a portrait of kit habits, the way the Gas page's Gas Mix card is a portrait of
gases.

## Goals

- A new **Tank configuration** card on the Insights Gas page, directly below
  the existing Gas Mix card.
- Every dive in scope sorted into exactly one **base configuration**.
- Independently, each dive counted under every **extra** that applies to it.
- Twin sets logged as a single cylinder are spotted from the cylinder's name
  or size.

## Non-goals

- No new fields, columns, roles, or schema change.
- No trend over time.
- No drill-down: rows are not tappable (decided by the maintainer; the dive
  list filters on stored fields, and the twin rule is computed, so a
  drill-down needs new plumbing that is out of scope).
- No editing tank roles from this card.
- Not a Dive focus factor and not a dive-list filter.

## Anti-goals

- A chart that implies overlapping categories are shares of a whole. The
  extras overlap, so they are bars, never a pie or a split bar.
- Labelling ordinary single cylinders as twins. When in doubt a cylinder is a
  single.

## Classification

Input per dive: its tanks (role, volume in litres, name, preset name, O2 %,
He %, start and end pressure), its gas switches, whether it has a recorded
profile, and its dive mode.

### Why the rules distrust Back Gas

Downloads rarely say "sidemount" or "stage". `parsed_tank_resolver.dart`
tags every open-circuit gas under 41% O2 as Back Gas, and maps
libdivecomputer's sidemount usage to Back Gas too (it does not say which
side). Shearwater reports no sidemount usage at all. So two Back Gas tanks
may be doubles, a sidemount pair, or a back gas plus an untagged stage. The
rules below follow `isMatchedPair` in `multi_cylinder_consumption.dart`,
which already treats two Back Gas tanks as a pair only when they hold the
same gas.

### Which cylinders count (merged dives)

When a dive's tanks come from more than one computer, only the cylinders of
the dive's primary computer count, plus any cylinder with no computer (added
by hand). A cylinder the consolidation step could not match appears once per
computer, and counting both copies would turn a single into a twin and a
one-gas dive into multi-gas. *(My call; the maintainer was told and did not
object. The builder finds how "primary" is recorded.)*

### Base configuration (exactly one per dive)

Checked in this order; the first match wins:

1. **Rebreather**: the dive mode is CCR or SCR, or any tank has the role
   Diluent or O2 Supply. *(Including dive mode is my call: a CCR dive logged
   without role-tagged tanks is still a rebreather dive.)*
2. **Sidemount**: any tank has the role Sidemount Left or Sidemount Right.
   One sidemount tank alone still counts.
3. **Twin backmount**: two Back Gas tanks form a matched pair (same gas,
   within `sameGasTolerancePct`), or any Back Gas tank looks like a twin set
   (below). Decided by the maintainer: Back Gas tanks on different gases are
   not a twin set.
4. **Single backmount**: one or more Back Gas tanks, none of which forms a
   matched pair or looks like a twin set. Air plus an untagged EAN32 is a
   single backmount dive.

Downloaded sidemount dives usually arrive as a same-gas Back Gas pair and so
count as Twin backmount. Decided by the maintainer: this is accepted, and the
card's note tells sidemount divers to set Sidemount Left/Right roles so those
dives count as sidemount.
5. **Other**: tanks are logged but none of the above matched (for example
   only a Stage, Pony or Bailout tank).
6. **No tanks logged**: the dive has no tanks.

Rebreather before Sidemount means a sidemount rebreather counts as a
rebreather. Pony and Bailout tanks never change the base configuration.

### Looks like a twin set

A single Back Gas tank counts as a twin set when either holds:

- **Name.** Its `name` or `presetName` (a stored slug such as `d12` or
  `twin_12`, so underscores count as separators), case-insensitively, contains
  "twin", "double", "doppel" or "manifold"; or "2x", "2 x" or "2×" followed by
  a number; or a standalone "D" immediately followed by a one- or two-digit
  number (D7, D12). Both fields are checked because a diver who picked their
  own "D12" preset may have left the tank name empty.
- **Size.** Its volume is 20 L (water capacity) or more. Common single
  cylinders top out around 18 L; 2×10 L, 2×AL80 (22.2 L) and 2×12 L all clear
  20 L.

Known, accepted gap: small twin sets logged as one tank (2×7 L = 14 L,
2×8.5 L = 17 L) overlap with large singles in size and count as twins only
when their name says so.

### Extras (any number per dive)

- **Stage(s)**: any tank with the role Stage.
- **Deco gas**: any tank with the role Deco.
- **Multi-gas**: two or more distinct gas mixes among the dive's **breathed**
  cylinders, ignoring Diluent and O2 Supply tanks (otherwise every rebreather
  dive is multi-gas). Two sidemount cylinders of the same gas are not
  multi-gas. Decided by the maintainer: only breathed gases count, so a
  computer's programmed but unused backup gas does not make a dive
  multi-gas. Mixes are distinct when they differ by more than
  `sameGasTolerancePct` in O2 or He, the same tolerance the matched-pair
  rule uses.

A cylinder is **breathed** when any of these holds:

- its start pressure is above its end pressure;
- a known gas switch names it (`knownGasSwitches` in
  `tank_usage_range.dart`);
- it is the dive's starting cylinder (the rule `activeTankAt` uses: a
  switch in the first `startingSwitchGraceSeconds`, else the SAC reference
  cylinder).

When a dive has no recorded profile, no gas switches and no pressure drop on
any cylinder (a hand-logged dive that lists its gases), every logged mix
counts as breathed. *(My call on the boundary: a dive with a recorded profile
and no switches is a one-gas dive, because a computer logs the switches a
diver makes. The maintainer approved "no signal means every mix counts";
this narrows "no signal" to dives without a profile.)*

## The card

Layout A from the mockup, chosen by the maintainer: one card, two groups of
horizontal bars in the existing Gas Mix bar style.

- Title "Tank configuration", subtitle along the lines of "Dives by how the
  tanks were set up".
- **Configuration** group: one bar per base configuration, each with its count
  and percentage of dives in scope. These add up to 100%.
- **Extras** group: one bar per extra, each with its count and percentage of
  all dives in scope. These overlap and need not add up to anything.
- Groups or rows with zero dives are hidden. The whole Extras group is hidden
  when no dive has an extra.
- A short note under the bars says how the card reads tanks, covering two
  things: twin sets logged as one cylinder are spotted by name or size, and
  sidemount dives count as sidemount only when their tanks have the
  Sidemount Left/Right roles (downloads usually tag them Back Gas). *(My call
  on wording: no unit-bearing number, so it reads the same in metric and
  imperial, e.g. "Twin sets logged as one cylinder are counted when the name
  says so (twin, double, D12, 2x12) or the cylinder is larger than any common
  single tank. Set Sidemount Left and Right on a dive's tanks for it to count
  as sidemount." The maintainer saw a "20 L" version in the mockup; if a
  number is wanted it must go through the active unit settings.)*
- Rows within each group are ordered by count, largest first, matching Gas
  Mix. *(My call.)*
- With no dives in scope, the usual empty state.
- Loading and error states follow the neighbouring cards.

## Scope of dives counted

The card follows the Insights filters like the cards around it and uses the
standard statistics scope, so dives excluded from statistics are left out.
*(My call: it uses the plain statistics scope, not the gas scope that also
drops gas-excluded and gauge-mode dives. Those exclusions exist because a
dive's gas data is unreliable for SAC; the tanks the diver carried are still
known.)*

## Constraints

- Every new user-facing string is localized through the ARB files.
- `insights_repository.dart` is already over 3,000 lines; new query code goes
  in a part file beside it, as the conditions and focus queries do.
- The classifier is a pure function in the domain layer so the rules above
  can be tested directly, one test per rule and per precedence edge.

## Left to the builder

- Whether the classification runs in SQL or in Dart over a per-tank query.
  Dart is expected, given the name matching.
- How count and percentage are shown on each bar: a change to
  `HorizontalCategoryBarChart` or a variant beside it.
- Exact l10n key names and the translated strings.
