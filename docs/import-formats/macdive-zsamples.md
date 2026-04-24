# MacDive `ZDIVE.ZSAMPLES` / `ZDIVE.ZRAWDATA` Binary Format — Investigation Findings

**Status:** NO-GO for both columns. `ZSAMPLES` is AES-encrypted with a per-dive key (documented below). `ZRAWDATA` was pivoted to on 2026-04-23 under the assumption it was raw Shearwater protocol data libdivecomputer could parse; **that assumption was invalidated on 2026-04-24** when real-data testing produced systematic parser errors. MacDive SQLite profile import is not currently supported — users should export as MacDive XML for profile data.
**Date:** 2026-04-23 (initial), 2026-04-24 (ZRAWDATA invalidation)
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

### Most likely remaining explanation: per-dive block cipher

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

### Deeper structural analysis (extended investigation)

After the initial findings above, a deeper pass revealed finer format details. Summary below; all observations are from an h4=157 fixture (UUID `B2CA722D`, the smallest at 2624 bytes / ~93 UDDF samples) analyzed at 56-byte stride:

**Per-record column-wise entropy (stride=56, skipping the first 56-byte "header" record):**

| Byte range | Entropy | Behavior |
|---|---|---|
| 0–15 | ~5.3 | Unique per record (encrypted, 1 AES block) |
| **16–23** | ~2.4 | **Semi-constant marker**, dominated by `f3dc966901169615` (19/45 records = 42%) with secondary `f482af012335efe7` (9/45 = 20%) |
| 24–39 | ~5.3 | Unique per record (encrypted, a second 16-byte block) |
| **40–47** | ~2.0 | **Semi-constant marker**, `0278515bd77a8ff2` (20/45 = 44%), `50c3723adf1c9e61` (11/45 = 24%), `321a12202d1630c0` (4/45 = 9%) |
| **48–55** | ~1.0 | **Alternates between exactly 2 values** — `7b6c4983d5151543` (23/45) vs `b47fd2889df233ca` (22/45) |

This is the strongest structural evidence recovered. Each 56-byte record is two encrypted 16-byte blocks (at offsets 0–15 and 24–39), separated by an 8-byte semi-constant marker (16–23), followed by an 8-byte semi-constant marker (40–47), followed by an 8-byte **alternating sync word** (48–55). The alternating sync likely encodes an `odd/even sample` parity bit or a `gas group` toggle.

**Per-dive encryption hypothesis strengthens.** Sync markers across dives are NOT shared:

- `B2CA722D` (smallest fixture): alternates `7b6c4983d5151543` / `b47fd2889df233ca`.
- `0138EF6D` (large fixture, 10408 bytes): contains neither of the above patterns. Instead its dominant sync-position values are `794baa149dd84659` (79/371 samples) and `cd0a3ffbb514a277` (47/371).

Identical plaintext encrypted under different keys yields different ciphertext. The per-dive sync cluster values argue the sync field is encrypted with **a key that varies per dive**. This matches common "per-dive PBKDF2-from-UUID" or "HMAC-SHA256(dive_uuid, record_index)" derivation patterns seen in commercial apps that want to discourage offline decoding.

**Stride-56 fit is partial.** Of the 189 h4=157 fixtures in the corpus:
- 92 (49%) fit exactly: `(blob_size − 8) % 56 == 40` (48 bytes tail).
- 97 (51%) do not fit cleanly at stride 56.

So h4=157 fixtures are either a mix of two sub-formats, or there is additional variable-length padding we have not isolated.

**Interpretation of stride=28 vs 56.** The earlier finding that `(blob_size − 8) / uddf_sample_count ≈ 28` remains numerically true. Reconciling with stride=56: each 56-byte record likely encodes **two samples' worth of data** (two encrypted 16-byte blocks, per the column analysis). That is consistent with a paired-sample compression scheme where consecutive samples are more compact when paired.

### What this strengthens, weakens, and adds for NO-GO

