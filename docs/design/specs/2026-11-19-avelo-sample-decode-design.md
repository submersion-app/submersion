# Avelo mode: decode and show the Avelo sample data

Date: 2026-11-19
Issue: #4664 (follow-up to #4657, PR #4662)
Release: v1.8.5
Findings: `docs/design/findings/2026-11-19-avelo-sample-bytes.md`

## Intent

Shearwater's Avelo mode logs Avelo sample records (`0x03`) whose repurposed
bytes hold what an Avelo diver watches during the dive: buoyancy, gas
remaining as a percentage, and the computer's own breathing rate (RMV).
libdivecomputer skips those bytes, so Submersion imports none of it, while
Shearwater Cloud shows all of it. #4662 marked the Hydrotank and blanked its
pressure-based gas numbers because no real log was available. An Avelo diver
has now sent eight real dives, and the findings document decodes the bytes
and checks them against Shearwater Cloud's own statistics (exact match on all
eight dives).

The diver should see, for an Avelo dive, what their computer recorded about
buoyancy, gas remaining and breathing rate, on the profile chart and as a
short summary on the dive page.

## Goals

- An Avelo dive downloaded, re-parsed or imported from Shearwater Cloud keeps
  three new per-sample values: Avelo buoyancy, gas remaining percent and the
  computer's RMV.
- The profile chart can show each as its own line, with values in the chart
  readout, in the diver's units.
- The dive page shows an Avelo summary: buoyancy minimum, maximum and average;
  RMV minimum and maximum; gas remaining at the start and end; the highest
  Hydrotank pressure. Computed with Shearwater's rule (only samples deeper
  than 0) so the numbers match Shearwater Cloud.
- Avelo dives already in a log get the values on re-parse, which is how #4662
  already reaches them.

## Non-goals

- A gas used or SAC figure derived from gas remaining percent (rejected in
  design: it assumes the Hydrotank starts with no water in it). #4662's blank
  SAC for a Hydrotank stays.
- Changing the modelled buoyancy section (`BuoyancySection`, the buoyancy
  twin). It does not model Hydrotank water; that is a separate question.
- Decoding bytes 14, 16 and 17 of the Avelo record (meaning not found).
- Storing the summary on the dive.
- The two-computer Avelo case from #4664 (no data).

## Anti-goals

- Non-Avelo dives must not change: no new chart lines, no summary, and their
  profile blobs stay at the codec version they use today.
- The computer's RMV must never be confused with Submersion's calculated
  RMV/SAC. It is labelled as the computer's.
- The computer's Avelo buoyancy must never be confused with the modelled
  buoyancy on the dive page. It is labelled as Avelo buoyancy.
- Special codes (no comms, not yet computed, not diving) must never reach the
  chart or the summary as numbers.

## Constraints

- Every per-sample field crosses the libdivecomputer fork, the native glue on
  every platform, the pigeon bridge, the import mappers and the profile
  series codec. The O2 cell millivolt change (patch 0007) is the map of that
  path.
- The fork lives at `submersion-app/libdivecomputer` (branch
  `submersion-patches`). A fork change needs its own PR there and a patch file
  in `packages/libdivecomputer_plugin/patches/` (next number: 0011); the
  submodule pointer moves once the fork PR merges, as in #4662.
- A new codec version cannot be read by an older app on a synced device until
  it updates. Only series that carry a new field are written with it, as v2
  does for GF99.
- The diver has not agreed to his dives being committed. Tests synthesize
  Avelo records instead (as #4662's native test does from the Petrel 3
  fixture). The values in the findings document may be used as expectations.
- Every displayed unit follows the active diver's unit settings.
- The chart settings add six `diver_settings` columns, so this ships a
  migration rung and sync changes. The new columns are fresh settings with a
  default, not a rewrite of stored values, so no data rung is needed.

## Approaches

Considered for getting the values out of the log:

- **Decode in the fork's Shearwater parser (chosen).** One decode serves
  download, re-parse and Shearwater Cloud import, all of which already run
  the parser.
- Decode the raw bytes in Dart. Rejected: it repeats the PNF walk and sample
  timing, and a downloaded dive's stored raw data is the compressed dump, so
  Dart would also have to decompress it.

Considered for the summary:

- **Computed from the stored samples when shown (chosen by the maintainer).**
  No schema change, nothing to keep in step after an edit, merge or re-parse.
- Stored as dive columns at import. Rejected: needs a migration rung and sync
  handling, and can drift from the samples.

## Design

### 1. libdivecomputer fork (patch 0011)

In `shearwater_predator_parser.c`, for a `LOG_RECORD_AVELO_SAMPLE`, report
three new sample types in addition to what it reports today. Append them to
`dc_sample_type_t` and give each a member in `dc_sample_value_t`, marked as a
Submersion patch like 0007 and 0010.

| Value | Bytes (`offset + pnf + N`) | Reported as | Skip when |
| --- | --- | --- | --- |
| Avelo buoyancy | 11-12, signed 16-bit big endian | kilograms (raw / 1000) | raw is `0x7FFE` |
| Gas remaining | 10 | percent (0 to 100) | raw above 100 (`0xFE` seen) |
| Computer RMV | 29-30, unsigned 16-bit big endian | litres per minute (raw / 100) | raw at or above `0xFFF0` |

