# Cylinders card as a table

Issue: #3675. Mockup: [assets/2026-10-25-cylinders-card-table-mockup.html](assets/2026-10-25-cylinders-card-table-mockup.html).

## Why

The Cylinders card on the dive detail page is hard to read on every dive.
Each fact about a cylinder arrived with its own issue and its own style: the
gas in brackets after the name, size and role as outlined chips, the gas used
in brackets with a slash mixing bar and litres, SAC/RMV in bold primary
colour, MOD/MND in small tertiary text with colons and a pipe, and the trip
cylinder and transmitter in a fourth style. Nothing lines up between tanks.

After a dive the diver looks for three things first: what kind of tank it
was, what gas it held, and how much pressure was used.

## Goals

- Those three facts lead, in columns that line up from tank to tank.
- Every secondary fact is written in one quiet style.
- Each tank is named once (no footnote that repeats the tank names).

## Non-goals

- No fact is added or removed; only layout and formatting change.
- MOD keeps using the working ppO2 setting for every tank.

## Design

A table, one row per cylinder, columns **Tank, Gas, Start, End, Used**.

- **Header:** each pressure column shows its label with the pressure unit
  under it, so the cells hold bare numbers.
- **Tank:** the role icon, then the tank's name if the diver gave one, else
  its preset name (AL80), else its formatted volume, else "Tank N". Under
  it, in muted text: the size when the name took the first line, and the
  role, joined by " · ". The role stays hidden on a dive whose only tank is
  back gas (as today, #2901).
- **Gas:** a pill filled with the profile chart's gas colour
  (`GasColors.forGasMix`). Its label is black or white, whichever reads
  better on the fill.
- **Start / End / Used:** right-aligned numbers; Used is emphasised. A
  missing value shows "--".
- **Detail under each row:** one muted style throughout, "label value" pairs
  joined by " · ":
  - Gas used (volume), SAC, RMV, MOD, MND, led by the source badge when the
    dive has two or more sources.
  - The trip cylinder line, when the tank is linked.
  - The transmitter serial with its Assign action when unregistered.
  - The "role read from the transmitter's name" warning keeps its error
    colour, since it is a warning.
  - The gear check-in button sits at the end of the detail block.
- **Below the table:** "MOD at ppO2 1.4" once, since every tank's MOD uses
  the same working ppO2. The Reassign pressure series action stays below.

## Builder's calls

- Columns are proportional (flex) so they line up across rows at any width;
  numbers scale down rather than overflow.
- The role icon stays (from #3314), now at the start of the Tank cell.
- Wrapping the transmitter line also removes the 20 px overflow the old row
  hit at phone width when a check-in button was present.