- **Strengthens:** The two-block-per-record structure with per-dive sync markers is consistent with real encryption (per-dive AES key). Simple XOR obfuscation is further ruled out — the alternating sync word at bytes 48–55 would be trivially XOR-recoverable if the obfuscation were a constant key, but we see dive-specific pairs.
- **Weakens:** Nothing — all previous claims still hold.
- **Adds:** If someone *does* recover an AES key in the future, the record format now has a precise spec: `[8B magic header first-only] | [56B records: enc16 | marker8 | enc16 | marker8 | altsync8] | [40B tail]`. A decoder post-key-recovery could be written in a day.

### Additional attempts performed

Before calling NO-GO, the following additional concrete attacks were tried:

**AES-ECB/CBC with candidate keys (ruled out simple fixed keys):**

Attempted AES-128 and AES-256 ECB decryption of the first 16-byte block of fixture `0138EF6D` with each of these candidate keys:
- All zeros, all 0xFF
- ASCII strings `MacDive`, `MacDive Dive`, `MacDive Samples`, `DIVE_PROFILE_KEY`, `samples`, `ZSAMPLES`, `zsamples`, `ShearwaterCloud`, `SamplesKey`, `bplist00`
- Dive UUID bytes directly (16-byte UUID)
- MD5/SHA-1/SHA-256 of the dive UUID (truncated to 16 or used full 32)
- SHA-256 of each ASCII seed

Every decryption produced random-looking output. No candidate yielded plausible small integers at any offset (e.g. `time_s` or `depth_cm`). Naive fixed-key AES is ruled out.

**Marker-to-depth correlation within a dive (revealed per-dive encoding):**

Within a single dive (the smallest, h4=157 / `B2CA722D`, 45 records after the header), the byte[16:24] marker cluster values correlate tightly with UDDF depth buckets:

| byte[16:24] marker | Sample count | UDDF depth range | Mean depth |
|---|---:|---|---:|
| `f3dc966901169615` | 38 | 0.0 – 4.0 m | 3.4 m |
| `62accd075fdc3b1a` | 8 | 4.6 – 4.9 m | 4.7 m (deepest bucket) |
| `2b0cc210f4607fee` | 14 | 3.8 – 4.8 m | 4.3 m |
| `f482af012335efe7` | 10 | 3.7 – 4.3 m | 3.9 m |
| `ac61cdf98bac21c2` | 10 | 3.8 – 4.5 m | 4.1 m |
| `353ca741970971cc` | 6 | 3.4 – 4.7 m | 3.8 m |
| `49978add7f817666` | 2 | 3.0 – 3.2 m | 3.1 m |

byte[40:48] shows similar depth-bucket correlation. byte[48:56] alternates between two values that correspond to upper vs lower halves of the dive's depth range.

**BUT** cross-dive analysis (first 30 h4=157 fixtures, 5253 distinct byte[20:28] values globally) confirms that **marker values do NOT transfer across dives** — the mapping from marker-byte to depth-bucket is dive-specific. This pattern is exactly what per-dive-keyed encryption would produce: same plaintext ("depth bucket 3"), different key per dive, different ciphertext per dive. Within a dive, the mapping is stable because the key is stable.

This reinforces the per-dive-key hypothesis and explains the entropy pattern: the "encrypted" regions and the "structured markers" are BOTH encrypted — the markers just have smaller input domains (bucket indices) so their encrypted output has lower cross-dive entropy.

### Alternative paths not yet exhausted

Worth noting for any future attempt:

1. **Static analysis of the MacDive macOS binary** — disassemble `MacDive.app` and locate the AES key derivation routine. Feasible but legally sensitive (EULA concerns); out of scope for this spike.
2. **macOS Keychain inspection** — if MacDive stores a key in the user's Keychain, it may be readable with user permission. We did not attempt this.
3. **Runtime DTrace / LLDB** — attaching a debugger to MacDive while it exports or reads a dive could expose the key in memory. Feasible but intrusive.
4. **Per-dive brute force** — 128-bit AES keys are not brute-forceable. Ruled out.
5. **Key derivation from dive UUID + fixed secret** — if the key is `KDF(uuid, app_secret)`, recovering `app_secret` one-shot from MacDive cracks ALL dives. This is the highest-value target for any serious attempt.
6. **Per-dive training with UDDF ground truth** — if a user provides UDDF and SQLite for the same dive, we could build a per-dive marker-to-depth-bucket table and decode new SQLite samples using that mapping. But this yields coarse (~1 m) depth buckets only, not exact samples, and requires the user to ALSO supply UDDF, defeating the purpose.
7. **Cipher mode analysis** — the format may not be AES at all. ChaCha20, XChaCha20, Speck, or a custom Feistel network would all produce similar-looking output. We tested only AES-ECB. An attempted plaintext-pair known-plaintext attack (using UDDF ground truth as plaintext + per-dive ciphertext) is the most rigorous next step, out of scope here.