The buoyancy unit (grams) and the RMV unit (litres per minute) are inferred,
not confirmed (see findings). All eight known dives are from an
imperial-unit computer; nothing yet shows whether a metric computer stores
the same units. Keep each scale in its own named constant with a comment
saying so (builder check; designer's call).

The before-dive buoyancy constant (-96 in every known dive, before the first
underwater sample) is reported as logged; the summary's depth rule leaves it
out.

A native test (beside `test_shearwater_avelo_hydrotank.c`) builds Avelo
records with known bytes, including each special code, and checks the
reported values.

### 2. Native glue and bridge

Carry the three values from `sample_callback` through the sample struct, the
pigeon `ProfileSample` (`aveloBuoyancy` kg, `aveloGasRemaining` percent,
`computerRmv` L/min, all nullable) and every platform converter, following
the path O2 cell millivolts took (darwin, Android `SampleDecoder`/JNI, Linux
and Windows converters, regenerated pigeon code).

### 3. Domain and storage

- `DiveProfilePoint` and the codec's `ProfileSample` gain the three nullable
  fields.
- Profile series codec v3 appends `avelo_buoyancy`, `avelo_gas_remaining` and
  `computer_rmv`. `encode` writes v3 only for a series with one of them;
  otherwise it keeps today's choice of v1 or v2. Update the forward-version
  sync test for v3.
- The import mappers (dive computer download, re-parse, Shearwater Cloud
  import via `shearwater_dive_mapper.dart`) copy the fields. Merge and
  consolidation keep them like any other sample field.
- Submersion's own UDDF backup writes and reads them in its custom
  extension, like GF99 and N2 load, so a backup and restore keeps them.

### 4. Profile chart

Three new optional lines, offered only when the dive has the data:

- **Avelo buoyancy**, in the diver's weight unit, signed (negative = heavy).
- **Gas remaining**, percent.
- **Computer RMV**, in the diver's volume-per-minute unit.

Each follows the full pattern every optional line has (GTR, O2 cell mV and
the modelled buoyancy line are the closest precedents; chosen by the
maintainer over session-only toggles):

- a `ProfileRightAxisMetric` value (`aveloBuoyancy`, `aveloGasRemaining`,
  `computerRmv`), so it can be the right axis and has a palette slot. The
  modelled `buoyancy` metric stays as it is; the new one is labelled
  "Avelo buoyancy" so the two never read as the same line;
- a synced `defaultShow...` column in `diver_settings`, default `false` like
  every other optional line, and a `profileColor...` column for the diver's
  palette: six new columns, one migration rung (in the `migrations/` ladder,
  never in `database.dart`), the sync serializer arms, and rows on the
  settings Appearance page and the settings conflict screen;
- a legend entry, a chart-options toggle and a readout value under the
  cursor, offered only when the dive has the data.

New strings go through the ARB files for every locale.

### 5. Dive page summary

In the Cylinders card, under the Hydrotank row, beside the existing Hydrotank
note, an Avelo block shown only when the dive has any of the three values:

```
Hydrotank  21%  ...                      (existing row)
  Pressure rises with the water pumped in ... (existing note)
  Avelo
    Gas remaining      100% -> 35%
    Buoyancy           -0.9 lb to +2.7 lb, average +0.6 lb
    RMV (computer)     0.38 to 1.05 cuft/min
    Max pressure       3498 psi
```

Computation, from the dive's primary profile:

- Use only samples with depth above 0 (Shearwater's rule; with it the decode
  matched Shearwater Cloud's statistics on every known dive).
- Buoyancy: minimum, maximum, mean of the samples that carry it.
- RMV: minimum and maximum.
- Gas remaining: first and last value.
- Max pressure: the highest Hydrotank pressure in the tank pressure series
  under the same depth rule.
- A line whose value is missing is left out; the block is left out when all
  are missing.

The summary is a pure function over the profile and tank pressures, tested
with values from the findings document.

### 6. Hydrotank figure: water and gas (added 2026-11-19)

Asked for by the maintainer during the build: the Cylinders card draws a
Hydrotank as water and gas instead of a pressure fill, which misleads for a
tank whose pressure rises with the water pumped in.

- The body is the tank's volume. From the bottom: estimated water in blue,
  then gas left (solid gas colour), then gas used (tint) to the top.
- Estimate, assuming no water at the start: the gas space is
  `(start pressure / pressure now) x gas remaining %` of the tank, and the
  water is the rest, clamped to 0 through the whole tank. Gas left is
  `gas space x gas remaining %`, gas used the rest of the gas space.
- Without the cursor it shows the end of the dive: the end pressure and the
  last underwater gas remaining. With the profile cursor on the chart it
  shows the moment under the cursor (the cursor's Hydrotank pressure and the
  gas remaining of the last sample at or before it), so pump-ins and purges
  move the water as the diver scrubs; the cursor's label sits at the top of
  the gas left.
- A "Water ~X (est.)" label, in the diver's volume unit, sits under the
  figure (the builder's call: the side labels are laid out for Start, End,
  Used and Now only); no label without a tank volume. While the cursor is
  shown the End mark has no level, since the gas level is then the
  cursor's moment, not the end of the dive's.
- When the dive has no gas remaining, no start pressure or no pressure at
  the moment shown, the Hydrotank keeps today's pressure figure.
- The water estimate rests on the same assumption turned down for SAC; here
  it only draws a picture, marked as an estimate, and changes no number
  anything else reads.

## Left to the builder

- Exact C names for the new sample types and union members.
- Where the summary computation lives (a small domain service is expected).
- Line colours and legend order, consistent with the existing palette.
- Whether the block in the Cylinders card also appears when the dive has no
  Hydrotank-role tank but carries the values (expected: show it under the
  first tank, or as its own row; pick what reads best).
