# App Performance — Phase 1 Findings

**Date:** 2026-06-24
**Spec:** docs/superpowers/specs/2026-06-24-app-performance-investigation-design.md
**Plan:** docs/superpowers/plans/2026-06-24-app-performance-phase1-measurement.md
**Mode:** profile, macOS

## Environment
- Flutter: 3.41.4 stable (framework ff37bef603, engine e4b8dca3f1)
- macOS: 26.5.1 (build 25F80)
- Mac: MacBook Pro (Mac17,8), **Apple M5 Pro**
- Display: Built-in Liquid Retina XDR, 3456x2234 Retina, ProMotion (up to 120 Hz)
- Frame budget: 8.3 ms @ 120 Hz / 16.7 ms @ 60 Hz — **confirm the actual budget line from the DevTools Frames chart** (Flutter macOS desktop may render at 60 Hz even on a ProMotion panel)
- Library shape (from the design spec): 37 dives, 40,933 profile samples (avg 1,106, max 3,644), 40,912 tank-pressure samples, 22 MB DB

## Scenario 1 — Cold start / load time

### Numbers
| Metric | Value |
| --- | --- |
| Time to first frame (engine -> splash) | **74 ms** (`flutter run --trace-startup`) |
| Perceived splash -> dashboard usable (cold, observed) | **~2 s** |
| Artificial floor (deterministic, from code) | **1.9 s** = 1 s minimum (`startup_page.dart:191`) + 0.9 s fade (`:110`) |

### Verdict
- Engine/framework init is **negligible** — 74 ms to first frame on an M5 Pro. NOT a contributor.
- Perceived load (~2 s) ≈ the artificial floor. Service init (DB opens, species seed) runs under the 1 s minimum (`Future.wait([_initializeServices(), Future.delayed(1s)])`), so at this library size it is **masked by the floor, not additive**.
- **L1 (shrink splash floor): CONFIRMED dominant.** ~1.5-1.8 s of perceived load is recoverable by reducing the 1 s minimum + 0.9 s fade to a minimal anti-flicker.
- **L2 (species re-seed) / L3 (redundant opens): not separately visible** — hidden under the 1 s minimum. They matter only once L1 lowers the floor below service-init time; quantify service-init (a cold-start CPU profile) when implementing L1.
- L4 (pre-runApp awaits): subsumed in the 74 ms first frame; negligible.

## Scenario 2 — First dive-details lag

Opened Dive #41 ("Alice in Wonderland", 3,644 samples) in profile mode; exact
Flutter.Frame build/raster timings + UI-isolate CPU samples pulled via the VM
Service (`scratchpad/vmcap.dart`).

### Numbers (Flutter frames)
| Open | Worst build | Raster (same frame) |
| --- | --- | --- |
| Cold | **35.6 ms** | 2.8 ms |
| Cold (next worst) | 27.5 / 27.1 / 26.8 / 24.0 / 23.6 ms | 2.4 / 2.2 / 18.4 / 17.7 / 0.8 ms |
| Warm (earlier run) | ~18.6 ms | ~17.5 ms |

### Verdict
- **Build-bound.** Worst cold frames are ~35 / 27 / 27 ms of **build** with only
  ~2-3 ms raster — the GPU is idle; the cost is Dart on the UI isolate. (Some
  fully-drawn frames also push raster to ~18-20 ms with all curves on screen.)
- **D1 (memoize + decimate): CONFIRMED, and it is a COMPUTE problem.** Reduce
  Dart work — cache computed `FlSpot`/axis data; feature-preserving decimation of
  the 3,644-sample series — which cuts build *and* the secondary raster cost. A
  `RepaintBoundary`/raster-only fix would not touch the 35 ms build.
- Named dive-specific hot function: `combineMultiTankPressures` (SAC/tank-pressure
  merge over the dense profile).
- Frame timings isolate the chart cleanly even with sync running concurrently:
  sync work cannot inflate a frame's *build* duration; it only drops extra frames.

## Scenario 3 — Background-sync stutter

Caught **live and unplanned**: during the cold dive-open, the on-launch auto-sync
was applying a base file on the main isolate. Clean UI-isolate CPU window
(n=24,278 @ 250us, clear -> act -> read):

### Numbers (top UI-isolate self-time)
| ms | % | function | attribution |
| --- | --- | --- | --- |
| 415 | 6.8 | `pread` | base-file I/O (sync) |
| 251 | 4.1 | `_Sha32BitSink.updateHash` | SHA-256 checksum (sync) |
| 244 | 4.0 | `sqlite3VdbeExec` | row writes (sync) + dive queries |
| 225 | 3.7 | `_GrowableList._grow` | list building |
| 220 | 3.6 | `BaseJsonStreamReader._captureByte` | JSON byte-parse (sync) |
| 192 | 3.2 | `read` | file I/O (sync) |
| 102 | 1.7 | `BaseJsonStreamReader.parse` | JSON parse (sync) |
| 59 | 1.0 | `BaseJsonStreamReader._consume` | JSON parse (sync) |
| 56 | 0.9 | `combineMultiTankPressures` | dive SAC (chart) |

