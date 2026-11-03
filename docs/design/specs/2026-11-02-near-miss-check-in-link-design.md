# Link a Near-Miss to a Gear Check-In

**Date:** 2026-11-02
**Issue:** [#3062](https://github.com/submersion-app/submersion/issues/3062)
**Release:** v1.8.4
**Status:** Design calls made by the builder at the maintainer's request (the
design questions were skipped). Every call below is the builder's, not an
agreed requirement.

## Problem

When gear fails on a dive, a diver can record it twice: as a check-in on the
item, and as a near-miss from the dive's menu. Not every check-in is a near-miss
and not every near-miss involves gear, but when a fault caused the near-miss the
two records describe one event and nothing ties them together.

A near-miss can already name an item (`incidents.equipment_id`, v202) and a dive.
What is missing is a link between the two records themselves.

## Goals

- A near-miss can point at the check-in that recorded the fault.
- A diver can reach that link from whichever record they made first.
- Logging a near-miss from a check-in does not make the diver retype what the
  check-in already says.

## Non-goals

- Merging the two records. They stay separate: the check-in is evidence about
  the gear, the near-miss is a private safety report.
- Changing the condition engine. See "Condition findings".
- Any export of near-miss content.

## Anti-goals

- A near-miss's content, or the fact that one exists, reaching a file or page
  that leaves the device. A near-miss is private by design.
- A required step. Most check-ins never become near-misses and the check-in
  flow must not grow a question for them.

## Data model

Add `incidents.observation_id`, nullable,
`TEXT REFERENCES equipment_observations(id) ON DELETE SET NULL`, at schema v338,
the rung after #4120's v337. `minimumCompatibleSchemaVersion` stays at 336: this
is an additive column and the sync overlay keeps it when an older peer omits it.

The column goes on `incidents`, not on `equipment_observations`, for three
reasons:

1. **Privacy.** Check-ins leave the app in CSV, Excel and UDDF exports. Near-miss
   reports never do. With the link on the near-miss, an exported check-in row
   cannot carry a reference to a private record, and no exporter changes.
2. **Shape.** A near-miss names one item, so it matches one check-in on that item.
3. **Shared gear.** A check-in on shared gear can be read by two diver profiles.
   Each may log their own near-miss against it, so many near-misses to one
   check-in has to work. The UI treats more than one as the rare case it is.

### Rules that keep the link true

- **Same item.** A linked near-miss names the check-in's item. Changing the item
  on the near-miss clears the link. Merging two items moves both rows, so the
  link survives.
- **Issues only.** Only a check-in with status `issue` can be linked. Saving a
  linked check-in as OK clears the link and keeps the near-miss.
- **Deleting a check-in** keeps the near-miss and clears the link.
- **Deleting an item** already keeps its near-misses and clears their gear link;
  it now clears `observation_id` in the same write, because the item's check-ins
  go with it.
- **Deleting a dive** changes nothing about the link. Both records survive and
  each loses only its own dive link.
- **Deleting a near-miss** leaves the check-in untouched.

Each severing write stamps `updated_at` and marks the near-miss pending.
`ON DELETE SET NULL` alone would move no clock and stage nothing.

## Sync

`incidents` gains a nullable `parentRefs` entry for `observationId`. The merge
runs with deferred foreign keys, so a near-miss may apply before its check-in in
one payload, and `repairDanglingForeignKeys` clears a link whose check-in was
deleted on a peer. The check-in row itself does not change.

The same repair clears a link whose check-in has become OK or names a different
item from the report. The saving device normally clears it, but a peer below v338
does not know the link and two devices can link and resolve at once. Every device
derives the same result from the same rows, so the repair stages nothing.

Resolving a conflict by keeping the peer's row, or a copy of it, runs the same
deferred write and repair. That row can name a check-in this device has since
deleted, since deleting one stages its near-miss and a peer's edit then conflicts.
A diver resolves a list of conflicts one row at a time, so this path checks the
written row's table and scans the whole database only when that table reports a
dangling reference.

## Reaching the link

### From a check-in

An issue row in the check-in sheet and on the item page's check-in card gets one
text action on its own line:

- **Log near-miss** when no near-miss is linked. It opens the near-miss form
  prefilled from the check-in.
- **Near-miss linked** when one is. It opens that near-miss. With several it
  reads "2 near-misses linked" and opens the log.

Linked near-misses are scoped to the active diver, like the near-miss log: one
profile never sees another's report, on shared gear included.

OK rows show neither action.

### Prefill from a check-in

The new form starts with the item, category Equipment, the check-in's dive, the
check-in's day, and the check-in's note as the narrative. All of it can be
changed before saving.

### From a near-miss

The form gains a **Gear check-in** row under Equipment involved, shown once an
item is named. It opens a picker holding None, the item's issue check-ins (this
dive's first, then the rest, newest first) and **Add check-in**, which opens the
existing check-in sheet for that item and selects the issue check-in the diver
just added.

Linking fills gaps and never overwrites:

- A near-miss with no dive takes the check-in's dive while the link stands. The
  form has no dive field, so that dive goes if the diver picks None, picks
  another check-in or changes the item.
- A new near-miss whose date the diver has not touched takes the check-in's day
  while the link stands. A report started from a check-in keeps that day.
- Another profile's check-in on shared gear can be linked, but never fills the
  dive: the report would show on that diver's dive, to them.

### Automatic match

Naming an item on a near-miss that has a dive selects the check-in when that item
has exactly one issue check-in on that dive. The row shows the match, and the
diver can change it to None. With two or more the row stays on None, since
guessing between faults would be wrong.

### Near-miss log

A linked report adds "Linked check-in" to its subtitle, beside "Linked to a dive".

## Condition findings

The engine is unchanged. The `incidentLinked` rule counts near-misses and the tag
rules count check-ins. They produce different findings about different evidence,
so linking does not double-count either one, and a link must not change a
finding's wording or severity.

## Exports

None change. The check-in row and entity gain no field, so no exporter has
anything new to write.

## Build order

1. Schema column, rung, backstop, `Incident.observationId`, repository reads and
   writes, `parentRefs`.
2. Severing rules in `EquipmentObservationRepository` and
   `IncidentRepository.unlinkFromDeletedEquipment`.
3. Check-in row action, shared by the sheet and the item card.
4. Near-miss form row, picker, prefill and automatic match.
5. Near-miss log subtitle, user docs.

## Left to the builder

- Exact wording of new strings, within the labels named above.
- Where the check-in picker's code lives.
