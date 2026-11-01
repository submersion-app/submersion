# Underwater track scale correction

Issue: #3823. Release: v1.8.4.

## Intent

A diver with a dead-reckoned underwater track (Suunto Nautic S, Seacraft ENC)
sees it on a map at the wrong size for the shoreline or landmarks it passed. The
alignment page can move the track, rotate it and pin its end, but cannot resize
it. The reporter called this "zoom", but the map and the 3D views already zoom:
what is missing is changing the track's size relative to the map.

The end-point correction only partly covers this. It stretches an out-and-back
track, but a loop already ends where it started, so there is no residual to
distribute and a size error stays.

The 2026-09-10 track design listed a "rotate-and-scale correction mode" as
later work (`2026-09-10-underwater-nav-track-design.md`). This is the scale half,
as a uniform correction rather than a replacement for the rubber band.

How often: only dead-reckoned tracks, and only when the diver has something on
the map to fit against. It is a minority of tracks, which is why this stays one
number on an existing page.

## Goals

- Resize a track against the map on the alignment page, saved with the track.
- Every view of the corrected track follows: alignment map, detail map, 3D
  views, terrain check.
- A size error on a loop can be corrected, which no existing tool can do.

## Non-goals

- Changing recorded distance or speed. Readouts stay as the device logged them.
- Separate scales for north and east, or scaling part of a track.
- Automatic fitting, and matching a landmark to solve for scale. Mockup option C
  was declined for now.
- Replacing the proportional end-point correction.
- Any change to the map or 3D view zoom.

## Anti-goals

- A scale that alters depth or time.
- A handle drag that can rotate the track or move the start.
- A reset, or any other change of scale, that fails to reach synced devices.
- An older peer's sync payload breaking the read of a track row.

## Decisions the maintainer made

1. Zoom means a saved scale on the track itself, not view zoom.
2. Distance and speed readouts stay as recorded, matching rotation and the
   end-point stretch today.
3. The control is a drag handle on the map plus a stepper (mockup option B).
4. The behaviour in "The drag handle" and "The stepper" below, as played back and
   confirmed in chat: handle on the farthest point of the dive, radial only,
   always shown once the track is on the map, stepper at 1% with a typed value,
   range 25% to 400%, saved only by Save, reset by Reset.
5. While the end is pinned, the handle is hidden and a short hint explains why.
   The stepper stays. See "When the end is pinned".

## Behaviour

### The correction

`NavTrackCorrection` gains `scaleFactor`, default 1.0 (100%). The steps of
`NavTrackCorrector.apply` become:

1. Rotate every raw (north, east) by `headingOffsetDeg` about the origin, as now.
2. **Scale** the samples of the active range about the rotated first active
   sample (`activeRange.start`), by `scaleFactor`. Horizontal only: depth and
   timestamp pass through. Samples outside the active range (pre-dive
   calibration, post-dive fix and tail) are left alone: they are GPS-derived, not
   dead-reckoned, and are not drawn as the swim path.
3. Resolve the end target and apply the proportional correction as now, on the
   scaled samples.

Consequences to hold on to:

- The pivot is the dive's start, not the local origin. On a recording with a
  pre-dive fix the two differ, and scaling about the origin would shift the
  whole dive.
- `sameAsStart`: the pivot is the target, so it is unchanged by the scale.
- `point`: the target is a place on the map, so it is unchanged by the scale.
- `gpsFix`: the target stays rotated as now and is not scaled. A fix is the truth
  the track is fitted to.
- Everything that returns the rotated list today must return the scaled list:
  no target, trust fraction 1, zero-length remainder.
- Samples at or before the trust mark are scaled too. Trust limits the end-point
  stretch only, and the scale applies to the whole active range.
- `cumulativeDistances` is unchanged. The stretch uses fractions of distance,
  which a uniform scale leaves as they were, so the trust slider still points at
  the same sample.
- At 1.0 the scale step is skipped entirely: output is identical to today, and
  a recording with no end correction is not classified just to apply it.

