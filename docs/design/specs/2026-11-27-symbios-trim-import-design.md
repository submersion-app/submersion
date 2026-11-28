# Import and show the trim angle a dive computer logs

Date: 2026-11-27
Issue: #5098 (split from #5064)
Release: v1.8.7
Related: PR #5031 (Trim Calculator in Planning, open when this was written)

## Intent

The Halcyon Symbios logs the diver's trim angle on every sample (the
`TRIM [°]` column of its CSV export). A Symbios owner (#5064) asked for it
to come in with the dive profile. Trim is the diver's body attitude in the
water: how far head up or head down they were. A diver working on trim wants
to see where it drifted (on the descent, at a stop, on the ascent), next to
depth, and to compare it with what their rig was doing at that moment.

Today the fork's Symbios parser reads the trim record and discards it, so
nothing reaches the app.

## Goals

- A Symbios dive downloaded or re-parsed keeps a per-sample trim angle in
  degrees.
- The profile chart can show trim as its own optional line (decided: the full
  optional-line pattern, like the Avelo lines and GTR), with its value in the
  chart readout under the cursor.
- The Trim Calculator (PR #5031) shows the logged trim when the dive it is
  on has trim (decided: option 2, a readout plus a trim strip on the time
  slider).
- Symbios dives already in a log get trim on "Re-parse", from their stored
  raw data.
- Any other computer whose parser later reports trim feeds the same field
  with no app change.

## Non-goals

- A trim summary on the dive page (average, range, time near flat). Offered
  and not chosen.
- Showing compass heading. It has the same gap (imported and stored since
  v105, never shown) but is not part of this request.
- Reading trim from Halcyon's CSV or UDDF exports. The app has no Symbios CSV
  import; trim comes through libdivecomputer only.
- Changing the Trim Calculator's model or its verdict. Logged trim is shown
  beside the model, never fed into it.

## Anti-goals

- Dives without trim must not change: no new chart line, no calculator
  readout, and their profile blobs stay at the codec version they use today.
- The logged angle must never read as the same thing as the calculator's
  figure tilt. PR #5031's spec makes the figure's tilt "a picture of the
  pull's strength, capped, not a prediction of an angle", and keeps degrees
  off it. The logged value is labelled as the computer's measurement and is
  never drawn as a tilt of the figure.
- A trim byte the computer did not mean as a reading (out of range) must
  never reach the chart as a number.

## Constraints

- A per-sample field crosses the libdivecomputer fork, the native glue on
  every platform, the pigeon bridge, the import mappers and the profile
  series codec. The Avelo samples change (#4664, PR #4775, patch 0011) is
  the map of that path; its spec is
  `docs/design/specs/2026-11-19-avelo-sample-decode-design.md`.
- The fork lives at `submersion-app/libdivecomputer` (branch
  `submersion-patches`). A fork change needs its own PR there, merged with a
  merge commit, and a patch file in `packages/libdivecomputer_plugin/patches/`
  (next number: 0012). The submodule pointer moves once the fork PR merges.
- Samples are stored in a compressed per-series blob, not in columns. A new
  field needs a new codec version. An older app on a synced device refuses a
  blob of a version it does not know until it updates, so only series that
  carry trim are written with the new version, as v3 does for Avelo.
- The chart settings add two `diver_settings` columns, so this ships a
  migration rung (in the `migrations/` ladder, never in `database.dart`) and
  sync serializer changes. They are fresh settings with a default, not a
  rewrite of stored values, so no data rung.
- PR #5031 is not merged. The Trim Calculator piece is built last, after it
  merges and main is merged into this branch. If it has not merged when
  everything else is done, ask the maintainer whether to wait or stack on its
  branch.
- No Symbios raw dive bytes are in the repository, and the reporter has not
  agreed to their data being committed. Native tests synthesize trim records.
- Degrees need no unit conversion; every other number shown beside trim
  (depth, time) follows the diver's unit settings as it does today.

## Approaches

How the value gets out of the log:

- **Decode in the fork's Symbios parser (chosen).** The parser already finds
  the record and reads the byte; it only has to report it. One change serves
  download and re-parse on every platform.
- A vendor sample (`DC_SAMPLE_VENDOR`) with the raw record. Rejected: every
  platform's glue would then parse Halcyon bytes itself.

How trim is shown (the maintainer chose):

- **A: a full optional chart line (chosen).** Legend entry, readout value,
  right axis, chart-options toggle, a synced "show by default" setting and a
  colour setting, like every other optional line.
- B: the same line with a per-viewing toggle and a fixed colour. Rejected:
  breaks with every other optional line, which were kept persistent for
  Avelo.
- C: a dive-page summary. Not chosen.

How the Trim Calculator shows it (the maintainer chose):

- **2: a readout plus a trim strip on the time slider (chosen).** The strip
  shows where trim drifted, so the diver can drag there and read the rig's
  pull at that moment.
- 1: the readout only. Rejected: the diver scrubs blind to find the moment.
- 3: a ghost figure drawn at the logged angle. Rejected: puts a real angle
  beside a tilt PR #5031 deliberately does not treat as an angle.

## Design

### 1. libdivecomputer fork (patch 0012)

- Append `DC_SAMPLE_TRIM` to `dc_sample_type_t` and a `double trim` member
  (degrees) to `dc_sample_value_t`, each marked as a Submersion patch with a
  comment, as 0007 and 0011 do.
- In `halcyon_symbios_parser.c`, the `ID_TRIM` branch reports the signed
  byte at `offset + 2` as `DC_SAMPLE_TRIM`, in degrees, as logged. The
  current read, `(signed int) data[offset + 2]` on an `unsigned char`
  buffer, can never be negative (a logged -13 reads as 243); it must go
  through `signed char` first (builder check; designer's call). A value
  outside -90 to +90 is not reported (no special codes are documented; this
  guards against them).
- A native test beside `test_halcyon_symbios_ble_download.c` builds a Symbios
  dive with trim records (including a negative value and an out-of-range
  byte) and checks the reported samples.

### 2. Native glue and bridge

Carry `trim` from `sample_callback` through the sample struct, the pigeon
`ProfileSample` (`trim`, degrees, nullable) and every platform converter,
following the Avelo samples change: darwin (`libdc_download.c`,
`libdc_wrapper.h`, `DiveComputerHostApiImpl.swift`), Android (`libdc_jni.cpp`,
`SampleDecoder.kt` and its test), Linux and Windows converters, and the
regenerated pigeon code for every platform.

### 3. Domain and storage

- `DiveProfilePoint`, the download entities and the codec's `ProfileSample`
  gain `trim` (double, degrees, nullable).
- Profile series codec v4 appends `trim` (float64). `encode` writes v4 only
  for a series with trim; otherwise it keeps today's lowest-version choice.
  Update the forward-version sync test for v4.
- The download path, re-parse (`reparse_service.dart`, which must mirror
  download), the re-import service and the universal-import profile mapper
  copy the field. Merge and consolidation keep it like any other sample
  field.
- Submersion's own UDDF backup writes and reads it in its custom extension,
  like the Avelo samples, so a backup and restore keeps it.

### 4. Profile chart

One new optional line, offered only when the dive has trim:

- **Trim**, in degrees, signed, with a dashed zero (flat) reference on its
  axis when it is the right axis.
- A `ProfileRightAxisMetric.trim` value, so it can be the right axis and has
  a palette slot.
- A synced `defaultShowTrim` column in `diver_settings`, default `false`
  like every other optional line, and a `profileColorTrim` column for the
  diver's palette: two columns, one migration rung, the sync serializer arms,
  and rows on the settings Appearance page (default visible metrics and
  profile colours) and the settings conflict screen.
- A legend entry, a chart-options toggle and a readout value under the
  cursor.
- An info-sheet term saying the value is the angle the dive computer logged.

New strings go through the ARB files for every locale.

### 5. Trim Calculator (after PR #5031 merges)

Shown only when the calculator's dive has trim samples:

```
  Your computer logged 9° head down at 42:10
  [ trim strip: logged trim across the dive, zero line dashed, ]
  [ a vertical mark at the time slider's position              ]
  ( time slider, unchanged )
```

- The readout gives the logged trim at the time slider's moment: the sample
  at or nearest before that time, as a whole degree with a direction word.
  With no sample in reach (a gap before the first trim sample), the readout
  says there is no reading at that time rather than showing a stale value.
- The strip sits directly above the time slider, spans the same time range,
  draws the logged trim against a dashed zero line, and marks the slider's
  position. It is a picture to scrub by; dragging on it is not required.
- Labelled as the computer's measurement. It does not move the figure, the
  gauges, the verdict or What would level you.

### 6. Sign convention and what the angle measures

Checked against the reporter's export on #5064 (one dive's CSV, handset
firmware 2.36.12, log version 1.03; read only, not committed):

- **Positive is head up.** After surfacing, at 0 m, every sample reads +51
  to +86 degrees, a diver floating upright. The whole dive spans -76 to +87.
  So: positive "head up", negative "head down", 0 "flat".
- **Whole degrees, signed.** The CSV gives whole numbers on both sides of
  zero, which fits a signed byte in degrees. The raw byte itself is still
  unconfirmed (no raw dump yet); the maintainer chose to build on this and
  confirm later. A wrong guess costs a re-parse, since raw data is kept.
- **It is the computer's own tilt.** The values on this wrist-worn handset
  (mean about +28 degrees during level swimming) follow the forearm, not only
  the body. The info-sheet term and the calculator readout say "the angle
  your computer logged", never "your trim".

## Left to the builder

- Exact C names, pigeon field names and the codec version number.
- Line colour and legend order, consistent with the existing palette.
- The trim axis range (expected: symmetric, padded to the dive's largest
  absolute value, at least +/-10 degrees so a well-trimmed dive is not
  exaggerated).
- The strip's height and how the calculator's layout fits it on phone and
  desktop widths.
