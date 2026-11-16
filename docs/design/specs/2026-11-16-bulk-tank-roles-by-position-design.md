# Bulk edit: tank roles by position

Issue: #4412

## Intent

A diver with a two-cylinder sidemount rig and hundreds of logged dives needs
tank 1 set to Sidemount left and tank 2 to Sidemount right on every dive. Bulk
Edit Selected, Tanks, Update writes one template to every tank of every
selected dive, so ticking Role gives both cylinders the same role. Today the
only way is to open each dive.

## Goals

- Set a different role per tank position across all selected dives in one
  save, from the existing Tanks Update editor.
- Keep everything Update already guarantees: rows edited in place, so start
  and end pressure, pressure series, gas switches and transmitter links
  survive, and one Undo restores the prior rows.
- Never guess: a dive whose tanks do not line up with the positions gets no
  roles, and the confirm dialog says how many such dives there are.

## Non-goals

- Per-position values for any field other than role (volume, gas, material
  and so on still go to every tank).
- Reordering tanks, or per-position roles in the Add and Replace modes.
- Listing the skipped dives by name (a count only).

## Anti-goals

- A dive with a different tank count or ambiguous order quietly getting the
  wrong roles.

## Approaches

1. **Inside Update, on the Role field (chosen).** Ticking Role offers "Same
   role on every tank" (today's behaviour) or "Role by tank position", an
   ordered list of roles. Other ticked fields still apply to every tank. It
   sits where a diver already sets roles, one save can set roles and fix specs
   together, and it reuses the existing write and undo path.
2. **A fourth Tanks mode, "Roles".** Simpler skip message, but another mode
   to find, and roles plus a spec fix take two saves.
3. **A separate "Set roles by position" action in the selection menu.**
   Dropped: it would sit outside the bulk form and need its own confirm and
   undo.

## Decided by Eric

- Matching rule: exact match only. A dive gets roles only when its tank count
  equals the number of positions. Other dives keep their roles; the confirm
  dialog reports how many were skipped.
- Placement: approach 1.

## Design

- `TankSpecsOp` gains an optional ordered `slotRoles` list. When Role is in
  the field mask and `slotRoles` is set, each dive's tanks are sorted by
  `tankOrder` and tank *i* gets `slotRoles[i]`. The single template role is
  ignored in that case.
- A dive whose tank count differs from `slotRoles.length` gets no role write.
  The other ticked fields still apply to it, as they do today.
- Writing a role clears `role_source`, as every diver-set role does.
- Undo needs nothing new: the existing `priorTankSpecRows` snapshot restores
  every row by id.
- Confirm dialog: alongside the existing "N dives have no tanks" line, a new
  line "Roles not set on N dives that don't have exactly K tanks", counting
  dives that have tanks but do not match.

## Builder's calls (open to correction)

- Two tanks on one dive sharing a `tankOrder` make the positions ambiguous;
  that dive counts as a mismatch and is skipped.
- "Role by tank position" starts with two positions, Sidemount left and
  Sidemount right, since that is the case that motivated it. The diver can
  change them, add positions, or remove down to one.
- Each position row reuses the role dropdown and its labels from the tank
  editor.
- New strings go into every ARB locale.