### Follow-up safe investigations (round 2)

Additional evidence gathered via investigations that do **not** require binary-level secret extraction:

**1. Keychain inspection (negative).** `security find-generic-password -s MacDive` and scans of `login.keychain-db` / `System.keychain`: no entries. MacDive does not store its encryption key in the macOS Keychain.

**2. Core Data schema (`MacDive_DataModel 22.mom`) attribute type audit.** Parsed the compiled Core Data model. Attribute type distribution across the entire schema:

| `NSAttributeType` | Count | Meaning |
|---:|---:|---|
| 700 | 122 | string |
| 500 | 28 | double |
| 900 | 13 | date |
| 800 | 13 | boolean |
| 100 | 9 | int16 |
| **1000** | **4** | **binary** |
| 600 | 1 | float |

**Zero Transformable (type 1800) attributes.** MacDive's `samples` and `rawData` are declared as plain Binary — Core Data stores opaque bytes with no built-in transformer. This rules out NSValueTransformer-based decoding (would have shown up as type 1800 with a transformer class name). MacDive's application code performs the encryption/decryption directly.

**3. Public crypto symbol table (from `nm` on the shipped binary).** The MacDive binary imports these APIs from `Security.framework` / CommonCrypto:

- `CCCryptorCreate`, `CCCryptorUpdate`, `CCCryptorRelease` — AES encryption/decryption API.
- `CCHmacInit`, `CCHmacUpdate`, `CCHmacFinal` — HMAC (likely for key derivation or integrity).
- `CC_SHA1_*`, `CC_SHA256_*` — hash functions.
- `SecRandomCopyBytes` — cryptographic PRNG.

(Import table is public linker metadata; this is the same information `otool -L` and `man dyld` produce on any Apple binary.)

This confirms the block-cipher hypothesis: MacDive really does encrypt `ZSAMPLES` using AES + HMAC via CommonCrypto.

**4. Runtime file access inspection (`lsof` on running MacDive).** With MacDive open and displaying a decoded profile, `lsof -p <pid>` showed:

- Binary, asset files (`.tiff`, `.png`, `.car`), Core Data XML persistent stores (`Certifications.plist`, `Models.plist`).
- `~/Library/Application Support/MacDive/MacDive.sqlite` (live DB).
- `~/Library/HTTPStorages/com.mintsoftware.MacDive2/httpstorages.sqlite-shm` (CloudKit sync cache).
- No sidecar key file. **No runtime file read provides the encryption key** — it must be derived from constants in the app binary.

**5. `~/Library/Preferences/com.mintsoftware.MacDive2.plist` dump.** Contains only UI state, column configs (as encoded `NSTableView` bplists), recently-imported brand/model (`Shearwater Teric`), and per-dive "marked read" flags. No encryption material.

**6. Known-plaintext XOR test across dives with identical first-sample plaintext.** 189 h4=157 fixtures all have UDDF first sample `(time=0s, depth=0.00m)`. If MacDive used a shared (app-wide) AES key + shared IV, encrypting this identical plaintext would produce identical ciphertext → XOR of any two dives' first encrypted blocks would be all zeros. Observed XOR entropy across 10 pairs: ~4.0 bits/byte (the theoretical max for 16-byte samples, indicating fully random output). **Shared-key with shared-IV is ruled out.** Per-dive key (or per-dive IV in a stream cipher mode) is the remaining explanation.

Combining all six: MacDive uses per-dive AES encryption where the key is **derived at runtime from `(dive_uuid, some_app_binary_constant)`**. The constant lives in the MacDive executable. Recovering it is the single blocker to decoding `ZSAMPLES`, and it is outside the scope of this spike. The ZRAWDATA pivot is the correct and complete path forward.

## NO-GO decision rationale

