# App Performance Investigation — Design

**Date:** 2026-06-24
**Status:** Design approved; measurement phase not yet started
**Branch/worktree:** `worktree-app-performance-investigation`

## Goal

Investigate and improve three observed performance symptoms, measuring first so
every fix is justified by data rather than guessed from code:

1. **App load time** — cold-start time before the app is usable.
2. **First dive-details lag** — a small delay rendering the dive-details page.
3. **Background-sync stutter** — slight UI jank while a sync runs.

Target platform for this effort: **macOS** (the developer's everyday machine,
where the symptoms are observed and which is the easiest to profile).

## Non-goals

- We do **not** commit up front to the largest architectural change (moving the
  database off the UI isolate). It is catalogued as a decision-gated avenue
  (S4) and only pursued if targeted fixes leave a symptom unsolved, with its
  own follow-up spec.
- We do **not** optimize for large libraries beyond noting scale-gated avenues
  (e.g. L7). The measured library is small (37 dives); fixes are prioritized for
  that real shape, with large-library items flagged for the future.

## The shared root cause (why one lever helps all three)

The app deliberately uses Drift's **synchronous `NativeDatabase`** rather than
`createInBackground` (`lib/core/services/database_service.dart:98-106`, with a
comment stating this avoids "isolate communication issues during migration").
Consequently **every** database open, migration, query, and sync write runs on
the UI isolate. Combined with **un-debounced reactive rebuilds**
(`watchDivesChanges` / the 22-table `watchDiveDetailChanges` have no
`.distinct()`/debounce), this single architectural fact is the multiplier behind
all three symptoms. It is good news for sequencing: a small number of targeted
fixes (and, if ever needed, the one gated architectural lever) improve startup,
details render, and sync smoothness together.

## Measured data shape (ground truth, 2026-06-24)

Read read-only from the live DB at
`~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db`:

| Metric | Value |
| --- | --- |
| Divers | 1 |
| Dives | 37 |
| Profile samples | 40,933 (avg 1,106/dive, **max 3,644**) |
| Tank-pressure samples | 40,912 (≈1:1 with profile samples) |
| Media (photos) | 434 |
| Species (seeded) | 550 |
| Dive sites | 19 |
| Equipment | 31 |
| Sightings | 17 |
| Dive computers | 3 |
| Pending sync records | 0 |
| Deletion-log rows | 62 |
| DB file size | 22 MB |
| Schema version | 91 (current) |

Timestamps confirm **1-2 second sample intervals** — dense, dive-computer
profiles. The densest dive (`0822a39f-26fd-4119-bdaa-673ea4562da3`, 3,644
samples) is the worst-case render target.

**Key implication:** the symptoms are driven by **profile sample density and
write volume**, not dive count. A static read of the code flagged the
full-library `getAllDives` load as a top startup bottleneck; the data refutes
that for this library (37 dives loads trivially). This is the measure-first
principle paying off before any fix is written.

---

## Section A — Measurement protocol (ad-hoc DevTools, profile mode)

No instrumentation is added to the repository. We profile `flutter run --profile
-d macos` with DevTools attached, except startup which uses a trace file. The
methodology's accepted trade-off: no durable re-measure harness, so each fix is
verified by re-running the relevant repro by hand (before/after).

Performance must be read in **profile mode**, never debug — debug builds are
unoptimized and routinely 5-10x slower, which would overstate every symptom and
mis-rank the culprits.

### Scenario 1 — Cold start / load time

- Capture with `flutter run --profile --trace-startup`, which writes
  `build/start_up_info.json` (`timeToFirstFrameMicros`,
  `timeToFirstFrameRasterizedMicros`, framework-init timings) and a saved engine
  timeline openable in Perfetto/DevTools.
- Decompose against the **known ~1.9 s artificial floor**
  (`lib/core/presentation/pages/startup_page.dart:191` — a 1 s hard minimum via
  `Future.delayed`, plus `:110` — a 900 ms fade controller).
- Decision the numbers settle: if real init work is **shorter** than the floor,
  the floor is the binding constraint (fix = shrink it); if **longer**, CPU-
  profile the init to attribute time (species re-seed, double DB open, redundant
  raw `sqlite3` opens).

### Scenario 2 — First dive-details lag

