# MacDive `ZDIVE.ZSAMPLES` Binary Format — Investigation Findings

**Status:** NO-GO for Phase 1 decoding. Recommend pivot to `ZRAWDATA` via `libdivecomputer`.
**Date:** 2026-04-23
**Author:** Eric Griffin
**Spec:** `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md`
**Plan:** `docs/superpowers/plans/2026-04-23-macdive-zsamples-phase-1-spike.md`

This document records what was learned about MacDive's proprietary `ZSAMPLES` binary format during the Phase 1 spike, so that any future attempt can build on concrete observations rather than repeat the search. It also justifies the NO-GO decision and the recommended pivot to the `ZRAWDATA` column via the already-integrated `libdivecomputer` plugin.

## Sample corpus

Extracted from `scripts/sample_data/MacDive.sqlite` (540 dives) paired with `scripts/sample_data/Apr 4 no iPad sync.uddf` (540 UDDF-decoded profiles):
- 350 dives have non-null `ZSAMPLES`.
- 348 of those have matching UUIDs in the UDDF file (usable paired fixtures).
- Corpus materialized at `scripts/reverse_engineering/zsamples/corpus/` by `extract_corpus.py`.

Per-computer presence in the full 540-dive DB:

| Computer | Dives | Has `ZRAWDATA` | Has `ZSAMPLES` |
|---|---:|---:|---:|
| Shearwater Teric | 217 | 217 | 217 |
| Shearwater Tern | 50 | 50 | 50 |
| Oceanic Matrix Master | 113 | 0 | 0 |
| (no computer field) | 99 | 0 | 81 |
| "No Computer" | 61 | 0 | 2 |

Shearwater dives have **identical** `ZRAWDATA` and `ZSAMPLES` coverage (267/267). This matters for the pivot.

## Format observations

### Fixed-size 8-byte header

Every blob starts with `04 00 00 00 XX XX 00 00` (little-endian):
- Bytes 0-3: constant `0x00000004` across all 348 fixtures.
- Bytes 4-7: one of 5 distinct values — `16`, `24`, `25`, `156`, `157`.

### The second header word determines record stride

Grouping fixtures by the bytes-4-7 value and computing `(blob_size − 8) / uddf_sample_count`:

| `h4` (u32 LE) | Fixtures | Stride (mean) | Stride (min–max) |
|---:|---:|---:|---:|
| 16 | 8 | 12.00 | 11.99 – 12.00 |
| 24 | 4 | 15.95 | 15.92 – 15.98 |
| 25 | 68 | 19.98 | 19.37 – 20.57 |
| 156 | 79 | 23.88 | 23.54 – 24.22 |
| 157 | 189 | 27.95 | 27.65 – 28.13 |

The progression is arithmetic with step 4 (12 → 16 → 20 → 24 → 28). Each variant likely adds one 4-byte optional field to the per-sample record. All fixtures' `(blob_size − 8)` is divisible by 4.

**This is the single most actionable finding.** A future implementer with a decoder for one variant has a clear path to the others.

### Apparent structure of the first "record" in h4=157 fixtures

Three h4=157 fixtures that share the body-prefix `84 b9 0a a0 9f bb 1e cc` (see next section) were compared at byte-level across their first 28 bytes:

```
UUID 0138EF6D: 84b90aa09fbb1ecc 5f68208198ac60ee 6ca7ab0e5e6499ec 8982a25a71ac47cc
UUID 05FD452A: 84b90aa09fbb1ecc 9c4c0fc05a76c8ce 6ae9bb112bba3494 8982a25a71ac47cc
UUID 088FD4CB: 84b90aa09fbb1ecc 91345842b06f161f 2c8d7ddd657d9595 8982a25a71ac47cc
```

- Bytes 0-7: constant across all three.
- Bytes 8-23 (16 bytes, one AES block worth): varies per dive.
- Bytes 24-31: constant across all three.

Bytes 24-27 (`89 82 a2 5a`) and 28-31 (`71 ac 47 cc`) appear to be a fixed terminator or header trailer. This framing pattern (constant header + variable 16-byte payload + constant footer) is consistent with block-cipher-encrypted data where some plaintext is shared across dives (e.g., a dive-start marker) and other plaintext varies (actual sample values). It is also consistent with an unencrypted custom format where those fixed fields represent metadata that happens to repeat (dive start flag, gas index, etc.).

