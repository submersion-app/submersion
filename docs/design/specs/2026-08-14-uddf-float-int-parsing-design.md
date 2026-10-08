# UDDF float-formatted integers and misplaced lead weight

Date: 2026-08-14
Status: implemented
Reported by: Jim Nowak (email, no GitHub access)

## Problem

A UDDF file exported from Oceanic Plus (Oceanic's iPhone app, recording from
an Apple Watch Ultra) imported with every profile waypoint stamped at time
zero, so the depth/time graph drew all samples stacked in a single column.

The reporter diagnosed it correctly: Oceanic writes `<divetime>` values with
float formatting (`15.0`) rather than plain integers (`15`), and stripping
`.0` from the file made the graph render.

Inspecting the file against the parser confirmed the cause and found two
further losses in the same export.

### Root cause

`int.tryParse` in Dart rejects any decimal point outright. Every UDDF field
with integer semantics was parsed with it, so a float-formatted value
returned null and fell through to whatever default the call site had:

| Field | Call site | Result before fix |
| --- | --- | --- |
| `divetime` | `uddf_full_import_service.dart:1571` | `?? 0` — all 2,652 waypoints stamped t=0 |
| `diveduration` | `uddf_full_import_service.dart:1943` | no fallback — runtime dropped entirely |

A third loss was structural rather than numeric. `<leadquantity>` was read
only from `<informationbeforedive><equipmentused>`, and Oceanic places
`<equipmentused>` in `<informationafterdive>`. Lead weight was silently
discarded on every dive.

All twelve dives in the reporter's file were affected by all three.

## Why not an Oceanic dialect

The codebase already has a dialect mechanism (`UddfNormalizer` +
`UddfDialect`), and `MacDiveDialect` regex-strips `.0` from exactly these
fields. Adding an `OceanicDialect` was considered and rejected:

1. **The fingerprint is weak and fails silently.** Oceanic's `<generator>`
   block has no `<name>` child. The only distinguishing string is a homepage
   URL that carries a locale segment
   (`https://www.oceanicworldwide.com/it/oceanic-plus/`), so it varies by
   user and can change without notice. A dialect that fails to detect
   reintroduces the bug with no error.
2. **It rewrites a file that mostly works.** `normalizeXml` reparses,
   mutates and re-serializes the whole document, adding regression surface
   to the parts that already import correctly, to fix a strict-parse issue
   at two call sites.
3. **It does not address the defect.** The parser was stricter than its
   input. Float-formatted integers are a routine JavaScript serialization
   artifact — Oceanic also emits `<datetime>...619Z</datetime>` and
   `<tankpressurebegin>2.2E7</tankpressurebegin>` — and two independent
   vendors have now hit it. A third would need a third dialect.
4. **Larger test surface, narrower coverage.** Dialects need detection tests
   against every other vendor; lenient parsing needs one helper test.

Dialects remain the right tool for genuine semantic conflicts, where the
same element means different things depending on who wrote the file.
Nothing in the Oceanic export is that.

### Detection tripwire found while evaluating this

`MacDiveDialect._hasMacDiveStructuralQuirks` fingerprints on
`<equipmentused>` nested inside `<informationafterdive>` — which Oceanic
also does. The only thing preventing MacDiveDialect from claiming Oceanic
files today is that Oceanic emits a `<generator>` element, which
short-circuits detection to the name check before the structural fallback
runs. If Oceanic ever drops that block, MacDive semantics would be applied
to Oceanic exports. A regression test now pins this.

## Design

Two vendor-agnostic changes. Neither requires the file to be attributed to
a known exporter, so neither can fail silently on an export whose generator
block changes.

### 1. Lenient integer parsing

`UddfImportParsers.parseUddfInt(String?)` accepts plain integers, float
formatting, exponent notation and surrounding whitespace; rounds genuinely
fractional input to nearest; returns null for null, blank, non-numeric and
non-finite input.

The finiteness guard is load-bearing rather than defensive: `double.tryParse`
succeeds on `"NaN"` and `"Infinity"`, and `double.round()` throws
`UnsupportedError` on both. Without the guard a single malformed element
would abort an entire import rather than skipping one field.