- Open the **densest dive** (`0822a39f-26fd-4119-bdaa-673ea4562da3`, 3,644
  samples) for the worst case, then a typical ~1,100-sample dive for contrast.
- Record the **CPU profiler** + the **Frames** chart. Open **cold** (first open
  after launch), then close and reopen **warm**. The cold−warm delta isolates
  cold-cache/query cost; the warm cost isolates the per-build chart + compute.
- Read the flame chart for: the provider fan-out
  (`lib/features/dive_log/presentation/pages/dive_detail_page.dart`, ~30
  `ref.watch`/`ref.read` sites), `FlSpot` list construction, and the chart's
  `reduce`/`sort`/`min`/`max` passes
  (`lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`).
- **Build-vs-raster split is the key read:** build-bound ⇒ our Dart (queries +
  `FlSpot`/axis computation) ⇒ fixes are memoization/decimation/`compute()`;
  raster-bound ⇒ GPU drawing too many points ⇒ fixes are `RepaintBoundary`/fewer
  points/simpler line styles.

### Scenario 3 — Background-sync stutter

- Requires an inbound change to exist (currently 0 pending sync records). Two
  repro paths:
  - *Faithful:* a second instance/device pushes edits to the same backend, then
    "Sync Now" on the Mac while recording.
  - *Local proxy:* a restore or file import triggers the same mass-write +
    reactive-rebuild path on one machine.
- Record the **Frames** chart during apply and watch for the **rebuild storm**:
  repeated `getAllDives` / `getStatistics` re-runs (and the `divesProvider` +
  `DiveListNotifier` double reload) firing per changeset, plus row-by-row writes
  of the ~80K profile/pressure rows.

### Deliverable

A short **findings report**: real numbers per scenario plus the attributed hot
spots. This becomes the evidence that ranks the fix backlog in Section B.

---

## Section B — Avenues backlog (ranked by the real data)

Each avenue: hypothesis → the measurement that confirms/refutes → candidate fix
→ risk/effort. ⭐ = likely first wave (high value, lower risk, data already
points here). 🔒 = decision-gated. Nothing is built until Section A confirms it.

### Load / cold start