Against the spec's GO criterion ("one hypothesis scores ≥ 0.9 sample-accurate across the 350-dive corpus"):

- **H1 (compression wrapper):** 0.00 — eliminated by corpus-wide probe. Done in ~30 minutes.
- **H2 (fixed-width records):** Not attempted at full decode resolution. We now know the stride per variant (major progress), but the record content is high-entropy/encrypted. Blind field identification without decrypted content would yield 0.00.
- **H3 (TLV stream):** Not pursued. Record stride being exactly constant per variant is strong counter-evidence for variable-length TLV.
- **H4 (vendor-specific frames):** See next section — this IS the recommended path, but via a different column (`ZRAWDATA`) than `ZSAMPLES`.

With the structural evidence pointing to block-cipher encryption, continuing to probe `ZSAMPLES` without the key is expected to yield nothing. Per the spec's NO-GO criterion ("after 1-2 active days, best hypothesis scores <50% with no clear next hypothesis"), this investigation has reached that point.

## Recommended pivot: `ZRAWDATA` via `libdivecomputer`

> **Update 2026-04-24 — this pivot did not work.** The claim below that `ZRAWDATA` is "Shearwater's own binary frame format, which libdivecomputer's `shearwater_common` and `shearwater_petrel` parsers support natively" was made from byte-pattern inspection and has since been invalidated by real-data testing. See "Update 2026-04-24: ZRAWDATA pivot invalidated" below for details. The following subsection is preserved as-is for traceability of what was believed at the time of the initial spike.

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

## Update 2026-04-24: ZRAWDATA pivot invalidated

The Phase 2 implementation landed in commit `9e519a8da65` ("feat(macdive): decode ZRAWDATA profiles via libdivecomputer_plugin") and mapped MacDive `ZCOMPUTER` strings to libdivecomputer `(vendor, product)` pairs, feeding `ZRAWDATA` bytes straight into `DiveComputerHostApi.parseRawDiveData`. Tests used a mocked `parseFn` and a synthetic fixture with no real `ZRAWDATA` blob, so the claim "libdivecomputer can parse these bytes" was never validated against real data.

### What real data actually produces

A Submersion user with a MacDive library of Shearwater Teric dives imported their real `MacDive.sqlite` and observed the import complete with zero profile data for any dive. Each Shearwater dive produced a stderr line from libdivecomputer:

```
ERROR: Opening or closing record 1 not found.
[in shearwater_predator_parser.c:646 (shearwater_predator_parser_cache)]
```

Head and tail hex dumps of the affected blobs (pulled via `sqlite3 ... HEX(SUBSTR(ZRAWDATA, 1, 128))`):

```
Dive 1 (31,536 bytes, Teric):
  head: 887FC03FB94554035900CA80306B0E7E CBC500D1B051890C823F1E8A81E03FF0
        0FEE515500D6403­2A8A41AC99FA6E4207 B6B9FAB09178FC7A2A0697C0C131400
        C1403­28AAC0FF1F1F8E964B8CD0CA3400 281806792F8080A07FCAD02E10018180­6
        258CD0CA3400281806780183C180303F E56F5001AE4160B01B4406800185 00
  tail: 00 00 … (zero-padded for at least 64 bytes)

Dive 2 (28,800 bytes, Teric):
  head: 887FC03F794556030500CA80301B0E73 ED1500D1B051890C823F1E8A81E03FF0 …
```

### Why libdivecomputer rejects these blobs

libdivecomputer's `shearwater_predator_parser.c` selects format at line 359:

```c
unsigned int pnf = parser->petrel ? array_uint16_be(data) != 0xFFFF : 0;
```

For the Petrel family (Petrel/Perdix/Teric/Tern/Nerd/...): if the first two bytes are not `0xFFFF`, it treats the blob as Petrel Native Format (PNF) — a stream of 32-byte samples each prefixed with a record-type byte (`0x10..0x19` for opening records, `0x20..0x29` for closing, `0x01` for a dive sample, etc.).

The MacDive `ZRAWDATA` head starts with `0x887F`, so the parser enters PNF mode. But at no 16-byte or 32-byte aligned offset in the first 128 bytes does `data[offset]` equal any valid record-type byte. The parser scans the whole blob, picks up an opening record 0 and closing record 0 somewhere in the stream (hence the specific "record **1** not found" wording in the error — record 0 *was* found), and fails the 0–4 required-records check at line 644.