A zero-only fractional part (`"15.0"`, `"15.000"`) is stripped textually
rather than routed through a double, so the value keeps exact integer
semantics. Raised in review: above 2^53 a double round-trip is lossy —
`"9007199254740993.0"` comes back as `...992` — for values Dart ints hold
exactly. No dive field approaches that magnitude, so this is about the
helper's contract rather than any reachable data; it costs one regex match
on a path that previously allocated a double anyway. Values that overflow
int64 still fall through to the double path, where `round()` saturates
rather than throwing.

Applied at all 28 integer-semantics parse sites across the UDDF import path:

| File | Sites |
| --- | --- |
| `uddf_full_import_service.dart` | 16 |
| `uddf_import_service.dart` | 9 |
| `uddf_import_parsers.dart` | 3 |

Covered fields: `divetime`, `diveduration`, `divenumber`, `passedtime`,
`ndl`, `rbt`, heart rate, scrubber duration and remaining, rating, tank
order, gas-switch and event timestamps, gradient factors, marine-life
sighting count, dive-type and dive-role sort order, gear service interval.

`UddfImportParsers.parseUddfDouble` is the decimal counterpart, added after
review pointed out that the lead-weight read accepted non-finite input.
`double.tryParse` succeeds on `"NaN"`, `"Infinity"` and `"-Infinity"`, so a
value that is only null-checked reaches the database intact. NaN is the
dangerous case: it compares false against everything including itself, so it
corrupts totals, averages and range checks downstream rather than failing
where it entered. Applied at all three `<leadquantity>` reads (two of which
predate this change).

Only `<leadquantity>` is converted. Sweeping every `double.tryParse` in the
import path is a larger mechanical change and is left as a follow-up; the
helper exists for it when that happens.

### 2. Lead weight read from either half of the dive

The existing `<informationafterdive><equipmentused>` block — which already
collects equipment refs from that location, with de-duplication — now also
reads `<leadquantity>` when `<informationbeforedive>` did not supply it.
The before-dive value wins, keeping this a fallback rather than an override.

Placing it inside the existing block avoids restructuring the before-dive
parse and cannot produce duplicate equipment refs.

### Not changed

`MacDiveDialect._floatIntPattern` is left in place. It is redundant now,
but removing it would expand the blast radius into MacDive regression
territory for no functional gain.

## Testing

`test/core/services/export/uddf/uddf_lenient_int_parse_test.dart` — helper
units covering plain, float, whitespace-padded, fractional, exponent,
out-of-32-bit-range, non-numeric and non-finite input.

`test/core/services/export/uddf/uddf_oceanic_float_import_test.dart` —
end-to-end regression on a synthetic fixture reproducing Oceanic's exact
serialization shape (invented site ids and coordinates; the reporter's own
dive data and GPS positions are deliberately not committed). Asserts
ascending waypoint timestamps, runtime from float `diveduration`, weight
from the after-dive `equipmentused`, before-dive precedence when both
halves supply weight, and that `MacDiveDialect` does not claim the file.

Verified red before the fix: waypoint timestamps came back
`[0, 0, 0, 0, 0]`, runtime null, weight null.

Verified against the reporter's real 609 KB file: all 12 dives import with
complete profiles (138-303 points each), runtimes and weights; zero
collapsed profiles.

## Known limitations and follow-ups

- **Oceanic appears to export lead weight in the user's display unit.** The
  reporter's dive notes read "12 lbs weights" while the file carries
  `<leadquantity>12.0</leadquantity>`. UDDF specifies kilograms, so the
  value is likely pounds passed through unconverted. Inferring the unit
  would require vendor attribution and is genuinely ambiguous (12 kg is a
  heavy but plausible weight), so it is not guessed at here. Worth raising
  with the reporter to confirm before considering any handling.
- **Oceanic's sample series outruns its stated duration.** The first dive
  carries 293 waypoints at 15-second spacing (ending at t=4380) against a
  `<diveduration>` of 3492 seconds. This looks like Oceanic including
  surface time in the profile, or reporting bottom time as duration. Not
  addressed; noted in case profile-versus-duration displays disagree.
- **Apple Health import** was reported separately by the same user and is
  out of scope here; the reporter suspects Oceanic is not writing to
  HealthKit on their device.
