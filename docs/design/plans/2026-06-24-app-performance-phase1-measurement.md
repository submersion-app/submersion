# App Performance — Phase 1 (Measurement) Implementation Plan

> **For agentic workers:** This plan is **executed interactively in the main session** (profile-mode app + DevTools + visual reading of flame charts and the Frames timeline). It is **not** suitable for subagent dispatch — a subagent cannot drive the DevTools GUI or read a flame chart. Use superpowers:executing-plans (inline, with checkpoints). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure the three performance symptoms (cold-start load, first dive-details lag, background-sync stutter) on macOS in profile mode, and produce a committed findings report that confirms/refutes each Section B avenue with real numbers and ranks them for Phase 2.

**Architecture:** Ad-hoc DevTools profiling — no instrumentation is added to the repo. Each scenario is run in `flutter run --profile`, captured via DevTools (Performance/CPU) or `--trace-startup`, and the numbers are recorded into a single findings document. The document's final section converts the measurements into a data-driven Phase 2 priority order.

**Tech Stack:** Flutter profile-mode builds, Dart DevTools (Performance view, CPU profiler), `flutter run --trace-startup`, macOS.

## Global Constraints

- **Profile mode only, never debug** — debug builds are 5-10x slower and would mis-rank culprits. Every measurement uses `--profile`.
- **Target platform: macOS** (the developer's everyday machine).
- **Densest dive for the worst-case render:** `0822a39f-26fd-4119-bdaa-673ea4562da3` (3,644 samples).
- **Known artificial startup floor:** ~1.9 s = 1 s hard minimum (`lib/core/presentation/pages/startup_page.dart:191`) + 900 ms fade (`:110`).
- **Findings report path:** `docs/superpowers/specs/2026-06-24-app-performance-findings.md`.
- **Do not commit incidental regenerated `.mocks.dart` files** (codegen side effects); stage only the findings report.
- **No `Co-Authored-By` trailer** in commits (developer preference).
- This phase changes **no application code** — only adds the findings document.

## Execution mode

Run the app from the worktree root:
`/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/app-performance-investigation`

Each scenario is a capture-and-record loop. The "test" for a measurement task is: *the report section now contains the recorded numbers and a verdict.* Commit after each scenario so partial progress is never lost.

---

### Task 1: Profiling environment + report scaffold

**Files:**
- Create: `docs/superpowers/specs/2026-06-24-app-performance-findings.md`

**Interfaces:**
- Produces: the findings document with an environment section and three empty scenario sections that Tasks 2-4 fill in, and a ranking section Task 5 completes.

- [ ] **Step 1: Confirm a profile build runs and record the build/device facts**

Run:
```bash
cd "/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/app-performance-investigation"
flutter --version
system_profiler SPDisplaysDataType | grep -iE "resolution|refresh|display type"
sw_vers
```
Record: Flutter version, macOS version, Mac model/chip, and **display refresh rate** (used to set the frame budget: 60 Hz → 16.7 ms/frame; 120 Hz ProMotion → 8.3 ms/frame).

- [ ] **Step 2: Launch the app in profile mode and confirm DevTools attaches**

Run:
```bash
flutter run --profile -d macos
```
In the run console, note the DevTools URL it prints (`The Flutter DevTools debugger and profiler ... available at: http://127.0.0.1:PORT?uri=...`). Open it. Confirm the **Performance** and **CPU profiler** tabs load. Leave this build running for Tasks 2-4 where possible (or relaunch per scenario as noted). Quit with `q` in the console when done.

- [ ] **Step 3: Create the findings report scaffold**

Create `docs/superpowers/specs/2026-06-24-app-performance-findings.md` with this content:

```markdown
# App Performance — Phase 1 Findings

**Date:** 2026-06-24
**Spec:** docs/superpowers/specs/2026-06-24-app-performance-investigation-design.md
**Mode:** profile, macOS

## Environment
- Flutter: <fill>
- macOS: <fill>
- Mac model/chip: <fill>
- Display refresh: <fill> Hz  → frame budget <fill> ms

## Scenario 1 — Cold start / load time
(filled by Task 2)

## Scenario 2 — First dive-details lag
(filled by Task 3)

## Scenario 3 — Background-sync stutter
(filled by Task 4)

## Avenue verdicts & Phase 2 ranking
(filled by Task 5)
```
Fill the Environment values from Steps 1-2.

- [ ] **Step 4: Verify the scaffold exists and commit**

Run:
```bash
git add docs/superpowers/specs/2026-06-24-app-performance-findings.md
git status -s -- docs/superpowers/specs/2026-06-24-app-performance-findings.md   # expect: A  ...findings.md
git commit -F - <<'MSG'
docs: app performance findings scaffold + measurement environment

Phase 1 measurement runbook output. Records the profiling environment
(Flutter/macOS/chip/display refresh + frame budget) and scaffolds the
three scenario sections.
MSG
```
Expected: one file changed; no `.mocks.dart` in the commit.

---

### Task 2: Scenario 1 — cold-start / load time

**Files:**
- Modify: `docs/superpowers/specs/2026-06-24-app-performance-findings.md` (Scenario 1 section)

**Interfaces:**
- Consumes: the report scaffold from Task 1.
- Produces: cold-start numbers + a "floor vs real init" verdict for avenues L1-L4.

- [ ] **Step 1: Capture engine startup timing**

Run:
```bash
flutter run --profile --trace-startup -d macos
```
Let the app reach the dashboard, then quit (`q`). Read the summary:
```bash
cat build/start_up_info.json
```
Record these fields (microseconds): `engineEnterTimestampMicros`, `timeToFrameworkInitMicros`, `timeToFirstFrameRasterizedMicros`, `timeToFirstFrameMicros`, `timeAfterFrameworkInitMicros`.

- [ ] **Step 2: Capture perceived time-to-interactive (the number users feel)**

`timeToFirstFrameMicros` is the *splash* frame, not the usable dashboard. Measure splash-appear → dashboard-usable separately:
- Start a screen recording (`Cmd-Shift-5`), cold-launch the profile build, stop when the dashboard's dives/stats are populated (not skeleton).
- Step through the recording to get the wall-clock seconds. Do this **3 times** and record min/median/max.

- [ ] **Step 3: CPU-profile the init work**

Relaunch `flutter run --profile -d macos`, open DevTools → CPU profiler, record across a cold start (or use the saved `--trace-startup` timeline in the Performance tab). Identify the time spent in: `NativeDatabase` open, the migration/`PRAGMA user_version` probes, and `SpeciesRepository.seedBuiltInSpecies` / the species JSON parse. Record the top 5 init hot spots with their self-times.

- [ ] **Step 4: Record results + verdict in the report**

Append under `## Scenario 1`:
```markdown
### Numbers
| Metric | Value |
| --- | --- |
| timeToFirstFrameMicros | <fill> |
| timeToFirstFrameRasterizedMicros | <fill> |
| timeToFrameworkInitMicros | <fill> |
| Perceived time-to-interactive (min/median/max, 3 runs) | <fill> |
| Top init hot spots (self-time) | <fill list> |

### Verdict
- Real init work vs the ~1.9 s artificial floor: <shorter | longer> by <fill>.
- L1 (splash floor): <confirmed dominant | not dominant> — evidence: <fill>.
- L2 (species re-seed): species-seed self-time = <fill> ms → <worth fixing | negligible>.
- L3 (redundant opens) / L4 (serial pre-runApp awaits): <fill from hot spots>.
```

- [ ] **Step 5: Commit**

Run:
```bash
git add docs/superpowers/specs/2026-06-24-app-performance-findings.md
git commit -m "docs: cold-start measurement findings (scenario 1)"
```

---

### Task 3: Scenario 2 — first dive-details lag

**Files:**
- Modify: `docs/superpowers/specs/2026-06-24-app-performance-findings.md` (Scenario 2 section)

**Interfaces:**
- Consumes: the report from Task 2.
- Produces: cold/warm open numbers, a build-vs-raster verdict, and a hot-spot list for avenues D1-D4.

- [ ] **Step 1: Cold open of the densest dive**

With `flutter run --profile -d macos` running and DevTools → Performance open:
- Press **Record**.
- From a freshly launched app (first navigation this session), tap the dive with the **longest profile** — the 3,644-sample dive (`0822a39f-26fd-4119-bdaa-673ea4562da3`; it is the longest/deepest in the list).
- Stop recording once the details page + chart are fully painted.

Read the **Frames** chart for the frame(s) spanning the navigation: record total frame time, **UI/build ms**, **raster ms**, and how many frames exceeded the budget from Task 1.

- [ ] **Step 2: Warm re-open of the same dive**

Navigate back to the list, **Record** again, re-open the same dive, stop. Record the same UI-build / raster / over-budget-frame numbers. The **cold − warm** delta isolates cold-cache/query cost; the warm cost isolates per-build chart + compute.

- [ ] **Step 3: CPU profiler on the open**

Switch to the CPU profiler, record one more open of the dive, and read **Bottom Up**. Record the top 8 functions by self-time. Note specifically the cost of: the provider fan-out queries (look for `DiveRepository` / `tankPressures` / `profileAnalysis` / `cylinderSac` / `weeklyOtu` / tide), `FlSpot` construction, and the chart's `reduce`/`sort`/`min`/`max` passes.

- [ ] **Step 4: Contrast with a typical dive**

Repeat Step 1 (cold open) with a typical ~1,100-sample dive. Record its UI-build/raster numbers to confirm the cost scales with sample density.

- [ ] **Step 5: Record results + verdict in the report**

Append under `## Scenario 2`:
```markdown
### Numbers
| Dive | Open | UI/build ms | Raster ms | Over-budget frames |
| --- | --- | --- | --- | --- |
| densest (3,644) | cold | <fill> | <fill> | <fill> |
| densest (3,644) | warm | <fill> | <fill> | <fill> |
| typical (~1,100) | cold | <fill> | <fill> | <fill> |

Top CPU self-time (densest open): <fill list of 8>

### Verdict
- Build-bound or raster-bound? <build | raster | mixed> — evidence: <fill>.
- First-open-only or every-time? cold−warm delta = <fill> → <fill interpretation>.
- D1 (chart memoize/decimate): <confirmed primary | secondary> — <build vs raster implication for the fix>.
- D2 (lazy below-the-fold queries): provider-query share of build = <fill>.
- D4 (media decode): <observed | not a factor>.
```

- [ ] **Step 6: Commit**

Run:
```bash
git add docs/superpowers/specs/2026-06-24-app-performance-findings.md
git commit -m "docs: dive-details lag measurement findings (scenario 2)"
```

---

### Task 4: Scenario 3 — background-sync stutter

**Files:**
- Modify: `docs/superpowers/specs/2026-06-24-app-performance-findings.md` (Scenario 3 section)

**Interfaces:**
- Consumes: the report from Task 3.
- Produces: frame-drop numbers during a sync/import apply and rebuild-storm evidence for avenues S1-S3.

- [ ] **Step 1: Stage an inbound change to apply**

Pick the available repro:
- **Faithful (preferred if sync is configured):** on a second device/instance signed into the same backend, edit several dives, then return to the Mac.
- **Local proxy (no second device):** prepare a UDDF or dive-computer file containing a handful of dives to import (additive, non-destructive). This exercises the same `tableUpdates` rebuild-storm + row-by-row write path that inbound sync apply triggers.

- [ ] **Step 2: Record the apply**

With `flutter run --profile -d macos` running and DevTools → Performance recording:
- Faithful: trigger **Sync Now** (Settings → Cloud Sync) and let the inbound changeset apply.
- Proxy: run the import.
Keep the dive list (or dashboard) visible during apply so the rebuild storm hits visible widgets. Stop recording when the apply completes.

- [ ] **Step 3: Read the Frames timeline for the storm**

Record: number of janky (over-budget) frames during apply, the worst frame's UI-build ms, and — from the timeline events — how many times `getAllDives` / `getStatistics` re-run during the single apply (the rebuild storm signature). Note whether `divesProvider` and the list notifier both reload per tick.

- [ ] **Step 4: CPU profiler on the apply (if faithful sync)**

If using the faithful path, record a CPU profile during apply and note the main-isolate self-time in JSON decode (`decodeChangeset`), checksum (`sha256`), and merge (`_mergeEntity`) plus the row-by-row `upsert`. (The import proxy will show the write + rebuild cost but not the decode/merge stages.)

- [ ] **Step 5: Record results + verdict in the report**

Append under `## Scenario 3`:
```markdown
### Numbers
| Metric | Value |
| --- | --- |
| Repro used | <faithful sync | import proxy> |
| Janky frames during apply | <fill> |
| Worst frame UI/build ms | <fill> |
| getAllDives / getStatistics re-runs per apply | <fill> |
| Main-isolate decode/checksum/merge self-time (faithful only) | <fill> |

### Verdict
- S1 (debounce rebuild storm): <confirmed primary cause | secondary> — re-run count = <fill>.
- S2 (batch writes): row-by-row write share = <fill>.
- S3 (offload sync CPU): decode/merge main-isolate time = <fill> → <worth offloading | minor>.
```

- [ ] **Step 6: Commit**

Run:
```bash
git add docs/superpowers/specs/2026-06-24-app-performance-findings.md
git commit -m "docs: sync-stutter measurement findings (scenario 3)"
```

---

### Task 5: Synthesize findings and rank Phase 2

**Files:**
- Modify: `docs/superpowers/specs/2026-06-24-app-performance-findings.md` (ranking section)

**Interfaces:**
- Consumes: the three completed scenario sections.
- Produces: a confirmed/refuted verdict per Section B avenue and an ordered Phase 2 backlog with the measured number that justifies each.

- [ ] **Step 1: Mark each avenue confirmed / refuted / unknown**

Append under `## Avenue verdicts & Phase 2 ranking`:
```markdown
### Avenue verdicts (from measured numbers)
| Avenue | Status | Justifying number |
| --- | --- | --- |
| L1 splash floor | <confirmed/refuted> | <fill> |
| L2 species re-seed | <confirmed/refuted> | <fill> |
| L3 redundant opens | <confirmed/refuted> | <fill> |
| L4 pre-runApp awaits | <confirmed/refuted> | <fill> |
| D1 chart memoize/decimate | <confirmed/refuted> | <fill> |
| D2 lazy sections | <confirmed/refuted> | <fill> |
| D4 media decode | <confirmed/refuted> | <fill> |
| S1 debounce storm | <confirmed/refuted> | <fill> |
| S2 batch writes | <confirmed/refuted> | <fill> |
| S3 offload sync CPU | <confirmed/refuted> | <fill> |
| S4 DB off UI isolate | <still gated — pursue only if above fall short> | <fill> |
```

- [ ] **Step 2: Produce the ordered Phase 2 backlog**

Append:
```markdown
### Phase 2 priority order
1. <avenue> — expected win <fill>, risk <fill>
2. ...
(Each entry becomes its own writing-plans round with before/after re-measurement.)
```
Order by measured impact × inverse risk. Demote any avenue the data refuted.

- [ ] **Step 3: Final commit**

Run:
```bash
git add docs/superpowers/specs/2026-06-24-app-performance-findings.md
git commit -m "docs: phase 1 findings synthesis + phase 2 ranking"
```

- [ ] **Step 4: Report completion**

State the confirmed top avenues and their numbers, and recommend the first Phase 2 plan to write.

---

## Self-Review

**Spec coverage:** Section A's three scenarios → Tasks 2/3/4. The findings-report deliverable → Tasks 1-5. Section B's avenues → verdict rows in Tasks 2-5. Section C's "proof-by-measurement" gate → the verdict/ranking in Task 5 that every Phase 2 plan must cite. The architectural lever S4 is explicitly kept gated (Task 5, Step 1). No spec section is unaddressed for Phase 1.

**Placeholder scan:** `<fill>` markers are measurement capture fields — the *deliverable* of a measurement task, not undefined behavior. Every step gives an exact command or exact DevTools action; no vague "profile it" instructions remain.

**Type/name consistency:** File path `docs/superpowers/specs/2026-06-24-app-performance-findings.md` is identical across all five tasks. Section headers (`## Scenario 1/2/3`, `## Avenue verdicts & Phase 2 ranking`) created in Task 1 match those appended to in Tasks 2-5. The densest-dive id matches the spec.

**Scope:** Phase 1 only, by design (the spec's measure-before-fix gate). Phase 2 fixes are deliberately out of scope and become separate writing-plans rounds grounded in this report.