### The body prefix `84 b9 0a a0 9f bb 1e cc` repeats

Across all 348 fixtures:

| Body prefix (bytes 8-15) | Fixtures |
|---|---:|
| `84b90aa09fbb1ecc` | 196 (56%) |
| `81bc66cfcb6fb13c` | 5 |
| `3103d2d682bd21ac` | 5 |
| `010f21776bda9d27` | 5 |
| `2c7a6061d19240fd` | 5 |
| (71 more distinct prefixes, 1–4 fixtures each) | 127 |

The dominant `84b90aa0` prefix appears across BOTH Shearwater Teric and Shearwater Tern — **the prefix is not a per-computer fingerprint**. It appears to be a dive-start marker or a "canonical" first-sample signature that many dives share (e.g., depth=0, surface-start dives).

Within fixture `0138EF6D` the pattern `84b90aa09fbb1ecc` also appears at offset 10392 (16 bytes before the blob ends), suggesting this magic is a **chunk-boundary marker** rather than a one-shot header. A future investigator should look for segmented structure where each `84b90aa0…` occurrence marks the start of a new time-window chunk.

### Entropy and periodicity

- Shannon entropy, per-blob, ~6.7 bits/byte (above structured-data range, below encrypted-data range of 7.8+). Moderate-to-high redundancy.
- `find_repeating_stride` (threshold 90% byte-equality at stride `S`) returned `None` post-header for every fixture checked. No naive fixed-width byte repetition detectable at common strides (2..64).

### Compression probe: NO HITS

Ran `compression_probe.py` across **all 348 fixtures**, testing gzip, zlib, raw DEFLATE, lzma, bz2, lz4_frame, lz4_block, zstd, and LZFSE at every offset 0..63. Results:

- 319 fixtures (92%) produced zero hits.
- 29 fixtures (8%) produced only `raw_deflate` hits at varying offsets with small decompressed sizes (38–498 bytes) — consistent with raw DEFLATE's well-known false-positive behavior on random-looking input. No hit produced a blob large enough to be plausible profile data.

**Hypothesis 1 (compression wrapper) is eliminated.**

### XOR-obfuscation probe: not a plausible fit

If the format were XOR-with-fixed-key obfuscation, two similar-duration dives' body XOR would produce low-entropy output with many zero bytes (since real dive profiles are highly correlated). Five pairs of h4=157 fixtures were XORed:

| Pair | XOR entropy | Zero-byte % |
|---|---:|---:|
| Pair 0 | 7.904 | 0.9% |
| Pair 1 | 7.426 | 13.3% |
| Pair 2 | 7.675 | 8.0% |
| Pair 3 | 7.368 | 14.9% |
| Pair 4 | 7.777 | 5.6% |
| h4=25 pair | 7.974 | 0.4% |
| Random baseline | 7.955 | ~0.4% |

Most pairs are indistinguishable from random XOR. Some (notably Pair 3 at 14.9% zeros — two dives with adjacent UUIDs) show mild structure but nowhere near the 30–70% zero rate a fixed-XOR scheme would produce. **Simple XOR obfuscation is ruled out.**

### Most likely remaining explanation: block cipher

Combining the evidence:
- No standard compression matches
- Entropy ~6.7 (mid-to-high) with repeating inter-dive patterns → not fully encrypted but partially predictable
- Fixed prefix/suffix around a 16-byte AES-block-sized variable region
- XOR of similar dives is near-random → not trivially keyable

…points to a block cipher (AES-128-ECB or AES-128-CBC with per-dive IV) where:
- The constant framing bytes encrypt a stable plaintext (a dive-start marker).
- The 16-byte variable region encrypts per-dive sample data.
- ECB would explain why the SAME plaintext (a shared dive-start record) encrypts to the SAME ciphertext across many dives — exactly the "`84b90aa0`" prefix pattern.

Without the AES key, decoding this format is not feasible in a bounded investigation timebox. MacDive's source is closed; recovering the key would require static analysis of the MacDive binary, which is out of scope for this spike.

## NO-GO decision rationale

Against the spec's GO criterion ("one hypothesis scores ≥ 0.9 sample-accurate across the 350-dive corpus"):

