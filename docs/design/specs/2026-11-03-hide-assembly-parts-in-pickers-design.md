# Hide assembly components from the gear pickers

Issue: #2514.

## Problem

A diver who builds regulators from components (issue #1487, assemblies in
[2026-09-09-equipment-assemblies-design.md](2026-09-09-equipment-assemblies-design.md))
sees every first stage, second stage and hose as its own row in Add
Equipment. The assemblies spec kept them there on purpose, so a part could
still be added on its own, but with several regulator sets the parts bury the
gear a diver actually picks. Picking the assembly already brings its parts
along through `GearExpander`.

The Spare status (#1803) is not a fit. Spare means a loose part on the shelf,
and it also hides a regulator from each tank's regulator dropdown, where a
first stage that belongs to a set is needed.

## Decisions

| Question | Decision |
| --- | --- |
| Per-item toggle (as the issue asks) or derived | Derived from the components index. A per-item toggle would need dozens of edits for the diver who filed it, plus a column, a migration, sync and export work. |
| What is hidden | An item one of whose assemblies is offered by the same list, after the caller's own limits (type filter, Spare) and before the diver's filter. |
| Getting a part anyway | A "Show components of assemblies" switch, reset each time the sheet opens, as the left-kit switch (#3210) is. |
| Assembly already on the dive | Its parts are offered: a part dropped from one dive is re-added this way, and the expander re-parents it. |
| Assembly Spare, retired, sold or lost | Its parts are offered, as the only way to add them. |
| Which pickers | Dive edit, bulk dive edit, the dive planner and the weight rig composer opt in with `hideAssemblyParts`. The cylinder pickers (own cylinder, transmitter) do not, since a twinset's single tanks are picked there. Lending, the mission DPV picker and trips do not: trips do not expand assemblies, so packing a regulator would bring its parts straight back. |
| Equipment set editor | Same rule and switch, except a ticked part always stays listed so it can be unticked. |

## Design

`ComponentsIndex.partsWithin(offered)` returns the ids in `offered` with a
parent also in `offered`, ignoring a self-loop. It is the whole rule; both
surfaces call it.

`EquipmentPickerSheet` watches `equipmentComponentsIndexProvider` only when
`hideAssemblyParts` is set. Until the index loads, or if it fails, nothing is
hidden. The hidden ids are applied with the caller's constraints, so the
filter sheet offers no chip that only matches hidden parts. The switch shows
only when it would bring back a row the diver's filter keeps, or to switch it
off. When the list is empty because the rest of the category is components,
the empty state says "Remaining gear is part of an assembly" and points at
the switch rather than claiming nothing is left.

`EquipmentSetEditPage` hides the same parts unless ticked, with the switch as
local widget state above the list.

No schema, sync or export change.