### Verdict
- **The sync apply runs entirely on the main (UI) isolate**: SHA-256
  (`_Sha32BitSink`), streaming JSON parse (`BaseJsonStreamReader.*`), SQLite
  writes (`sqlite3VdbeExec` + LinkedHashMap row hydration), base-file I/O
  (`pread`/`read`). This is the #358 streaming base-apply path — memory-safe, but
  still 100% main-isolate CPU.
- **Sync fires on launch AND on resume / window focus** (`_maybeSyncOnResume`).
  Every refocus can run this apply, so the stutter is an everyday occurrence — and
  it is why a sync-free interactive capture was impossible (focusing the app to
  interact re-triggers sync).
- **S3 (offload sync CPU to an isolate): CONFIRMED high value.** SHA-256 + JSON
  parse are pure CPU and directly offloadable; that alone removes most of the
  observed main-isolate burden.
- **S2 (batch writes): CONFIRMED** — `sqlite3VdbeExec` + per-row map building =
  row-by-row apply.
- **S1 (debounce rebuild storm): NOT directly measured** (needs a multi-changeset
  sync with the dive list visible). Remains a sound but lower-confidence
  hypothesis than S2/S3.
- Strongest evidence yet for **S4** (move DB/sync off the UI isolate) as the
  root-cause lever: sync I/O and the chart build are serialized on one isolate.

## Avenue verdicts & Phase 2 ranking

### Verdicts (from measured numbers)
| Avenue | Status | Justifying number |
| --- | --- | --- |
| L1 splash floor | **CONFIRMED dominant** | 74 ms first frame vs ~1.9 s floor; ~2 s perceived |
| L2 species re-seed | not separately visible | hidden under the 1 s minimum |
| L3 redundant opens | not separately visible | hidden under the 1 s minimum |
| L4 pre-runApp awaits | refuted (negligible) | subsumed in 74 ms first frame |
| D1 chart memoize/decimate | **CONFIRMED (build-bound)** | 35 ms build / 2.8 ms raster cold |
| D2 lazy below-fold | likely | `combineMultiTankPressures` 56 ms on open |
| D4 media decode | refuted (not observed) | absent from samples |
| S1 debounce storm | hypothesis (unmeasured) | not captured this run |
| S2 batch writes | **CONFIRMED** | `sqlite3VdbeExec` + per-row maps |
| S3 offload sync CPU | **CONFIRMED high value** | SHA-256 251 ms + JSON parse ~380 ms, main isolate |
| S4 DB off UI isolate | strongly supported | sync I/O + chart build on one isolate |
| (new) sync-on-resume | observed | sync fires on every window focus |

### Phase 2 priority order (impact x inverse risk)
1. **L1 — shrink the splash floor.** ~1.5-1.8 s perceived-load win, tiny low-risk
   change. Do first.
2. **D1 — memoize + feature-preserving decimation of the profile chart.** Kills the
   35 ms cold build (and trims raster). Med risk (preserve max-depth/ceiling/
   gas-switch/safety-stop features). Highest-value details fix.
3. **S3 — offload the sync apply's pure CPU (SHA-256, JSON parse) to an isolate.**
   Directly removes the observed main-isolate stutter on launch/resume. Med-high risk.
4. **S2 — batch the sync row writes** (`batch()` vs row-by-row). Med risk.
5. **S1 — debounce/coalesce the reactive rebuilds.** Sound but unmeasured; low-med
   risk; pairs with S2/S3.
6. **D2 — lazy-load below-the-fold sections** (defer SAC/`combineMultiTankPressures`
   until expanded). Med.

- **S4 (DB/sync off the UI isolate)** — gated root-cause lever; evidence is strong;
  pursue with its own spec only if 1-5 leave a symptom unsolved.
- Consider **gating/deferring sync-on-resume** so a window focus doesn't trigger a
  main-isolate apply (largely subsumed if S3/S4 land).

### Method note
All numbers captured with `scratchpad/vmcap.dart` (VM Service over WebSocket: exact
`Flutter.Frame` build/raster + `getCpuSamples`). Browser-based DevTools could not be
driven (sandboxed browser cannot reach the host VM-service port); the shell could,
so profiling was scripted. CPU capture requires `setFlag('profiler','true')` +
`clearCpuSamples` immediately before the window, else the profiler's own JSON
serialization dominates the samples.