`NavTrackGpsFixDotsLayer` stays on raw points, so the dots do not move. The trust
readout, the detail stats and the list row stats stay as recorded.

### The drag handle

A new marker on the alignment map.

**Where it sits.** On the sample of the active range farthest from the first
active sample, measured on raw points. Rotation and a uniform scale cannot change
which sample that is, so the index is stable during a drag and needs no
recalculation from the corrected points. It is drawn at that sample's corrected
position, so it stays on the visible track.

**When it shows.** When the track is on the map (anchor set), that raw farthest
distance is at least 10 m, and the end is not pinned (see below). Hidden while the
crosshair placement flow is active. The stepper works regardless.

**What a drag does.** Radial only, measured on the ground from the corrected
position of the dive's start, `P`:

- On press: record the current scale `s0` and the distance `d0` from `P` to the
  pointer's ground position.
- On move: `d` is the distance from `P` to the pointer's ground position, and the
  scale becomes `s0 * d / d0`, clamped to the range and rounded to 0.1%.

Ratios from the press, not per-frame deltas, so a long drag does not drift and the
pointer's offset from the handle's centre does not matter. The handle stays under
the pointer: whenever it is shown, every corrected sample's offset from `P` is
exactly proportional to the scale. With end mode `none` that offset is
`s * r`. With `sameAsStart` the target is `P`, so it is `s * (r - g * r_end)`,
where `g` is the sample's fraction of the stretch and does not depend on `s`.

Requirements on the gesture:

- The pointer position must be converted through the camera, so it is correct on
  a rotated map.
- The map must not pan while the handle is held.
- It goes through `_updateCorrection`, so the terrain check debounces as it does
  for a marker drag.
- It looks distinct from the green start, red end and the trust diamond, and
  offers a semantic label.

### When the end is pinned

The end is **pinned** when the correction resolves a real end target other than
`sameAsStart` and has room to apply it. That means end mode `point` with both the
anchor and the end point set, or `gpsFix` on a recording with a post-dive fix, and
in both cases a trust fraction below 1. An incomplete `point`, or a `gpsFix` with
no fix, resolves to no correction and does not count.

While pinned, the end sample lands on the target whatever the scale is, so the pin
sets the track's overall size and a scale can only reshape the path between the
start and the end. On a nearly straight track it changes almost nothing.

- The handle is hidden.
- The stepper stays and still works, including its stored value.
- A one-line hint under the Scale row says so, along the lines of "The end is
  pinned, so it sets the track's size. Scale only reshapes the path between."

The rule for "pinned" belongs beside the corrector's own target resolution, so the
page cannot disagree with what `apply` does. This mostly affects Seacraft tracks
ending at a GPS fix, whose size is already set by that fix. The Suunto case in the
issue has no fix, so it is unaffected.

### The stepper

A row labelled "Scale:" with the same shape as `NavTrackRotationControl`: minus,
a directly editable field with a `%` suffix, plus.

- Steps of 1%. The field takes one decimal, such as 103.5, in the diver's locale,
  through the same number helpers rotation uses.
- Clamped to 25% to 400%. Unreadable text restores the field and says why,
  as rotation does.
- It reseeds from the stored value when the value changes and the field has no
  focus, so a handle drag updates it live.
- Rotation and Scale share a row on a wide screen and stack on a phone.

Duplicating `NavTrackRotationControl` wholesale would be a smell. Sharing its
stepper and field logic is the builder's call.

### Saving and resetting

The scale joins the in-memory correction: Save persists it, "open in 3D" persists
it, Cancel discards it, and Reset returns it to 1.0.

`_transientRoute` must carry it, or the live map will not move. The detail page's
`_RouteMap._framingOf` must include it, or a saved scale will not reframe the map.

### Detail page

When the scale is not 100%, the correction section shows a line such as
"Track scale: 138%". The recorded distance no longer matches the drawn track on
such a track, so the page should say why.

## Storage and sync