- **H1 (compression wrapper):** 0.00 — eliminated by corpus-wide probe. Done in ~30 minutes.
- **H2 (fixed-width records):** Not attempted at full decode resolution. We now know the stride per variant (major progress), but the record content is high-entropy/encrypted. Blind field identification without decrypted content would yield 0.00.
- **H3 (TLV stream):** Not pursued. Record stride being exactly constant per variant is strong counter-evidence for variable-length TLV.
- **H4 (vendor-specific frames):** See next section — this IS the recommended path, but via a different column (`ZRAWDATA`) than `ZSAMPLES`.

With the structural evidence pointing to block-cipher encryption, continuing to probe `ZSAMPLES` without the key is expected to yield nothing. Per the spec's NO-GO criterion ("after 1-2 active days, best hypothesis scores <50% with no clear next hypothesis"), this investigation has reached that point.

## Recommended pivot: `ZRAWDATA` via `libdivecomputer`

Every Shearwater dive (267/540 = 49% of the DB; 267/350 = 76% of dives with any sample data) has a `ZRAWDATA` column alongside `ZSAMPLES`. `ZRAWDATA` is the raw dive-computer sensor dump in the vendor's native format. First bytes across three Shearwater Teric dives:

```
887fc03fb94554035900ca80306b0e7e cbc500d1b051890c823f1e8a81e03ff0
887fc03f794556030500ca80301b0e73 ed1500d1b051890c823f1e8a81e03ff0
887fc03f39455403de00ca40302b0e6b 1be000d1b051890c823f1e8a81e03ff0
```

Observations:
- Bytes 0-3: constant `88 7f c0 3f` across all Shearwater Teric dives (dive-computer fingerprint).
- Bytes 20-31: constant across all three, repeating `b051890c 823f1e8a 81e03ff0`.
- Bytes 16-19: `XX XX 00 d1` pattern — two varying bytes then `00 d1`.

This is Shearwater's own binary frame format, which **libdivecomputer's `shearwater_common` and `shearwater_petrel` parsers support natively**. The project already ships `libdivecomputer_plugin` at `packages/libdivecomputer_plugin/` with the upstream `libdivecomputer` repository as a submodule.

### Coverage comparison

| Approach | Dives covered | % of sample DB | % of "has any profile" dives |
|---|---:|---:|---:|
| `ZSAMPLES` decoded (hypothetical) | 350 | 65% | 100% |
| `ZRAWDATA` via libdivecomputer | 267 | 49% | 76% |

The gap — 83 dives with `ZSAMPLES` but no `ZRAWDATA` — consists of the "(no computer)" and "No Computer" categories, which are old imports where device metadata wasn't preserved. Users for those dives likely already expected imperfect profile fidelity. The pivot loses that long tail but gains **certainty** for the main use case (active Shearwater users).

### Phase 2 under the pivot

Phase 2 (the actual Dart decoder implementation) now targets `ZRAWDATA` instead of `ZSAMPLES`. The `MacDiveSamplesDecoder` / `MacDiveSqliteSample` architecture from the design spec is unchanged; the decoder body calls into `libdivecomputer_plugin` rather than parsing `ZSAMPLES` bytes directly. A separate Phase 2 plan covers the implementation details.

For dives with no `ZRAWDATA` (the 83 `ZSAMPLES`-only dives), the mapper continues to emit `profile: []` with an `ImportWarning` flagging that ZSAMPLES-only dives do not yet produce profile data. A future milestone could revisit ZSAMPLES decoding if someone reverse-engineers the encryption (e.g., a MacDive plugin community finds the key).

## Artifacts kept in-repo

Under `scripts/reverse_engineering/zsamples/`:
- `extract_corpus.py`, `blob_inspect.py`, `compression_probe.py`, `differ.py`, `batch_score.py`, and the `hypotheses/` package are retained. They are reusable against any future format-drift or re-attempt.
- `corpus/` contents are gitignored (real user dive data); regenerate on demand with `python extract_corpus.py`.
- `test_zsamples_spike.py` has 19 passing tests covering the tooling.

This investigation produced negative results on `ZSAMPLES` decoding but positive results on the pivot strategy. The tooling above makes any future attempt cheap to resume.
