# MacDive SQLite Profile Decoding — Design

**Status:** Draft
**Author:** Eric Griffin
**Created:** 2026-04-23
**Context:** Continuation of the MacDive Import Robustness work (`docs/superpowers/specs/2026-04-21-macdive-import-design.md`). Milestone 3 of that plan (PR #256, `feature/macdive-sqlite`) deferred decoding of `ZDIVE.ZSAMPLES` — MacDive's proprietary profile-sample BLOB. This spec covers the follow-up that closes the gap.

## Problem

PR #256 lands MacDive SQLite import with all dive metadata (tags, critters, gear, events, tanks, gases, sites, buddies) but emits `profile: []` for every dive. Users importing their MacDive database currently cannot see time-series profile data (depth-over-time, temperature, tank pressure, ppO2, NDL) unless they also export UDDF separately and run a second import. For the ~65% of dives in a typical MacDive database that have `ZSAMPLES` data, we need the SQLite path to produce the same profile output the UDDF importer already produces.

The existing metadata-only path was a deliberate scope decision in PR #256: MacDive's `ZSAMPLES` format isn't bplist, and the initial probing (zlib / gzip / lzma at offsets 0/4/8/12) didn't yield a known wrapper. Decoding the format requires focused reverse-engineering work, which we now undertake.

## Goals

1. Decode `ZDIVE.ZSAMPLES` for every dive where the blob is non-null and the format is understood, producing the same `List<Map<String, dynamic>>` payload shape the UDDF and MacDive-native-XML importers already emit.
2. Produce output that is sample-for-sample equivalent to the UDDF import for the same UUID, within documented tolerance.
3. Degrade gracefully: per-dive decode failures become `ImportWarning`s, never abort the import. Metadata-only dives still land exactly as they do today.
4. Ship the decoder behind the same test discipline the rest of the MacDive importer uses (unit + golden + gated real-sample regression).

## Non-Goals

- Decoding `ZDIVE.ZRAWDATA` (the raw dive-computer sensor dump). That's a separate fallback path, reserved for a future milestone if `ZSAMPLES` decoding proves infeasible or if we later want to cover the 83 sample-DB dives that have `ZSAMPLES` without a full-fidelity raw dump.
- Modifying the `DiveProfilePoint` domain entity or the `dive_profiles` Drift table. The importer already projects `Map<String, dynamic>` → domain entity correctly.
- UI work. Warnings surface through the existing import-wizard warning list with no visual changes.
- Round-trip re-export to MacDive's format.
- Solving the ~35% of dives in a typical MacDive database that have no sample data at all (manual entries, non-computer-synced dives).

## Approach summary

Two phases with an explicit gate:

- **Phase 1 (investigation spike):** Build throwaway scripts in `scripts/reverse_engineering/zsamples/` that extract paired corpora (ZSAMPLES blob + UDDF ground truth for the same dive UUID), probe the format, and score candidate decodings. Exits when either (a) a single decoder hypothesis scores ≥90% sample-accurate across the 350 ZSAMPLES-bearing dives in the sample database, or (b) the spike timebox (1-2 active days) expires without a viable hypothesis.
- **Phase 2 (implementation):** If Phase 1 succeeded, implement `MacDiveSamplesDecoder` + `MacDiveSqliteSample` typed model, wire into the existing reader/mapper, ship tests at three levels. If Phase 1 failed, this spec is closed and a separate plan covers the ZRAWDATA fallback.

The rest of this document describes what each phase produces concretely.

## Phase 1 — Investigation spike

### Deliverables

1. `docs/import-formats/macdive-zsamples.md` — written format specification precise enough that a programmer unfamiliar with the investigation can implement the decoder from it alone.
2. `scripts/reverse_engineering/zsamples/` — committed scripts, retained for future format drifts.
3. A go/no-go decision recorded as a commit to the plan file.

### Scripts

| File | Purpose |
|---|---|
| `extract_corpus.dart` | Reads `scripts/sample_data/MacDive.sqlite` + `scripts/sample_data/Apr 4 no iPad sync.uddf`, emits paired fixtures under `corpus/<uuid>.zsamples.bin` + `corpus/<uuid>.uddf.json`. UDDF → JSON projection uses the existing `UddfImportParser` so ground-truth data matches exactly what the production importer would produce. |
| `inspect.dart <fixture>` | Pretty-prints a ZSAMPLES blob: hex dump, candidate interpretations at each offset (u8/u16/u32/float LE and BE), repeating-group detection by offset stride, entropy-per-window graph. Human-driven exploration tool. |
| `compression_probe.dart <fixture>` | Attempts LZFSE, LZVN, LZ4, zstd, and Apple Archive decompression at every offset 0 through 64. PR #256 only tried zlib/gzip/lzma at offsets 0/4/8/12; this expands the search to cover Apple's native compression codecs, which are the plausible candidates given MacDive is a native macOS app. |
| `differ.dart <fixture> <hypothesis>` | Takes a Dart function `Uint8List → List<Sample>` as the hypothesis. Decodes, compares to UDDF ground truth. Returns a score: sample-count accuracy, timestamp RMSE, depth RMSE, temperature RMSE, and % samples within tolerance (exact timestamp, ±0.1m depth, ±0.5°C temp). |
| `batch_score.dart <hypothesis>` | Runs a hypothesis across every fixture in `corpus/`, reports per-dive scores plus an aggregate histogram. This is the go/no-go measurement. |

### Ranked hypotheses (cheap → expensive)

1. **Apple compression wrapper.** Run `compression_probe.dart` against fixtures from both observed header variants (`0x19` and `0x9D`). If LZFSE/LZVN/LZ4 hits at any offset, the rest of the format is whatever lies under the wrapper — likely a simple repeating record. *(Expected: 20 minutes.)*
2. **Fixed-width sample records after the 8-byte header.** Compute candidate strides from `(blob_size − 8) / expected_sample_count`, where expected count = `duration / sample_interval`. Search for clean integer divisors and byte patterns at that stride. `inspect.dart`'s entropy-per-window graph flags any strong periodicity. *(Expected: 1-2 hours.)*
3. **Typed record stream (TLV-like).** Each sample is one or more `(tag, length, value)` records; the decoder walks the stream. Consistent with MacDive's likely data model of "depth + optional temp + optional pressure + optional event per timestamp." *(Expected: half a day.)*
4. **Container-of-blocks (vendor-specific frames).** Second header byte becomes a protocol-family ID; each family decodes differently. libdivecomputer's per-vendor parsers are reference material for framing conventions. *(Remainder of timebox.)*

### Validators

Beyond the differ's sample-by-sample comparison, per-dive aggregates on `ZDIVE` are cheap sanity checks:

- `ZMAXDEPTH` — must match `max(decoded.depth)` within ±0.1m.
- `ZAVERAGEDEPTH` — must match mean within ±0.1m.
- `ZTEMPHIGH` / `ZTEMPLOW` — must match decoded temp extremes within ±0.5°C.
- `ZSAMPLEINTERVAL` — if constant-interval, must match `decoded[1].time - decoded[0].time`.
- `ZTOTALDURATION` — must be `≥ decoded.last.time`.

### Exit criteria

- **GO** — one hypothesis scores ≥90% sample-accurate across the 350-dive corpus; remaining failures are either attributable to a small number of distinguishable format variants (implementable in bounded time) or isolated outliers where we emit `profile: []` with a warning.
- **NO-GO** — after 1-2 active days, best hypothesis scores <50% with no clear next hypothesis. Spec is closed. ZRAWDATA fallback planning begins in a new spec.
- **ESCALATE** — unusual findings (cryptographic signatures, per-dive salting, identical profiles with non-identical bytes) trigger a conversation before further spend.

## Phase 2 — Implementation

### File layout

All new code lives under `lib/features/universal_import/data/services/`:

```
macdive_db_reader.dart         (exists)   — calls the decoder, stores typed samples
macdive_dive_mapper.dart       (exists)   — line ~334 stops emitting profile: []
macdive_raw_types.dart         (exists)   — MacDiveRawDive gains `samples` field
macdive_samples_decoder.dart   (new)      — public entry point, pure function
macdive_samples/               (new; conditional)
    macdive_sqlite_sample.dart           — typed model, mirrors MacDiveXmlSample
    variants/                             — only if >1 format variant exists
        <variant>_decoder.dart
```

The `variants/` directory is created only if Phase 1 confirms multiple format families. A single-family decoder stays a single file.

### Typed model

`MacDiveSqliteSample` has field names and units identical to `MacDiveXmlSample` so downstream projection code doesn't branch on source:

```dart
class MacDiveSqliteSample {
  final Duration time;
  final double? depthMeters;
  final double? pressureBar;        // tank pressure if present
  final double? temperatureCelsius;
  final double? ppO2;               // bar
  final int? ndlSeconds;
  // Additional fields if Phase 1 reveals them: heartRate, setpoint, event markers.
}
```

Values are stored in SI canonical units. The decoder reads `ZMETADATA.SystemOfUnits` from the caller and delegates any imperial→SI conversion to the existing `MacDiveUnitConverter`.

### Decoder API

Pure function, no I/O, fully testable in isolation:

```dart
class MacDiveSamplesDecoder {
  const MacDiveSamplesDecoder();

  /// Returns decoded samples in SI canonical units.
  /// Throws MacDiveSamplesDecodeError if the blob is malformed or the header
  /// variant is unknown. Returns [] for a header-only blob (no sample body).
  List<MacDiveSqliteSample> decode(
    Uint8List blob, {
    required MacDiveUnitSystem units,
    required MacDiveUnitConverter converter,
  });
}

class MacDiveSamplesDecodeError implements Exception {
  final String reason;           // e.g. "unknown header variant 0x9D"
  final int? offendingOffset;    // for debug / warning surfaces
  const MacDiveSamplesDecodeError(this.reason, {this.offendingOffset});
}
```

### Reader integration

`MacDiveDbReader`'s per-dive loop decodes the blob immediately after reading it. Errors become per-dive warnings on the logbook:

```dart
try {
  final decoded = (samplesBlob == null)
      ? const <MacDiveSqliteSample>[]
      : decoder.decode(samplesBlob, units: units, converter: converter);
  dive = dive.copyWith(samples: decoded);
} on MacDiveSamplesDecodeError catch (e) {
  warnings.add(ImportWarning.sampleDecodeFailed(
    diveUuid: dive.uuid,
    reason: e.reason,
    offendingOffset: e.offendingOffset,
  ));
  dive = dive.copyWith(samples: const <MacDiveSqliteSample>[]);
}
```

`MacDiveRawDive` gains `samples: List<MacDiveSqliteSample>` (non-nullable, empty by default). The existing `samplesBlob: Uint8List?` field remains for diagnostic use during the ramp-up period; it can be removed once the decoder is proven.

### Mapper integration

`MacDiveDiveMapper._buildDiveMap()` replaces the current `map['profile'] = const <Map<String, dynamic>>[];` line with a projection of `dive.samples` into payload maps. The projection duplicates the 10-line helper from `MacDiveXmlParser` (lines 279-291). The two are intentionally independent:

- Rationale: `MacDiveXmlSample` and `MacDiveSqliteSample` have identical shape today, but they represent different upstream formats and will evolve on different schedules. A shared projection would couple them.
- Cost of duplication: ~10 lines of trivial mechanical code.
- Benefit of duplication: each format owns its projection; changes to one don't risk the other.

### Warning flow

New variant on `ImportWarning`:

```dart
ImportWarning.sampleDecodeFailed({
  required String diveUuid,
  required String reason,
  int? offendingOffset,
});
```

The wizard UI already renders `ImportWarning`s. Polish: if more than 10 warnings share the same `reason` field, collapse to one aggregated line (`"N dives: <reason>"`). Single-line helper, single test. Worth including because un-decodable blobs will cluster by format variant.

## Testing

### Layer 1 — decoder unit tests

File: `test/features/universal_import/data/services/macdive_samples_decoder_test.dart`
Fixtures: `test/fixtures/macdive_sqlite/zsamples_golden/` (committed, each ≤1KB, redacted if needed).

Coverage targets:
- Each header variant Phase 1 surfaces (`0x19`, `0x9D`, any others).
- Boundary conditions: zero samples (header-only), single sample, maximum observed blob size.
- Unit handling: imperial-unit blob decoded with `MacDiveUnitSystem.imperial`, metric with `MacDiveUnitSystem.metric`.
- Malformed input: truncated body, unknown header variant, garbage bytes after a valid header.

### Layer 2 — decoder golden tests

Same test file, separate group. Decode committed fixture → JSON → `expect(jsonEncode(decoded), matchesGoldenFile('...'))`. Catches any regression that changes byte interpretation.

Curated fixture set: one per header variant, one per combination of optional fields (pressure present/absent, ppO2 present/absent, etc.), one minimal. Target ≤10 fixtures, each <1KB.

**Redaction rule:** any field that could identify a user or computer (serial numbers, timestamps corresponding to real dives) is byte-patched to zero in the committed fixture.

### Layer 3 — real-sample regression (gated)

File: `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart`

Pattern matches the existing `macdive_xml_real_sample_test.dart`:
- Skipped in CI (no fixtures committed — user's dive log is private).
- Runs locally with `flutter test --dart-define=MACDIVE_SQLITE_SAMPLE=/path/to/MacDive.sqlite --dart-define=MACDIVE_UDDF_SAMPLE=/path/to/sync.uddf --run-skipped --tags=real-data test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart`.

Assertions:
- Every dive with non-null `ZSAMPLES` in the SQLite file produces either a decoded profile or a per-dive warning — no silent data loss.
- For every dive UUID present in both SQLite and UDDF, decoded profiles match within tolerance: timestamp exact, depth ±0.1m, temperature ±0.5°C, sample count ≥ UDDF count × 0.95.
- Total warnings count is bounded (e.g., <5% of dives with `ZSAMPLES`).

## Error handling

| Failure | Response |
|---|---|
| Blob is `null` | `samples = []`, no warning. Normal for manual dives. |
| Blob has known header but truncated body | Throw `MacDiveSamplesDecodeError("truncated at byte N")`, catch in reader, emit warning, `samples = []`. Dive metadata still imports. |
| Blob has unknown header variant | Throw `MacDiveSamplesDecodeError("unknown header variant 0x%02X")`, same recovery. |
| Decoded samples violate sanity bounds (depth < 0 or > 1000m, timestamps non-monotonic) | Decoder returns samples anyway. Post-decode validation in the mapper nulls out offending fields and emits a warning. |

A decode failure never halts the import or drops the dive record. Profile decoding is strictly additive.

## Rollout

### Branch topology

```
main
 │
 ├── feature/macdive-sqlite                       (PR #256, open)
 │    └── feature/macdive-sqlite-profiles         (new; this spec)
 │
 └─── merges in order: #256 first, then profiles PR
```

The profiles PR targets `feature/macdive-sqlite`, not `main`, preserving review stackability. When #256 merges, this branch rebases onto `main` and re-targets.

### Sequencing

1. Cut `feature/macdive-sqlite-profiles` from `feature/macdive-sqlite`.
2. Phase 1 commits: scripts under `scripts/reverse_engineering/zsamples/`, format spec under `docs/import-formats/macdive-zsamples.md`, plan update recording the go/no-go decision.
3. If GO: Phase 2 commits add the decoder, types, reader/mapper wiring, and tests.
4. If NO-GO: spec closed, new spec initiated for ZRAWDATA fallback. Phase 1 artifacts remain in-repo for future reference.

### Plan alignment

Append a link to this spec at the tail of `docs/superpowers/plans/2026-04-21-macdive-sqlite-import.md` so future readers can find the continuation.

## Open questions

None material at spec-approval time. Phase 1 will surface any; they get resolved inline in `docs/import-formats/macdive-zsamples.md` before Phase 2 starts.

## Phase 1 outcome (recorded 2026-04-23)

**Decision:** NO-GO on `ZSAMPLES` decoding. PIVOT to `ZRAWDATA` via libdivecomputer.

**Summary of findings:** The Phase 1 spike successfully built all tooling (`extract_corpus`, `blob_inspect`, `compression_probe`, `differ`, `batch_score`) and characterised the `ZSAMPLES` format, but did not crack it. Specifically:

- The second header word (`bytes 4–7` LE) perfectly predicts the per-sample record stride: `16→12`, `24→16`, `25→20`, `156→24`, `157→28` bytes per sample (arithmetic progression, step 4). This is a clean, reusable finding.
- All standard compression codecs (gzip, zlib, raw DEFLATE, lzma, bz2, lz4 frame/block, zstd, LZFSE) were probed at every offset 0..63 across all 348 paired fixtures. No plausible hits (29 tiny false positives under `raw_deflate` only).
- XOR-with-fixed-key obfuscation eliminated via pair-entropy analysis (XOR of similar dives produced 7.4–7.9 bits/byte, essentially indistinguishable from the random baseline of 7.95).
- The first 28-byte record in many fixtures has a constant 8-byte prefix and constant 8-byte trailer surrounding a 16-byte variable payload — consistent with block-cipher encryption.

Without the encryption key (would require static analysis of the MacDive binary), `ZSAMPLES` is not decodable within a bounded investigation timebox.

**Pivot rationale:** Every Shearwater dive in the sample DB has **both** `ZRAWDATA` and `ZSAMPLES` (267 of 267). `ZRAWDATA` holds the raw Shearwater sensor dump, which the already-integrated `libdivecomputer_plugin` can parse. The pivot gives 267/540 = 49% of all dives (76% of dives with any sample data) via a certain, maintained code path, vs. the theoretical 65% via a speculative `ZSAMPLES` decoder.

**Artifacts produced:**
- `docs/import-formats/macdive-zsamples.md` — full Phase 1 findings document.
- `scripts/reverse_engineering/zsamples/` — retained tooling and 19 passing pytest tests.
- Phase 2 plan (pivot): `docs/superpowers/plans/2026-04-23-macdive-profile-phase-2-zrawdata.md`.

**Decisions for Phase 2 under the pivot:**
- Decoder target: `ZRAWDATA` column, not `ZSAMPLES`.
- Implementation: thin adapter over `libdivecomputer_plugin`, calling the Shearwater parser family.
- Coverage fallback: dives without `ZRAWDATA` continue to emit `profile: []` with an `ImportWarning`. Current user behavior for those dives (use UDDF import for profile data) is preserved.
- Architecture (`MacDiveSamplesDecoder` / `MacDiveSqliteSample`) from the original spec is retained — the decoder body changes, the public interface does not.