- `nav_tracks.scale_factor`, `REAL NOT NULL DEFAULT 1`, in schema v333. Column
  only: the `DEFAULT` gives every existing row 1.0, so there is no backfill.
  Added through a `_assertNavTrackScaleFactorColumn` helper in
  `track_migrations.dart`, called from the rung and from `_assertNavTracksSchema`,
  following v285 and v330. It needs no change to `before_open.dart`.
- Non-null with a default, like `headingOffsetDeg`. An older peer's payload omits
  the key: the merge overlay keeps the local value, and `_withSchemaDefaults`
  fills 1.0 before `fromJson` on a row that is new here, so no read can throw.
- Because no row is ever NULL, the change log records 1.0 as the old value, so an
  Undo writes 1.0 and reaches other devices like any other edit.
- `minimumCompatibleSchemaVersion` does not change: this is a new defaulted column.
- Entity: field, constructor, `copyWith`, `correction` getter and `props`.
- Conflict catalogue: add `scaleFactor` to `site_trip_fields.dart` as a number
  field, with a `settings_conflict_field_scaleFactor` label.
- Change log: `nav_tracks` is tracked. The triggers narrow by the live table's
  columns, so confirm the new column is captured.

Claim the schema number by re-checking main and open PRs immediately before
pushing, since rungs are often taken in parallel.

## Strings

New keys, in all 11 locales: the scale label, the handle's semantic label, the
pinned-end hint, the detail line and the conflict field label. Inside underwater-only screens the
vocabulary is plain "track".

## Existing marker dragging

Reading `NavTrackAlignPage._dragPoint` and `NavTrackDraggableMarker` suggests two
bugs, neither yet confirmed in the running app:

1. `_dragPoint` treats screen dx as east and dy as north, ignoring camera rotation,
   so on a rotated map a start or end marker may move the wrong way.
2. The marker uses a `Listener`, which does not claim the gesture, so the map may
   pan under the marker during a drag.

The builder verifies both in the running app. The new handle must not have either
problem. If they are real for the start and end markers, fix them in this PR and
list them under Follow-ups.

## Testing

- Corrector: scale about the first active sample; pivot differs from the origin
  with a pre-dive fix; depth and timestamp unchanged; pre-dive and tail samples
  untouched; 1.0 identical to today; each end mode (`sameAsStart` still closes,
  `point` lands on the point, `gpsFix` lands on the unscaled target); trust prefix
  scaled; trust fraction 1 returns the scaled list; a loop's size changes.
- Handle maths, as pure functions: farthest index, the ratio from press, clamping,
  rounding, and `d0` of zero doing nothing. The handle stays under the pointer in
  end modes `none` and `sameAsStart`, with trust set.
- The pinned rule: `point` complete and incomplete, `gpsFix` with and without a
  post-dive fix, `sameAsStart`, `none`, and trust fraction 1.
- Widget: stepper and typed entry; locale; clamp; Save, Cancel, Reset; the handle
  hidden with no anchor, on a short track, while placing and while pinned; the hint
  shown only while pinned; a drag updates the field; the terrain summary follows.
- Repository and migration: v333 from an older database gives existing rows 1.0,
  and a saved scale reads back.
- Sync: a peer payload without `scaleFactor` on merge, adopt and restore. Add it to
  the cross-version round trip test if that is where the pattern lives.
- Detail page: reframes on a scale change, the line shows only away from 100%.

## Calls the author made

The maintainer has not been asked about these. Each is easy to change.

- The 10 m minimum for showing the handle.
- The detail page's "Track scale" line.
- Clamping the handle's result and rounding it to 0.1%.
- Samples outside the active range are not scaled.

## Left to the builder

- Whether to extract a shared stepper from `NavTrackRotationControl`.
- The handle's glyph and colour, within "distinct from the existing markers".
- How map panning is suspended while the handle is held.
- The exact wording of new strings.
- Where the handle's maths and gesture live. `nav_track_align_page.dart` is
  already at 816 lines, so they belong outside it and the page only wires them in.
  Splitting the page further waits for open PR #4038, which reworks the same panel.
