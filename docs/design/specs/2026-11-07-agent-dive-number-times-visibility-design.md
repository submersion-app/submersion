# Agent writes for dive number, times and measured visibility

Issue #4294 (Refs #4071). Approved in chat on 2026-11-07.

## Why

An agent importing a paper logbook through agent access cannot record the
dive's number, its length or a measured visibility. The dives land with the
next free number, no runtime or bottom time (so they add nothing to hours or
totals), and visibility only as a band. The agent falls back to custom fields
and notes, and the diver retypes everything.

## Goals

- `DiveWrites` accepts `dive_number`, `runtime_s`, `bottom_time_s`,
  `exit_time`, `visibility_m`, `visibility_min_m` and `visibility_max_m` on
  create and update, through the existing preview and Allow flow.
- The field names are the keys a dive read already returns, so the confirm
  dialog shows them in the diver's units with no new formatting (`_s` as
  minutes and seconds, `_m` as depth, `exit_time` as a clock time).
- The rules follow the dive editor.

## Non-goals

- No change to the read documents, the editor, or how a profile derives a
  bottom time.
- No renumbering of other dives, and no uniqueness check on numbers.

## Decisions

### Dive number (decided in chat)

- `dive_number` is a whole number of 1 or more, nullable on update.
- On create, a sent number replaces the next free number; without one the
  create still takes the next free number, as today.
- Duplicates are allowed, as in the editor: a paper dive 20 may land beside a
  computer dive already numbered 20, and renumbering is the diver's call.
- A planned dive never holds a number, as in the editor, so a non-null
  `dive_number` on a planned dive is refused.

### Times (decided in chat)

- `runtime_s`, `bottom_time_s` and `exit_time` are writable on every dive,
  with or without a computer profile, as the editor allows.
- Setting `exit_time` sets runtime to exit minus entry. The preview lists the
  runtime as an indirect change (on create, as a filled field).
- A `runtime_s` that disagrees with the dive's exit, the stored one or one in
  the same change, is refused, telling the agent to change or clear
  `exit_time` instead. That includes clearing runtime while an exit stays.
- An exit at or before the entry is refused. So is one more than 24 hours
  after it (builder's call, confirmed in the playback).
- Moving `date_time` keeps shifting the stored exit with it, so runtime stays.
  When the same change also names `exit_time`, the named exit is the one
  written, after the shift, and runtime follows it against the new entry.
- Clearing `exit_time` leaves the runtime as it is, as the editor does.
- `bottom_time_s` is independent: it never fills runtime, nor runtime it.

The entry a runtime is measured from is the dive's entry time, or its
`date_time` when it has none, as `Dive.effectiveEntryTime` reads.

### Visibility (decided in chat)

A dive holds one visibility shape (#3226): a measurement, a range, or a band.

- `visibility_m` is a measurement. `visibility_min_m` and `visibility_max_m`
  are a range, either end of which may be open ("80+ ft" is a minimum with no
  maximum).
- Writing a non-null value of one shape clears the other shapes, and the
  preview lists each cleared field. Writing the band already clears both
  measured shapes today; a measurement now clears the range and band, and a
  range end clears the measurement and band.
- Naming two shapes with non-null values in one change is refused.
- A range end combines with the other end as stored. The result must have
  its low end below its high end, else the change is refused with a hint to
  clear or set the other end in the same change.
- A restated value still clears a stale other shape (as the band does today),
  so the three measured keys join `effectFields`.

## Builder's calls

- Limits: `runtime_s` and `bottom_time_s` 0 to 86400 seconds; visibility 0 to
  200 m; `dive_number` 1 to 1,000,000.
- No check that bottom time is at most runtime; the editor has none.
- The tool note gains a sentence on the time and visibility rules so an agent
  learns them from the tool description, not from refusals.