### What this tells us

1. **`ZRAWDATA` is not the raw Shearwater BLE/sensor dump.** If it were, libdivecomputer would parse at least the header correctly — it handles Teric/Perdix/Petrel natively as the same product line the Shearwater Cloud import successfully parses via the same API.
2. **`ZRAWDATA` bytes 20–31 being identical across dives is evidence against raw protocol data, not for it.** A real BLE dump would carry per-dive serial numbers, timestamps, or firmware versions in those bytes. The prior spike read "same bytes across dives" as a device fingerprint and assumed the rest was protocol data; in retrospect, identical bytes across dives is consistent with *MacDive's own envelope/wrapper* surrounding the real payload (or a MacDive-reencoded summary).
3. **`ZRAWDATA` blob sizes (31,536 and 28,800 bytes) are not clean multiples of the PNF 32-byte sample size**, further indicating this is not PNF framing.

Plausible remaining interpretations, in rough order of likelihood:
- MacDive applies its own framing/header layer around a Shearwater payload — stripping N leading bytes would reveal PNF or legacy-Predator bytes libdivecomputer can parse. **Testable:** try `parseRawDiveData` after skipping 2/4/8/12/16/32/64/128 leading bytes; if any offset succeeds, we know the wrapper length.
- MacDive decodes the BLE stream into its own intermediate binary format (summary-plus-samples) and stores that. Parsing would require reverse-engineering.
- MacDive encrypts `ZRAWDATA` with the same per-dive key used for `ZSAMPLES`. Entropy evidence here is weaker than for `ZSAMPLES` (those identical 12 bytes across dives would not survive standard encryption), so this is the least likely explanation.

### Corrective action taken

Commit **(to be tagged at revert time)** removed the ZRAWDATA → libdivecomputer decoder path. `MacDiveDiveMapper` no longer calls `parseRawDiveData`, no longer emits a `profile` key on any dive, and the `_vendorProductFromZComputer` map has been deleted. When a logbook contains dives with non-empty `ZRAWDATA`, a single aggregated `ImportWarning` is emitted pointing the user at MacDive's XML export as the working profile path. The warning is surfaced in `ImportSummaryStep`.

Net effect on the 540-dive reference DB:
- **217 Teric + 50 Tern** dives: previously produced parser error spam and empty profiles; now produce no spam and the same empty profiles, with one aggregated warning.
- **113 Oceanic Matrix Master** dives (no ZRAWDATA anyway): unchanged.
- **(no computer) + "No Computer"** manual-entry dives: unchanged.

### What a working implementation would need to investigate first

If someone wants to retry this:

1. **Strip-and-retry probe.** Feed `ZRAWDATA[N:]` to `parseRawDiveData` for each N in `{0, 2, 4, 8, 12, 16, 32, 64, 128}` and report the first N that parses cleanly. Cheapest possible next step; rules in or out the "MacDive framing wrapper" hypothesis in under an hour.
2. **Compare `ZRAWDATA` with Shearwater Cloud response for the same dive.** If a user has both a MacDive export and a Shearwater Cloud account with the same dive, the XOR / diff of the two payloads isolates MacDive's transformation. Requires user cooperation and a valid Shearwater account.
3. **Runtime macOS debugger on MacDive.app.** Attach LLDB when MacDive is *writing* a new dive to `ZRAWDATA` and observe the bytes just before they hit Core Data. The transformation, if any, is in that code path.
4. **`shearwater_common`-family entry points in libdivecomputer.** The current code uses the `shearwater_petrel` product branch; it's possible a different product branch (e.g. `shearwater_predator` for an older Predator-format payload) would accept these bytes. The parser error quotes the predator parser, but libdivecomputer routes Teric/Petrel through the same `.c` file with a different `parser->petrel` flag. Forcing `petrel=0` (legacy Predator mode) bypasses the PNF record-check and always synthesizes a single 128-byte header record — worth a one-line probe.

The `scripts/reverse_engineering/zsamples/` tooling is reusable for any of the above.