| # | Avenue | Hypothesis | Candidate fix | Risk / Effort |
| --- | --- | --- | --- | --- |
| **L1** ⭐ | Shrink the artificial splash floor (`startup_page.dart:191`, `:110`) | The ~1.9 s floor exceeds real init at 37 dives, so it *is* the perceived load time | Reduce/remove the 1 s minimum (keep minimal anti-flicker); shorten or skip the fade when init already exceeded it | Low / Low |
| **L2** | Seed species once, not every launch (`species_repository.dart:372`) | Parses the bundled species asset and runs an `INSERT OR IGNORE` per species on every cold start (the live DB currently holds 550 species; confirm the asset's row count during measurement) | Gate behind a "seeded@dataVersion" marker; only run when the bundled data version changes | Low / Low |
| **L3** | Collapse redundant DB opens (`startup_page.dart:152`, `database_service.dart:178`, Drift open; second DB `local_cache_database_service.dart:44-58`) | Schema probe + compat assert + Drift each open the file; cache DB opened on the critical path | Consolidate the version probe/compat assert; open the cache DB lazily — **preserving the "DB newer than app" guard** | Med / Med |
| **L4** | Parallelize/defer pre-`runApp` awaits (`main.dart:61-68`) | SharedPrefs + app-support dir + log-service init run serially before the first frame | `Future.wait` the independent ones; defer log-service init off the critical path | Low / Low |
| **L6** | Migration ladder + pre-migration DB copy (`startup_page.dart:311`) | Only on version-bump launches; 22 MB copy is fast | Catalog; deprioritize | — / — |
| **L7** | `getAllDives` full-library hydration (`dive_repository_impl.dart:99-218`) | Negligible at 37 dives | Flag for future large-library users only | — (scale-gated) |

### First dive-details lag

| # | Avenue | Hypothesis | Candidate fix | Risk / Effort |
| --- | --- | --- | --- | --- |
| **D1** ⭐ | Memoize + decimate the profile chart (`dive_profile_chart.dart`) | 3,644 samples × several curves rebuilt every interaction (tooltip/playback/range/legend); `reduce`/`sort` each build | Cache computed `FlSpot`/axis ranges per (dive, settings, visible curves); **feature-preserving** decimation for display; `RepaintBoundary`; `compute()` if build-bound | Med / Med |
| **D2** | Lazy-load below-the-fold sections (~30-provider fan-out) | SAC/OTU/tide/segment queries hit the 40K-row tables on open | Defer each section's queries until its collapsible section expands; combine related queries; memoize | Low-Med / Med |
| **D3** | Cold-vs-every-time attribution | Measurement branch, not a fix | If first-open-only ⇒ prewarm most-recent dive's providers post-launch; if every-time ⇒ it's D1/D2 | — |
| **D4** | Thumbnail (not full-res) media (434 media rows) | Image decode on open | Ensure details page decodes thumbnail-sized images (cache caps already applied in `main.dart`) | Low / Low |

### Background-sync stutter

| # | Avenue | Hypothesis | Candidate fix | Risk / Effort |
| --- | --- | --- | --- | --- |
| **S1** ⭐ | Debounce/coalesce the rebuild storm (`dive_repository_impl.dart:50-94`; `dive_providers.dart:120,204,264-293`) | Per-changeset commits re-run `getAllDives` + `getStatistics` repeatedly; `divesProvider` + `DiveListNotifier` double reload | Add debounce/coalescing and/or `.distinct()`; de-dupe the double reload; consider fewer commits per apply — **must still deliver final state (no stale-after-sync regression)** | Low-Med / Low-Med |
| **S2** | Batch the sync writes (`sync_data_serializer.dart`, merge `sync_service.dart:1342-1510`; FK repair `:704-759`) | Row-by-row `upsert` + per-row `fetchRecord` + up-to-5 FK-check passes for ~80K rows | Use `batch()` bulk upserts; reduce/condition FK-repair passes — **preserving merge/LWW correctness** | Med / Med |
| **S3** | Offload sync CPU to an isolate (decode `changeset_codec.dart:17-18`; checksum `sync_data_serializer.dart:666-677`; merge) | JSON decode + SHA-256 + LWW run on the UI isolate | `compute()` the pure-CPU stages (DB-write stage is harder; ties to S4) | Med-High / High |
| **S4** 🔒 | Root-cause lever: move the DB off the UI isolate (`createInBackground`) (`database_service.dart:98-106`) | Fixes load, details queries, *and* sync writes at once — but exactly what the team avoided for migration safety | Decision-gated; its own spec/spike; only if targeted fixes leave a symptom unsolved | High / High |

---

## Section C — Sequencing & success criteria

### Phases

1. **Measure.** Run the Section A protocol; produce the findings report.
2. **First wave.** Implement the data-validated wins (likely **L1, D1, S1**),
   each on its own branch/PR per project conventions, **re-running the relevant
   repro before/after to prove the number moved**.
3. **Follow-ons.** Implement further avenues as measurement justifies them.
4. **Decision gate.** Only consider **S4** if targeted fixes leave a symptom
   unsolved; it gets a dedicated spec/spike before any code.

### Success criteria

- **Proof-by-measurement:** every claimed improvement is backed by a before/after
  DevTools number (the measure-first contract).
- **Load:** real time-to-interactive is the binding constraint, not an artificial
  floor.
- **Details:** the 3,644-sample dive opens within frame budget (no dropped
  frames); warm reopen stays smooth under interaction.
- **Sync:** a representative inbound sync/import holds frame budget — no visible
  stutter.
- **No regressions:** test suite green; sync merge/LWW correctness unchanged;
  dive-profile fidelity preserved (see constraint below).

### Domain & safety constraints

- **Feature-preserving decimation (D1).** A naive "every Nth point" downsampler
  can erase exactly what divers need to see — max-depth spike, decompression
  ceiling, gas-switch transition, safety-stop. Any decimation must be peak-aware
  (e.g. LTTB or min/max-per-bucket) and must never drop event-flagged samples.
  Pull in the tech-diving domain knowledge when implementing D1.
- **Debounce must not drop state (S1).** Coalescing reactive rebuilds must still
  deliver the final post-sync state; prior bugs in this codebase were
  stale-after-sync, so the fix must converge on the latest data.
- **Preserve migration safety (L3).** Consolidating DB opens must keep the
  "database newer than app" guard that prevents opening an incompatible schema.
